// lib/widgets/subtitle_overlay.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SubtitleOverlay extends StatelessWidget {
  final String? text;
  final double fontSize;

  const SubtitleOverlay({
    super.key,
    required this.text,
    this.fontSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 12,
      left: 12,
      right: 12,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: Container(
          key: ValueKey(text),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xE60A101C), // Deep navy with 90% opacity
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.goldPrimary.withOpacity(0.4),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              text!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                color: AppTheme.goldPrimary,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                height: 1.5,
                shadows: const [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 6,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
