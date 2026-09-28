import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskTrackerService {
  static final _supabase = Supabase.instance.client;

  static Future<void> trackAction(String key, {int amount = 1}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      debugPrint('[TASK_TRACKER]: Tracking action "$key" with amount $amount');

      final taskResponse = await _supabase
          .from('tasks')
          .select('id, target_count, category')
          .eq('key', key)
          .eq('is_active', true)
          .maybeSingle();

      if (taskResponse == null) {
        debugPrint(
          '[TASK_TRACKER_WARN]: Task key "$key" not found or inactive',
        );
        return;
      }

      final taskId = taskResponse['id'];
      final targetCount = taskResponse['target_count'] as int;
      final category = taskResponse['category'] ?? 'daily';

      final progressResponse = await _supabase
          .from('user_task_progress')
          .select('*')
          .eq('user_id', userId)
          .eq('task_id', taskId)
          .maybeSingle();

      if (progressResponse == null) {
        final int currentCount = amount;
        final bool isCompleted = currentCount >= targetCount;

        await _supabase.from('user_task_progress').insert({
          'user_id': userId,
          'task_id': taskId,
          'current_count': currentCount > targetCount
              ? targetCount
              : currentCount,
          'is_completed': isCompleted,
          'is_claimed': false,
          'last_reset_at': DateTime.now().toIso8601String(),
        });
        debugPrint(
          '[TASK_TRACKER]: Created progress record for "$key" at count $currentCount',
        );
      } else {
        bool needsReset = false;
        if (category == 'daily') {
          final String? lastResetStr = progressResponse['last_reset_at'];
          if (lastResetStr != null) {
            final lastReset = DateTime.parse(lastResetStr).toLocal();
            final now = DateTime.now();
            if (lastReset.year != now.year ||
                lastReset.month != now.month ||
                lastReset.day != now.day) {
              needsReset = true;
            }
          } else {
            needsReset = true;
          }
        }

        if (needsReset) {
          final int currentCount = amount;
          final bool isCompleted = currentCount >= targetCount;

          await _supabase
              .from('user_task_progress')
              .update({
                'current_count': currentCount > targetCount
                    ? targetCount
                    : currentCount,
                'is_completed': isCompleted,
                'is_claimed': false,
                'last_reset_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', progressResponse['id']);
          debugPrint(
            '[TASK_TRACKER]: Reset and updated progress for daily task "$key" to count $currentCount (Completed: $isCompleted)',
          );
        } else {
          if (progressResponse['is_completed'] == true) {
            debugPrint('[TASK_TRACKER]: Task "$key" already completed');
            return;
          }

          final int newCount =
              (progressResponse['current_count'] as int) + amount;
          final bool isCompleted = newCount >= targetCount;

          await _supabase
              .from('user_task_progress')
              .update({
                'current_count': newCount > targetCount
                    ? targetCount
                    : newCount,
                'is_completed': isCompleted,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', progressResponse['id']);
          debugPrint(
            '[TASK_TRACKER]: Updated progress for "$key" to count $newCount (Completed: $isCompleted)',
          );
        }
      }
    } catch (e) {
      debugPrint('[TASK_TRACKER_ERROR]: Failed to track action for "$key": $e');
    }
  }

  static Future<Map<String, dynamic>> claimReward(String progressId) async {
    try {
      debugPrint(
        '[TASK_TRACKER]: Claiming reward for progress ID: $progressId',
      );
      final response = await _supabase.rpc(
        'claim_task_reward',
        params: {'p_progress_id': progressId},
      );
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('[TASK_TRACKER_ERROR]: Claim reward failed: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<void> dailyCheckIn() async {
    await trackAction('sign_in');
  }
}
