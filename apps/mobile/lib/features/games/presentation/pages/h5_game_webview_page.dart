import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/util/baishun_game.dart';
import 'package:sk_live/core/util/tulasi_game.dart';
import 'package:sk_live/features/wallet/presentation/pages/wallet_screen.dart';

void launchH5Game(
  BuildContext context, {
  required String name,
  required String gameUrl,
  bool maintenanceMode = false,
  String? maintenanceMessage,
  Map<String, dynamic>? gameConfig,
  double? heightPercent,
  String? roomId,
  String? gameMode,
}) {
  if (maintenanceMode) {
    final msg = maintenanceMessage?.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (msg != null && msg.isNotEmpty)
              ? msg
              : 'This game is under maintenance. Please try again later.',
        ),
      ),
    );
    return;
  }

  final tulasi = isTulasiGameUrl(gameUrl) || isTulasiGameConfig(gameConfig);
  final baishun =
      !tulasi &&
      (isBaishunGameConfig(gameConfig) ||
          isBaishunGameUrl(gameUrl) ||
          isBaishunGameUrl(
            resolveBaishunGameUrl(gameConfig, fallbackUrl: gameUrl),
          ));
  final landscape =
      tulasi && isTulasiLandscape(gameConfig) ||
      baishun && isBaishunLandscape(gameConfig);

  late final String finalUrl;
  if (tulasi) {
    final token = currentSkAccessToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to play this game.')),
      );
      return;
    }
    finalUrl = buildTulasiLaunchUrl(
      gameUrl,
      token: token,
      lang: tulasiLangCode(context),
      isLandscape: landscape,
    );
  } else if (baishun) {
    final token = currentSkAccessToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to play this game.')),
      );
      return;
    }
    finalUrl = resolveBaishunGameUrl(gameConfig, fallbackUrl: gameUrl);
    if (finalUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Game URL is not configured.')),
      );
      return;
    }
  } else {
    final uri = Uri.parse(gameUrl);
    finalUrl = uri
        .replace(
          queryParameters: {
            ...uri.queryParameters,
            'gateway': AppConstants.realtimeGatewayUrl,
          },
        )
        .toString();
  }

  final fallbackPct = tulasi
      ? 55.0
      : baishun
      ? 95.0
      : 70.0;
  final pct = (heightPercent ?? fallbackPct).clamp(35.0, 95.0);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => H5GameWebViewSheet(
      url: finalUrl,
      tulasi: tulasi,
      baishun: baishun,
      landscape: landscape,
      heightPercent: pct,
      roomId: roomId ?? kBaishunShowroomRoomId,
      gameMode: gameMode ?? (roomId != null ? '3' : '2'),
    ),
  );
}

class H5GameWebViewSheet extends StatefulWidget {
  const H5GameWebViewSheet({
    super.key,
    required this.url,
    required this.heightPercent,
    this.tulasi = false,
    this.baishun = false,
    this.landscape = false,
    this.roomId = kBaishunShowroomRoomId,
    this.gameMode = '2',
  });

  final String url;
  final double heightPercent;
  final bool tulasi;
  final bool baishun;
  final bool landscape;
  final String roomId;
  final String gameMode;

  @override
  State<H5GameWebViewSheet> createState() => _H5GameWebViewSheetState();
}

class _H5GameWebViewSheetState extends State<H5GameWebViewSheet> {
  InAppWebViewController? _controller;
  bool _baishunLoaded = false;

  Future<void> _openWallet() async {
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WalletScreen()));
    if (!mounted || _controller == null || !widget.baishun) return;
    final userId = await baishunUserIdForWallet();
    if (userId != null && userId.isNotEmpty) {
      await notifyBaishunWalletUpdate(_controller!, userId: userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final launchUri = Uri.tryParse(widget.url);
    final userScripts = <UserScript>[];
    if (widget.tulasi && !widget.landscape) {
      userScripts.add(
        UserScript(
          source: tulasiPortraitOrientationSpoofJs,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      );
    }
    if (widget.baishun) {
      userScripts.add(
        UserScript(
          source: baishunNativeBridgeBootstrapJs,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      );
    }

    return Container(
      height:
          MediaQuery.sizeOf(context).height * (widget.heightPercent / 100.0),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                initialUserScripts: userScripts.isEmpty
                    ? null
                    : UnmodifiableListView<UserScript>(userScripts),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                  transparentBackground: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  useHybridComposition: true,
                  useShouldOverrideUrlLoading: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  useWideViewPort: widget.tulasi || widget.baishun,
                  loadWithOverviewMode: widget.tulasi || widget.baishun,
                  allowUniversalAccessFromFileURLs: widget.baishun,
                  allowFileAccessFromFileURLs: widget.baishun,
                ),
                onWebViewCreated: (controller) async {
                  _controller = controller;
                  if (!widget.baishun || !context.mounted) return;
                  await wireBaishunWebView(
                    controller: controller,
                    context: context,
                    roomId: widget.roomId,
                    gameMode: widget.gameMode,
                    onDestroy: () {
                      if (mounted) Navigator.of(context).pop();
                    },
                    onGameLoaded: () {
                      if (mounted) setState(() => _baishunLoaded = true);
                    },
                    onRecharge: _openWallet,
                  );
                },
                shouldOverrideUrlLoading: (controller, action) async {
                  final navUrl = action.request.url?.toString() ?? '';
                  final proto = tulasiProtocolFromUrl(navUrl);
                  if (proto == TulasiWebProtocol.exit) {
                    if (context.mounted) Navigator.of(context).pop();
                    return NavigationActionPolicy.CANCEL;
                  }
                  if (proto == TulasiWebProtocol.recharge) {
                    await _openWallet();
                    return NavigationActionPolicy.CANCEL;
                  }
                  if (widget.tulasi && launchUri != null) {
                    final patched = reattachTulasiLaunchQuery(
                      navUrl,
                      launchUri,
                    );
                    if (patched != null) {
                      await controller.loadUrl(
                        urlRequest: URLRequest(url: WebUri(patched)),
                      );
                      return NavigationActionPolicy.CANCEL;
                    }
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                onLoadStop: (controller, loadedUrl) async {
                  if (widget.tulasi) {
                    if (launchUri != null) {
                      final patched = reattachTulasiLaunchQuery(
                        loadedUrl?.toString() ?? '',
                        launchUri,
                      );
                      if (patched != null) {
                        await controller.loadUrl(
                          urlRequest: URLRequest(url: WebUri(patched)),
                        );
                        return;
                      }
                    }
                    if (!widget.landscape) {
                      await controller.evaluateJavascript(
                        source: tulasiPinGameContentTopJs,
                      );
                      Future<void>.delayed(
                        const Duration(milliseconds: 400),
                        () {
                          controller.evaluateJavascript(
                            source: tulasiPinGameContentTopJs,
                          );
                        },
                      );
                    }
                    return;
                  }
                  if (widget.baishun) return;
                  final accessToken =
                      Supabase.instance.client.auth.currentSession?.accessToken;
                  if (accessToken == null || accessToken.isEmpty) return;
                  final expectedHost = Uri.tryParse(widget.url)?.host ?? '';
                  final host = loadedUrl?.host ?? '';
                  if (expectedHost.isEmpty ||
                      (host != expectedHost &&
                          !host.endsWith('.$expectedHost'))) {
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
                    debugPrint('[H5GameWebView] session inject failed: $e');
                  }
                },
              ),
            ),
            if (widget.baishun && !_baishunLoaded)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
