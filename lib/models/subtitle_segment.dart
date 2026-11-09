// lib/models/subtitle_segment.dart
class SubtitleSegment {
  final int index;
  final Duration start;
  final Duration duration;
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

  bool isActiveAt(Duration position) {
    return position >= start && position <= end;
  }

  Map<String, dynamic> toTranslationJson() => {
        'index': index,
        'text': originalText,
      };

  @override
  String toString() =>
      'SubtitleSegment(index: $index, start: ${start.inSeconds}s, text: $originalText)';
}
