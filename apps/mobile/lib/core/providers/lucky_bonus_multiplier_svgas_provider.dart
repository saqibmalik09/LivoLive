import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LuckyBonusMultiplierSvga {
  final String id;
  final int multiplier;
  final String label;
  final String svgaUrl;
  final String appliesTo;

  const LuckyBonusMultiplierSvga({
    required this.id,
    required this.multiplier,
    required this.label,
    required this.svgaUrl,
    required this.appliesTo,
  });

  factory LuckyBonusMultiplierSvga.fromJson(Map<String, dynamic> json) {
    return LuckyBonusMultiplierSvga(
      id: json['id']?.toString() ?? '',
      multiplier: (json['multiplier'] as num?)?.toInt() ?? 0,
      label: json['label']?.toString() ?? '',
      svgaUrl: json['svga_url']?.toString() ?? '',
      appliesTo: json['applies_to']?.toString() ?? 'both',
    );
  }

  bool appliesFor(String variant) {
    if (appliesTo == 'both') return true;
    return appliesTo == variant;
  }
}

final luckyBonusMultiplierSvgasProvider =
    FutureProvider<List<LuckyBonusMultiplierSvga>>((ref) async {
      final rows = await Supabase.instance.client
          .from('lucky_bonus_multiplier_svgas')
          .select('id, multiplier, label, svga_url, applies_to')
          .eq('is_enabled', true)
          .order('multiplier');

      return (rows as List)
          .map(
            (e) => LuckyBonusMultiplierSvga.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .where((e) => e.svgaUrl.isNotEmpty && e.multiplier > 0)
          .toList();
    });

String? resolveLuckyBonusMultiplierSvgaUrl({
  required List<LuckyBonusMultiplierSvga> assets,
  required int multiplier,
  required String variant,
}) {
  if (multiplier <= 0 || assets.isEmpty) return null;
  final scoped = assets.where((a) => a.appliesFor(variant)).toList();
  if (scoped.isEmpty) return null;

  for (final a in scoped) {
    if (a.multiplier == multiplier) return a.svgaUrl;
  }

  LuckyBonusMultiplierSvga? best;
  for (final a in scoped) {
    if (a.multiplier <= multiplier &&
        (best == null || a.multiplier > best.multiplier)) {
      best = a;
    }
  }
  return best?.svgaUrl;
}
