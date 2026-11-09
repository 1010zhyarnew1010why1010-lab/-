// lib/screens/home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/app_settings.dart';
import '../models/subtitle_segment.dart';
import '../models/translation_state.dart';
import '../services/settings_service.dart';
import '../services/translation_service.dart';
import '../services/youtube_service.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/subtitle_overlay.dart';
import '../widgets/transcript_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Services
  final _settingsService = SettingsService();
  final _youtubeService = YoutubeService();

  // Settings
  AppSettings _settings = AppSettings.defaults;

  // Share intent
  StreamSubscription? _sharingSubscription;

  // URL input
  final _urlController = TextEditingController();
  bool _isUrlLoading = false;

  // Video player
  YoutubePlayerController? _playerController;
  String? _currentVideoId;
  String? _videoTitle;

  // Transcript state
  List<SubtitleSegment> _segments = [];
  TranslationState _translationState = const TranslationState();
  int _activeSegmentIndex = -1;

  // Playback polling
  Timer? _positionTimer;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initSharingIntent();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.load();
    if (mounted) setState(() => _settings = settings);
  }

  void _initSharingIntent() {
    // Handle the case where the app is opened from share intent while cold.
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      for (final file in value) {
        if (file.path.isNotEmpty) {
          _handleSharedUrl(file.path);
          break;
        }
      }
    });

    // Handle shared URLs while app is running.
    _sharingSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      for (final file in value) {
        if (file.path.isNotEmpty) {
          _handleSharedUrl(file.path);
          break;
        }
      }
    });
  }

  void _handleSharedUrl(String url) {
    if (!mounted) return;
    final cleaned = url.trim();
    if (cleaned.isEmpty) return;
    _urlController.text = cleaned;
    _loadVideo(cleaned);
  }

  Future<void> _loadVideo(String url) async {
    if (_isUrlLoading) return;
    if (_settings.geminiApiKey.isEmpty) {
      _showApiKeyMissingDialog();
      return;
    }

    setState(() {
      _isUrlLoading = true;
      _segments = [];
      _activeSegmentIndex = -1;
      _translationState = const TranslationState(
        status: TranslationStatus.extractingCaptions,
      );
    });

    try {
      // 1. Extract transcript from YouTube.
      final result = await _youtubeService.extractTranscript(url);
      final videoId = result.videoId;
      final title = result.title;
      final segments = result.segments;

      if (!mounted) return;
      setState(() {
        _segments = segments;
        _videoTitle = title;
        _currentVideoId = videoId;
      });

      // 2. Set up video player immediately so it can buffer.
      _setupPlayer(videoId);

      // 3. Check translation cache.
      final cached =
          await _settingsService.loadCachedTranslation(videoId);
      if (cached != null) {
        _applyTranslations(cached);
        if (mounted) {
          setState(() {
            _translationState = const TranslationState(
              status: TranslationStatus.completed,
            );
            _isUrlLoading = false;
          });
        }
        return;
      }

      // 4. Begin batched translation.
      final numBatches = (segments.length / 50).ceil();
      if (mounted) {
        setState(() => _translationState = TranslationState(
              status: TranslationStatus.translating,
              totalBatches: numBatches,
              completedBatches: 0,
            ));
      }

      final translationService =
          TranslationService(apiKey: _settings.geminiApiKey);

      await translationService.translateSegments(
        segments,
        onBatchComplete: (completed, total) {
          if (mounted) {
            setState(() {
              _translationState = _translationState.copyWith(
                status: TranslationStatus.translating,
                completedBatches: completed,
                totalBatches: total,
              );
              // Trigger rebuild so list updates live as batches arrive.
            });
          }
        },
      );

      // 5. Cache the completed translation.
      final translatedMap = segments
          .where((s) => s.translatedText != null)
          .map((s) => {'index': s.index, 'text': s.translatedText!})
          .toList();
      await _settingsService.cacheTranslation(videoId, translatedMap);

      if (mounted) {
        setState(() => _translationState = const TranslationState(
              status: TranslationStatus.completed,
            ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _translationState = TranslationState(
              status: TranslationStatus.error,
              errorMessage: e.toString().replaceFirst('Exception: ', ''),
            ));
      }
    } finally {
      if (mounted) setState(() => _isUrlLoading = false);
    }
  }

  void _applyTranslations(List<Map<String, dynamic>> cached) {
    for (final item in cached) {
      final index = item['index'] as int?;
      final text = item['text'] as String?;
      if (index == null || text == null) continue;
      final matchIdx =
          _segments.indexWhere((s) => s.index == index);
      if (matchIdx != -1) {
        _segments[matchIdx].translatedText = text;
      }
    }
  }

  void _setupPlayer(String videoId) {
    _positionTimer?.cancel();
    _playerController?.dispose();

    _playerController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: false, // We handle our own captions.
        loop: false,
      ),
    );

    // Poll playback position every 250ms to sync subtitles.
    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _updateActiveSegment(),
    );
  }

  void _updateActiveSegment() {
    if (_playerController == null || _segments.isEmpty) return;
    final pos = _playerController!.value.position;
    int found = -1;
    for (int i = 0; i < _segments.length; i++) {
      if (_segments[i].isActiveAt(pos)) {
        found = i;
        break;
      }
    }
    if (found != _activeSegmentIndex && mounted) {
      setState(() => _activeSegmentIndex = found);
    }
  }

  void _seekTo(Duration position) {
    _playerController?.seekTo(position);
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (_) => SettingsDialog(
        current: _settings,
        settingsService: _settingsService,
        onSaved: (updated) async {
          await _settingsService.save(updated);
          if (mounted) setState(() => _settings = updated);
        },
      ),
    );
  }

  void _showApiKeyMissingDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 10),
            Text('API Key Required'),
          ],
        ),
        content: const Text(
          'Please set your Gemini API key in Settings before loading a video.\n\n'
          'You can get a free key at ai.google.dev',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _openSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sharingSubscription?.cancel();
    _positionTimer?.cancel();
    _playerController?.dispose();
    _urlController.dispose();
    _youtubeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.translate_rounded, size: 22),
            SizedBox(width: 8),
            Text(
              'KurdTube AI',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          // URL input bar
          _buildUrlInputBar(),

          // Status indicator
          if (_translationState.status != TranslationStatus.idle &&
              _translationState.status != TranslationStatus.completed)
            _buildStatusBar(),

          // Error display
          if (_translationState.status == TranslationStatus.error)
            _buildErrorCard(),

          // Video player + transcript
          if (_playerController != null && _currentVideoId != null)
            Expanded(child: _buildPlayerAndTranscript())
          else if (_translationState.status == TranslationStatus.idle ||
              _translationState.status == TranslationStatus.error)
            _buildEmptyState(),
        ],
      ),
    );
  }

  Widget _buildUrlInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _urlController,
              decoration: InputDecoration(
                hintText: 'Paste a YouTube URL here...',
                prefixIcon: const Icon(Icons.link_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
                suffixIcon: _urlController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => setState(() => _urlController.clear()),
                      )
                    : null,
              ),
              textInputAction: TextInputAction.go,
              onSubmitted: (v) => _loadVideo(v.trim()),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _isUrlLoading
                ? null
                : () => _loadVideo(_urlController.text.trim()),
            icon: _isUrlLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Load'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final state = _translationState;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              value: state.isLoading && state.totalBatches > 0
                  ? state.progress
                  : null,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.statusMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _translationState.errorMessage ?? 'Unknown error',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.subtitles_rounded,
                size: 80,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.3),
              ),
              const SizedBox(height: 20),
              Text(
                'KurdTube AI',
                style:
                    Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
              ),
              const SizedBox(height: 10),
              Text(
                'Paste a YouTube URL above, or share a video\n'
                'directly from the YouTube app to get\n'
                'synchronized Kurdish (Sorani) subtitles.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 24),
              if (_settings.geminiApiKey.isEmpty)
                FilledButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.key_rounded),
                  label: const Text('Set Gemini API Key'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerAndTranscript() {
    final activeText = _activeSegmentIndex >= 0 &&
            _activeSegmentIndex < _segments.length
        ? _segments[_activeSegmentIndex].translatedText
        : null;

    return Column(
      children: [
        // Video player with subtitle overlay
        YoutubePlayerBuilder(
          player: YoutubePlayer(
            controller: _playerController!,
            showVideoProgressIndicator: true,
            progressIndicatorColor:
                Theme.of(context).colorScheme.primary,
            onReady: () {},
          ),
          builder: (context, player) {
            return Stack(
              children: [
                player,
                SubtitleOverlay(
                  text: activeText,
                  fontSize: _settings.subtitleFontSize,
                ),
              ],
            );
          },
        ),

        // Video title
        if (_videoTitle != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              _videoTitle!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // Divider + "Transcript" label
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.format_list_bulleted_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Kurdish Transcript',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              if (_translationState.status == TranslationStatus.translating)
                Text(
                  '${_translationState.completedBatches}/'
                  '${_translationState.totalBatches} batches',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
            ],
          ),
        ),

        // Interactive transcript list
        Expanded(
          child: TranscriptList(
            segments: _segments,
            activeIndex: _activeSegmentIndex,
            onSeek: _seekTo,
          ),
        ),
      ],
    );
  }
}
