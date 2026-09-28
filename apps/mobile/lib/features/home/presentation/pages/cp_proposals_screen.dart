import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/cp_nest_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/theme/app_colors.dart';
import 'package:sk_live/core/util/media_url_util.dart';
import 'package:sk_live/core/widgets/svga_player.dart';

class CPProposalsScreen extends ConsumerWidget {
  const CPProposalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposalsAsync = ref.watch(pendingProposalsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          context.l10n.cp_proposalsTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: proposalsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, st) => Center(
          child: Text(
            'Error: $e',
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        data: (proposals) {
          if (proposals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.heart_copy,
                    size: 80,
                    color: Colors.white.withOpacity(0.05),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.cp_noPending,
                    style: const TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: proposals.length,
            itemBuilder: (context, index) {
              final proposal = proposals[index];
              return _buildProposalCard(context, ref, proposal);
            },
          );
        },
      ),
    );
  }

  Widget _buildProposalCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> proposal,
  ) {
    final sender = proposal['sender'] as Map<String, dynamic>? ?? {};
    final item = proposal['item'] as Map<String, dynamic>? ?? {};
    final expiresAt = DateTime.parse(proposal['expires_at']);
    final timeLeft = expiresAt.difference(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: sender['avatar_url'] != null
                    ? CachedNetworkImageProvider(sender['avatar_url'])
                    : null,
                child: sender['avatar_url'] == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sender['username'] ?? 'Unknown User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sent you a ${item['name'] ?? 'Proposal'}',
                      style: TextStyle(
                        color: AppColors.accent.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (item['svga_url'] != null &&
                  item['svga_url'].toString().trim().isNotEmpty)
                SizedBox(
                  width: 50,
                  height: 50,
                  child: RaveSVGAPlayer(
                    resUrl: item['svga_url'].toString(),
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                )
              else if (item['image_url'] != null)
                MediaUrlUtil.isSvgaUrl(item['image_url']?.toString())
                    ? SizedBox(
                        width: 50,
                        height: 50,
                        child: RaveSVGAPlayer(
                          resUrl: item['image_url'].toString(),
                          fit: BoxFit.contain,
                          repeat: true,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: item['image_url'],
                        width: 50,
                        height: 50,
                        fit: BoxFit.contain,
                      ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Expires in: ${timeLeft.inHours}h ${timeLeft.inMinutes % 60}m',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      _handleResponse(context, ref, proposal['id'], false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white12),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(context.l10n.cp_reject),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      _handleResponse(context, ref, proposal['id'], true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    context.l10n.cp_accept,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleResponse(
    BuildContext context,
    WidgetRef ref,
    String proposalId,
    bool accept,
  ) async {
    try {
      await CPNestActions.respondToProposal(
        proposalId: proposalId,
        accept: accept,
      );
      ref.invalidate(pendingProposalsProvider);
      ref.invalidate(currentCoupleProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept
                  ? 'Proposal Accepted! You are now a couple.'
                  : 'Proposal Rejected.',
            ),
            backgroundColor: accept ? Colors.green : Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
