import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserLevelKind { wealth, charm, agency }

const levelRewardFeatureKeys = [
  'frame',
  'bubble',
  'card_background',
  'entrance',
];

const agencyProfileFrameKeys = ['hero_frame', 'honor_frame', 'charm_frame'];

final wealthLevelConfigsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final client = Supabase.instance.client;

  final configs = await client
      .from('level_configs')
      .select()
      .eq('category', 'user_wealth')
      .order('level', ascending: true);

  final assets = await client
      .from('wealth_level_assets')
      .select('level, feature_key, shop_item_id, shop_items(name, image_url)');

  return List<Map<String, dynamic>>.from(configs).map((config) {
    final level = config['level'];
    final levelAssets = (assets as List)
        .where((asset) => asset['level'] == level)
        .map((asset) => Map<String, dynamic>.from(asset as Map))
        .toList();
    return {
      ...Map<String, dynamic>.from(config),
      'wealth_level_assets': levelAssets,
    };
  }).toList();
});

final charmLevelConfigsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final response = await Supabase.instance.client
      .from('charm_level_configs')
      .select(
        '*, charm_level_assets(feature_key, image_url, shop_item_id, shop_items(name, image_url))',
      )
      .order('level', ascending: true);

  return List<Map<String, dynamic>>.from(response);
});

final agencyLevelConfigsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final response = await Supabase.instance.client
      .from('agency_level_configs')
      .select(
        '*, agency_level_assets(feature_key, image_url, shop_item_id, shop_items(name, image_url))',
      )
      .order('level', ascending: true);

  return List<Map<String, dynamic>>.from(response);
});

String? badgeUrlForLevelConfig(
  UserLevelKind kind,
  Map<String, dynamic> config,
) {
  if (kind == UserLevelKind.wealth || kind == UserLevelKind.agency) {
    return config['badge_url']?.toString();
  }

  final assets = config['charm_level_assets'] as List?;
  if (assets == null) return null;

  for (final asset in assets) {
    if (asset is Map && asset['feature_key'] == 'badge') {
      return asset['image_url']?.toString();
    }
  }
  return null;
}

String? agencyProfileFrameUrl(Map<String, dynamic> config, String featureKey) {
  final assets = config['agency_level_assets'] as List? ?? [];
  for (final asset in assets) {
    if (asset is Map && asset['feature_key'] == featureKey) {
      final url = asset['image_url']?.toString();
      if (url != null && url.isNotEmpty) return url;
    }
  }
  return null;
}

String? agencyHeroFrameUrl(Map<String, dynamic> config) =>
    agencyProfileFrameUrl(config, 'hero_frame');

String? agencyHonorFrameUrl(Map<String, dynamic> config) =>
    agencyProfileFrameUrl(config, 'honor_frame');

String? agencyCharmFrameUrl(Map<String, dynamic> config) =>
    agencyProfileFrameUrl(config, 'charm_frame');

String? agencyBadgeUrl(Map<String, dynamic> config) =>
    config['badge_url']?.toString();

int agencyLevelFromExp(List<Map<String, dynamic>> configs, int exp) {
  if (configs.isEmpty) return 0;
  var level = 0;
  var matched = false;
  for (final config in configs) {
    final minExp = (config['min_exp'] as num?)?.toInt() ?? 0;
    if (exp >= minExp) {
      level = (config['level'] as num?)?.toInt() ?? level;
      matched = true;
    }
  }
  return matched ? level : 0;
}

Map<String, dynamic>? agencyConfigForLevel(
  List<Map<String, dynamic>> configs,
  int level,
) {
  for (final config in configs) {
    if ((config['level'] as num?)?.toInt() == level) {
      return config;
    }
  }
  return configs.isNotEmpty ? configs.first : null;
}

String agencyTierName(List<Map<String, dynamic>> configs, int level) {
  final config = agencyConfigForLevel(configs, level);
  return config?['tier_name']?.toString() ?? 'Bronze Agency';
}

int agencyExpThreshold(List<Map<String, dynamic>> configs, int level) {
  final config = agencyConfigForLevel(configs, level);
  return (config?['min_exp'] as num?)?.toInt() ?? 0;
}

List<Map<String, dynamic>> rewardAssetsForLevel(
  UserLevelKind kind,
  Map<String, dynamic> config,
) {
  final List<Map<String, dynamic>> rewards = [];
  final assetsKey = switch (kind) {
    UserLevelKind.wealth => 'wealth_level_assets',
    UserLevelKind.charm => 'charm_level_assets',
    UserLevelKind.agency => 'agency_level_assets',
  };
  final assets = config[assetsKey] as List? ?? [];

  for (final key in levelRewardFeatureKeys) {
    Map<String, dynamic>? match;
    for (final asset in assets) {
      if (asset is Map &&
          asset['feature_key'] == key &&
          asset['shop_item_id'] != null) {
        match = Map<String, dynamic>.from(asset);
        break;
      }
    }
    if (match != null) {
      rewards.add({'feature_key': key, 'level': config['level'], ...match});
    }
  }
  return rewards;
}

double calculateLevelProgress(num current, num min, num next) {
  if (next <= min) return 1.0;
  return ((current - min) / (next - min)).clamp(0.0, 1.0);
}

({Map<String, dynamic>? prev, Map<String, dynamic>? next}) levelWindow(
  List<Map<String, dynamic>> configs,
  int currentLevel,
) {
  Map<String, dynamic>? prev;
  Map<String, dynamic>? next;

  for (final config in configs) {
    final lvl = (config['level'] as num?)?.toInt() ?? 0;
    if (lvl > currentLevel) {
      next = config;
      break;
    }
    if (lvl == currentLevel) {
      prev = config;
    }
  }

  return (prev: prev, next: next);
}
