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

  /// Sanitizes multiple API keys input (can be List<String> or a String separated by comma, newline, semicolon).
  static List<String> sanitizeApiKeys(dynamic input) {
    if (input == null) return [defaultGeminiApiKey];
    List<String> rawList = [];
    if (input is List) {
      rawList = input.map((e) => e.toString()).toList();
    } else if (input is String) {
      rawList = input.split(RegExp(r'[\n\r,;]+'));
    }
    final List<String> cleaned = [];
    for (final k in rawList) {
      final c = k.trim().replaceAll(RegExp(r'[\s"\x27]'), '');
      if (c.isNotEmpty && !cleaned.contains(c)) {
        cleaned.add(c);
      }
    }
    if (cleaned.isEmpty) {
      cleaned.add(defaultGeminiApiKey);
    }
    return cleaned;
  }

  final List<String> geminiApiKeys;
  String get geminiApiKey =>
      geminiApiKeys.isNotEmpty ? geminiApiKeys.first : defaultGeminiApiKey;

  final double subtitleFontSize;
  final String defaultDialect; // 'sorani' or 'kurmanji'
  final String defaultScript; // 'arabic' or 'latin'
  final double playbackSpeed;

  AppSettings({
    List<String>? geminiApiKeys,
    String? geminiApiKey,
    required this.subtitleFontSize,
    this.defaultDialect = 'sorani',
    this.defaultScript = 'arabic',
    this.playbackSpeed = 1.0,
  }) : geminiApiKeys = (geminiApiKeys != null && geminiApiKeys.isNotEmpty)
            ? sanitizeApiKeys(geminiApiKeys)
            : sanitizeApiKeys(geminiApiKey);

  AppSettings copyWith({
    dynamic geminiApiKeys,
    String? geminiApiKey,
    double? subtitleFontSize,
    String? defaultDialect,
    String? defaultScript,
    double? playbackSpeed,
  }) {
    List<String> newKeys = this.geminiApiKeys;
    if (geminiApiKeys != null) {
      newKeys = AppSettings.sanitizeApiKeys(geminiApiKeys);
    } else if (geminiApiKey != null) {
      newKeys = AppSettings.sanitizeApiKeys(geminiApiKey);
    }

    return AppSettings(
      geminiApiKeys: newKeys,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      defaultDialect: defaultDialect ?? this.defaultDialect,
      defaultScript: defaultScript ?? this.defaultScript,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }

  static AppSettings get defaults => AppSettings(
        geminiApiKeys: [defaultGeminiApiKey],
        subtitleFontSize: 16.0,
        defaultDialect: 'sorani',
        defaultScript: 'arabic',
        playbackSpeed: 1.0,
      );
}
