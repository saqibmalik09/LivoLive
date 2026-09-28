import 'package:flutter/material.dart';
import 'package:sk_live/features/home/presentation/pages/cp_event/cp_event_assets.dart';

class CpEventTabButton extends StatelessWidget {
  const CpEventTabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                selected ? CpEventAssets.focusButton : CpEventAssets.button,
              ),
              fit: BoxFit.fill,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              shadows: selected
                  ? const [Shadow(blurRadius: 6, color: Colors.black45)]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
