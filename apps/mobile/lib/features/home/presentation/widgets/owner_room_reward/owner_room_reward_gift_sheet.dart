import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/owner_room_reward_provider.dart';
import 'package:sk_live/core/providers/room_reward_provider.dart';
import 'package:sk_live/core/util/number_formatter.dart';
import 'package:sk_live/core/widgets/svga_player.dart';
import 'package:sk_live/features/home/presentation/widgets/room_reward/room_reward_assets.dart';
import 'package:sk_live/features/home/presentation/widgets/owner_room_reward/owner_room_reward_record_screen.dart';
import 'package:sk_live/features/home/presentation/widgets/owner_room_reward/owner_room_reward_rules_sheet.dart';

const double _kBgW = 229;
const double _kBgH = 336;
const double _kBgAspect = _kBgW / _kBgH;

String _formatClaimCountdown(int seconds) {
  final s = seconds.clamp(0, 999);
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(1, '0')}:${r.toString().padLeft(2, '0')}';
}

class OwnerRoomRewardGiftSheet extends ConsumerStatefulWidget {
  const OwnerRoomRewardGiftSheet({super.key, required this.roomId});

  final String roomId;

  static Future<void> show(BuildContext context, {required String roomId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OwnerRoomRewardGiftSheet(roomId: roomId),
    );
  }

  @override
  ConsumerState<OwnerRoomRewardGiftSheet> createState() =>
      _OwnerRoomRewardGiftSheetState();
}

class _OwnerRoomRewardGiftSheetState
    extends ConsumerState<OwnerRoomRewardGiftSheet> {
  int? _selectedLevel;
  bool _opening = false;
  Timer? _claimTick;
  bool _refreshingOnExpire = false;

  @override
  void dispose() {
    _claimTick?.cancel();
    super.dispose();
  }

  void _ensureClaimTicker(RoomRewardProgress progress) {
    final open = progress.openClaimLevel;
    final needsTick = open != null && open.liveClaimSecondsRemaining() > 0;
    if (!needsTick) {
      _claimTick?.cancel();
      _claimTick = null;
      return;
    }
    if (_claimTick?.isActive == true) return;
    _claimTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final p = ref
          .read(ownerRoomRewardProgressProvider(widget.roomId))
          .valueOrNull;
      final lv = p?.openClaimLevel;
      final left = lv?.liveClaimSecondsRemaining() ?? 0;
      if (left <= 0) {
        _claimTick?.cancel();
        _claimTick = null;
        if (!_refreshingOnExpire) {
          _refreshingOnExpire = true;
          ref.invalidate(ownerRoomRewardProgressProvider(widget.roomId));
          Future<void>.delayed(const Duration(milliseconds: 400), () {
            _refreshingOnExpire = false;
          });
        }
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(
      ownerRoomRewardProgressProvider(widget.roomId),
    );
    final progress = progressAsync.valueOrNull ?? RoomRewardProgress.empty();
    _ensureClaimTicker(progress);
    final maxLv = progress.levels.isEmpty ? 5 : progress.maxLevel.clamp(1, 99);
    final selected = (_selectedLevel ?? progress.focusLevel).clamp(1, maxLv);
    final levelInfo = progress.levelInfo(selected);
    final required = levelInfo?.requiredPoints ?? 0;
    final claimSecs = levelInfo?.liveClaimSecondsRemaining() ?? 0;
    final canOpen = (levelInfo?.canOpen ?? false) && claimSecs > 0;
    final claimed = levelInfo?.claimed ?? false;
    final forfeited = levelInfo?.forfeited ?? false;
    final ratio = progress.progressForLevel(selected);
    final levelItems = progress.itemsForLevel(selected);
    final featured = levelItems.where((i) => i.isFeatured).toList();
    final featuredItem = featured.isNotEmpty
        ? featured.first
        : (levelItems.isNotEmpty ? levelItems.first : null);
    final gridItems = featuredItem == null
        ? levelItems
        : levelItems.where((i) => i.id != featuredItem.id).toList();

    final screen = MediaQuery.sizeOf(context);
    final maxH = screen.height * 0.92;
    var panelW = screen.width;
    var panelH = panelW / _kBgAspect;
    if (panelH > maxH) {
      panelH = maxH;
      panelW = panelH * _kBgAspect;
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: panelW,
        height: panelH,
        child: progressAsync.isLoading && progress.levels.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    RoomRewardAssets.giftboxBg,
                    width: panelW,
                    height: panelH,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),

                  Positioned(
                    left: panelW * 0.04,
                    top: panelH * 0.07,
                    child: GestureDetector(
                      onTap: () => OwnerRoomRewardRecordScreen.open(
                        context,
                        roomId: widget.roomId,
                      ),
                      child: Image.asset(
                        RoomRewardAssets.recordButton,
                        width: panelW * 0.14,
                        height: panelW * 0.14,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  Positioned(
                    right: panelW * 0.05,
                    top: panelH * 0.09,
                    child: GestureDetector(
                      onTap: () => OwnerRoomRewardRulesSheet.show(
                        context,
                        roomId: widget.roomId,
                      ),
                      child: Container(
                        width: panelW * 0.09,
                        height: panelW * 0.09,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.25),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.55),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '?',
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.w900,
                            fontSize: panelW * 0.05,
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    left: panelW * 0.22,
                    top: panelH * 0.03,
                    width: panelW * 0.56,
                    height: panelH * 0.29,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: (canOpen && !_opening)
                          ? () => _openBox(selected)
                          : null,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            left: panelW * 0.06,
                            top: 0,
                            width: panelW * 0.44,
                            height: panelH * 0.22,
                            child: IgnorePointer(
                              child: RaveSVGAPlayer(
                                key: ValueKey('aperture_$selected'),
                                resUrl: RoomRewardAssets.apertureBoxSvga(
                                  selected,
                                ),
                                fit: BoxFit.contain,
                                repeat: true,
                              ),
                            ),
                          ),
                          if (_opening)
                            const Positioned(
                              bottom: 4,
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else if (canOpen)
                            Positioned(
                              bottom: 4,
                              child: Text(
                                'Claim ${_formatClaimCountdown(claimSecs)}',
                                style: TextStyle(
                                  color: const Color(0xFFFFE082),
                                  fontSize: panelW * 0.034,
                                  fontWeight: FontWeight.w900,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black54,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (claimed)
                            Positioned(
                              bottom: 6,
                              child: Text(
                                'Claimed',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: panelW * 0.032,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else if (forfeited)
                            Positioned(
                              bottom: 6,
                              child: Text(
                                'Missed',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: panelW * 0.032,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    left: panelW * 0.48,
                    top: panelH * 0.325,
                    width: panelW * 0.40,
                    child: Text(
                      NumberFormatter.format(progress.energy),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: panelW * 0.032,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  Positioned(
                    left: panelW * 0.08,
                    top: panelH * 0.355,
                    width: panelW * 0.84,
                    child: Row(
                      children: [
                        if (selected == 1) ...[
                          Text(
                            'Lv1',
                            style: TextStyle(
                              color: const Color(0xFFFFE082),
                              fontSize: panelW * 0.048,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          SizedBox(width: panelW * 0.02),
                        ],
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 8,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: panelW * 0.02),
                        Text(
                          '${NumberFormatter.format(progress.energy)}/${NumberFormatter.format(required)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: panelW * 0.028,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Positioned(
                    left: panelW * 0.04,
                    top: panelH * 0.42,
                    width: panelW * 0.92,
                    height: panelH * 0.19,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(maxLv, (i) {
                        final lv = i + 1;
                        final isSelected = lv == selected;
                        final isLv1 = lv == 1;
                        return Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _selectedLevel = lv),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  bottom: isLv1 ? 0 : panelH * 0.012,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _LevelShelfItem(
                                    level: lv,
                                    selected: isSelected,
                                    boxSize: isLv1
                                        ? panelW * 0.16
                                        : panelW * 0.115,
                                    showLv1Label: isLv1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  if (featuredItem != null)
                    Positioned(
                      left: panelW * 0.04,
                      top: panelH * 0.72,
                      width: panelW * 0.28,
                      height: panelH * 0.24,
                      child: _RewardSlotContent(
                        item: featuredItem,
                        fontSize: panelW * 0.032,
                        padding: 8,
                      ),
                    ),

                  ..._buildSmallSlots(panelW, panelH, gridItems),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildSmallSlots(
    double panelW,
    double panelH,
    List<RoomRewardItemInfo> items,
  ) {
    const cols = 3;
    const rows = 2;
    final originLeft = panelW * 0.42;
    final originTop = panelH * 0.72;
    final cellW = panelW * 0.14;
    final cellH = panelH * 0.125;
    final gapX = panelW * 0.035;
    final gapY = panelH * 0.018;

    final widgets = <Widget>[];
    final count = items.length.clamp(0, cols * rows);
    for (var i = 0; i < count; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final item = items[i];
      final nudgeX = col == 0
          ? -panelW * 0.024
          : col == 2
          ? panelW * 0.024
          : 0.0;
      widgets.add(
        Positioned(
          left: originLeft + col * (cellW + gapX) + nudgeX,
          top: originTop + row * (cellH + gapY),
          width: cellW,
          height: cellH,
          child: _RewardSlotContent(item: item, fontSize: panelW * 0.026),
        ),
      );
    }
    return widgets;
  }

  Future<void> _openBox(int level) async {
    if (_opening) return;
    setState(() => _opening = true);
    final res = await OwnerRoomRewardService.openBox(
      roomId: widget.roomId,
      level: level,
    );
    if (!mounted) return;
    setState(() => _opening = false);

    ref.invalidate(ownerRoomRewardProgressProvider(widget.roomId));
    ref.invalidate(ownerRoomRewardClaimsProvider(widget.roomId));

    if (res['success'] == true) {
      final reward = res['reward'];
      final map = reward is Map
          ? Map<String, dynamic>.from(reward)
          : <String, dynamic>{};
      final title = map['title']?.toString() ?? 'Reward';
      final type = map['reward_type']?.toString() ?? '';
      final coins = (map['coin_amount'] as num?)?.toInt() ?? 0;
      final headline = type == 'coins'
          ? 'You won ${NumberFormatter.format(coins)} Coins!'
          : 'You won $title!';
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Reward',
        barrierColor: Colors.black.withValues(alpha: 0.65),
        pageBuilder: (ctx, anim, _) {
          return _SigninRewardCelebration(
            headline: headline,
            imageUrl: map['image_url']?.toString() ?? '',
            onClose: () => Navigator.pop(ctx),
          );
        },
      );
    } else {
      final message = res['message']?.toString() ?? 'Failed to open';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _LevelShelfItem extends StatelessWidget {
  const _LevelShelfItem({
    required this.level,
    required this.selected,
    required this.boxSize,
    required this.showLv1Label,
  });

  final int level;
  final bool selected;
  final double boxSize;
  final bool showLv1Label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: boxSize * 0.32,
          child: selected
              ? _SelectBubble(size: boxSize * 0.30)
              : const SizedBox.shrink(),
        ),
        AnimatedScale(
          scale: selected ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: SizedBox(
            width: boxSize,
            height: boxSize * 0.78,
            child: IgnorePointer(
              child: RaveSVGAPlayer(
                key: ValueKey('shelf_$level'),
                resUrl: RoomRewardAssets.shelfBoxSvga(level),
                fit: BoxFit.contain,
                repeat: true,
              ),
            ),
          ),
        ),
        SizedBox(height: boxSize * 0.03),
        if (selected)
          _SelectBubble(size: boxSize * 0.30, label: 'Lv$level')
        else if (showLv1Label)
          Text(
            'Lv1',
            style: TextStyle(
              color: Colors.white70,
              fontSize: boxSize * 0.20,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          )
        else
          SizedBox(height: boxSize * 0.30),
      ],
    );
  }
}

class _SelectBubble extends StatelessWidget {
  const _SelectBubble({required this.size, this.label});

  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: label != null ? size * 1.55 : size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3B0), Color(0xFFFFD54F), Color(0xFFFFA000)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD54F).withValues(alpha: 0.55),
            blurRadius: 10,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: label != null
          ? Text(
              label!,
              style: TextStyle(
                color: const Color(0xFF4A2C00),
                fontWeight: FontWeight.w900,
                fontSize: size * 0.38,
                height: 1,
              ),
            )
          : Icon(
              Icons.arrow_drop_down_rounded,
              color: const Color(0xFF4A2C00),
              size: size * 0.85,
            ),
    );
  }
}

class _RewardSlotContent extends StatelessWidget {
  const _RewardSlotContent({
    required this.item,
    required this.fontSize,
    this.padding = 6,
  });

  final RoomRewardItemInfo item;
  final double fontSize;
  final double padding;

  static const _coinAssets = [
    'assets/rewards/lucky-bag/coin-1.webp',
    'assets/rewards/lucky-bag/coin-2.webp',
    'assets/rewards/lucky-bag/coin-3.webp',
    'assets/rewards/lucky-bag/coin-4.webp',
  ];

  String _coinAssetForAmount(int amount) {
    if (amount >= 5000) return _coinAssets[3];
    if (amount >= 1500) return _coinAssets[2];
    if (amount >= 500) return _coinAssets[1];
    return _coinAssets[0];
  }

  @override
  Widget build(BuildContext context) {
    final isCoins = item.rewardType == 'coins' && item.coinAmount > 0;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: isCoins
                ? Image.asset(
                    _coinAssetForAmount(item.coinAmount),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.monetization_on,
                      color: Color(0xFFFFD54F),
                    ),
                  )
                : item.imageUrl.isEmpty
                ? const SizedBox.shrink()
                : CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.contain,
                    fadeInDuration: Duration.zero,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
          ),
        ),
        if (isCoins)
          Transform.translate(
            offset: const Offset(0, -4),
            child: Text(
              NumberFormatter.format(item.coinAmount),
              style: TextStyle(
                color: const Color(0xFFFFE082),
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
      ],
    );
  }
}

class _SigninRewardCelebration extends StatelessWidget {
  const _SigninRewardCelebration({
    required this.headline,
    required this.imageUrl,
    required this.onClose,
  });

  final String headline;
  final String imageUrl;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: onClose,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size.width,
              height: size.height * 0.55,
              child: RaveSVGAPlayer(
                resUrl: RoomRewardAssets.signinRewardSvga,
                fit: BoxFit.contain,
                repeat: false,
                onFinished: onClose,
              ),
            ),
            Positioned(
              top: size.height * 0.18,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFFFF0),
                        Color(0xFFFFE082),
                        Color(0xFFFFB300),
                        Color(0xFFFF6F00),
                      ],
                      stops: [0.0, 0.35, 0.7, 1.0],
                    ).createShader(bounds),
                    child: Text(
                      'Congratulations!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: size.width * 0.085,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        height: 1.05,
                        letterSpacing: 0.5,
                        shadows: const [
                          Shadow(
                            color: Color(0xAA4A1500),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                          Shadow(
                            color: Color(0x66FFD54F),
                            blurRadius: 16,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFFE1F5FE),
                        Color(0xFF80D8FF),
                        Color(0xFFFFD54F),
                      ],
                    ).createShader(bounds),
                    child: Text(
                      headline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: size.width * 0.048,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        shadows: const [
                          Shadow(
                            color: Color(0x88000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (imageUrl.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 72,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
