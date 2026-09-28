import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailySignInDayReward {
  const DailySignInDayReward({
    required this.dayNumber,
    required this.rewardType,
    required this.coinAmount,
    this.shopItemId,
    this.imageUrl,
    this.label,
    this.shopItemName,
  });

  final int dayNumber;
  final String rewardType;
  final int coinAmount;
  final String? shopItemId;
  final String? imageUrl;
  final String? label;
  final String? shopItemName;

  bool get isAsset => rewardType == 'shop_item';

  factory DailySignInDayReward.fromJson(Map<String, dynamic> json) {
    return DailySignInDayReward(
      dayNumber: (json['day_number'] as num?)?.toInt() ?? 0,
      rewardType: json['reward_type']?.toString() ?? 'coins',
      coinAmount: (json['coin_amount'] as num?)?.toInt() ?? 0,
      shopItemId: json['shop_item_id']?.toString(),
      imageUrl: json['image_url']?.toString(),
      label: json['label']?.toString(),
      shopItemName: json['shop_item_name']?.toString(),
    );
  }
}

class DailySignInSummary {
  const DailySignInSummary({
    required this.streakDay,
    required this.consecutiveDays,
    required this.checkedToday,
    required this.days,
  });

  final int streakDay;
  final int consecutiveDays;
  final bool checkedToday;
  final List<DailySignInDayReward> days;
}

class DailySignInService {
  DailySignInService._();

  static const _popupPrefPrefix = 'daily_signin_popup_';

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  static String _userId() =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  static Future<DailySignInSummary?> fetchSummary() async {
    try {
      final raw = await Supabase.instance.client.rpc(
        'get_daily_signin_summary',
      );
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      if (map['success'] != true) return null;
      final daysRaw = map['days'];
      final days = <DailySignInDayReward>[];
      if (daysRaw is List) {
        for (final d in daysRaw) {
          if (d is Map) {
            days.add(
              DailySignInDayReward.fromJson(Map<String, dynamic>.from(d)),
            );
          }
        }
      }
      days.sort((a, b) => a.dayNumber.compareTo(b.dayNumber));
      return DailySignInSummary(
        streakDay: (map['streak_day'] as num?)?.toInt() ?? 0,
        consecutiveDays: (map['consecutive_days'] as num?)?.toInt() ?? 0,
        checkedToday: map['checked_today'] == true,
        days: days,
      );
    } catch (e) {
      debugPrint('[DailySignIn] fetchSummary failed: $e');
      return null;
    }
  }

  static Future<bool> shouldShowPopup() async {
    final userId = _userId();
    if (userId.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final shownKey = '$_popupPrefPrefix${userId}_${_todayKey()}';
    if (prefs.getBool(shownKey) == true) return false;

    final summary = await fetchSummary();
    if (summary == null) return false;
    if (summary.checkedToday) return false;
    return true;
  }

  static Future<void> markPopupShown() async {
    final userId = _userId();
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_popupPrefPrefix${userId}_${_todayKey()}', true);
  }

  static Future<({bool ok, String message, int streak, int? coins})>
  performSignIn() async {
    try {
      final raw = await Supabase.instance.client.rpc('task_daily_checkin');
      final map = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final ok = map['success'] == true;
      await markPopupShown();
      return (
        ok: ok,
        message:
            map['message']?.toString() ??
            (ok ? 'Signed in successfully!' : 'Could not sign in'),
        streak: (map['streak_day'] as num?)?.toInt() ?? 0,
        coins:
            (map['coin_amount'] as num?)?.toInt() ??
            (map['reward'] as num?)?.toInt(),
      );
    } catch (e) {
      debugPrint('[DailySignIn] performSignIn failed: $e');
      return (
        ok: false,
        message: 'Could not sign in. Try again.',
        streak: 0,
        coins: null,
      );
    }
  }
}
