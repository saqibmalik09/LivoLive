import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/bottom_nav_config_provider.dart';
import 'package:sk_live/core/providers/navigation_provider.dart';
import 'package:sk_live/core/providers/task_provider.dart';
import 'package:sk_live/features/wallet/presentation/pages/wallet_screen.dart';
import 'package:sk_live/features/task/data/task_center_provider.dart';
import 'package:sk_live/features/task/presentation/widgets/task_checkin_header.dart';
import 'package:sk_live/features/task/presentation/widgets/task_prize_wheel.dart';
import 'package:sk_live/features/task/presentation/widgets/task_section_list.dart';
import 'package:sk_live/features/task/presentation/widgets/task_theme.dart';
import 'package:sk_live/core/services/task_tracker_service.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskScreen extends ConsumerStatefulWidget {
  const TaskScreen({super.key});

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  bool _claimBusy = false;
  bool _checkinBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(userTasksProvider);
      ref.invalidate(taskCenterSummaryProvider);
      _maybeTrackEmailLinked();
    });
  }

  Future<void> _maybeTrackEmailLinked() async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email != null && email.trim().isNotEmpty) {
      await TaskTrackerService.trackAction('newbie_link_email');
    }
  }

  Future<void> _onCheckIn() async {
    if (_checkinBusy) return;
    setState(() => _checkinBusy = true);
    try {
      final res = await taskDailyCheckin();
      ref.invalidate(taskCenterSummaryProvider);
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Checked in! +${res['reward']} coins'),
            backgroundColor: TaskTheme.panel,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ?? context.l10n.task_checkinFailed,
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checkinBusy = false);
    }
  }

  Future<void> _onClaim(Map<String, dynamic> task) async {
    final progressId = task['progress_id']?.toString() ?? '';
    if (progressId.isEmpty || _claimBusy) return;
    setState(() => _claimBusy = true);
    try {
      final res = await TaskTrackerService.claimReward(progressId);
      ref.invalidate(userTasksProvider);
      ref.invalidate(taskCenterSummaryProvider);
      if (!mounted) return;
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Claimed ${res['reward_amount']} coins!'),
            backgroundColor: TaskTheme.panel,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ?? context.l10n.reward_claimFailed,
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _claimBusy = false);
    }
  }

  void _onGo(Map<String, dynamic> task) {
    final actionRoute = task['action_route']?.toString() ?? '';
    if (actionRoute.isEmpty || actionRoute == 'claim') return;

    if (actionRoute == '/trends') {
      Navigator.pop(context);
      ref.read(bottomNavIndexProvider.notifier).state = bottomNavIndexForKey(
        'party',
      );
    } else if (actionRoute == '/home') {
      Navigator.pop(context);
      ref.read(bottomNavIndexProvider.notifier).state = bottomNavIndexForKey(
        'home',
      );
    } else if (actionRoute == '/recharge' || actionRoute == '/wallet') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WalletScreen()),
      );
    } else if (actionRoute.startsWith('/')) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(userTasksProvider);
    final summaryAsync = ref.watch(taskCenterSummaryProvider);

    return Scaffold(
      backgroundColor: TaskTheme.deep,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: TaskTheme.pageBg),
            ),
          ),
          const Positioned.fill(child: CustomPaint(painter: _Starfield())),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: TaskTheme.goldButton,
                          boxShadow: [
                            BoxShadow(
                              color: TaskTheme.gold.withValues(alpha: 0.45),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Color(0xFF3B2500),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: tasksAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: TaskTheme.goldLight,
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        'Error: $e',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    data: (tasks) {
                      final filtered = tasks
                          .where((t) => t['key']?.toString() != 'sign_in')
                          .toList();
                      final newbie = filtered
                          .where((t) => t['category'] == 'newbie')
                          .toList();
                      final daily = filtered
                          .where((t) => t['category'] == 'daily')
                          .toList();
                      final summary =
                          summaryAsync.valueOrNull ?? TaskCenterSummary.empty;

                      return RefreshIndicator(
                        color: TaskTheme.goldLight,
                        backgroundColor: TaskTheme.panel,
                        onRefresh: () async {
                          ref.invalidate(userTasksProvider);
                          ref.invalidate(taskCenterSummaryProvider);
                          await ref.read(taskCenterSummaryProvider.future);
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            TaskCheckinHeader(
                              summary: summary,
                              busy: _checkinBusy,
                              onCheckIn: _onCheckIn,
                            ),
                            TaskSectionList(
                              title: context.l10n.task_newbieTasks,
                              tasks: newbie,
                              claimBusy: _claimBusy,
                              onClaim: _onClaim,
                              onGo: _onGo,
                            ),
                            TaskSectionList(
                              title: context.l10n.task_dailyTasks,
                              tasks: daily,
                              claimBusy: _claimBusy,
                              onClaim: _onClaim,
                              onGo: _onGo,
                            ),
                            TaskPrizeWheel(
                              remainingDraws: summary.wheelDraws,
                              spins: summary.spins,
                              segments: taskWheelSegmentsFromTiers(
                                summary.wheelTiers,
                              ),
                              onSpin: () async {
                                final res = await spinTaskWheel();
                                ref.invalidate(taskCenterSummaryProvider);
                                return res;
                              },
                              onEmptyDraw: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.l10n.task_noDrawsLeft,
                                    ),
                                    backgroundColor: TaskTheme.panel,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Starfield extends CustomPainter {
  const _Starfield();

  @override
  void paint(Canvas canvas, Size size) {
    TaskStarfieldPainter().paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
