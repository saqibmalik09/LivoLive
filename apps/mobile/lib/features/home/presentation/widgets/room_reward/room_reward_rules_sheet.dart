import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/providers/room_reward_provider.dart';

class RoomRewardRulesSheet extends ConsumerWidget {
  const RoomRewardRulesSheet({super.key, required this.roomId});

  final String roomId;

  static Future<void> show(BuildContext context, {required String roomId}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RoomRewardRulesSheet(roomId: roomId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(roomRewardProgressProvider(roomId));
    final rules = progressAsync.valueOrNull?.rules ?? const <String>[];

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.72,
      decoration: const BoxDecoration(
        color: Color(0xFF0B1B3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF4A6FA5), width: 1.2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Iconsax.arrow_left, color: Colors.white),
                ),
                const Expanded(
                  child: Text(
                    'Rules',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: progressAsync.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    )
                  : ListView.separated(
                      itemCount: rules.isEmpty ? 1 : rules.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 18),
                      itemBuilder: (context, index) {
                        final text = rules.isEmpty
                            ? 'Send gifts in this room to earn energy and open gift boxes.'
                            : rules[index];
                        return Text(
                          text,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.55,
                            fontSize: 14,
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
