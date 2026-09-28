import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:sk_live/core/providers/party_events_provider.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/features/home/presentation/pages/party_event_content.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventWebViewScreen extends StatefulWidget {
  const EventWebViewScreen({super.key, required this.event});

  final PartyEvent event;

  @override
  State<EventWebViewScreen> createState() => _EventWebViewScreenState();
}

class _EventWebViewScreenState extends State<EventWebViewScreen> {
  double _progress = 0;
  bool _hasError = false;

  String _resolveWebUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme) return raw;
    if (uri.queryParameters.containsKey('event_id')) return uri.toString();
    return uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'event_id': widget.event.id,
          },
        )
        .toString();
  }

  Future<void> _injectSession(
    InAppWebViewController controller,
    WebUri? loadedUrl,
    String expectedUrl,
  ) async {
    final accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) return;
    final expectedHost = Uri.tryParse(expectedUrl)?.host ?? '';
    final host = loadedUrl?.host ?? '';
    if (expectedHost.isEmpty ||
        (host != expectedHost && !host.endsWith('.$expectedHost'))) {
      return;
    }
    final payload = jsonEncode({
      'access_token': accessToken,
      'gateway': AppConstants.realtimeGatewayUrl,
    });
    try {
      await controller.evaluateJavascript(
        source:
            '''
          (function(){
            try {
              window.__SK_SESSION = $payload;
              window.dispatchEvent(new CustomEvent('sklive-auth', { detail: window.__SK_SESSION }));
            } catch (e) {}
          })();
        ''',
      );
    } catch (e) {
      debugPrint('[EventWebView] session inject failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = PartyEventContent.fromEvent(widget.event);
    final url = _resolveWebUrl(content.webUrl);

    if (url.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(content.pageTitle),
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
        ),
        body: const Center(
          child: Text(
            'Event URL not configured.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          content.pageTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        bottom: _progress < 1 && !_hasError
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.transparent,
                  color: AppColors.primary,
                ),
              )
            : null,
      ),
      body: _hasError
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could not load event page.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(() => _hasError = false),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(url)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                supportZoom: false,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
              ),
              onProgressChanged: (_, progress) {
                setState(() => _progress = progress / 100);
              },
              onReceivedError: (_, _, _) {
                if (mounted) setState(() => _hasError = true);
              },
              onLoadStop: (controller, loadedUrl) async {
                await _injectSession(controller, loadedUrl, url);
              },
            ),
    );
  }
}
