import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/vip_provider.dart';
import 'package:sk_live/core/widgets/svga_player_muted.dart';
import 'package:sk_live/features/auth/presentation/widgets/vip/vip_feature_icon.dart';

class VipPrivilegeSection extends StatelessWidget {
  const VipPrivilegeSection({
    super.key,
    required this.allFeatures,
    required this.currentPlan,
    required this.levelAssets,
    required this.onFeatureTap,
  });

  final List<VipFeatureDetail> allFeatures;
  final VipPlan currentPlan;
  final List<Map<String, dynamic>> levelAssets;
  final void Function(
    VipFeatureDetail feature,
    bool isUnlocked,
    String? displayUrl,
    String? displaySvga,
  )
  onFeatureTap;

  @override
  Widget build(BuildContext context) {
    final privileges = allFeatures
        .where((f) => !forbiddenVipPrivileges.contains(f.key))
        .where((f) => f.category == 'exclusive_privileges')
        .toList();

    var unlocked = 0;
    for (final f in privileges) {
      if (currentPlan.features[f.key] == true) unlocked++;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            _SectionHeader(
              title: 'Exclusive Privileges $unlocked/${privileges.length}',
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 20,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: privileges.length,
              itemBuilder: (context, index) {
                final feature = privileges[index];
                final isUnlocked = currentPlan.features[feature.key] ?? false;
                final display = _resolveAsset(
                  feature.key,
                  levelAssets,
                  currentPlan.level,
                );

                return GestureDetector(
                  onTap: () =>
                      onFeatureTap(feature, isUnlocked, display.$1, display.$2),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 68,
                            width: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isUnlocked
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black26,
                              border: Border.all(
                                color: isUnlocked
                                    ? const Color(
                                        0xFFFFD700,
                                      ).withValues(alpha: 0.45)
                                    : Colors.white10,
                              ),
                            ),
                            child: _FeaturePreview(
                              featureKey: feature.key,
                              isUnlocked: isUnlocked,
                              displayUrl: display.$1,
                              displaySvga: display.$2,
                              iconSize: 34,
                            ),
                          ),
                          if (!isUnlocked)
                            Positioned(
                              right: 4,
                              top: 4,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.lock,
                                  color: Colors.white38,
                                  size: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        feature.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUnlocked ? Colors.white : Colors.white30,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFFFFD700).withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFFFD700),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFFD700).withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeaturePreview extends StatelessWidget {
  const _FeaturePreview({
    required this.featureKey,
    required this.isUnlocked,
    required this.displayUrl,
    required this.displaySvga,
    required this.iconSize,
  });

  final String featureKey;
  final bool isUnlocked;
  final String? displayUrl;
  final String? displaySvga;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (isUnlocked && displaySvga != null && displaySvga!.isNotEmpty) {
      return SVGAPlayerMuted(resUrl: displaySvga!);
    }
    if (displayUrl != null && displayUrl!.isNotEmpty) {
      return Image.network(
        displayUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          vipFeatureIcon(featureKey),
          color: isUnlocked ? const Color(0xFFFFD700) : Colors.white24,
          size: iconSize,
        ),
      );
    }
    return Icon(
      vipFeatureIcon(featureKey),
      color: isUnlocked ? const Color(0xFFFFD700) : Colors.white24,
      size: iconSize,
    );
  }
}

(String?, String?) _resolveAsset(
  String featureKey,
  List<Map<String, dynamic>> levelAssets,
  int level,
) {
  try {
    final asset = levelAssets.firstWhere(
      (a) => a['feature_key'] == featureKey && a['level'] == level,
    );
    return (asset['image_url']?.toString(), asset['svga_url']?.toString());
  } catch (_) {
    return (null, null);
  }
}
