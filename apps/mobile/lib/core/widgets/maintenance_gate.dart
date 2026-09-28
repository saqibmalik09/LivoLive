import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/active_room_provider.dart';
import 'package:sk_live/core/providers/maintenance_provider.dart';
import 'package:sk_live/core/services/room_exit_coordinator.dart';
import 'package:sk_live/core/theme/app_colors.dart';

class MaintenanceGate extends ConsumerStatefulWidget {
  const MaintenanceGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends ConsumerState<MaintenanceGate> {
  bool _tearingDown = false;

  Future<void> _leaveActiveRoom() async {
    if (_tearingDown) return;
    final roomId =
        ref.read(currentLiveRoomIdProvider) ??
        ref.read(minimizedRoomProvider)?['id']?.toString();
    if (roomId == null || roomId.isEmpty) return;
    _tearingDown = true;
    try {
      await RoomExitCoordinator.leaveRoom(ref, roomId: roomId);
    } catch (e) {
      debugPrint('[MAINTENANCE] room teardown failed: $e');
    } finally {
      _tearingDown = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MaintenanceStatus>(maintenanceProvider, (prev, next) {
      if (next.enabled && prev?.enabled != true) {
        unawaited(_leaveActiveRoom());
      }
    });

    final status = ref.watch(maintenanceProvider);
    if (!status.enabled) return widget.child;

    return Stack(
      children: [
        widget.child,
        PopScope(
          canPop: false,
          child: Scaffold(
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(gradient: AppColors.roomGradient),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.build_circle_outlined,
                          color: AppColors.primaryLight,
                          size: 72,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const Text(
                        'Under Maintenance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        status.message.trim().isEmpty
                            ? 'LIVO is temporarily unavailable while we carry '
                                  'out maintenance. Please check back shortly.'
                            : status.message,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 15,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => unawaited(
                            ref.read(maintenanceProvider.notifier).refresh(),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 8,
                            shadowColor: AppColors.primary.withOpacity(0.4),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh_rounded),
                              SizedBox(width: 10),
                              Text(
                                'Try Again',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'This screen closes automatically once we are back.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
