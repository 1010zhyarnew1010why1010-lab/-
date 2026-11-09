// lib/services/translation_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subtitle_segment.dart';

/// Handles batched translation of subtitle segments via the Gemini REST API.
class TranslationService {
  static const int _batchSize = 50;
  static const String _model = 'gemini-2.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  static const String _systemInstruction =
      'You are an expert English-to-Central Kurdish (Sorani) translator. '
      'Translate the provided JSON array of subtitle segments into natural, fluent, '
      'and context-aware Sorani Kurdish (Arabic script). '
      'Maintain the exact JSON structure: [{"index": 0, "text": "..."}]. '
      'Do not merge or skip indices. Keep technical terms clear and accurate. '
      'Return ONLY the JSON array with no extra commentary, markdown, or code fences.';

  final String apiKey;

  TranslationService({required this.apiKey});

  /// Translates all segments in batches, calling [onBatchComplete] after each.
  /// Returns the segments with [translatedText] populated.
  Future<void> translateSegments(
    List<SubtitleSegment> segments, {
    required void Function(int completed, int total) onBatchComplete,
  }) async {
    final batches = _splitIntoBatches(segments, _batchSize);
    final total = batches.length;

    for (int i = 0; i < batches.length; i++) {
      final batch = batches[i];
      final translated = await _translateBatch(batch);

      // Apply translations back to segments.
      for (final item in translated) {
        final index = item['index'] as int?;
        final text = item['text'] as String?;
        if (index != null && text != null) {
          final seg = segments.firstWhere(
            (s) => s.index == index,
            orElse: () => batch.first, // fallback; should not happen
          );
          seg.translatedText = text;
        }
      }

      onBatchComplete(i + 1, total);
    }
  }

  Future<List<Map<String, dynamic>>> _translateBatch(
      List<SubtitleSegment> batch) async {
    final inputJson = jsonEncode(batch.map((s) => s.toTranslationJson()).toList());

    final requestBody = {
      'system_instruction': {
        'parts': [
          {'text': _systemInstruction}
        ]
      },
      'contents': [
        {
          'parts': [
            {'text': inputJson}
          ]
        }
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'temperature': 0.2,
        'topP': 0.9,
      },
    };

    final uri = Uri.parse('$_baseUrl?key=$apiKey');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      String errorMessage = 'Gemini API error ${response.statusCode}';
      try {
        final errorBody = jsonDecode(response.body);
        final apiError = errorBody['error'];
        if (apiError != null) {
          errorMessage = '${apiError['message'] ?? errorMessage} '
              '(status: ${apiError['status'] ?? response.statusCode})';
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }

    final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

    // Extract text from Gemini's response format.
    final candidates = responseBody['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception(
          'Gemini returned an empty response. '
          'This may be due to content filtering. '
          'Please try again.');
    }

    final content = candidates[0]['content'] as Map?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw Exception('Gemini response had no content parts.');
    }

    final rawText = (parts[0]['text'] as String? ?? '').trim();

    try {
      final decoded = jsonDecode(rawText);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      // Try to extract JSON array from raw text with regex fallback.
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(rawText);
      if (jsonMatch != null) {
        try {
          final extracted = jsonDecode(jsonMatch.group(0)!);
          if (extracted is List) {
            return extracted.cast<Map<String, dynamic>>();
          }
        } catch (_) {}
      }
      throw Exception(
          'Failed to parse Gemini JSON response.\n'
          'Raw response snippet: ${rawText.length > 200 ? rawText.substring(0, 200) : rawText}');
    }

    return [];
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
