import 'package:flutter/material.dart';
import 'package:sk_live/features/real_name/presentation/widgets/real_name_theme.dart';

class RealNameWarningBanner extends StatelessWidget {
  const RealNameWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: RealNameTheme.warningBg,
      child: const Text(
        'The following information is required, in order to ensure your interests, please fill in the truth.',
        style: TextStyle(
          color: RealNameTheme.warningText,
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}

class RealNamePrimaryButton extends StatelessWidget {
  const RealNamePrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: RealNameTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: RealNameTheme.primary.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}

class RealNameLabeledField extends StatelessWidget {
  const RealNameLabeledField({
    super.key,
    required this.label,
    required this.child,
    this.required = false,
  });

  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              if (required)
                const TextSpan(
                  text: '* ',
                  style: TextStyle(
                    color: RealNameTheme.warningText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              TextSpan(
                text: label,
                style: const TextStyle(
                  color: RealNameTheme.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
