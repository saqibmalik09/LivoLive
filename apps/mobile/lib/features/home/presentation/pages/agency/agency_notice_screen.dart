import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sk_live/core/providers/agency_center_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class AgencyNoticeScreen extends ConsumerStatefulWidget {
  const AgencyNoticeScreen({super.key, required this.agencyId});

  final String agencyId;

  @override
  ConsumerState<AgencyNoticeScreen> createState() => _AgencyNoticeScreenState();
}

class _AgencyNoticeScreenState extends ConsumerState<AgencyNoticeScreen> {
  Future<void> _compose() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New notice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(hintText: 'Title'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Content'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Post'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ref
        .read(agencyCenterActionsProvider)
        .postNotice(
          agencyId: widget.agencyId,
          title: titleCtrl.text.trim(),
          body: bodyCtrl.text.trim(),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          res['message']?.toString() ??
              (res['success'] == true ? 'Posted' : 'Failed'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noticesAsync = ref.watch(agencyNoticesProvider(widget.agencyId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notice',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _compose,
            icon: const Icon(Icons.add, color: Colors.black),
            tooltip: 'Post notice',
          ),
        ],
      ),
      body: noticesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => asyncErrorWidget(e),
        data: (notices) {
          if (notices.isEmpty) {
            return const Center(
              child: Text(
                'No notices yet',
                style: TextStyle(color: Colors.black45),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notices.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = notices[i];
              final author = n['author'] as Map<String, dynamic>?;
              final created = DateTime.tryParse(
                n['created_at']?.toString() ?? '',
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n['title']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(n['body']?.toString() ?? ''),
                    const SizedBox(height: 6),
                    Text(
                      '${author?['username'] ?? 'Staff'}'
                      '${created != null ? ' · ${DateFormat('yyyy-MM-dd HH:mm').format(created.toLocal())}' : ''}',
                      style: const TextStyle(
                        color: Colors.black38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
