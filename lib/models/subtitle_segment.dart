// lib/models/subtitle_segment.dart
class SubtitleSegment {
  final int index;
  final Duration start;
  Duration duration;
  final String originalText;
  String? translatedText;

  SubtitleSegment({
    required this.index,
    required this.start,
    required this.duration,
    required this.originalText,
    this.translatedText,
  });

  Duration get end => start + duration;
  set end(Duration newEnd) {
    if (newEnd > start) {
      duration = newEnd - start;
    } else {
      duration = Duration.zero;
    }
  }

  bool isActiveAt(Duration position) {
    return position >= start && position < end;
  }

  Map<String, dynamic> toTranslationJson() => {
        'index': index,
        'text': originalText,
      };

  Map<String, dynamic> toJson() => {
        'index': index,
        'startMs': start.inMilliseconds,
        'durationMs': duration.inMilliseconds,
        'originalText': originalText,
        'translatedText': translatedText,
      };

  factory SubtitleSegment.fromJson(Map<String, dynamic> json) =>
      SubtitleSegment(
        index: json['index'] as int? ?? 0,
        start: Duration(milliseconds: json['startMs'] as int? ?? 0),
        duration: Duration(milliseconds: json['durationMs'] as int? ?? 1500),
        originalText: json['originalText'] as String? ?? '',
        translatedText: json['translatedText'] as String?,
      );

  String formatTimestamp() {
    final m = start.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = start.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (start.inHours > 0) {
      final h = start.inHours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  String toSrtTimestamp(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = d.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }

  String toVttTimestamp(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final ms = d.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  @override
  String toString() =>
      'SubtitleSegment(index: $index, start: ${start.inSeconds}s, text: $originalText)';
}
