import 'package:flutter/material.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/features/home/presentation/pages/game_star/game_star_assets.dart';
import 'package:sk_live/l10n/app_localizations.dart';

Future<void> showGameStarRulesPopup(
  BuildContext context, {
  required String rules,
  DateTime? startAt,
  DateTime? endAt,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (ctx) {
      final screen = MediaQuery.sizeOf(ctx);
      final w = (screen.width * 0.9).clamp(280.0, 400.0);
      final h = w * (520 / 433);
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(GameStarAssets.rulesPopup, fit: BoxFit.fill),
              ),
              Positioned(
                left: w * 0.10,
                right: w * 0.10,
                top: h * 0.16,
                bottom: h * 0.08,
                child: ClipRect(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(4, 4, 8, 16),
                      child: _RulesBody(
                        rules: rules,
                        startAt: startAt,
                        endAt: endAt,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _RulesBody extends StatelessWidget {
  const _RulesBody({required this.rules, this.startAt, this.endAt});

  final String rules;
  final DateTime? startAt;
  final DateTime? endAt;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final blocks = _parseRules(
      rules,
      startAt: startAt,
      endAt: endAt,
      l10n: l10n,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in blocks) ...[
          if (block.isHeading)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Text(
                block.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                  shadows: [Shadow(blurRadius: 3, color: Colors.black54)],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4FC3F7),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      block.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 2, color: Colors.black45)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _RuleLine {
  const _RuleLine({required this.text, required this.isHeading});
  final String text;
  final bool isHeading;
}

List<_RuleLine> _parseRules(
  String raw, {
  DateTime? startAt,
  DateTime? endAt,
  required AppLocalizations l10n,
}) {
  final lines = raw
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  final out = <_RuleLine>[];

  final hasPeriod = lines.any(
    (l) =>
        l.toLowerCase().contains('event period') ||
        l.toLowerCase().contains(l10n.event_period.toLowerCase()),
  );
  if (!hasPeriod && (startAt != null || endAt != null)) {
    out.add(_RuleLine(text: l10n.event_period, isHeading: true));
    out.add(
      _RuleLine(
        text: _formatPeriod(startAt, endAt, l10n: l10n),
        isHeading: false,
      ),
    );
  }

  for (final line in lines) {
    final cleaned = line
        .replaceFirst(RegExp(r'^[\d]+[.)]\s*'), '')
        .replaceFirst(RegExp(r'^[•\-–*]\s*'), '')
        .trim();
    if (cleaned.isEmpty) continue;

    final isHeading = _looksLikeHeading(cleaned, line, l10n);
    out.add(_RuleLine(text: cleaned, isHeading: isHeading));
  }
  return out;
}

bool _looksLikeHeading(String cleaned, String original, AppLocalizations l10n) {
  if (original.startsWith('•') ||
      original.startsWith('-') ||
      original.startsWith('*') ||
      RegExp(r'^\d+[.)]').hasMatch(original)) {
    return false;
  }
  if (cleaned.length <= 42 && !cleaned.contains('. ')) {
    final lower = cleaned.toLowerCase();
    if (lower.contains('period') ||
        lower.contains('gameplay') ||
        lower.contains('points') ||
        lower.contains('leaderboard') ||
        lower.contains('ranking') ||
        lower.contains('reward') ||
        lower.contains('calculation') ||
        lower == cleaned && !cleaned.contains(':')) {
      if (!cleaned.contains(':') ||
          cleaned.endsWith('Rules') ||
          cleaned.endsWith('Rewards') ||
          cleaned.endsWith('Points') ||
          cleaned.endsWith('Period')) {
        return true;
      }
    }
  }
  final headings = {
    'Event Period',
    'Core Gameplay & Points',
    'Calculation Rules',
    'Leaderboard Ranking Rules',
    'Rewards',
    l10n.event_period,
    l10n.event_coreGameplay,
  };
  return headings.contains(cleaned);
}

String _formatPeriod(
  DateTime? start,
  DateTime? end, {
  required AppLocalizations l10n,
}) {
  String fmt(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = d.toLocal();
    return '${local.year}.${months[local.month - 1]} ${local.day}';
  }

  if (start != null && end != null) {
    return '${fmt(start)} – ${fmt(end)}';
  }
  if (end != null) return 'Until ${fmt(end)}';
  if (start != null) return 'From ${fmt(start)}';
  return l10n.event_duringWindow;
}
