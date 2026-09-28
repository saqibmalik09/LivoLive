import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/auth_provider.dart';
import 'package:sk_live/core/services/dm_realtime_hub.dart';
import 'package:sk_live/core/util/app_constants.dart';

class DmGatewayHost extends ConsumerStatefulWidget {
  const DmGatewayHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DmGatewayHost> createState() => _DmGatewayHostState();
}

class _DmGatewayHostState extends ConsumerState<DmGatewayHost> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authStateProvider).valueOrNull?.session;
    if (AppConstants.useDmGateway &&
        AppConstants.useRealtimeGateway &&
        session != null) {
      DmRealtimeHub.instance.ensureStarted();
    }
    return widget.child;
  }
}
