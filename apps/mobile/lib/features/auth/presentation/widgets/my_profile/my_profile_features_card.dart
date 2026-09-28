import 'package:flutter/material.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';

class MyProfileFeaturesCard extends StatelessWidget {
  const MyProfileFeaturesCard({
    super.key,
    required this.vipLevel,
    required this.onJoinVip,
    required this.onWallet,
    required this.onStore,
    required this.onVip,
    required this.onDecoration,
    required this.onAgency,
    required this.onEvents,
    this.onHostCenter,
    this.showHostCenter = false,
    this.onWeeklyRoomReward,
    this.showWeeklyRoomReward = false,
    this.onMicReward,
  });

  static const _walletAsset = 'assets/profile/wallet.webp';
  static const _storeAsset = 'assets/profile/store.webp';
  static const _vipAsset = 'assets/profile/vip.webp';
  static const _decorationAsset = 'assets/profile/decoration.webp';
  static const _agencyAsset = 'assets/profile/agency.webp';
  static const _eventsAsset = 'assets/profile/events.webp';
  static const _hostCenterAsset = 'assets/profile/host_center.webp';
  static const _weeklyRoomRewardAsset = 'assets/profile/room_reward.webp';
  static const _micRewardAsset = 'assets/profile/mic_reward.webp';

  final int vipLevel;
  final VoidCallback onJoinVip;
  final VoidCallback onWallet;
  final VoidCallback onStore;
  final VoidCallback onVip;
  final VoidCallback onDecoration;
  final VoidCallback onAgency;
  final VoidCallback onEvents;
  final VoidCallback? onHostCenter;
  final bool showHostCenter;
  final VoidCallback? onWeeklyRoomReward;
  final bool showWeeklyRoomReward;
  final VoidCallback? onMicReward;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VipBanner(vipLevel: vipLevel, onJoinVip: onJoinVip),
        const SizedBox(height: 8),
        _FeatureGrid(
          showHostCenter: showHostCenter,
          showWeeklyRoomReward: showWeeklyRoomReward,
          onStore: onStore,
          onVip: onVip,
          onDecoration: onDecoration,
          onEvents: onEvents,
          onWallet: onWallet,
          onHostCenter: onHostCenter,
          onWeeklyRoomReward: onWeeklyRoomReward,
          onMicReward: onMicReward,
          onAgency: onAgency,
          storeAsset: _storeAsset,
          vipAsset: _vipAsset,
          decorationAsset: _decorationAsset,
          agencyAsset: _agencyAsset,
          eventsAsset: _eventsAsset,
          walletAsset: _walletAsset,
          hostCenterAsset: _hostCenterAsset,
          weeklyRoomRewardAsset: _weeklyRoomRewardAsset,
          micRewardAsset: _micRewardAsset,
        ),
      ],
    );
  }
}

class _VipBanner extends StatelessWidget {
  const _VipBanner({required this.vipLevel, required this.onJoinVip});

  static const _asset = 'assets/profile/vip_banner.webp';

  final int vipLevel;
  final VoidCallback onJoinVip;

  @override
  Widget build(BuildContext context) {
    final label = vipLevel > 0
        ? context.l10n.profile_upgrade
        : context.l10n.profile_getVip;

    return GestureDetector(
      onTap: onJoinVip,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Image.asset(
            _asset,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            filterQuality: FilterQuality.high,
          ),
          Positioned(
            right: 14,
            child: _Vip3dButton(label: label, onTap: onJoinVip),
          ),
          if (vipLevel > 0)
            Positioned(
              left: 12,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  context.l10n.profile_vipLevel(vipLevel),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Vip3dButton extends StatelessWidget {
  const _Vip3dButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFB45309).withValues(alpha: 0.55),
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              offset: const Offset(0, 6),
              blurRadius: 10,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF1A8), Color(0xFFFFD54F), Color(0xFFF6A700)],
              stops: [0.0, 0.45, 1.0],
            ),
            border: Border.all(color: const Color(0xFFFFF8D6), width: 1.2),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5B2C00),
              fontWeight: FontWeight.w900,
              fontSize: 13,
              height: 1,
              letterSpacing: 0.2,
              shadows: [
                Shadow(
                  color: Color(0x66FFFFFF),
                  offset: Offset(0, 1),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({
    required this.showHostCenter,
    required this.showWeeklyRoomReward,
    required this.onStore,
    required this.onVip,
    required this.onDecoration,
    required this.onEvents,
    required this.onWallet,
    required this.onHostCenter,
    required this.onWeeklyRoomReward,
    required this.onMicReward,
    required this.onAgency,
    required this.storeAsset,
    required this.vipAsset,
    required this.decorationAsset,
    required this.agencyAsset,
    required this.eventsAsset,
    required this.walletAsset,
    required this.hostCenterAsset,
    required this.weeklyRoomRewardAsset,
    required this.micRewardAsset,
  });

  final bool showHostCenter;
  final bool showWeeklyRoomReward;
  final VoidCallback onStore;
  final VoidCallback onVip;
  final VoidCallback onDecoration;
  final VoidCallback onEvents;
  final VoidCallback onWallet;
  final VoidCallback? onHostCenter;
  final VoidCallback? onWeeklyRoomReward;
  final VoidCallback? onMicReward;
  final VoidCallback onAgency;
  final String storeAsset;
  final String vipAsset;
  final String decorationAsset;
  final String agencyAsset;
  final String eventsAsset;
  final String walletAsset;
  final String hostCenterAsset;
  final String weeklyRoomRewardAsset;
  final String micRewardAsset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = <_GridItemData>[
      _GridItemData(
        label: l10n.profile_store,
        asset: storeAsset,
        onTap: onStore,
      ),
      _GridItemData(label: l10n.profile_vip, asset: vipAsset, onTap: onVip),
      _GridItemData(
        label: l10n.profile_decoration,
        asset: decorationAsset,
        onTap: onDecoration,
      ),
      _GridItemData(
        label: l10n.profile_events,
        asset: eventsAsset,
        onTap: onEvents,
      ),
      _GridItemData(
        label: l10n.profile_wallet,
        asset: walletAsset,
        onTap: onWallet,
      ),
      if (showHostCenter && onHostCenter != null)
        _GridItemData(
          label: l10n.profile_hostCenter,
          asset: hostCenterAsset,
          onTap: onHostCenter!,
        ),
      if (showWeeklyRoomReward && onWeeklyRoomReward != null)
        _GridItemData(
          label: l10n.profile_roomReward,
          asset: weeklyRoomRewardAsset,
          onTap: onWeeklyRoomReward!,
        ),
      if (onMicReward != null)
        _GridItemData(
          label: l10n.profile_micReward,
          asset: micRewardAsset,
          onTap: onMicReward!,
        ),
      _GridItemData(
        label: l10n.profile_agency,
        asset: agencyAsset,
        onTap: onAgency,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 0.92,
        ),
        itemBuilder: (context, index) {
          final item = items[index];
          return _GridTile(item: item);
        },
      ),
    );
  }
}

class _GridItemData {
  const _GridItemData({
    required this.label,
    required this.onTap,
    this.asset,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final String? asset;
  final IconData? icon;
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.item});

  final _GridItemData item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          if (item.asset != null)
            Image.asset(item.asset!, width: 42, height: 42, fit: BoxFit.contain)
          else
            Icon(item.icon, size: 34, color: const Color(0xFF1A1A2E)),
          const SizedBox(height: 4),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A4A5E),
            ),
          ),
        ],
      ),
    );
  }
}
