import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/rupee_game_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class RupeeGameHelpScreen extends ConsumerWidget {
  const RupeeGameHelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helpAsync = ref.watch(rupeeGameHelpProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          context.l10n.game_help,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: helpAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => asyncErrorWidget(e),
        data: (sections) {
          if (sections.isEmpty) {
            return const Center(child: Text('No help content available.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sections.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final section = sections[index];
              return ExpansionTile(
                initiallyExpanded: section.isExpandedDefault,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                title: Text(
                  section.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                trailing: const Icon(
                  Iconsax.minus,
                  size: 18,
                  color: Colors.black54,
                ),
                children: section.items.map((item) {
                  final isFaq = item.trim().startsWith('Q:');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Colors.grey.shade800,
                          fontWeight: isFaq
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }
}
