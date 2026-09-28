import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rxdart/rxdart.dart';

final _supabase = Supabase.instance.client;

final userTasksProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final userId = _supabase.auth.currentUser?.id;
  if (userId == null) return Stream.value([]);

  final progressStream = _supabase
      .from('user_task_progress')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId);

  final tasksStream = _supabase
      .from('tasks')
      .stream(primaryKey: ['id'])
      .eq('is_active', true);

  return Rx.combineLatest2<
    List<Map<String, dynamic>>,
    List<Map<String, dynamic>>,
    List<Map<String, dynamic>>
  >(tasksStream, progressStream, (tasks, progresses) {
    final combined = tasks.map((task) {
      final progress = progresses.firstWhere(
        (p) => p['task_id'] == task['id'],
        orElse: () => <String, dynamic>{},
      );

      final lastResetStr = progress['last_reset_at'];
      bool isOldDailyTask = false;
      if (task['category'] == 'daily' && lastResetStr != null) {
        final lastReset = DateTime.parse(lastResetStr).toLocal();
        final now = DateTime.now();
        if (lastReset.year != now.year ||
            lastReset.month != now.month ||
            lastReset.day != now.day) {
          isOldDailyTask = true;
        }
      }

      return {
        ...task,
        'progress_id': isOldDailyTask ? null : progress['id'],
        'current_count': isOldDailyTask ? 0 : (progress['current_count'] ?? 0),
        'is_completed': isOldDailyTask
            ? false
            : (progress['is_completed'] ?? false),
        'is_claimed': isOldDailyTask
            ? false
            : (progress['is_claimed'] ?? false),
      };
    }).toList();

    combined.sort((a, b) {
      final aClaimed = a['is_claimed'] == true ? 1 : 0;
      final bClaimed = b['is_claimed'] == true ? 1 : 0;

      if (aClaimed != bClaimed) {
        return aClaimed.compareTo(bClaimed);
      }

      final aCompleted = a['is_completed'] == true ? 1 : 0;
      final bCompleted = b['is_completed'] == true ? 1 : 0;

      if (aCompleted != bCompleted) {
        return bCompleted.compareTo(aCompleted);
      }

      return (a['key'] as String).compareTo(b['key'] as String);
    });

    return combined;
  });
});
