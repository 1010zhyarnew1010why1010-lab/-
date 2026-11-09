// lib/widgets/subtitle_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
      bottom: 8,
      left: 8,
      right: 8,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        child: Container(
          key: ValueKey(text),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              text!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                height: 1.5,
                shadows: const [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 4,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 200.ms),
      ),
    );
  }
}
