// lib/models/history_item.dart
import 'subtitle_segment.dart';

class HistoryItem {
  final String videoId;
  final String videoUrl;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final int durationSeconds;
  final DateTime translatedAt;
  final String dialect; // 'sorani' or 'kurmanji'
  final String script; // 'arabic' or 'latin'
  final List<SubtitleSegment> segments;

  HistoryItem({
    required this.videoId,
    required this.videoUrl,
    required this.title,
    this.channelName = 'YouTube',
    required this.thumbnailUrl,
    this.durationSeconds = 0,
    required this.translatedAt,
    this.dialect = 'sorani',
    this.script = 'arabic',
    required this.segments,
  });

  int get translatedCount =>
      segments.where((s) => s.translatedText != null && s.translatedText!.isNotEmpty).length;

  bool get isFullyTranslated =>
      segments.isNotEmpty && translatedCount == segments.length;

  double get completionRatio =>
      segments.isEmpty ? 0.0 : translatedCount / segments.length;

  String get formattedDuration {
    final m = (durationSeconds ~/ 60).toString();
    final count = segments.length.toString();
    return '$m خولەک • $count دێڕ';
  }

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'videoUrl': videoUrl,
        'title': title,
        'channelName': channelName,
        'thumbnailUrl': thumbnailUrl,
        'durationSeconds': durationSeconds,
        'translatedAt': translatedAt.toIso8601String(),
        'dialect': dialect,
        'script': script,
        'segments': segments.map((s) => s.toJson()).toList(),
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        videoId: json['videoId'] as String? ?? '',
        videoUrl: json['videoUrl'] as String? ?? '',
        title: json['title'] as String? ?? 'Untitled Video',
        channelName: json['channelName'] as String? ?? 'YouTube',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        durationSeconds: json['durationSeconds'] as int? ?? 0,
        translatedAt: json['translatedAt'] != null
            ? DateTime.tryParse(json['translatedAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        dialect: json['dialect'] as String? ?? 'sorani',
        script: json['script'] as String? ?? 'arabic',
        segments: (json['segments'] as List?)
                ?.map((s) => SubtitleSegment.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
