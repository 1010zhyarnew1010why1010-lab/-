// lib/models/app_settings.dart
class AppSettings {
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
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      defaultDialect: defaultDialect ?? this.defaultDialect,
      defaultScript: defaultScript ?? this.defaultScript,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }

  static const AppSettings defaults = AppSettings(
    geminiApiKey: '',
    subtitleFontSize: 16.0,
    defaultDialect: 'sorani',
    defaultScript: 'arabic',
    playbackSpeed: 1.0,
  );
}
