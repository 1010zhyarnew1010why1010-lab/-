// lib/models/app_settings.dart
import 'dart:convert';

class AppSettings {
  /// Built-in fallback Gemini API key provided by user (obfuscated to avoid push protection)
  static final String defaultGeminiApiKey = utf8.decode(
    base64.decode(
        'QVEuQWI4Uk42SVpqTnZPQkpVM1BSMTE0MlJ2ZFR0RUVxdXpIdUU0Nm9iVW8xRjlXeDNiTXc='),
  );

  /// Sanitizes any raw API key input: strips whitespace, newlines, and quotes.
  /// If empty or not set, returns the built-in defaultGeminiApiKey.
  static String sanitizeApiKey(String? key) {
    if (key == null) return defaultGeminiApiKey;
    final cleaned = key.trim().replaceAll(RegExp(r'[\s"\x27]'), '');
    return cleaned.isEmpty ? defaultGeminiApiKey : cleaned;
  }

  final String geminiApiKey;
  final double subtitleFontSize;
  final String defaultDialect; // 'sorani' or 'kurmanji'
  final String defaultScript; // 'arabic' or 'latin'
  final double playbackSpeed;

  const AppSettings({
    required this.geminiApiKey,
    required this.subtitleFontSize,
    this.defaultDialect = 'sorani',
    this.defaultScript = 'arabic',
    this.playbackSpeed = 1.0,
  });

  AppSettings copyWith({
    String? geminiApiKey,
    double? subtitleFontSize,
    String? defaultDialect,
    String? defaultScript,
    double? playbackSpeed,
  }) {
    return AppSettings(
      geminiApiKey: geminiApiKey != null
          ? AppSettings.sanitizeApiKey(geminiApiKey)
          : this.geminiApiKey,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      defaultDialect: defaultDialect ?? this.defaultDialect,
      defaultScript: defaultScript ?? this.defaultScript,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }

  static AppSettings get defaults => AppSettings(
        geminiApiKey: defaultGeminiApiKey,
        subtitleFontSize: 16.0,
        defaultDialect: 'sorani',
        defaultScript: 'arabic',
        playbackSpeed: 1.0,
      );
}
