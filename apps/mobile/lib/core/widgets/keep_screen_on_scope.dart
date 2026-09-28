import 'package:flutter/material.dart';
import 'package:sk_live/core/services/keep_screen_on_service.dart';

class KeepScreenOnScope extends StatefulWidget {
  final Widget child;

  const KeepScreenOnScope({super.key, required this.child});

  @override
  State<KeepScreenOnScope> createState() => _KeepScreenOnScopeState();
}

class _KeepScreenOnScopeState extends State<KeepScreenOnScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    KeepScreenOnService.enable();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    KeepScreenOnService.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    KeepScreenOnService.onAppLifecycleChange(state);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
