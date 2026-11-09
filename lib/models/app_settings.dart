// lib/models/app_settings.dart
class AppSettings {
  final String geminiApiKey;
  final double subtitleFontSize;

  const AppSettings({
    required this.geminiApiKey,
    required this.subtitleFontSize,
  });

  AppSettings copyWith({String? geminiApiKey, double? subtitleFontSize}) {
    return AppSettings(
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
    );
  }

  static const AppSettings defaults = AppSettings(
    geminiApiKey: '',
    subtitleFontSize: 16.0,
  );
}
