import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sk_live/core/providers/cp_nest_provider.dart';
import 'package:sk_live/core/router/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> openCpProposalAcceptScreen(
  BuildContext? context, {
  String? proposalId,
}) async {
  final ctx = context ?? AppRouter.navigatorKey.currentContext;
  if (ctx == null || proposalId == null || proposalId.isEmpty) return;

  Map<String, dynamic>? proposal;
  try {
    proposal = await Supabase.instance.client
        .from('cp_proposals')
        .select(
          '*, sender:sender_id(id, username, avatar_url), item:item_id(id, name, image_url, svga_url)',
        )
        .eq('id', proposalId)
        .maybeSingle();
  } catch (e) {
    debugPrint('CP proposal fetch failed: $e');
  }

  if (proposal == null) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text('Proposal expired or already handled'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
    return;
  }

  final status = proposal['status']?.toString() ?? '';
  if (status != 'pending') {
    if (ctx.mounted) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('Proposal is already $status')));
    }
    return;
  }

  final expiresRaw = proposal['expires_at']?.toString();
  if (expiresRaw != null) {
    final expires = DateTime.tryParse(expiresRaw);
    if (expires != null && expires.isBefore(DateTime.now())) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Proposal has expired'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
  }

  if (!ctx.mounted) return;

  final sender = proposal['sender'] as Map<String, dynamic>? ?? {};
  final item = proposal['item'] as Map<String, dynamic>? ?? {};
  final senderName = sender['username']?.toString() ?? 'Someone';
  final itemName = item['name']?.toString() ?? 'a gift';
  final id = proposal['id']?.toString();

  await showDialog<void>(
    context: ctx,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'CP Proposal',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$senderName sent you "$itemName". Accept to become a couple?',
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.pinkAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.pinkAccent.withValues(alpha: 0.4),
              ),
            ),
            child: const Text(
              'Accepting creates your CP bond. Rejecting declines the gift.',
              style: TextStyle(color: Colors.pinkAccent, fontSize: 12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            if (id == null) return;
            try {
              await CPNestActions.respondToProposal(
                proposalId: id,
                accept: false,
              );
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Proposal rejected')),
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text(_formatError(e))));
              }
            }
          },
          child: const Text(
            'Reject',
            style: TextStyle(color: Colors.redAccent),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(dialogContext);
            if (id == null) return;
            try {
              await CPNestActions.respondToProposal(
                proposalId: id,
                accept: true,
              );
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Accepted! You are now a couple.'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(
                  ctx,
                ).showSnackBar(SnackBar(content: Text(_formatError(e))));
              }
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
          child: const Text(
            'Accept',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

Future<void> openCpProposalFromNotification(Map<String, dynamic> notif) async {
  final metadata = notif['metadata'];
  Map<String, dynamic> meta = {};
  if (metadata is Map) {
    meta = Map<String, dynamic>.from(metadata);
  } else if (metadata is String && metadata.isNotEmpty) {
    try {
      meta = Map<String, dynamic>.from(jsonDecode(metadata) as Map);
    } catch (_) {}
  }

  final proposalId = meta['proposal_id']?.toString();
  if (proposalId == null) return;

  await openCpProposalAcceptScreen(null, proposalId: proposalId);
}

String _formatError(Object e) => e.toString().replaceFirst('Exception: ', '');
