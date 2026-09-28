import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sk_live/core/services/home_hot_cards_cache_service.dart';

enum HotCardMediaType { image, svga, video }

enum HotCarouselLink { game, cp, charm }

class HotCardMedia {
  const HotCardMedia({required this.url, required this.mediaType});

  final String url;
  final HotCardMediaType mediaType;

  String versionedUrl(String version) {
    if (url.isEmpty) return url;
    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters);
    params['v'] = version;
    return uri.replace(queryParameters: params).toString();
  }
}

class HotCarouselSlide {
  const HotCarouselSlide({required this.media, required this.link});

  final HotCardMedia media;
  final HotCarouselLink link;
}

class HomeHotCardsConfig {
  const HomeHotCardsConfig({
    required this.slides,
    required this.partyCard,
    required this.musicCard,
    required this.carouselIntervalMs,
    this.partyCardRoomId,
    this.musicCardRoomId,
    this.updatedAt,
  });

  final List<HotCarouselSlide> slides;
  final HotCardMedia partyCard;
  final HotCardMedia musicCard;
  final int carouselIntervalMs;
  final String? partyCardRoomId;
  final String? musicCardRoomId;
  final DateTime? updatedAt;

  String get cacheVersion =>
      updatedAt?.millisecondsSinceEpoch.toString() ?? slides.length.toString();

  factory HomeHotCardsConfig.fromMap(Map<String, dynamic> map) {
    DateTime? updatedAt;
    final raw = map['updated_at'];
    if (raw is String && raw.isNotEmpty) {
      updatedAt = DateTime.tryParse(raw);
    }

    HotCardMedia mediaFor(String prefix) {
      return HotCardMedia(
        url: (map['${prefix}_url'] as String?)?.trim() ?? '',
        mediaType: _parseMediaType(map['${prefix}_media_type'] as String?),
      );
    }

    String? roomId(String key) {
      final v = map[key]?.toString().trim();
      if (v == null || v.isEmpty) return null;
      return v;
    }

    return HomeHotCardsConfig(
      slides: [
        HotCarouselSlide(
          media: mediaFor('carousel_1'),
          link: _parseLink(
            map['carousel_1_link'] as String?,
            HotCarouselLink.game,
          ),
        ),
        HotCarouselSlide(
          media: mediaFor('carousel_2'),
          link: _parseLink(
            map['carousel_2_link'] as String?,
            HotCarouselLink.cp,
          ),
        ),
        HotCarouselSlide(
          media: mediaFor('carousel_3'),
          link: _parseLink(
            map['carousel_3_link'] as String?,
            HotCarouselLink.charm,
          ),
        ),
      ],
      partyCard: mediaFor('party_card'),
      musicCard: mediaFor('music_card'),
      partyCardRoomId: roomId('party_card_room_id'),
      musicCardRoomId: roomId('music_card_room_id'),
      carouselIntervalMs:
          (map['carousel_interval_ms'] as num?)?.toInt() ?? 4000,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'carousel_1_url': slides.isNotEmpty ? slides[0].media.url : '',
    'carousel_1_media_type': slides.isNotEmpty
        ? slides[0].media.mediaType.name
        : 'image',
    'carousel_1_link': slides.isNotEmpty ? slides[0].link.name : 'game',
    'carousel_2_url': slides.length > 1 ? slides[1].media.url : '',
    'carousel_2_media_type': slides.length > 1
        ? slides[1].media.mediaType.name
        : 'image',
    'carousel_2_link': slides.length > 1 ? slides[1].link.name : 'cp',
    'carousel_3_url': slides.length > 2 ? slides[2].media.url : '',
    'carousel_3_media_type': slides.length > 2
        ? slides[2].media.mediaType.name
        : 'image',
    'carousel_3_link': slides.length > 2 ? slides[2].link.name : 'charm',
    'party_card_url': partyCard.url,
    'party_card_media_type': partyCard.mediaType.name,
    'party_card_room_id': partyCardRoomId,
    'music_card_url': musicCard.url,
    'music_card_media_type': musicCard.mediaType.name,
    'music_card_room_id': musicCardRoomId,
    'carousel_interval_ms': carouselIntervalMs,
    'updated_at': updatedAt?.toIso8601String(),
  };

  static HomeHotCardsConfig defaults() => HomeHotCardsConfig.fromMap({});

  static HotCardMediaType _parseMediaType(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'svga':
        return HotCardMediaType.svga;
      case 'video':
        return HotCardMediaType.video;
      default:
        return HotCardMediaType.image;
    }
  }

  static HotCarouselLink _parseLink(String? raw, HotCarouselLink fallback) {
    switch (raw?.toLowerCase()) {
      case 'cp':
        return HotCarouselLink.cp;
      case 'charm':
        return HotCarouselLink.charm;
      case 'game':
        return HotCarouselLink.game;
      default:
        return fallback;
    }
  }
}

class HomeHotCardsConfigNotifier extends AsyncNotifier<HomeHotCardsConfig> {
  @override
  Future<HomeHotCardsConfig> build() async {
    ref.keepAlive();
    final cached = await HomeHotCardsCacheService.loadCached();
    if (cached != null) {
      unawaited(_silentRefresh());
      return cached;
    }
    final remote = await _fetchRemote();
    await HomeHotCardsCacheService.saveCached(remote);
    return remote;
  }

  Future<void> _silentRefresh() async {
    try {
      final cached = await HomeHotCardsCacheService.loadCached();
      final remote = await _fetchRemote();
      if (!HomeHotCardsCacheService.hasChanged(cached, remote)) return;
      await HomeHotCardsCacheService.saveCached(remote);
      state = AsyncData(remote);
    } catch (e) {
      debugPrint('[HomeHotCardsConfig] silent refresh failed: $e');
    }
  }

  Future<HomeHotCardsConfig> _fetchRemote() async {
    try {
      final response = await Supabase.instance.client
          .from('home_hot_cards_config')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (response == null) return HomeHotCardsConfig.defaults();
      return HomeHotCardsConfig.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('[HomeHotCardsConfig] fetch failed: $e');
      return await HomeHotCardsCacheService.loadCached() ??
          HomeHotCardsConfig.defaults();
    }
  }
}

final homeHotCardsConfigProvider =
    AsyncNotifierProvider<HomeHotCardsConfigNotifier, HomeHotCardsConfig>(
      HomeHotCardsConfigNotifier.new,
    );
