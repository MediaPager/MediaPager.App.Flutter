import 'package:flutter_test/flutter_test.dart';
import 'package:mediapager_app_flutter/models/server_connection.dart';
import 'package:mediapager_app_flutter/services/server_store.dart';

void main() {
  group('resolveApiBaseUrlResponse', () {
    test('uses the API URL advertised by the SPA', () {
      expect(
        resolveApiBaseUrlResponse(
          'https://frontend.example.com',
          '{"apiBaseUrl":"https://api.custom.example"}',
        ),
        'https://api.custom.example',
      );
    });

    test('resolves a relative API URL against the SPA origin', () {
      expect(
        resolveApiBaseUrlResponse(
          'https://media.example.com',
          '{"apiBaseUrl":"/"}',
        ),
        'https://media.example.com',
      );
    });

    test('accepts a plain-text API URL from the discovery route', () {
      expect(
        resolveApiBaseUrlResponse(
          'https://frontend.example.com',
          'https://api.custom.example',
        ),
        'https://api.custom.example',
      );
    });

    test('ignores an HTML SPA fallback response', () {
      expect(
        resolveApiBaseUrlResponse(
          'https://media.example.com',
          '<!doctype html><html><body>SPA</body></html>',
        ),
        isNull,
      );
    });
  });

  group('normalizeServerUrl', () {
    test('trims whitespace and trailing slash', () {
      expect(
        normalizeServerUrl('  https://media.example.com/  '),
        'https://media.example.com',
      );
    });

    test('allows HTTP for local MediaPager servers', () {
      expect(
        normalizeServerUrl('http://192.168.1.20:5000/'),
        'http://192.168.1.20:5000',
      );
      expect(
        normalizeServerUrl('http://mediapager.local'),
        'http://mediapager.local',
      );
    });

    test('allows HTTP for IPv4 and IPv6 literal server addresses', () {
      expect(
        normalizeServerUrl('http://203.0.113.25:5000'),
        'http://203.0.113.25:5000',
      );
      expect(
        normalizeServerUrl('http://[2001:db8::25]:5000'),
        'http://[2001:db8::25]:5000',
      );
    });

    test('requires HTTPS for internet-accessible servers', () {
      expect(
        () => normalizeServerUrl('http://media.example.com'),
        throwsFormatException,
      );
    });

    test('rejects credentials and query strings in the server address', () {
      expect(
        () => normalizeServerUrl('https://user:pass@media.example.com'),
        throwsFormatException,
      );
      expect(
        () => normalizeServerUrl('https://media.example.com/?token=secret'),
        throwsFormatException,
      );
    });
  });

  test('server connection profile round-trips its non-secret fields', () {
    const profile = ServerConnection(
      id: 'server-id',
      nickname: 'Home',
      url: 'https://media.example.com',
      username: 'viewer@example.com',
    );

    expect(
      ServerConnection.fromJson(profile.toJson()).toJson(),
      profile.toJson(),
    );
  });
}
