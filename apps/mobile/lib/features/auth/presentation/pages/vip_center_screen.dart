import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/vip_provider.dart';
import 'package:sk_live/core/widgets/svga_player_muted.dart';
import 'package:sk_live/features/auth/presentation/widgets/vip/vip_assets.dart';
import 'package:sk_live/features/auth/presentation/widgets/vip/vip_badge_tab_bar.dart';
import 'package:sk_live/features/auth/presentation/widgets/vip/vip_feature_icon.dart';
import 'package:sk_live/features/auth/presentation/widgets/vip/vip_hero_banner.dart';
import 'package:sk_live/features/auth/presentation/widgets/vip/vip_privilege_section.dart';
import 'package:sk_live/features/auth/presentation/widgets/vip/vip_purchase_bar.dart';
import 'package:sk_live/features/auth/presentation/widgets/vip/vip_reward_preview_card.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

class VipCenterScreen extends ConsumerStatefulWidget {
  const VipCenterScreen({super.key});

  @override
  ConsumerState<VipCenterScreen> createState() => _VipCenterScreenState();
}

class _VipCenterScreenState extends ConsumerState<VipCenterScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _unlockedCount(VipPlan plan, List<VipFeatureDetail> allFeatures) {
    final filtered = allFeatures
        .where((f) => !forbiddenVipPrivileges.contains(f.key))
        .toList();
    var count = 0;
    for (final feature in filtered) {
      if (plan.features[feature.key] == true) count++;
    }
    return count;
  }

  int _totalCount(List<VipFeatureDetail> allFeatures) {
    return allFeatures
        .where((f) => !forbiddenVipPrivileges.contains(f.key))
        .length;
  }

  Future<void> _purchase(VipPlan plan) async {
    try {
      final success = await ref
          .read(vipPurchaseControllerProvider)
          .purchaseVip(plan);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully purchased ${plan.name}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFeatureDetail(
    VipFeatureDetail feature,
    bool isUnlocked,
    String? displayUrl,
    String? displaySvga,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD700).withValues(alpha: 0.05),
                ),
                child: Center(
                  child: displaySvga != null && displaySvga.isNotEmpty
                      ? SizedBox(
                          height: 90,
                          width: 90,
                          child: SVGAPlayerMuted(resUrl: displaySvga),
                        )
                      : displayUrl != null && displayUrl.isNotEmpty
                      ? Image.network(
                          displayUrl,
                          height: 90,
                          width: 90,
                          fit: BoxFit.contain,
                        )
                      : Icon(
                          vipFeatureIcon(feature.key),
                          color: const Color(0xFFFFD700),
                          size: 60,
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                feature.name,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUnlocked
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isUnlocked ? 'UNLOCKED' : 'LOCKED',
                  style: TextStyle(
                    color: isUnlocked ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                feature.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    context.l10n.vip_gotIt,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRewardDetail({
    required String label,
    required bool isUnlocked,
    String? imageUrl,
    String? svgaUrl,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 48),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 100,
                child: svgaUrl != null && svgaUrl.isNotEmpty
                    ? SVGAPlayerMuted(resUrl: svgaUrl)
                    : imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.contain)
                    : Icon(
                        Iconsax.gift,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isUnlocked
                    ? 'Included in this VIP level'
                    : 'Locked for this level',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(vipPlansProvider);
    final featuresAsync = ref.watch(vipFeatureDetailsProvider);
    final levelAssetsAsync = ref.watch(vipLevelAssetsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: plansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return const Center(child: Text('No VIP plans available'));
          }

          final currentPlan = plans[_currentPage];

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                VipAssets.background,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFF1A1208)),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Text(
                            context.l10n.vip_centerTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Iconsax.info_circle,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    VipBadgeTabBar(
                      planCount: plans.length,
                      selectedIndex: _currentPage,
                      onSelected: (index) {
                        setState(() => _currentPage = index);
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutCubic,
                        );
                      },
                    ),
                    SizedBox(
                      height: 200,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) =>
                            setState(() => _currentPage = index),
                        itemCount: plans.length,
                        itemBuilder: (context, index) {
                          final plan = plans[index];
                          return featuresAsync.when(
                            data: (features) => VipHeroBanner(
                              level: plan.level,
                              levelIndex: index,
                              unlockedCount: _unlockedCount(plan, features),
                              totalCount: _totalCount(features),
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (e, _) => asyncErrorWidget(e),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: featuresAsync.when(
                        data: (features) => levelAssetsAsync.when(
                          data: (levelAssets) => AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: KeyedSubtree(
                              key: ValueKey(_currentPage),
                              child: ListView(
                                physics: const ClampingScrollPhysics(),
                                padding: EdgeInsets.zero,
                                children: [
                                  VipRewardPreviewCard(
                                    plan: currentPlan,
                                    levelAssets: levelAssets,
                                    levelIndex: _currentPage,
                                    onRewardTap:
                                        ({
                                          required featureKey,
                                          required label,
                                          required isUnlocked,
                                          imageUrl,
                                          svgaUrl,
                                        }) {
                                          _showRewardDetail(
                                            label: label,
                                            isUnlocked: isUnlocked,
                                            imageUrl: imageUrl,
                                            svgaUrl: svgaUrl,
                                          );
                                        },
                                  ),
                                  VipPrivilegeSection(
                                    allFeatures: features,
                                    currentPlan: currentPlan,
                                    levelAssets: levelAssets,
                                    onFeatureTap: _showFeatureDetail,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => asyncErrorWidget(e),
                        ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => asyncErrorWidget(e),
                      ),
                    ),
                    VipPurchaseBar(
                      plan: currentPlan,
                      onPurchase: () => _purchase(currentPlan),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => asyncErrorWidget(e),
      ),
    );
  }
}
