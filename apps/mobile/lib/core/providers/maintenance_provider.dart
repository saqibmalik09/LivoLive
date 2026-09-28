import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaintenanceStatus {
  const MaintenanceStatus({required this.enabled, this.message = ''});

  final bool enabled;
  final String message;

  static const off = MaintenanceStatus(enabled: false);
}

final maintenanceProvider =
    StateNotifierProvider<MaintenanceNotifier, MaintenanceStatus>((ref) {
      final notifier = MaintenanceNotifier();
      ref.onDispose(notifier.stopPolling);
      return notifier;
    });

class MaintenanceNotifier extends StateNotifier<MaintenanceStatus> {
  MaintenanceNotifier() : super(MaintenanceStatus.off) {
    if (kDebugMode) return;
    unawaited(refresh());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
  }

  static const _pollInterval = Duration(seconds: 30);

  Timer? _timer;
  bool _inFlight = false;

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    if (kDebugMode) return;
    if (_inFlight) return;
    _inFlight = true;
    try {
      final raw = await Supabase.instance.client.rpc('get_app_maintenance');
      final map = _asMap(raw);
      final next = MaintenanceStatus(
        enabled: map['enabled'] == true,
        message: map['message']?.toString() ?? '',
      );
      if (next.enabled != state.enabled || next.message != state.message) {
        debugPrint('[MAINTENANCE] enabled=${next.enabled}');
      }
      if (mounted) state = next;
    } catch (e) {
      debugPrint('[MAINTENANCE] check failed: $e');
      if (mounted && state.enabled) state = MaintenanceStatus.off;
    } finally {
      _inFlight = false;
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }
}
