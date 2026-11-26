import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/util/app_image_cache.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:sk_live/core/util/number_formatter.dart';

class RoomBonusPattiData {
  const RoomBonusPattiData({
    required this.senderId,
    required this.username,
    required this.avatarUrl,
    required this.giftIcon,
    required this.subtitle,
    required this.comboCount,
    required this.bonusCoins,
    required this.isLuckyPro,
    this.bonusMultiplier = 1,
  });

  final String senderId;
  final String username;
  final String? avatarUrl;
  final String? giftIcon;
  final String subtitle;
  final int comboCount;
  final int bonusCoins;
  final bool isLuckyPro;

  /// What the roll paid relative to the gift's value, shown as "x25".
  final int bonusMultiplier;

  RoomBonusPattiData copyWith({
    String? username,
    String? avatarUrl,
    String? giftIcon,
    String? subtitle,
    int? comboCount,
    int? bonusCoins,
    bool? isLuckyPro,
    int? bonusMultiplier,
  }) {
    return RoomBonusPattiData(
      senderId: senderId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      giftIcon: giftIcon ?? this.giftIcon,
      subtitle: subtitle ?? this.subtitle,
      comboCount: comboCount ?? this.comboCount,
      bonusCoins: bonusCoins ?? this.bonusCoins,
      isLuckyPro: isLuckyPro ?? this.isLuckyPro,
      bonusMultiplier: bonusMultiplier ?? this.bonusMultiplier,
    );
  }
}

class RoomBonusPattiOverlay extends StatefulWidget {
  const RoomBonusPattiOverlay({
    super.key,
    required this.data,
    required this.visible,
    this.onDismissed,
  });

  final RoomBonusPattiData data;
  final bool visible;
  final VoidCallback? onDismissed;

  static const asset = 'assets/room/bonuspatti.webp';

  @override
  State<RoomBonusPattiOverlay> createState() => _RoomBonusPattiOverlayState();
}

class _RoomBonusPattiOverlayState extends State<RoomBonusPattiOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _comboPop;
  late final AnimationController _coinsPop;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  late final Animation<double> _comboScale;
  late final Animation<double> _coinsScale;
  bool _notifiedDismiss = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 420),
    );
    _comboPop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _coinsPop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _slide = Tween<Offset>(begin: const Offset(-1.15, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _comboScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.45,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.45,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_comboPop);
    _coinsScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.38,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.38,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_coinsPop);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !_notifiedDismiss) {
        _notifiedDismiss = true;
        widget.onDismissed?.call();
      }
    });
    if (widget.visible) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant RoomBonusPattiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _notifiedDismiss = false;
      _controller.forward(from: 0);
    } else if (!widget.visible && oldWidget.visible) {
      _controller.reverse();
    }

    if (widget.data.comboCount > oldWidget.data.comboCount) {
      _comboPop.forward(from: 0);
    }
    if (widget.data.bonusCoins > oldWidget.data.bonusCoins) {
      _coinsPop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _comboPop.dispose();
    _coinsPop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final barW = (size.width * 0.94).clamp(300.0, 420.0);

    const nativeAspect = 720 / 220;
    final barH = barW / nativeAspect;
    final avatarSize = barH * 0.62;

    return Positioned(
      left: 0,
      right: 0,

      top: size.height * 0.58,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Center(
              child: SizedBox(
                width: barW,
                height: barH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: barW * 0.018,
                      top: (barH - avatarSize) / 2 - barH * 0.02,
                      width: avatarSize,
                      height: avatarSize,
                      child: _Avatar(url: widget.data.avatarUrl),
                    ),
                    Positioned.fill(
                      child: Image.asset(
                        RoomBonusPattiOverlay.asset,
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.centerLeft,
                        filterQuality: FilterQuality.high,
                      ),
                    ),

                    Positioned(
                      left: barW * 0.215,
                      top: barH * 0.42,
                      right: barW * 0.52,
                      child: Text(
                        widget.data.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                          shadows: [
                            Shadow(
                              color: Colors.black87,
                              blurRadius: 1,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      left: barW * 0.46,
                      width: barW * 0.20,
                      top: 0,
                      bottom: 0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.data.giftIcon != null &&
                                widget.data.giftIcon!.isNotEmpty) ...[
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CachedNetworkImage(
                                  // Gift sheet's cached rendition: on disk
                                  // already, so the icon is there as the
                                  // strip slides in.
                                  imageUrl:
                                      SupabaseImageTransform.url(
                                        widget.data.giftIcon!,
                                        width: 128,
                                        height: 128,
                                        resize: 'contain',
                                        quality: 75,
                                      ) ??
                                      widget.data.giftIcon!,
                                  cacheManager: AppImageCache.manager,
                                  fadeInDuration: Duration.zero,
                                  fit: BoxFit.contain,
                                  errorWidget: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(width: 3),
                            ],
                            ScaleTransition(
                              scale: _comboScale,
                              child: _Gradient3DText(
                                text: 'x${widget.data.comboCount}',
                                fontSize: 18,
                                colors: const [
                                  Color(0xFFE8FF9D),
                                  Color(0xFFB8FF3C),
                                  Color(0xFF7BCB00),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    Positioned(
                      right: barW * 0.065,
                      top: barH * 0.18,
                      width: barW * 0.24,
                      height: barH * 0.42,
                      child: Align(
                        alignment: Alignment.center,
                        child: ScaleTransition(
                          scale: _coinsScale,
                          child: _Gradient3DText(
                            text:
                                '+${NumberFormatter.format(widget.data.bonusCoins)}',
                            fontSize: 20,
                            colors: const [
                              Color(0xFFFFF4C2),
                              Color(0xFFFFD54F),
                              Color(0xFFFFA000),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // The multiplier the roll hit, under the coins: the room
                    // sees what the gift paid, not only how much.
                    if (widget.data.bonusMultiplier > 1)
                      Positioned(
                        right: barW * 0.065,
                        top: barH * 0.58,
                        width: barW * 0.24,
                        child: Align(
                          alignment: Alignment.center,
                          child: _Gradient3DText(
                            text: 'x${widget.data.bonusMultiplier}',
                            fontSize: 13,
                            colors: const [
                              Color(0xFFDFFBFF),
                              Color(0xFF7BE8FF),
                              Color(0xFF17A9E0),
                            ],
                          ),
                        ),
                      ),

                    Positioned(
                      right: barW * 0.012,
                      bottom: barH * 0.26,
                      width: barW * 0.15,
                      height: barH * 0.24,
                      child: Center(
                        child: Text(
                          widget.data.isLuckyPro ? 'Pro' : 'Lucky',
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFFFFF3C4),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            height: 1,
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 1,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Gradient3DText extends StatelessWidget {
  const _Gradient3DText({
    required this.text,
    required this.fontSize,
    required this.colors,
  });

  final String text;
  final double fontSize;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: -0.2,

      shadows: const [
        Shadow(color: Colors.black87, offset: Offset(0, 2), blurRadius: 1),
      ],
    );
    return ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: const [0.0, 0.5, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: url != null && url!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const ColoredBox(
                color: Colors.black45,
                child: Icon(Icons.person, color: Colors.white70, size: 22),
              ),
            )
          : const ColoredBox(
              color: Colors.black45,
              child: Icon(Icons.person, color: Colors.white70, size: 22),
            ),
    );
  }
}
