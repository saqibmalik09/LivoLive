import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/auth_provider.dart';

/// Optimistic wallet coins for gift UI. Avoids `invalidate(userProfileProvider)`
/// after every send (that flashes loading for seconds under gift storms).
final walletCoinsOverrideProvider = StateProvider<int?>((ref) => null);

int resolveWalletCoins(dynamic ref, Map<String, dynamic>? profile) {
  final override = ref.read(walletCoinsOverrideProvider);
  if (override != null) return override;
  return (profile?['coins'] as num?)?.toInt() ?? 0;
}

void applyOptimisticCoinSpend(dynamic ref, int cost) {
  if (cost <= 0) return;
  final profile = ref.read(userProfileProvider).valueOrNull;
  final current = resolveWalletCoins(ref, profile);
  ref.read(walletCoinsOverrideProvider.notifier).state =
      (current - cost).clamp(0, 1 << 62);
}

void refundOptimisticCoinSpend(dynamic ref, int cost) {
  if (cost <= 0) return;
  final profile = ref.read(userProfileProvider).valueOrNull;
  final current = resolveWalletCoins(ref, profile);
  ref.read(walletCoinsOverrideProvider.notifier).state = current + cost;
}

void syncWalletCoinsOverrideFromProfile(
  dynamic ref,
  Map<String, dynamic>? profile,
) {
  final override = ref.read(walletCoinsOverrideProvider);
  if (override == null || profile == null) return;
  final server = (profile['coins'] as num?)?.toInt();
  if (server == null) return;
  // Spend confirmed (server dropped to/below optimistic), or stale local
  // override at 0 while the profile still has coins — that used to lock Send
  // forever ("insufficient coins" / dead button) after a bad sync.
  if (server <= override || (override <= 0 && server > 0)) {
    ref.read(walletCoinsOverrideProvider.notifier).state = null;
  }
}

/// Call when opening the gift sheet so a previous room's override cannot
/// block sends with a fake 0 balance.
void clearStaleWalletOverrideForGiftSheet(
  dynamic ref,
  Map<String, dynamic>? profile,
) {
  final override = ref.read(walletCoinsOverrideProvider);
  if (override == null) return;
  final server = (profile?['coins'] as num?)?.toInt();
  if (server == null) return;
  if (override <= 0 && server > 0) {
    ref.read(walletCoinsOverrideProvider.notifier).state = null;
  }
  if (server <= override) {
    ref.read(walletCoinsOverrideProvider.notifier).state = null;
  }
}
