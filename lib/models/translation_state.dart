// lib/models/translation_state.dart
enum TranslationStatus {
  idle,
  verifyingLink,
  extractingCaptions,
  translating,
  completed,
  error,
}

class TranslationState {
  final TranslationStatus status;
  final int totalBatches;
  final int completedBatches;
  final String? errorMessage;
  final int estimatedSecondsRemaining;

  const TranslationState({
    this.status = TranslationStatus.idle,
    this.totalBatches = 0,
    this.completedBatches = 0,
    this.errorMessage,
    this.estimatedSecondsRemaining = 0,
  });

  TranslationState copyWith({
    TranslationStatus? status,
    int? totalBatches,
    int? completedBatches,
    String? errorMessage,
    int? estimatedSecondsRemaining,
  }) {
    return TranslationState(
      status: status ?? this.status,
      totalBatches: totalBatches ?? this.totalBatches,
      completedBatches: completedBatches ?? this.completedBatches,
      errorMessage: errorMessage ?? this.errorMessage,
      estimatedSecondsRemaining:
          estimatedSecondsRemaining ?? this.estimatedSecondsRemaining,
    );
  }

  bool get isLoading =>
      status == TranslationStatus.verifyingLink ||
      status == TranslationStatus.extractingCaptions ||
      status == TranslationStatus.translating;

  double get progress {
    if (status == TranslationStatus.completed) return 1.0;
    if (status == TranslationStatus.verifyingLink) return 0.05;
    if (status == TranslationStatus.extractingCaptions) return 0.15;
    if (totalBatches == 0) return 0.2;
    // 0.2 to 1.0 scale
    return 0.2 + (completedBatches / totalBatches) * 0.8;
  }

  int get percentage => (progress * 100).clamp(0, 100).toInt();

  // 4 Checklist Steps state
  bool get step1Done =>
      status != TranslationStatus.idle; // Link verified
  bool get step2Done =>
      status == TranslationStatus.translating ||
      status == TranslationStatus.completed; // Transcript extracted
  bool get step3InProgress =>
      status == TranslationStatus.translating; // AI Translating
  bool get step3Done =>
      status == TranslationStatus.completed;
  bool get step4Done =>
      status == TranslationStatus.completed; // Timestamp sync

  String get statusMessageKurdish {
    switch (status) {
      case TranslationStatus.idle:
        return '';
      case TranslationStatus.verifyingLink:
        return 'پشکنینی بەستەری یووتیوب...';
      case TranslationStatus.extractingCaptions:
        return 'دەرهێنانی دەقی ڤیدیۆ...';
      case TranslationStatus.translating:
        return 'وەرگێڕان بەردەوامە ($completedBatches لە $totalBatches)...';
      case TranslationStatus.completed:
        return 'وەرگێڕان بە سەرکەوتوویی تەواو بوو!';
      case TranslationStatus.error:
        return errorMessage ?? 'هەڵەیەک ڕوویدا.';
    }
  }
}
