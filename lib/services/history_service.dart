// lib/services/history_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/history_item.dart';
import '../models/subtitle_segment.dart';

class HistoryService {
  static const _keyHistoryList = 'saved_history_videos_v2';

  /// Loads all saved history items, sorted newest first
  Future<List<HistoryItem>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_keyHistoryList);
    if (jsonList == null || jsonList.isEmpty) return [];

    final List<HistoryItem> items = [];
    for (final raw in jsonList) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        items.add(HistoryItem.fromJson(map));
      } catch (_) {}
    }

    // Sort newest first
    items.sort((a, b) => b.translatedAt.compareTo(a.translatedAt));
    return items;
  }

  /// Retrieves a specific history item by videoId
  Future<HistoryItem?> getItem(String videoId) async {
    final list = await getHistory();
    final match = list.where((item) => item.videoId == videoId);
    return match.isNotEmpty ? match.first : null;
  }

  /// Saves or updates a history item
  Future<void> saveOrUpdate(HistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getHistory();

    final existingIndex = list.indexWhere((i) => i.videoId == item.videoId);
    if (existingIndex != -1) {
      list[existingIndex] = item;
    } else {
      list.insert(0, item);
    }

    final encoded = list.map((i) => jsonEncode(i.toJson())).toList();
    await prefs.setStringList(_keyHistoryList, encoded);
  }

  /// Deletes a specific history item
  Future<void> deleteItem(String videoId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getHistory();
    list.removeWhere((i) => i.videoId == videoId);
    final encoded = list.map((i) => jsonEncode(i.toJson())).toList();
    await prefs.setStringList(_keyHistoryList, encoded);
  }

  /// Clears all history
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistoryList);
  }

  /// Generates standard SubRip (.srt) subtitle string
  String generateSrt(List<SubtitleSegment> segments) {
    final buffer = StringBuffer();
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final text = (seg.translatedText != null && seg.translatedText!.isNotEmpty)
          ? seg.translatedText!
          : seg.originalText;

      buffer.writeln('${i + 1}');
      buffer.writeln('${seg.toSrtTimestamp(seg.start)} --> ${seg.toSrtTimestamp(seg.end)}');
      buffer.writeln(text);
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  /// Generates standard WebVTT (.vtt) subtitle string
  String generateVtt(List<SubtitleSegment> segments) {
    final buffer = StringBuffer();
    buffer.writeln('WEBVTT');
    buffer.writeln();
    for (int i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final text = (seg.translatedText != null && seg.translatedText!.isNotEmpty)
          ? seg.translatedText!
          : seg.originalText;

      buffer.writeln('${i + 1}');
      buffer.writeln('${seg.toVttTimestamp(seg.start)} --> ${seg.toVttTimestamp(seg.end)}');
      buffer.writeln(text);
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  /// Exports SRT and triggers native Android Share sheet
  Future<void> exportAndShareSrt(HistoryItem item) async {
    final content = generateSrt(item.segments);
    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = _sanitizeFileName(item.title);
      final file = File('${tempDir.path}/${sanitizedTitle}_ku.srt');
      await file.writeAsString(content, encoding: utf8);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'ژێرنووسی کوردی بۆ ڤیدیۆ: ${item.title}',
      );
    } catch (_) {
      // Fallback: Copy to clipboard
      await Clipboard.setData(ClipboardData(text: content));
    }
  }

  /// Exports VTT and triggers native Android Share sheet
  Future<void> exportAndShareVtt(HistoryItem item) async {
    final content = generateVtt(item.segments);
    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = _sanitizeFileName(item.title);
      final file = File('${tempDir.path}/${sanitizedTitle}_ku.vtt');
      await file.writeAsString(content, encoding: utf8);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'ژێرنووسی کوردی (VTT) بۆ ڤیدیۆ: ${item.title}',
      );
    } catch (_) {
      // Fallback: Copy to clipboard
      await Clipboard.setData(ClipboardData(text: content));
    }
  }

  String _sanitizeFileName(String name) {
    return name
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(' ', '_')
        .trim();
  }
}
