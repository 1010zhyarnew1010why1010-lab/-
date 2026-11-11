// lib/models/translation_state.dart

enum TranslationStatus {
  idle,
  verifyingLink,
  extractingCaptions,
  translating,
  syncingTimestamps,
  completed,
  error,
}

class TranslationState {
  final TranslationStatus status;
  final double currentProgress; // 0.0 to 1.0
  final int totalBatches;
  final int completedBatches;
  final String? errorMessage;
  final int estimatedSecondsRemaining;

  const TranslationState({
    this.status = TranslationStatus.idle,
    this.currentProgress = 0.0,
    this.totalBatches = 0,
    this.completedBatches = 0,
    this.errorMessage,
    this.estimatedSecondsRemaining = 0,
  });

  TranslationState copyWith({
    TranslationStatus? status,
    double? currentProgress,
    int? totalBatches,
    int? completedBatches,
    String? errorMessage,
    int? estimatedSecondsRemaining,
  }) {
    return TranslationState(
      status: status ?? this.status,
      currentProgress: currentProgress ?? this.currentProgress,
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
      status == TranslationStatus.translating ||
      status == TranslationStatus.syncingTimestamps;

  double get progress => currentProgress.clamp(0.0, 1.0);

  int get percentage => (progress * 100).round();

  // 4 Checklist Steps state
  bool get step1Done => currentProgress >= 0.15;
  bool get step1InProgress => status == TranslationStatus.verifyingLink;

  bool get step2Done => currentProgress >= 0.40;
  bool get step2InProgress => status == TranslationStatus.extractingCaptions;

  bool get step3Done => currentProgress >= 0.85;
  bool get step3InProgress => status == TranslationStatus.translating;

  bool get step4Done =>
      currentProgress >= 1.0 || status == TranslationStatus.completed;
  bool get step4InProgress => status == TranslationStatus.syncingTimestamps;

  String get statusMessageKurdish {
    switch (status) {
      case TranslationStatus.idle:
        return '';
      case TranslationStatus.verifyingLink:
        return 'پشکنینی بەستەری یووتیوب...';
      case TranslationStatus.extractingCaptions:
        return 'دەرهێنانی دەقی ڤیدیۆ...';
      case TranslationStatus.translating:
        return 'وەرگێڕانی بەشی یەکەم بۆ کوردی...';
      case TranslationStatus.syncingTimestamps:
        return 'هاوکاتکردنی کاتی و دەستپێکردن...';
      case TranslationStatus.completed:
        return 'ئامادەیە بۆ سەیرکردن!';
      case TranslationStatus.error:
        return errorMessage ?? 'هەڵەیەک ڕوویدا.';
    }
  }
}
