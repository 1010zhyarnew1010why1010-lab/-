// lib/services/youtube_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subtitle_segment.dart';

class YoutubeService {
  /// Extracts video title and transcript segments from a YouTube URL.
  /// Uses a resilient multi-tier fallback architecture:
  ///   1. InnerTube ANDROID player client (strict 8s timeout)
  ///   2. InnerTube WEB player client (strict 8s timeout)
  ///   3. Desktop HTML scraping (ytInitialPlayerResponse) (strict 8s timeout)
  /// All network calls have strict timeouts so "دەرهێنانی دەق" NEVER hangs.
  Future<({String title, String videoId, List<SubtitleSegment> segments})>
      extractTranscript(String url) async {
    final videoId = parseVideoId(url);
    if (videoId == null) {
      throw Exception(
          'تکایە بەستەرێکی دروستی یووتیوب بنووسە یان دابنێ (Watch, Shorts, Share).');
    }

    final client = http.Client();
    try {
      String title = 'YouTube Video';
      List<dynamic>? captionTracks;

      // ── Tier 1: InnerTube ANDROID Client (Primary, 8s timeout) ───────────────
      try {
        final androidResult =
            await _fetchFromInnerTubeAndroid(client, videoId)
                .timeout(const Duration(seconds: 8));
        if (androidResult.title.isNotEmpty) {
          title = androidResult.title;
        }
        if (androidResult.captionTracks != null &&
            androidResult.captionTracks!.isNotEmpty) {
          captionTracks = androidResult.captionTracks;
        }
      } catch (_) {
        // Fallback to Tier 2
      }

      // ── Tier 2: InnerTube WEB Client (Fallback, 8s timeout) ──────────────────
      if (captionTracks == null || captionTracks.isEmpty) {
        try {
          final webClientResult =
              await _fetchFromInnerTubeWeb(client, videoId)
                  .timeout(const Duration(seconds: 8));
          if (webClientResult.title.isNotEmpty && title == 'YouTube Video') {
            title = webClientResult.title;
          }
          if (webClientResult.captionTracks != null &&
              webClientResult.captionTracks!.isNotEmpty) {
            captionTracks = webClientResult.captionTracks;
          }
        } catch (_) {
          // Fallback to Tier 3
        }
      }

      // ── Tier 3: HTML ytInitialPlayerResponse Scraping (8s timeout) ───────────
      if (captionTracks == null || captionTracks.isEmpty) {
        try {
          final htmlResult =
              await _fetchFromWatchHtml(client, videoId)
                  .timeout(const Duration(seconds: 8));
          if (htmlResult.title.isNotEmpty && title == 'YouTube Video') {
            title = htmlResult.title;
          }
          if (htmlResult.captionTracks != null &&
              htmlResult.captionTracks!.isNotEmpty) {
            captionTracks = htmlResult.captionTracks;
          }
        } catch (_) {
          // Exhausted tiers
        }
      }

      if (captionTracks == null || captionTracks.isEmpty) {
        throw Exception(
            'هیچ ژێرنووسێک بۆ ئەم ڤیدیۆیە بەردەست نییە. '
            'ڕەنگە دروستکەری ڤیدیۆکە ژێرنووسی دانەنابێت یان ناچالاکی کردبێت.');
      }

      // Select the best track (English preferred, or first available)
      final selectedTrack = _selectBestCaptionTrack(captionTracks);
      final baseUrl = selectedTrack['baseUrl'] as String?;
      if (baseUrl == null || baseUrl.isEmpty) {
        throw Exception('بەستەری ژێرنووسەکە دروست نییە.');
      }

      // Download and parse segments (JSON3 first, safe regex XML fallback)
      final segments = await _fetchAndParseSegments(client, baseUrl);
      if (segments.isEmpty) {
        throw Exception(
            'ژێرنووس بۆ ئەم ڤیدیۆیە دۆزرایەوە، بەڵام دەقی ناوەوەی نەخوێندرایەوە.');
      }

      // If title is still generic, quick fallback to oEmbed
      if (title == 'YouTube Video') {
        try {
          final oEmbedTitle = await _fetchTitleFromOEmbed(client, videoId)
              .timeout(const Duration(seconds: 5));
          if (oEmbedTitle != null && oEmbedTitle.isNotEmpty) {
            title = oEmbedTitle;
          }
        } catch (_) {}
      }

      return (title: title, videoId: videoId, segments: segments);
    } finally {
      client.close();
    }
  }

  /// InnerTube ANDROID client request
  Future<({String title, List<dynamic>? captionTracks})>
      _fetchFromInnerTubeAndroid(http.Client client, String videoId) async {
    final uri =
        Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');
    final payload = jsonEncode({
      'context': {
        'client': {
          'clientName': 'ANDROID',
          'clientVersion': '20.10.38',
          'androidSdkVersion': 30,
          'hl': 'en',
          'gl': 'US',
        }
      },
      'videoId': videoId,
    });

    final response = await client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'User-Agent':
                'com.google.android.youtube/20.10.38 (Linux; U; Android 14; US) gzip',
          },
          body: payload,
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return (title: '', captionTracks: null);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final videoDetails = data['videoDetails'] as Map<String, dynamic>?;
    final title = videoDetails?['title'] as String? ?? '';

    final captions = data['captions'] as Map<String, dynamic>?;
    final tracklist =
        captions?['playerCaptionsTracklistRenderer'] as Map<String, dynamic>?;
    final tracks = tracklist?['captionTracks'] as List?;

    return (title: title, captionTracks: tracks);
  }

  /// InnerTube WEB client request
  Future<({String title, List<dynamic>? captionTracks})>
      _fetchFromInnerTubeWeb(http.Client client, String videoId) async {
    final uri =
        Uri.parse('https://www.youtube.com/youtubei/v1/player?prettyPrint=false');
    final payload = jsonEncode({
      'context': {
        'client': {
          'clientName': 'WEB',
          'clientVersion': '2.20240313.01.00',
          'hl': 'en',
          'gl': 'US',
        }
      },
      'videoId': videoId,
    });

    final response = await client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
          },
          body: payload,
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return (title: '', captionTracks: null);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final videoDetails = data['videoDetails'] as Map<String, dynamic>?;
    final title = videoDetails?['title'] as String? ?? '';

    final captions = data['captions'] as Map<String, dynamic>?;
    final tracklist =
        captions?['playerCaptionsTracklistRenderer'] as Map<String, dynamic>?;
    final tracks = tracklist?['captionTracks'] as List?;

    return (title: title, captionTracks: tracks);
  }

  /// Desktop watch page scraping fallback
  Future<({String title, List<dynamic>? captionTracks})> _fetchFromWatchHtml(
      http.Client client, String videoId) async {
    final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    final response = await client.get(
      uri,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
        'Cookie': 'CONSENT=YES+1',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) {
      return (title: '', captionTracks: null);
    }

    final html = response.body;
    final match =
        RegExp(r'ytInitialPlayerResponse\s*=\s*(\{.+?\});(?:var|<\/script>)')
            .firstMatch(html);
    if (match == null) {
      return (title: '', captionTracks: null);
    }

    final data = jsonDecode(match.group(1)!) as Map<String, dynamic>;
    final videoDetails = data['videoDetails'] as Map<String, dynamic>?;
    final title = videoDetails?['title'] as String? ?? '';

    final captions = data['captions'] as Map<String, dynamic>?;
    final tracklist =
        captions?['playerCaptionsTracklistRenderer'] as Map<String, dynamic>?;
    final tracks = tracklist?['captionTracks'] as List?;

    return (title: title, captionTracks: tracks);
  }

  /// Selects the most suitable track:
  ///   1. Manual English
  ///   2. Auto-generated English
  ///   3. Any manual track
  ///   4. First available
  Map<String, dynamic> _selectBestCaptionTrack(List<dynamic> tracks) {
    Map<String, dynamic>? manualEn;
    Map<String, dynamic>? autoEn;
    Map<String, dynamic>? anyManual;

    for (final raw in tracks) {
      if (raw is! Map<String, dynamic>) continue;
      final lang = (raw['languageCode'] as String? ?? '').toLowerCase();
      final kind = raw['kind'] as String? ?? '';
      final vssId = raw['vssId'] as String? ?? '';
      final isAuto = kind == 'asr' || vssId.startsWith('a.');

      if (!isAuto && lang.startsWith('en')) {
        manualEn ??= raw;
      } else if (isAuto && lang.startsWith('en')) {
        autoEn ??= raw;
      } else if (!isAuto) {
        anyManual ??= raw;
      }
    }

    if (manualEn != null) return manualEn;
    if (autoEn != null) return autoEn;
    if (anyManual != null) return anyManual;
    return tracks.first as Map<String, dynamic>;
  }

  /// Downloads captions from baseUrl and parses them resiliently.
  /// Tries JSON3 format first, then raw XML with regex parsing.
  Future<List<SubtitleSegment>> _fetchAndParseSegments(
      http.Client client, String baseUrl) async {
    // 1. Try JSON3 format
    final jsonUrl =
        baseUrl.contains('?') ? '$baseUrl&fmt=json3' : '$baseUrl?fmt=json3';
    try {
      final res = await client.get(
        Uri.parse(jsonUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        final segments = _parseJson3(res.body);
        if (segments.isNotEmpty) return segments;
      }
    } catch (_) {}

    // 2. Try raw XML with Regex parsing (immune to XML parser root errors)
    try {
      final res = await client.get(
        Uri.parse(baseUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        final segments = _parseXmlRegex(res.body);
        if (segments.isNotEmpty) return segments;
      }
    } catch (_) {}

    // 3. Try srv3 format as final fallback
    final srv3Url =
        baseUrl.contains('?') ? '$baseUrl&fmt=srv3' : '$baseUrl?fmt=srv3';
    try {
      final res = await client.get(
        Uri.parse(srv3Url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 && res.body.trim().isNotEmpty) {
        final segments = _parseXmlRegex(res.body);
        if (segments.isNotEmpty) return segments;
      }
    } catch (_) {}

    return [];
  }

  /// Parses JSON3 caption format
  List<SubtitleSegment> _parseJson3(String jsonStr) {
    final List<SubtitleSegment> segments = [];
    try {
      final data = jsonDecode(jsonStr);
      if (data is! Map<String, dynamic>) return segments;
      final events = data['events'] as List?;
      if (events == null) return segments;

      for (final event in events) {
        if (event is! Map) continue;
        final tStartMs = (event['tStartMs'] as num?)?.toInt() ?? 0;
        final dDurationMs = (event['dDurationMs'] as num?)?.toInt() ?? 0;
        final segs = event['segs'] as List?;
        if (segs == null || segs.isEmpty) continue;

        final buffer = StringBuffer();
        for (final s in segs) {
          if (s is Map && s['utf8'] != null) {
            buffer.write(s['utf8']);
          }
        }

        final text = _decodeHtml(buffer.toString());
        if (text.isEmpty) continue;

        segments.add(SubtitleSegment(
          index: segments.length,
          start: Duration(milliseconds: tStartMs),
          duration:
              Duration(milliseconds: dDurationMs > 0 ? dDurationMs : 1500),
          originalText: text,
        ));
      }
    } catch (_) {}
    return segments;
  }

  /// Parses XML using regex (immune to empty root or malformed XML crashes)
  List<SubtitleSegment> _parseXmlRegex(String xmlStr) {
    final List<SubtitleSegment> segments = [];

    // Pattern 1: <text start="10.349" dur="2.681">Text</text>
    final textPattern = RegExp(
      r'<text[^>]*start="([\d.]+)"(?:[^>]*dur="([\d.]+)")?[^>]*>([\s\S]*?)<\/text>',
      caseSensitive: false,
    );

    for (final match in textPattern.allMatches(xmlStr)) {
      final startSec = double.tryParse(match.group(1) ?? '0') ?? 0.0;
      final durSec = double.tryParse(match.group(2) ?? '1.5') ?? 1.5;
      final rawText = match.group(3) ?? '';
      final text = _decodeHtml(rawText);
      if (text.isEmpty) continue;

      segments.add(SubtitleSegment(
        index: segments.length,
        start: Duration(milliseconds: (startSec * 1000).round()),
        duration: Duration(milliseconds: (durSec * 1000).round()),
        originalText: text,
      ));
    }

    if (segments.isNotEmpty) return segments;

    // Pattern 2: <p t="10349" d="2681">Text</p> (format=3 / TTML)
    final pPattern = RegExp(
      r'<p[^>]*t="(\d+)"(?:[^>]*d="(\d+)")?[^>]*>([\s\S]*?)<\/p>',
      caseSensitive: false,
    );

    for (final match in pPattern.allMatches(xmlStr)) {
      final startMs = int.tryParse(match.group(1) ?? '0') ?? 0;
      final durMs = int.tryParse(match.group(2) ?? '1500') ?? 1500;
      final rawText = match.group(3) ?? '';
      final text = _decodeHtml(rawText);
      if (text.isEmpty) continue;

      segments.add(SubtitleSegment(
        index: segments.length,
        start: Duration(milliseconds: startMs),
        duration: Duration(milliseconds: durMs),
        originalText: text,
      ));
    }

    return segments;
  }

  /// Safe HTML entity decoder & tag stripper
  String _decodeHtml(String input) {
    var text = input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');

    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1)!);
      return code != null ? String.fromCharCode(code) : match.group(0)!;
    });

    text = text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final code = int.tryParse(match.group(1)!, radix: 16);
      return code != null ? String.fromCharCode(code) : match.group(0)!;
    });

    // Remove any inline XML/HTML tags (like <b>, <font>, etc.)
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    return text.trim();
  }

  /// Fallback title extraction via oEmbed
  Future<String?> _fetchTitleFromOEmbed(
      http.Client client, String videoId) async {
    final uri = Uri.parse(
        'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json');
    final res =
        await client.get(uri).timeout(const Duration(seconds: 5));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['title'] as String?;
    }
    return null;
  }

  /// Parses YouTube video ID from standard, shortened, mobile, or embedded links
  String? parseVideoId(String url) {
    final cleaned = url.trim();
    final patterns = [
      RegExp(
          r'(?:v=|\/v\/|youtu\.be\/|\/embed\/|\/shorts\/)([A-Za-z0-9_-]{11})'),
      RegExp(r'youtu\.be\/([A-Za-z0-9_-]{11})'),
      RegExp(r'[\?&]v=([A-Za-z0-9_-]{11})'),
      RegExp(r'\/shorts\/([A-Za-z0-9_-]{11})'),
      RegExp(r'^([A-Za-z0-9_-]{11})$'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(cleaned);
      if (match != null && match.group(1) != null) {
        return match.group(1);
      }
    }
    return null;
  }

  void dispose() {}
}
