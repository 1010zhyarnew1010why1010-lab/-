// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const keyApiKey = 'gemini_api_key';
  static const _keyFontSize = 'subtitle_font_size';
  static const _keyDialect = 'default_dialect';
  static const _keyScript = 'default_script';
  static const _keyPlaybackSpeed = 'playback_speed';
  static const _prefixTranslationCache = 'translation_cache_';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString(keyApiKey);
    final sanitizedKey = AppSettings.sanitizeApiKey(storedKey);

    return AppSettings(
      geminiApiKey: sanitizedKey,
      subtitleFontSize: prefs.getDouble(_keyFontSize) ?? 16.0,
      defaultDialect: prefs.getString(_keyDialect) ?? 'sorani',
      defaultScript: prefs.getString(_keyScript) ?? 'arabic',
      playbackSpeed: prefs.getDouble(_keyPlaybackSpeed) ?? 1.0,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final cleanKey = AppSettings.sanitizeApiKey(settings.geminiApiKey);
    await prefs.setString(keyApiKey, cleanKey);
    await prefs.setDouble(_keyFontSize, settings.subtitleFontSize);
    await prefs.setString(_keyDialect, settings.defaultDialect);
    await prefs.setString(_keyScript, settings.defaultScript);
    await prefs.setDouble(_keyPlaybackSpeed, settings.playbackSpeed);
  }

  /// Directly save or update just the API key (used by error card quick dialog)
  Future<String> saveApiKey(String rawKey) async {
    final cleanKey = AppSettings.sanitizeApiKey(rawKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyApiKey, cleanKey);
    return cleanKey;
  }

  /// Save a translated transcript to cache keyed by video ID.
  Future<void> cacheTranslation(
      String videoId, List<Map<String, dynamic>> segments) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefixTranslationCache$videoId';
    final List<String> encoded = segments
        .map((s) => '${s['index']}|${s['text']}')
        .toList();
    await prefs.setStringList(key, encoded);
  }

  /// Load a cached translation. Returns null if not cached.
  Future<List<Map<String, dynamic>>?> loadCachedTranslation(
      String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefixTranslationCache$videoId';
    final encoded = prefs.getStringList(key);
    if (encoded == null) return null;

    final List<Map<String, dynamic>> result = [];
    for (final item in encoded) {
      final pipeIndex = item.indexOf('|');
      if (pipeIndex == -1) continue;
      final index = int.tryParse(item.substring(0, pipeIndex));
      if (index == null) continue;
      result.add({'index': index, 'text': item.substring(pipeIndex + 1)});
    }
    return result.isEmpty ? null : result;
  }

  /// Clear all cached translations.
  Future<void> clearAllCaches() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
      (k) => k.startsWith(_prefixTranslationCache),
    );
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
