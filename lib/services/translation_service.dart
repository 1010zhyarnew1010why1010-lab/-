// lib/services/translation_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/subtitle_segment.dart';

/// Contextual and resilient subtitle translation service using Gemini 2.5 Flash.
class TranslationService {
  static const int _batchSize = 25; // 25 segments per batch for deep contextual awareness
  static const String _model = 'gemini-2.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  final String apiKey;
  final String dialect; // 'sorani' or 'kurmanji'
  final String script; // 'arabic' or 'latin'

  TranslationService({
    required this.apiKey,
    this.dialect = 'sorani',
    this.script = 'arabic',
  });

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
4. Maintain exact 1-to-1 index mapping. Return an array of JSON objects with {"index": number, "text": "string"}.
5. Do NOT skip, combine, or invent indices. Keep technical and domain-specific terms accurate.
6. Return ONLY the JSON array. Do not output markdown code blocks, preambles, or commentary.
''';
  }

  /// Translates segments in batches of 25 with sliding previous context.
  Future<void> translateSegments(
    List<SubtitleSegment> segments, {
    String videoTitle = '',
    required void Function(int completed, int total, int estimatedSecondsRemaining)
        onBatchComplete,
  }) async {
    if (segments.isEmpty) return;

    final batches = _splitIntoBatches(segments, _batchSize);
    final totalBatches = batches.length;
    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < totalBatches; i++) {
      final batch = batches[i];

      // Provide the last 2 translated segments of the previous batch for cohesive context
      String previousContext = '';
      if (i > 0 && batches[i - 1].isNotEmpty) {
        final prev = batches[i - 1];
        final lastTwo = prev.length >= 2 ? prev.sublist(prev.length - 2) : prev;
        final lines = lastTwo
            .map((s) =>
                'Segment ${s.index} (EN: "${s.originalText}" -> KU: "${s.translatedText ?? ''}")')
            .join(' | ');
        previousContext = 'PREVIOUS_SUBTITLE_CONTEXT (Do not re-translate): $lines';
      }

      final batchStartTime = stopwatch.elapsedMilliseconds;
      final translatedItems = await _translateBatchWithRetry(
        batch,
        videoTitle: videoTitle,
        previousContext: previousContext,
      );

      // Apply translations back to segments
      for (final item in translatedItems) {
        final index = item['index'] as int?;
        final text = item['text'] as String?;
        if (index != null && text != null && text.trim().isNotEmpty) {
          final matchIdx = segments.indexWhere((s) => s.index == index);
          if (matchIdx != -1) {
            segments[matchIdx].translatedText = text.trim();
          }
        }
      }

      // Calculate estimated time remaining
      final elapsedForThisBatch = stopwatch.elapsedMilliseconds - batchStartTime;
      final remainingBatches = totalBatches - (i + 1);
      final estimatedSecRemaining = ((elapsedForThisBatch * remainingBatches) / 1000).ceil();

      onBatchComplete(i + 1, totalBatches, estimatedSecRemaining);
    }
  }

  /// Executes batch translation with auto-retry and fresh HTTP client on connection aborts.
  Future<List<Map<String, dynamic>>> _translateBatchWithRetry(
    List<SubtitleSegment> batch, {
    required String videoTitle,
    required String previousContext,
  }) async {
    const maxRetries = 3;
    final delays = [const Duration(milliseconds: 1500), const Duration(milliseconds: 3000), const Duration(milliseconds: 5000)];

    Exception? lastException;

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      http.Client? client;
      try {
        client = http.Client();
        return await _translateBatch(
          client,
          batch,
          videoTitle: videoTitle,
          previousContext: previousContext,
        );
      } on SocketException catch (e) {
        lastException = e;
      } on http.ClientException catch (e) {
        lastException = e;
      } on TimeoutException catch (e) {
        lastException = e;
      } catch (e) {
        lastException = Exception(e.toString());
        // For fatal API errors like 400 or 403, do not retry blindly
        if (e.toString().contains('403') || e.toString().contains('API_KEY_INVALID')) {
          rethrow;
        }
      } finally {
        client?.close();
      }

      if (attempt < maxRetries - 1) {
        await Future.delayed(delays[attempt]);
      }
    }

    // Fallback: If network retries failed completely, try salvage or rethrow
    throw lastException ??
        Exception('Connection to Gemini API failed after $maxRetries attempts.');
  }

  Future<List<Map<String, dynamic>>> _translateBatch(
    http.Client client,
    List<SubtitleSegment> batch, {
    required String videoTitle,
    required String previousContext,
  }) async {
    final segmentsJson = batch.map((s) => s.toTranslationJson()).toList();

    final inputPrompt = StringBuffer();
    if (videoTitle.isNotEmpty) {
      inputPrompt.writeln('VIDEO TITLE: "$videoTitle"');
    }
    if (previousContext.isNotEmpty) {
      inputPrompt.writeln(previousContext);
    }
    inputPrompt.writeln('SUBTITLE SEGMENTS TO TRANSLATE (JSON):');
    inputPrompt.writeln(jsonEncode(segmentsJson));

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
        'thinkingConfig': {'thinkingBudget': 0}, // Zero thinking overhead for maximum speed
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

    final uri = Uri.parse(_baseUrl);

    final response = await client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey, // API Key in header - no URL leaks
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
      throw Exception('Gemini returned an empty response. Content may be filtered.');
    }

    final content = candidates[0]['content'] as Map?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini response contains no parts.');
    }

    final rawText = (parts[0]['text'] as String? ?? '').trim();
    return _parseJsonResilient(rawText, batch);
  }

  /// Resilient parser: jsonDecode -> regex array match -> regex salvage parser.
  /// Never throws on truncated or slightly malformed outputs.
  List<Map<String, dynamic>> _parseJsonResilient(
      String rawText, List<SubtitleSegment> expectedBatch) {
    if (rawText.isEmpty) return [];

    // Attempt 1: Standard JSON decode
    try {
      final decoded = jsonDecode(rawText);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) => {
                  'index': m['index'] is int ? m['index'] : int.tryParse('${m['index']}'),
                  'text': m['text']?.toString() ?? '',
                })
            .where((m) => m['index'] != null && (m['text'] as String).isNotEmpty)
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
                    'index': m['index'] is int ? m['index'] : int.tryParse('${m['index']}'),
                    'text': m['text']?.toString() ?? '',
                  })
              .where((m) => m['index'] != null && (m['text'] as String).isNotEmpty)
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
