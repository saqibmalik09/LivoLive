import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/game_overlay_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/util/app_constants.dart';
import 'package:sk_live/core/util/baishun_game.dart';
import 'package:sk_live/core/util/baishun_launch.dart';
import 'package:sk_live/core/util/tulasi_game.dart';
import 'package:sk_live/core/util/wave_game.dart';
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

  final wave = isWaveGameConfig(gameConfig) || isWaveGameUrl(gameUrl);
  final tulasi =
      !wave && (isTulasiGameUrl(gameUrl) || isTulasiGameConfig(gameConfig));
  final baishun =
      !wave &&
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
  if (wave) {
    final token = currentSkAccessToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to play this game.')),
      );
      return;
    }
    finalUrl = openWavePlayUrl(gameUrl, token);
  } else if (tulasi) {
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

  final fallbackPct = wave
      ? 60.0
      : tulasi
      ? 55.0
      : baishun
      ? 95.0
      : 70.0;
  final pct = (heightPercent ?? fallbackPct).clamp(35.0, wave ? 100.0 : 95.0);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => H5GameWebViewSheet(
      url: finalUrl,
      wave: wave,
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
    this.wave = false,
    this.tulasi = false,
    this.baishun = false,
    this.landscape = false,
    this.roomId = kBaishunShowroomRoomId,
    this.gameMode = '2',
    this.supportZoom = true,
  });

  final String url;
  final double heightPercent;
  final bool wave;
  final bool tulasi;
  final bool baishun;
  final bool landscape;
  final String roomId;
  final String gameMode;

  final bool supportZoom;

  @override
  State<H5GameWebViewSheet> createState() => _H5GameWebViewSheetState();
}

const Duration _kBaishunSlowAfter = Duration(seconds: 25);

class _H5GameWebViewSheetState extends State<H5GameWebViewSheet> {
  InAppWebViewController? _controller;
  bool _baishunLoaded = false;

  BaishunLaunchSession _launch = BaishunLaunchSession();
  String? _baishunError;
  bool _baishunSlow = false;
  Timer? _slowTimer;

  bool _showLoading = true;
  Timer? _loadingTimer;

  final GlobalKey _webViewSlotKey = GlobalKey();

  ProviderContainer? _container;

  @override
  void initState() {
    super.initState();
    if (widget.baishun) {
      _launch.prefetch();
      _armSlowTimer();
    }
    _container = ProviderScope.containerOf(context, listen: false);
    final container = _container!;
    Future.microtask(() => _bumpOpenGames(container, 1));
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _loadingTimer?.cancel();
    final container = _container;
    if (container != null) {
      Future.microtask(() => _bumpOpenGames(container, -1));
    }
    super.dispose();
  }

  static void _bumpOpenGames(ProviderContainer container, int delta) {
    final notifier = container.read(gameOverlayOpenProvider.notifier);
    final next = notifier.state + delta;
    notifier.state = next < 0 ? 0 : next;
  }

  void _hideLoading() {
    _loadingTimer?.cancel();
    if (mounted && _showLoading) setState(() => _showLoading = false);
  }

  void _armSlowTimer() {
    _slowTimer?.cancel();
    _slowTimer = Timer(_kBaishunSlowAfter, () {
      if (mounted && !_baishunLoaded) setState(() => _baishunSlow = true);
    });
  }

  void _showBaishunError(String message) {
    if (!mounted || _baishunLoaded) return;
    _slowTimer?.cancel();
    setState(() => _baishunError = message);
  }

  Future<void> _retryBaishun() async {
    _loadingTimer?.cancel();
    setState(() {
      _baishunError = null;
      _baishunSlow = false;
      _baishunLoaded = false;
      _showLoading = true;
      _launch = BaishunLaunchSession()..prefetch();
    });
    _armSlowTimer();
    await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri(widget.url)));
  }

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
    if (widget.wave) {
      userScripts.add(
        UserScript(
          source: waveCloseBridgeJs,
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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Offstage(
                      offstage: !_showLoading,
                      child: const _GameLoading(),
                    ),
                  ),
                  Positioned.fill(
                    key: _webViewSlotKey,
                    child: _buildWebView(context, launchUri, userScripts),
                  ),
                  if (widget.baishun && _baishunError != null)
                    Positioned.fill(
                      child: _BaishunProblem(
                        message: _baishunError!,
                        onRetry: _retryBaishun,
                        onClose: () => Navigator.of(context).pop(),
                      ),
                    )
                  else if (widget.baishun && _baishunSlow && !_baishunLoaded)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: _BaishunSlowBar(
                        onRetry: _retryBaishun,
                        onClose: () => Navigator.of(context).pop(),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.baishun && !_baishunLoaded && _baishunError == null)
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

  Widget _buildWebView(
    BuildContext context,
    Uri? launchUri,
    List<UserScript> userScripts,
  ) {
    return InAppWebView(
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
        useWideViewPort: widget.tulasi || widget.baishun || widget.wave,
        loadWithOverviewMode: widget.tulasi || widget.baishun || widget.wave,
        thirdPartyCookiesEnabled: true,
        applicationNameForUserAgent: widget.wave ? 'SKLiveGames/1.0' : null,
        allowUniversalAccessFromFileURLs: widget.baishun,
        allowFileAccessFromFileURLs: widget.baishun,
        supportZoom: widget.supportZoom,
      ),
      onWebViewCreated: (controller) async {
        _controller = controller;
        if (widget.wave) {
          controller.addJavaScriptHandler(
            handlerName: 'waveGameClose',
            callback: (_) {
              if (context.mounted) Navigator.of(context).pop();
            },
          );
        }
        if (!widget.baishun || !context.mounted) return;
        await wireBaishunWebViewWithLaunch(
          controller: controller,
          context: context,
          roomId: widget.roomId,
          gameMode: widget.gameMode,
          session: () => _launch,
          onDestroy: () {
            if (mounted) Navigator.of(context).pop();
          },
          onGameLoaded: () {
            _slowTimer?.cancel();
            _loadingTimer?.cancel();
            if (mounted) {
              setState(() {
                _baishunLoaded = true;
                _baishunSlow = false;
                _baishunError = null;
                _showLoading = false;
              });
            }
          },
          onRecharge: _openWallet,
          onConfigFailed: () => _showBaishunError(
            'Could not connect to the game. Please check your '
            'internet and try again.',
          ),
        );
      },
      onReceivedError: (controller, request, error) {
        if (!widget.baishun || request.isForMainFrame != true) {
          return;
        }
        _showBaishunError(
          'The game could not be loaded. Please check your '
          'internet and try again.',
        );
      },
      onReceivedHttpError: (controller, request, response) {
        if (!widget.baishun || request.isForMainFrame != true) {
          return;
        }
        if ((response.statusCode ?? 0) < 400) return;
        _showBaishunError(
          'The game is not available right now. Please try again.',
        );
      },
      shouldOverrideUrlLoading: (controller, action) async {
        final navUrl = action.request.url?.toString() ?? '';
        if (widget.wave && isWaveCloseUrl(navUrl)) {
          if (context.mounted) Navigator.of(context).pop();
          return NavigationActionPolicy.CANCEL;
        }
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
          final patched = reattachTulasiLaunchQuery(navUrl, launchUri);
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
        _loadingTimer?.cancel();
        _loadingTimer = Timer(const Duration(seconds: 8), _hideLoading);
        if (widget.wave && isWaveCloseUrl(loadedUrl?.toString() ?? '')) {
          if (context.mounted) Navigator.of(context).pop();
          return;
        }
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
            Future<void>.delayed(const Duration(milliseconds: 400), () {
              controller.evaluateJavascript(source: tulasiPinGameContentTopJs);
            });
          }
          return;
        }
        if (widget.baishun || widget.wave) return;
        final accessToken =
            Supabase.instance.client.auth.currentSession?.accessToken;
        if (accessToken == null || accessToken.isEmpty) return;
        final expectedHost = Uri.tryParse(widget.url)?.host ?? '';
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
          debugPrint('[H5GameWebView] session inject failed: $e');
        }
      },
    );
  }
}

class _GameLoading extends StatelessWidget {
  const _GameLoading();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

class _BaishunProblem extends StatelessWidget {
  const _BaishunProblem({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Colors.white70,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: onClose,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BaishunSlowBar extends StatelessWidget {
  const _BaishunSlowBar({required this.onRetry, required this.onClose});

  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'The game is taking longer than usual.',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            TextButton(onPressed: onClose, child: const Text('Close')),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
