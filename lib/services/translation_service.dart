// lib/services/translation_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/subtitle_segment.dart';

/// Contextual and resilient subtitle translation service using Gemini API
/// with multi-key rotation and multi-model fallback chain.
class TranslationService {
  static const int defaultBatchSize = 100; // Large batch size cuts API calls by 80%!
  static const List<String> _models = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
  ];

  final List<String> apiKeys;
  final String dialect; // 'sorani' or 'kurmanji'
  final String script; // 'arabic' or 'latin'

  int _currentKeyIndex = 0;
  int _currentModelIndex = 0;

  TranslationService({
    List<String>? apiKeys,
    String? apiKey,
    this.dialect = 'sorani',
    this.script = 'arabic',
  }) : apiKeys = (apiKeys != null && apiKeys.isNotEmpty)
            ? AppSettings.sanitizeApiKeys(apiKeys)
            : AppSettings.sanitizeApiKeys(apiKey);

  String get activeApiKey => apiKeys.isNotEmpty
      ? apiKeys[_currentKeyIndex % apiKeys.length]
      : AppSettings.defaultGeminiApiKey;

  String get activeModel => _models[_currentModelIndex % _models.length];

  static String sanitizeKey(String? rawKey) {
    return AppSettings.sanitizeApiKey(rawKey);
  }

  String _buildSystemInstruction() {
    final targetDialect = dialect.toLowerCase() == 'kurmanji'
        ? 'Kurmanji Kurdish (کرمانجی)'
        : 'Central Kurdish (Sorani / سۆرانی)';

    final scriptFormat = script.toLowerCase() == 'latin'
        ? 'Latin script (Hawar alphabet, e.g. "Silav, ev vîdyoyek e")'
        : 'standard Kurdish Arabic-based alphabet (ئەلفوبێی کوردی، پیتەکانی: ڵ، ڕ، ە، ێ، ۆ، وو، ڤ، چ، ژ، گ)';

    return '''
You are an expert English-to-$targetDialect translator specializing in high-quality video subtitles.
Translate the provided array of subtitle segments into natural, idiomatic, context-aware $targetDialect using $scriptFormat.

CRITICAL SUBTITLE TRANSLATION RULES:
1. YouTube subtitles break spoken sentences into arbitrary, short fragments. NEVER translate word-by-word or in isolation.
2. Read the whole batch and previous context to understand complete sentences and speaker intent before translating.
3. Distribute the natural Kurdish sentence across the provided segment indices so subtitle timings align with the speaker's voice.
4. Maintain exact 1-to-1 local index mapping (0 to N-1). Return an array of JSON objects with {"index": number, "text": "string"}.
5. Do NOT skip, combine, or invent indices. Keep technical and domain-specific terms accurate.
6. Return ONLY the JSON array. Do not output markdown code blocks, preambles, or commentary.
''';
  }

  /// Translates only the first batch (15 segments) for ultra-fast instant playback.
  Future<void> translateFirstBatch(
    List<SubtitleSegment> segments, {
    int batchSize = 15,
    String videoTitle = '',
  }) async {
    if (segments.isEmpty) return;
    final firstBatch = segments.take(batchSize).toList();
    await _translateAndApplyBatch(
      firstBatch,
      videoTitle: videoTitle,
      previousContext: '',
    );
  }

  /// Translates the remaining batches sequentially in the background while user watches.
  /// Uses default batchSize = 100 to drastically reduce API requests.
  Future<void> translateRemainingBatches(
    List<SubtitleSegment> segments, {
    int startIndex = 15,
    int batchSize = defaultBatchSize,
    String videoTitle = '',
    required void Function(int completedBatches, int totalBatches)
        onBatchComplete,
    bool Function()? isCancelled,
  }) async {
    if (segments.length <= startIndex) return;

    final remainingSegments = segments.sublist(startIndex);
    final batches = _splitIntoBatches(remainingSegments, batchSize);
    final totalBatches = batches.length + 1; // +1 for first batch

    for (int i = 0; i < batches.length; i++) {
      if (isCancelled != null && isCancelled()) break;

      // 2-second delay between batch requests to stay within RPM rate limits
      if (i > 0) {
        await Future.delayed(const Duration(milliseconds: 2000));
      }

      if (isCancelled != null && isCancelled()) break;

      final batch = batches[i];
      final currentOverallBatchIndex = i + 2;

      // Sliding context from up to 2 translated previous segments
      String previousContext = '';
      final firstIdxInThisBatch = batch.first.index;
      final prevSegments = segments
          .where((s) =>
              s.index < firstIdxInThisBatch &&
              s.translatedText != null &&
              s.translatedText!.isNotEmpty)
          .toList();
      if (prevSegments.isNotEmpty) {
        final lastTwo = prevSegments.length >= 2
            ? prevSegments.sublist(prevSegments.length - 2)
            : prevSegments;
        final lines = lastTwo
            .map((s) =>
                'Segment ${s.index} (EN: "${s.originalText}" -> KU: "${s.translatedText}")')
            .join(' | ');
        previousContext =
            'PREVIOUS_SUBTITLE_CONTEXT (Do not re-translate): $lines';
      }

      try {
        await _translateAndApplyBatch(
          batch,
          videoTitle: videoTitle,
          previousContext: previousContext,
        );

        if (isCancelled != null && isCancelled()) break;
        onBatchComplete(currentOverallBatchIndex, totalBatches);
      } catch (e) {
        // Wait and continue with next batch rather than crashing
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }

  /// Translates segments in batches of 100 with sliding previous context.
  Future<void> translateSegments(
    List<SubtitleSegment> segments, {
    String videoTitle = '',
    required void Function(int completed, int total, int estimatedSecondsRemaining)
        onBatchComplete,
  }) async {
    if (segments.isEmpty) return;

    final batches = _splitIntoBatches(segments, defaultBatchSize);
    final totalBatches = batches.length;
    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < totalBatches; i++) {
      if (i > 0) {
        await Future.delayed(const Duration(milliseconds: 2000));
      }

      final batch = batches[i];

      String previousContext = '';
      if (i > 0 && batches[i - 1].isNotEmpty) {
        final prev = batches[i - 1];
        final lastTwo = prev.length >= 2 ? prev.sublist(prev.length - 2) : prev;
        final lines = lastTwo
            .map((s) =>
                'Segment ${s.index} (EN: "${s.originalText}" -> KU: "${s.translatedText ?? ''}")')
            .join(' | ');
        previousContext =
            'PREVIOUS_SUBTITLE_CONTEXT (Do not re-translate): $lines';
      }

      final batchStartTime = stopwatch.elapsedMilliseconds;
      await _translateAndApplyBatch(
        batch,
        videoTitle: videoTitle,
        previousContext: previousContext,
      );

      final elapsedForThisBatch =
          stopwatch.elapsedMilliseconds - batchStartTime;
      final remainingBatches = totalBatches - (i + 1);
      final estimatedSecRemaining =
          ((elapsedForThisBatch * remainingBatches) / 1000).ceil();

      onBatchComplete(i + 1, totalBatches, estimatedSecRemaining);
    }
  }

  /// Translates a batch using local 0-based indexing and applies results to batch.
  /// Also detects any missing segments and performs a single targeted retry.
  Future<void> _translateAndApplyBatch(
    List<SubtitleSegment> batch, {
    required String videoTitle,
    required String previousContext,
  }) async {
    if (batch.isEmpty) return;

    // Build local 0-based list for the AI request
    final localBatchInput = List.generate(
      batch.length,
      (idx) => {'index': idx, 'text': batch[idx].originalText},
    );

    final translatedItems = await _translateWithKeyAndModelFallback(
      localBatchInput,
      videoTitle: videoTitle,
      previousContext: previousContext,
    );

    // Apply translations
    final Set<int> receivedLocalIndices = {};
    for (final item in translatedItems) {
      final localIdx = item['index'] as int?;
      final text = item['text'] as String?;
      if (localIdx != null &&
          localIdx >= 0 &&
          localIdx < batch.length &&
          text != null &&
          text.trim().isNotEmpty) {
        batch[localIdx].translatedText = text.trim();
        receivedLocalIndices.add(localIdx);
      }
    }

    // Zero Skipped Lines Check: Find missing indices in this batch
    final List<SubtitleSegment> missingSegments = [];
    final List<int> missingLocalIndices = [];
    for (int i = 0; i < batch.length; i++) {
      if (!receivedLocalIndices.contains(i) ||
          batch[i].translatedText == null ||
          batch[i].translatedText!.isEmpty) {
        missingSegments.add(batch[i]);
        missingLocalIndices.add(i);
      }
    }

    // If any items were skipped, do a single targeted follow-up call
    if (missingSegments.isNotEmpty && missingSegments.length <= 25) {
      try {
        final retryLocalInput = List.generate(
          missingSegments.length,
          (idx) => {'index': idx, 'text': missingSegments[idx].originalText},
        );
        final retryItems = await _translateWithKeyAndModelFallback(
          retryLocalInput,
          videoTitle: videoTitle,
          previousContext: previousContext,
        );
        for (final item in retryItems) {
          final relIdx = item['index'] as int?;
          final text = item['text'] as String?;
          if (relIdx != null &&
              relIdx >= 0 &&
              relIdx < missingLocalIndices.length &&
              text != null &&
              text.trim().isNotEmpty) {
            final targetBatchIdx = missingLocalIndices[relIdx];
            batch[targetBatchIdx].translatedText = text.trim();
          }
        }
      } catch (_) {
        // Fallback: segments retain null and display original text
      }
    }
  }

  /// Sends request with automatic Model and Key failover on HTTP 429 / Quota limits
  Future<List<Map<String, dynamic>>> _translateWithKeyAndModelFallback(
    List<Map<String, dynamic>> items, {
    required String videoTitle,
    required String previousContext,
  }) async {
    final totalKeys = apiKeys.isNotEmpty ? apiKeys.length : 1;
    final totalCombinations = totalKeys * _models.length;

    Exception? lastError;

    for (int combo = 0; combo < totalCombinations; combo++) {
      final key = activeApiKey;
      final model = activeModel;

      http.Client? client;
      try {
        client = http.Client();
        return await _executePost(
          client,
          items,
          key: key,
          model: model,
          videoTitle: videoTitle,
          previousContext: previousContext,
        );
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        final errStr = e.toString().toLowerCase();

        final isQuotaOrRateLimit = errStr.contains('429') ||
            errStr.contains('resource_exhausted') ||
            errStr.contains('quota') ||
            errStr.contains('limit');

        if (isQuotaOrRateLimit) {
          // Fallback to next model first
          _currentModelIndex++;
          if (_currentModelIndex >= _models.length) {
            _currentModelIndex = 0;
            // Rotate to next API key
            _currentKeyIndex = (_currentKeyIndex + 1) % totalKeys;
          }
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        // Fatal auth errors for this key -> advance key immediately
        if (errStr.contains('403') ||
            errStr.contains('api_key_invalid') ||
            errStr.contains('api key not valid')) {
          _currentKeyIndex = (_currentKeyIndex + 1) % totalKeys;
          if (combo < totalCombinations - 1) continue;
        }

        // Network glitch -> retry after small pause
        await Future.delayed(const Duration(milliseconds: 1500));
      } finally {
        client?.close();
      }
    }

    throw lastError ??
        Exception('هەموو کلیلەکانی API و مۆدێلەکان کۆتاییان هات (Quota Exceeded)');
  }

  Future<List<Map<String, dynamic>>> _executePost(
    http.Client client,
    List<Map<String, dynamic>> items, {
    required String key,
    required String model,
    required String videoTitle,
    required String previousContext,
  }) async {
    final inputPrompt = StringBuffer();
    if (videoTitle.isNotEmpty) {
      inputPrompt.writeln('VIDEO TITLE: "$videoTitle"');
    }
    if (previousContext.isNotEmpty) {
      inputPrompt.writeln(previousContext);
    }
    inputPrompt.writeln('SUBTITLE SEGMENTS TO TRANSLATE (JSON):');
    inputPrompt.writeln(jsonEncode(items));

    final requestBody = {
      'system_instruction': {
        'parts': [
          {'text': _buildSystemInstruction()}
        ]
      },
      'contents': [
        {
          'parts': [
            {'text': inputPrompt.toString()}
          ]
        }
      ],
      'generationConfig': {
        'thinkingConfig': {'thinkingBudget': 0},
        'maxOutputTokens': 8192,
        'temperature': 0.3,
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'ARRAY',
          'items': {
            'type': 'OBJECT',
            'properties': {
              'index': {'type': 'INTEGER'},
              'text': {'type': 'STRING'}
            },
            'required': ['index', 'text']
          }
        }
      },
    };

    final cleanKey = sanitizeKey(key);
    final endpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$cleanKey';

    final response = await client
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': cleanKey,
          },
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      String errorMsg = 'Gemini API error ${response.statusCode}';
      try {
        final errJson = jsonDecode(response.body);
        final msg = errJson['error']?['message'];
        if (msg != null) errorMsg = msg.toString();
      } catch (_) {}
      throw Exception(errorMsg);
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseBody['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception(
          'Gemini returned an empty response. Content may be filtered.');
    }

    final content = candidates[0]['content'] as Map?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini response contains no parts.');
    }

    final rawText = (parts[0]['text'] as String? ?? '').trim();
    return _parseJsonResilient(rawText);
  }

  /// Resilient parser: jsonDecode -> regex array match -> regex salvage parser.
  List<Map<String, dynamic>> _parseJsonResilient(String rawText) {
    if (rawText.isEmpty) return [];

    // Attempt 1: Standard JSON decode
    try {
      final decoded = jsonDecode(rawText);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) => {
                  'index': m['index'] is int
                      ? m['index']
                      : int.tryParse('${m['index']}'),
                  'text': m['text']?.toString() ?? '',
                })
            .where((m) =>
                m['index'] != null && (m['text'] as String).isNotEmpty)
            .toList();
      }
    } catch (_) {}

    // Attempt 2: Extract array block
    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(rawText);
    if (arrayMatch != null) {
      try {
        final decoded = jsonDecode(arrayMatch.group(0)!);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((m) => {
                    'index': m['index'] is int
                        ? m['index']
                        : int.tryParse('${m['index']}'),
                    'text': m['text']?.toString() ?? '',
                  })
              .where((m) =>
                  m['index'] != null && (m['text'] as String).isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }

    // Attempt 3: Salvage regex parser (recovers valid entries even from truncated text)
    final List<Map<String, dynamic>> salvaged = [];
    final itemRegex = RegExp(
      r'\{\s*"index"\s*:\s*(\d+)\s*,\s*"text"\s*:\s*"((?:[^"\\]|\\.)*)"\s*\}',
      dotAll: true,
    );

    for (final match in itemRegex.allMatches(rawText)) {
      final index = int.tryParse(match.group(1) ?? '');
      final rawSubText = match.group(2) ?? '';
      if (index != null && rawSubText.isNotEmpty) {
        final unescapedText = _unescapeJsonString(rawSubText);
        salvaged.add({
          'index': index,
          'text': unescapedText,
        });
      }
    }

    return salvaged;
  }

  String _unescapeJsonString(String str) {
    try {
      return jsonDecode('"$str"') as String;
    } catch (_) {
      return str
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', '\\')
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\r', '')
          .replaceAll(r'\t', ' ');
    }
  }

  List<List<SubtitleSegment>> _splitIntoBatches(
      List<SubtitleSegment> segments, int batchSize) {
    final batches = <List<SubtitleSegment>>[];
    for (int i = 0; i < segments.length; i += batchSize) {
      batches.add(
        segments.sublist(
          i,
          (i + batchSize < segments.length) ? i + batchSize : segments.length,
        ),
      );
    }
    return batches;
  }
}
