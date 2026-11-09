// lib/models/translation_state.dart
enum TranslationStatus {
  idle,
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

  const TranslationState({
    this.status = TranslationStatus.idle,
    this.totalBatches = 0,
    this.completedBatches = 0,
    this.errorMessage,
  });

  TranslationState copyWith({
    TranslationStatus? status,
    int? totalBatches,
    int? completedBatches,
    String? errorMessage,
  }) {
    return TranslationState(
      status: status ?? this.status,
      totalBatches: totalBatches ?? this.totalBatches,
      completedBatches: completedBatches ?? this.completedBatches,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String get statusMessage {
    switch (status) {
      case TranslationStatus.idle:
        return '';
      case TranslationStatus.extractingCaptions:
        return 'Extracting captions...';
      case TranslationStatus.translating:
        return 'Translating batch $completedBatches of $totalBatches into Kurdish...';
      case TranslationStatus.completed:
        return 'Translation complete!';
      case TranslationStatus.error:
        return errorMessage ?? 'An unknown error occurred.';
    }
  }

  bool get isLoading =>
      status == TranslationStatus.extractingCaptions ||
      status == TranslationStatus.translating;

  double get progress {
    if (totalBatches == 0) return 0.0;
    return completedBatches / totalBatches;
  }
}
