// lib/widgets/gold_button.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double? width;

  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 54.0,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: isEnabled
            ? AppTheme.goldGradient
            : LinearGradient(
                colors: [
                  AppTheme.goldMuted.withOpacity(0.4),
                  AppTheme.goldDark.withOpacity(0.3),
                ],
              ),
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: AppTheme.goldPrimary.withOpacity(0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: isEnabled ? onPressed : null,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.textDark,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontFamily: 'NotoNaskhArabic',
                          color: AppTheme.textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (icon != null) ...[
                        const SizedBox(width: 8),
                        Icon(icon, color: AppTheme.textDark, size: 20),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
