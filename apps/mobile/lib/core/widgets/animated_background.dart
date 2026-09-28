import 'dart:async';
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final List<String> images;
  final Widget? child;
  final Duration switchDuration;
  final Duration fadeDuration;

  const AnimatedBackground({
    super.key,
    required this.images,
    this.child,
    this.switchDuration = const Duration(seconds: 5),
    this.fadeDuration = const Duration(seconds: 2),
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(widget.switchDuration, (timer) {
      if (mounted) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % widget.images.length;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ...widget.images.asMap().entries.map((entry) {
          final index = entry.key;
          final imagePath = entry.value;
          return AnimatedOpacity(
            opacity: _currentIndex == index ? 1.0 : 0.0,
            duration: widget.fadeDuration,
            curve: Curves.easeInOut,
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.3),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
          );
        }),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}
