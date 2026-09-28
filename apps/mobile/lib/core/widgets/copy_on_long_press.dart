import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CopyOnLongPress extends StatefulWidget {
  const CopyOnLongPress({
    super.key,
    required this.child,
    required this.text,
    this.borderRadius,
    this.emptyHint,
  });

  final Widget child;

  final String? text;
  final BorderRadius? borderRadius;

  final String? emptyHint;

  @override
  State<CopyOnLongPress> createState() => _CopyOnLongPressState();
}

class _CopyOnLongPressState extends State<CopyOnLongPress> {
  String? _badge;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _flash(String label) {
    _hideTimer?.cancel();
    setState(() => _badge = label);
    _hideTimer = Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() => _badge = null);
    });
  }

  void _onLongPress() {
    final text = widget.text?.trim() ?? '';
    if (text.isEmpty) {
      final hint = widget.emptyHint;
      if (hint != null && hint.isNotEmpty) {
        HapticFeedback.selectionClick();
        _flash(hint);
      }
      return;
    }
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    _flash('Copied');
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);
    return GestureDetector(
      onLongPress: _onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          if (_badge != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 120),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: radius,
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Text(
                          _badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
