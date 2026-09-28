import 'dart:async';

import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/material.dart';
import 'package:sk_live/core/services/app_telemetry.dart';

class TelemetryRouteObserver extends NavigatorObserver {
  String? _activeRoute;
  Trace? _activeTrace;

  String _routeName(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) return name;
    return route.settings.arguments?.toString() ?? route.runtimeType.toString();
  }

  Future<void> _startScreenTrace(String routeName) async {
    if (routeName.isEmpty || routeName == _activeRoute) return;
    await _stopScreenTrace();
    _activeRoute = routeName;
    unawaited(AppTelemetry.logScreenView(routeName));
    _activeTrace = AppTelemetry.startTrace('screen_$routeName');
  }

  Future<void> _stopScreenTrace() async {
    await AppTelemetry.stopTrace(_activeTrace);
    _activeTrace = null;
    _activeRoute = null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    unawaited(_startScreenTrace(_routeName(route)));
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      unawaited(_startScreenTrace(_routeName(newRoute)));
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      unawaited(_startScreenTrace(_routeName(previousRoute)));
    } else {
      unawaited(_stopScreenTrace());
    }
  }
}

final telemetryRouteObserver = TelemetryRouteObserver();
