import 'package:sk_live/core/providers/party_events_provider.dart';

class PartyEventContent {
  const PartyEventContent({
    required this.event,
    required this.rules,
    required this.rewards,
    required this.ctaLabel,
    required this.webUrl,
    required this.pageTitle,
    required this.cpGiftIds,
  });

  final PartyEvent event;
  final String rules;
  final String rewards;
  final String ctaLabel;
  final String webUrl;
  final String pageTitle;
  final List<String> cpGiftIds;

  factory PartyEventContent.fromEvent(PartyEvent event) {
    final cfg = event.actionConfig;
    final giftRaw = cfg['cp_gift_ids'];
    final giftIds = <String>[];
    if (giftRaw is List) {
      for (final g in giftRaw) {
        final id = g?.toString().trim() ?? '';
        if (id.isNotEmpty) giftIds.add(id);
      }
    }
    return PartyEventContent(
      event: event,
      rules: (cfg['rules'] as String?)?.trim() ?? '',
      rewards: (cfg['rewards'] as String?)?.trim() ?? '',
      ctaLabel: (cfg['cta_label'] as String?)?.trim().isNotEmpty == true
          ? cfg['cta_label'] as String
          : 'Open CP Nest',
      webUrl: (cfg['web_url'] as String?)?.trim() ?? '',
      pageTitle: (cfg['page_title'] as String?)?.trim() ?? event.title,
      cpGiftIds: giftIds,
    );
  }
}
