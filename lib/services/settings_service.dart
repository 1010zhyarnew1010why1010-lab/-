// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService {
  static const _keyApiKey = 'gemini_api_key';
  static const _keyFontSize = 'subtitle_font_size';
  static const _prefixTranslationCache = 'translation_cache_';

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      geminiApiKey: prefs.getString(_keyApiKey) ?? '',
      subtitleFontSize: prefs.getDouble(_keyFontSize) ?? 16.0,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyApiKey, settings.geminiApiKey);
    await prefs.setDouble(_keyFontSize, settings.subtitleFontSize);
  }

  /// Save a translated transcript to cache keyed by video ID.
  Future<void> cacheTranslation(
      String videoId, List<Map<String, dynamic>> segments) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefixTranslationCache$videoId';
    // Encode as a flat list of "index|text" strings to avoid json_encode dep.
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
