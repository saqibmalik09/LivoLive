import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/app_locale.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/core/providers/locale_provider.dart';
import 'package:sk_live/features/task/presentation/widgets/task_theme.dart';

class LanguageScreen extends ConsumerWidget {
  const LanguageScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LanguageScreen()));
  }

  String _nativeName(BuildContext context, String code) {
    final l = context.l10n;
    switch (code) {
      case 'en':
        return l.lang_english;
      case 'ar':
        return l.lang_arabic;
      case 'id':
        return l.lang_indonesian;
      case 'tr':
        return l.lang_turkish;
      case 'ur':
        return l.lang_urdu;
      case 'hi':
        return l.lang_hindi;
      case 'pt':
        return l.lang_portuguese;
      case 'th':
        return l.lang_thai;
      case 'vi':
        return l.lang_vietnamese;
      default:
        return code;
    }
  }

  String _subtitle(BuildContext context, String code) {
    final l = context.l10n;
    switch (code) {
      case 'en':
        return l.lang_subtitle_en;
      case 'ar':
        return l.lang_subtitle_ar;
      case 'id':
        return l.lang_subtitle_id;
      case 'tr':
        return l.lang_subtitle_tr;
      case 'ur':
        return l.lang_subtitle_ur;
      case 'hi':
        return l.lang_subtitle_hi;
      case 'pt':
        return l.lang_subtitle_pt;
      case 'th':
        return l.lang_subtitle_th;
      case 'vi':
        return l.lang_subtitle_vi;
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider).languageCode;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FB),
      appBar: AppBar(
        title: Text(
          l10n.lang_title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A2E),
        elevation: 0.5,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: AppLocale.codes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final code = AppLocale.codes[index];
          final selected = code == current;
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                if (selected) {
                  Navigator.pop(context);
                  return;
                }
                await ref.read(localeProvider.notifier).setLocaleCode(code);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.lang_changed)),
                );
                Navigator.pop(context);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nativeName(context, code),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subtitle(context, code),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: TaskTheme.goldButton,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: Color(0xFF3B2500),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
