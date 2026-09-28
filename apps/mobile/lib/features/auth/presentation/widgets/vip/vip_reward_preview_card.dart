import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/vip_provider.dart';
import 'package:sk_live/core/widgets/svga_player_muted.dart';
import 'package:sk_live/features/auth/presentation/widgets/vip/vip_assets.dart';
import 'package:sk_live/features/auth/presentation/widgets/vip/vip_feature_icon.dart';

typedef VipRewardTapCallback =
    void Function({
      required String featureKey,
      required String label,
      required bool isUnlocked,
      String? imageUrl,
      String? svgaUrl,
    });

class VipRewardPreviewCard extends StatelessWidget {
  const VipRewardPreviewCard({
    super.key,
    required this.plan,
    required this.levelAssets,
    required this.levelIndex,
    required this.onRewardTap,
  });

  final VipPlan plan;
  final List<Map<String, dynamic>> levelAssets;
  final int levelIndex;
  final VipRewardTapCallback onRewardTap;

  static const _frameSlot = _RewardSlot(
    featureKey: 'has_exclusive_frame',
    label: 'Frame',
  );
  static const _bubbleSlot = _RewardSlot(
    featureKey: 'has_chat_bubble',
    label: 'Bubble',
  );
  static const _cardSlot = _RewardSlot(
    featureKey: 'has_vip_title',
    label: 'Title',
  );
  static const _entranceSlot = _RewardSlot(
    featureKey: 'has_entrance_show',
    label: 'Entrance',
  );

  String? _distinguishedCardUrl() {
    final asset = _assetFor('has_distinguished_card');
    final url = asset?['image_url']?.toString();
    if (url != null && url.isNotEmpty) return url;
    return null;
  }

  Map<String, dynamic>? _assetFor(String featureKey) {
    try {
      return levelAssets.firstWhere(
        (a) => a['feature_key'] == featureKey && a['level'] == plan.level,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = VipLevelTheme.colorsForIndex(levelIndex);
    final accentLight = accent[0];
    final accentDark = accent[1];
    final cardUrl = _distinguishedCardUrl();
    final hasFloatingCard = cardUrl != null;
    final frameTopOffset = hasFloatingCard
        ? (plan.level <= 4 ? 28.0 : 46.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(top: frameTopOffset),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: EdgeInsets.only(top: hasFloatingCard ? 0 : 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentLight.withValues(alpha: 0.25),
                        const Color(0xFF3D2817).withValues(alpha: 0.92),
                        accentDark.withValues(alpha: 0.2),
                      ],
                    ),
                    border: Border.all(
                      color: accentLight.withValues(alpha: 0.65),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentLight.withValues(alpha: 0.15),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                        child: SizedBox(
                          height: 168,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 42,
                                child: _buildSlot(
                                  _frameSlot,
                                  accentLight,
                                  accentDark,
                                  tall: true,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 58,
                                child: Column(
                                  children: [
                                    Expanded(
                                      flex: 55,
                                      child: _buildSlot(
                                        _bubbleSlot,
                                        accentLight,
                                        accentDark,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      flex: 45,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _buildSlot(
                                              _cardSlot,
                                              accentLight,
                                              accentDark,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildSlot(
                                              _entranceSlot,
                                              accentLight,
                                              accentDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _OrnamentHeader(
                    accentLight: accentLight,
                    accentDark: accentDark,
                  ),
                ),
              ],
            ),
          ),
          if (hasFloatingCard)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Image.network(
                cardUrl,
                width: MediaQuery.sizeOf(context).width - 32,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSlot(
    _RewardSlot slot,
    Color accentLight,
    Color accentDark, {
    bool tall = false,
  }) {
    final asset = _assetFor(slot.featureKey);
    final imageUrl = asset?['image_url']?.toString();
    final svgaUrl = asset?['svga_url']?.toString();
    final isUnlocked = plan.features[slot.featureKey] == true;

    return GestureDetector(
      onTap: () => onRewardTap(
        featureKey: slot.featureKey,
        label: slot.label,
        isUnlocked: isUnlocked,
        imageUrl: imageUrl,
        svgaUrl: svgaUrl,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isUnlocked
                ? [
                    accentLight.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.55),
                  ]
                : [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.6),
                  ],
          ),
          border: Border.all(
            color: isUnlocked
                ? accentLight.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.all(tall ? 10 : 6),
                child: _RewardPreview(
                  featureKey: slot.featureKey,
                  isUnlocked: isUnlocked,
                  imageUrl: imageUrl,
                  svgaUrl: svgaUrl,
                  tall: tall,
                ),
              ),
            ),
            if (!isUnlocked)
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.lock,
                  size: 11,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrnamentHeader extends StatelessWidget {
  const _OrnamentHeader({required this.accentLight, required this.accentDark});

  final Color accentLight;
  final Color accentDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _WingIcon(color: accentLight, flip: true),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [accentLight, accentDark]),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: accentLight.withValues(alpha: 0.45),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              Iconsax.diamonds,
              size: 12,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          _WingIcon(color: accentLight, flip: false),
        ],
      ),
    );
  }
}

class _WingIcon extends StatelessWidget {
  const _WingIcon({required this.color, required this.flip});

  final Color color;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: flip,
      child: Icon(
        Iconsax.wind_2,
        size: 22,
        color: color.withValues(alpha: 0.85),
      ),
    );
  }
}

class _RewardPreview extends StatelessWidget {
  const _RewardPreview({
    required this.featureKey,
    required this.isUnlocked,
    required this.imageUrl,
    required this.svgaUrl,
    required this.tall,
  });

  final String featureKey;
  final bool isUnlocked;
  final String? imageUrl;
  final String? svgaUrl;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    if (isUnlocked && svgaUrl != null && svgaUrl!.isNotEmpty) {
      return SVGAPlayerMuted(resUrl: svgaUrl!);
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.contain,
        color: isUnlocked ? null : Colors.white24,
        colorBlendMode: isUnlocked ? null : BlendMode.modulate,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Icon(
      vipFeatureIcon(featureKey),
      size: tall ? 42 : 28,
      color: isUnlocked
          ? const Color(0xFFFFD700)
          : Colors.white.withValues(alpha: 0.2),
    );
  }
}

class _RewardSlot {
  const _RewardSlot({required this.featureKey, required this.label});

  final String featureKey;
  final String label;
}
