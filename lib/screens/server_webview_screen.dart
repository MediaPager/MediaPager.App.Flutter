import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';
import 'package:webview_all_android/webview_all_android.dart';
import 'package:webview_all_wkwebview/webview_all_wkwebview.dart';

import '../models/server_connection.dart';
import '../services/server_store.dart';

class ServerWebViewScreen extends StatefulWidget {
  const ServerWebViewScreen({
    super.key,
    required this.store,
    required this.server,
  });

  final ServerStore store;
  final ServerConnection server;

  @override
  State<ServerWebViewScreen> createState() => _ServerWebViewScreenState();
}

class _ServerWebViewScreenState extends State<ServerWebViewScreen> {
  WebViewController? _controller;
  String? _error;
  bool _connecting = true;
  int _progress = 0;

  bool get _isMobilePlatform =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    if (mounted) {
      setState(() {
        _connecting = true;
        _error = null;
      });
    }

    try {
      final session = await widget.store.refreshMobileSession(widget.server);

      final PlatformWebViewControllerCreationParams creationParams =
          WebViewPlatform.instance is WebKitWebViewPlatform
          ? WebKitWebViewControllerCreationParams(
              mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
              allowsInlineMediaPlayback: true,
            )
          : const PlatformWebViewControllerCreationParams();
      final controller = WebViewController.fromPlatformCreationParams(
        creationParams,
      );
      if (controller.platform is AndroidWebViewController) {
        await (controller.platform as AndroidWebViewController)
            .setMediaPlaybackRequiresUserGesture(false);
      }
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (_isMobilePlatform) {
        await controller.addJavaScriptChannel(
          'MediaPagerApp',
          onMessageReceived: (message) {
            if (!mounted) return;
            switch (message.message) {
              case 'refresh':
                controller.reload();
                break;
              case 'backToServers':
                Navigator.of(context).pop();
                break;
            }
          },
        );
      }
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _connecting = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _connecting = false);
          },
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == false || !mounted) return;
            setState(() {
              _connecting = false;
              _error = error.description.isEmpty
                  ? 'The MediaPager page could not be loaded.'
                  : error.description;
            });
          },
        ),
      );

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _connecting = true;
        _progress = 0;
      });

      final scopesValue = jsonEncode(session.scopes);
      final bootstrapPage =
          '''
<!doctype html>
<html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
<body><p style="font:16px sans-serif">Connecting to MediaPager…</p><script>
try {
  localStorage.setItem('mediapager.accessToken', ${_javascriptString(session.accessToken)});
  localStorage.setItem('mediapager.scopes', ${_javascriptString(scopesValue)});
  localStorage.setItem('mediapager.userEmail', ${_javascriptString(widget.server.username)});
  window.location.replace(${_javascriptString('${widget.server.url}/')});
} catch (error) {
  document.body.textContent = 'Could not prepare the MediaPager session: ' + error;
}
</script></body></html>
''';

      // Use a same-origin base URL so localStorage is available before the SPA's
      // JavaScript starts and reads its saved MediaPager session.
      await controller.loadHtmlString(
        bootstrapPage,
        baseUrl: '${widget.server.url}/__mediapager_app_bootstrap__/',
      );
    } on MobileSessionException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not connect: $error');
    } finally {
      if (mounted && _controller == null) setState(() => _connecting = false);
    }
  }

  String _javascriptString(String value) =>
      jsonEncode(value)
          .replaceAll('<', r'\u003C')
          .replaceAll('>', r'\u003E')
          .replaceAll('&', r'\u0026');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isMobilePlatform
          ? null
          : AppBar(
              leading: IconButton(
                tooltip: 'Back to servers',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                widget.server.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                IconButton(
                  tooltip: 'Reload server',
                  onPressed: _controller?.reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      body: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_connecting)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 18),
                          Text('Connecting to ${widget.server.nickname}…'),
                          if (_progress > 0) ...[
                            const SizedBox(height: 12),
                            LinearProgressIndicator(value: _progress / 100),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_error != null)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, size: 48),
                          const SizedBox(height: 16),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: _connect,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Try again'),
                              ),
                              if (_isMobilePlatform)
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Back to server list'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
