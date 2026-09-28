import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sk_live/core/services/party_screen_cache_service.dart';

class PartyScreenConfig {
  const PartyScreenConfig({
    required this.topImageUrl,
    required this.bottomImageUrl,
    this.updatedAt,
  });

  final String topImageUrl;
  final String bottomImageUrl;
  final DateTime? updatedAt;

  static const fallbackTopAsset = 'assets/home/party_top_hot.webp';
  static const fallbackBottomAsset = 'assets/home/party_bottom_hot.webp';

  static const fallbackAsset = fallbackTopAsset;

  String get cacheVersion =>
      updatedAt?.millisecondsSinceEpoch.toString() ??
      '$topImageUrl$bottomImageUrl'.hashCode.toString();

  String versionedUrl(String url) {
    if (url.isEmpty) return url;
    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters);
    params['v'] = cacheVersion;
    return uri.replace(queryParameters: params).toString();
  }

  String get versionedTopUrl => versionedUrl(topImageUrl);
  String get versionedBottomUrl => versionedUrl(bottomImageUrl);

  factory PartyScreenConfig.fromMap(Map<String, dynamic> map) {
    DateTime? updatedAt;
    final raw = map['updated_at'];
    if (raw is String && raw.isNotEmpty) {
      updatedAt = DateTime.tryParse(raw);
    }
    return PartyScreenConfig(
      topImageUrl: (map['top_image_url'] as String?)?.trim() ?? '',
      bottomImageUrl: (map['bottom_image_url'] as String?)?.trim() ?? '',
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'top_image_url': topImageUrl,
    'bottom_image_url': bottomImageUrl,
    'updated_at': updatedAt?.toIso8601String(),
  };

  static PartyScreenConfig empty() =>
      const PartyScreenConfig(topImageUrl: '', bottomImageUrl: '');
}

class PartyScreenConfigNotifier extends AsyncNotifier<PartyScreenConfig> {
  bool _refreshScheduled = false;

  @override
  Future<PartyScreenConfig> build() async {
    ref.keepAlive();

    final cached = await PartyScreenCacheService.loadCached();
    if (cached != null) {
      _scheduleSilentRefresh();
      return cached;
    }

    final remote = await _fetchRemote();
    await PartyScreenCacheService.saveCached(remote);
    return remote;
  }

  Future<void> checkForUpdatesSilently() async {
    try {
      final cached =
          state.valueOrNull ?? await PartyScreenCacheService.loadCached();
      final remote = await _fetchRemote();
      if (!PartyScreenCacheService.hasChanged(cached, remote)) return;
      await PartyScreenCacheService.saveCached(remote);
      state = AsyncData(remote);
    } catch (e) {
      debugPrint('[PartyScreenConfig] silent check failed: $e');
    }
  }

  void _scheduleSilentRefresh() {
    if (_refreshScheduled) return;
    _refreshScheduled = true;
    unawaited(
      Future<void>(() async {
        try {
          final cached = await PartyScreenCacheService.loadCached();
          final remote = await _fetchRemote();
          if (!PartyScreenCacheService.hasChanged(cached, remote)) return;
          await PartyScreenCacheService.saveCached(remote);
          state = AsyncData(remote);
        } catch (e) {
          debugPrint('[PartyScreenConfig] silent refresh failed: $e');
        }
      }),
    );
  }

  Future<PartyScreenConfig> _fetchRemote() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('party_screen_config')
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (response == null) return PartyScreenConfig.empty();
      return PartyScreenConfig.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('[PartyScreenConfig] fetch failed: $e');
      return await PartyScreenCacheService.loadCached() ??
          PartyScreenConfig.empty();
    }
  }
}

final partyScreenConfigProvider =
    AsyncNotifierProvider<PartyScreenConfigNotifier, PartyScreenConfig>(
      PartyScreenConfigNotifier.new,
    );
