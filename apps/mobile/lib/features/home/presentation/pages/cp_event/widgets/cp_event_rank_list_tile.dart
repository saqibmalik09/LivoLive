import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/cp_event_provider.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/cp_event_assets.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/widgets/cp_couple_avatar_pair.dart';

class CpEventRankListTile extends StatelessWidget {
  const CpEventRankListTile({super.key, required this.couple});

  final CpEventCoupleRank couple;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(CpEventAssets.cpList),
          fit: BoxFit.fill,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${couple.rank}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CpCoupleAvatarPair(
            avatar1: couple.user1Avatar,
            avatar2: couple.user2Avatar,
            size: 36,
            overlap: 10,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              couple.displayNames,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const Icon(Icons.favorite, color: Color(0xFFFF6BA8), size: 14),
          const SizedBox(width: 4),
          Text(
            formatCpEventScore(couple.score),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
