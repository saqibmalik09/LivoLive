import 'package:flutter/material.dart';
import 'package:pag/pag.dart';

class RefPagLoop extends StatefulWidget {
  const RefPagLoop({
    super.key,
    required this.asset,
    required this.width,
    required this.height,
    required this.active,
    this.placeholder = const SizedBox.expand(),
  });

  final String asset;
  final double width;
  final double height;
  final bool active;
  final Widget placeholder;

  @override
  State<RefPagLoop> createState() => _RefPagLoopState();
}

class _RefPagLoopState extends State<RefPagLoop> with WidgetsBindingObserver {
  final GlobalKey<PAGViewState> _pagKey = GlobalKey<PAGViewState>();
  bool _appResumed = true;
  bool _shownOnScreen = true;
  bool? _playing;

  bool get _shouldPlay => _shownOnScreen && _appResumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _appResumed) return;
    _appResumed = resumed;
    _apply();
  }

  void _apply() {
    final shouldPlay = _shouldPlay;
    if (_playing == shouldPlay) return;
    final pag = _pagKey.currentState;
    if (!mounted || pag == null) return;
    if (shouldPlay) {
      pag.start();
    } else {
      pag.pause();
    }
    _playing = shouldPlay;
  }

  @override
  Widget build(BuildContext context) {
    _shownOnScreen = widget.active && TickerMode.valuesOf(context).enabled;
    if (_playing != _shouldPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _apply());
    }
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.placeholder,
            PAGView.asset(
              widget.asset,
              key: _pagKey,
              width: widget.width,
              height: widget.height,
              repeatCount: PAGView.REPEAT_COUNT_LOOP,
              autoPlay: false,
              defaultBuilder: (_) => const SizedBox.shrink(),
              onInit: () {
                _playing = null;
                _apply();
              },
            ),
          ],
        ),
      ),
    );
  }
}
