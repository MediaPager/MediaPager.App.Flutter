import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/server_connection.dart';

class ServerStore extends ChangeNotifier {
  ServerStore()
    : _storage = const FlutterSecureStorage(
        mOptions: MacOsOptions(usesDataProtectionKeychain: false),
      );

  static const _serversKey = 'mediapager.servers';
  static const _defaultServerKey = 'mediapager.defaultServerId';
  static const _refreshTokenPrefix = 'mediapager.mobileRefreshToken.';

  final FlutterSecureStorage _storage;
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  final List<ServerConnection> _servers = [];
  String? _defaultServerId;

  List<ServerConnection> get servers => List.unmodifiable(_servers);
  String? get defaultServerId => _defaultServerId;
  ServerConnection? get defaultServer {
    for (final server in _servers) {
      if (server.id == _defaultServerId) return server;
    }
    return null;
  }

  Future<void> load() async {
    final raw = await _preferences.getString(_serversKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _servers
          ..clear()
          ..addAll(
            decoded.map(
              (item) => ServerConnection.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            ),
          );
      } on FormatException {
        _servers.clear();
      } on TypeError {
        _servers.clear();
      }
    }

    _defaultServerId = await _preferences.getString(_defaultServerKey);
    if (!_servers.any((server) => server.id == _defaultServerId)) {
      _defaultServerId = null;
      await _preferences.remove(_defaultServerKey);
    }
    notifyListeners();
  }

  Future<ServerConnection> saveServer({
    String? id,
    required String nickname,
    required String url,
    required String username,
    required String password,
  }) async {
    final existingIndex = id == null
        ? -1
        : _servers.indexWhere((item) => item.id == id);
    final serverId = id ?? const Uuid().v4();
    final profile = ServerConnection(
      id: serverId,
      nickname: nickname.trim(),
      url: normalizeServerUrl(url),
      username: username.trim(),
    );

    final existingProfile = existingIndex < 0 ? null : _servers[existingIndex];
    final oldRefreshToken = existingProfile == null
        ? null
        : await _storage.read(key: '$_refreshTokenPrefix$serverId');
    final changedLogin =
        existingProfile == null ||
        existingProfile.url != profile.url ||
        existingProfile.username != profile.username;

    String refreshToken;
    if (password.isNotEmpty) {
      final session = await _createMobileSession(
        profile,
        password,
        deviceName:
            'MediaPager ${defaultTargetPlatform.name} · ${profile.nickname}',
      );
      refreshToken = session.refreshToken;
    } else if (existingProfile != null &&
        !changedLogin &&
        oldRefreshToken != null) {
      refreshToken = oldRefreshToken;
    } else {
      throw ArgumentError(
        'Enter your password to sign in or update this server connection.',
      );
    }

    await _storage.write(
      key: '$_refreshTokenPrefix$serverId',
      value: refreshToken,
    );
    if (oldRefreshToken != null &&
        oldRefreshToken != refreshToken &&
        existingProfile != null) {
      await _revokeRefreshToken(existingProfile.url, oldRefreshToken);
    }
    if (existingIndex < 0) {
      _servers.add(profile);
    } else {
      _servers[existingIndex] = profile;
    }
    await _persistServers();

    if (_defaultServerId == null) {
      await setDefaultServer(serverId);
    } else {
      notifyListeners();
    }
    return profile;
  }

  Future<MobileAppSession> refreshMobileSession(ServerConnection server) async {
    final refreshToken = await _storage.read(
      key: '$_refreshTokenPrefix${server.id}',
    );
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const MobileSessionException(
        'Sign in to this server again to continue.',
      );
    }
    final response = await _postJson(
      server.url,
      '/auth/mobile-sessions/refresh',
      {'refreshToken': refreshToken},
    );
    final session = MobileAppSession.fromJson(response);
    await _storage.write(
      key: '$_refreshTokenPrefix${server.id}',
      value: session.refreshToken,
    );
    return session;
  }

  Future<void> setDefaultServer(String? id) async {
    if (id != null && !_servers.any((server) => server.id == id)) {
      throw ArgumentError('The default server must be a saved connection.');
    }
    _defaultServerId = id;
    if (id == null) {
      await _preferences.remove(_defaultServerKey);
    } else {
      await _preferences.setString(_defaultServerKey, id);
    }
    notifyListeners();
  }

  Future<void> removeServer(ServerConnection server) async {
    final refreshToken = await _storage.read(
      key: '$_refreshTokenPrefix${server.id}',
    );
    if (refreshToken != null) {
      await _revokeRefreshToken(server.url, refreshToken);
    }
    _servers.removeWhere((item) => item.id == server.id);
    await _storage.delete(key: '$_refreshTokenPrefix${server.id}');
    await _persistServers();
    if (_defaultServerId == server.id) {
      await setDefaultServer(_servers.isEmpty ? null : _servers.first.id);
    } else {
      notifyListeners();
    }
  }

  Future<void> _persistServers() => _preferences.setString(
    _serversKey,
    jsonEncode(_servers.map((server) => server.toJson()).toList()),
  );

  Future<MobileAppSession> _createMobileSession(
    ServerConnection server,
    String password, {
    required String deviceName,
  }) async {
    final response = await _postJson(server.url, '/auth/mobile-sessions', {
      'email': server.username,
      'password': password,
      'deviceName': deviceName,
    });
    return MobileAppSession.fromJson(response);
  }

  Future<void> _revokeRefreshToken(
    String serverUrl,
    String refreshToken,
  ) async {
    try {
      await _postJson(serverUrl, '/auth/mobile-sessions/revoke', {
        'refreshToken': refreshToken,
      });
    } catch (_) {
      // Local removal must still work when a server is offline or unreachable.
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String serverUrl,
    String path,
    Map<String, Object?> body,
  ) async {
    final apiBaseUrl = await _apiBaseUrl(serverUrl);
    final uri = _appendApiPath(apiBaseUrl, path);
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) {
      throw const MobileSessionException(
        'The server did not accept these credentials or the app session has expired.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? error;
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        error = json['error'] as String? ?? json['detail'] as String?;
      } catch (_) {
        error = null;
      }
      throw MobileSessionException(
        error ?? 'The server returned HTTP ${response.statusCode}.',
      );
    }
    if (response.body.isEmpty) return <String, dynamic>{};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<String> _apiBaseUrl(String serverUrl) async {
    final site = Uri.parse(serverUrl);
    try {
      final response = await http
          .get(site.resolve('/runtime-config.json'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final config = jsonDecode(response.body) as Map<String, dynamic>;
        final configured = config['apiBaseUrl'] as String?;
        if (configured != null && configured.trim().isNotEmpty) {
          return site.resolve(configured.trim()).toString();
        }
      }
    } catch (_) {
      // Most single-origin installs don't publish runtime-config.json.
    }
    return serverUrl;
  }

  Uri _appendApiPath(String baseUrl, String path) {
    final base = Uri.parse(baseUrl);
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    final endpoint = path.startsWith('/') ? path.substring(1) : path;
    return base.replace(
      path: '$basePath$endpoint',
      query: null,
      fragment: null,
    );
  }
}

class MobileAppSession {
  const MobileAppSession({
    required this.accessToken,
    required this.refreshToken,
    required this.sessionId,
    required this.scopes,
  });

  final String accessToken;
  final String refreshToken;
  final String sessionId;
  final List<String> scopes;

  factory MobileAppSession.fromJson(Map<String, dynamic> json) =>
      MobileAppSession(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        sessionId: json['sessionId'] as String,
        scopes: (json['scopes'] as List<dynamic>? ?? const []).cast<String>(),
      );
}

class MobileSessionException implements Exception {
  const MobileSessionException(this.message);
  final String message;

  @override
  String toString() => message;
}

String normalizeServerUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      !const {'http', 'https'}.contains(uri.scheme.toLowerCase())) {
    throw const FormatException(
      'Enter a valid server address beginning with http:// or https://.',
    );
  }
  if (uri.userInfo.isNotEmpty ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    throw const FormatException(
      'Enter the server address only, without credentials or query parameters.',
    );
  }
  if (uri.scheme.toLowerCase() == 'http' && !_isLocalServerHost(uri.host)) {
    throw const FormatException(
      'Use HTTPS for internet-accessible servers. HTTP is supported for local network servers.',
    );
  }
  return uri
      .replace(path: '', query: null, fragment: null)
      .toString()
      .replaceFirst(RegExp(r'/$'), '');
}

bool _isLocalServerHost(String host) {
  final value = host.toLowerCase();
  if (value == 'localhost' ||
      value.endsWith('.localhost') ||
      value.endsWith('.local') ||
      !value.contains('.')) {
    return true;
  }
  // Permit HTTP for IP-literal servers (including private/local ranges) so
  // self-hosted instances can be reached directly without a DNS hostname.
  return InternetAddress.tryParse(value) != null;
}
