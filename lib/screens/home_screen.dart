// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../models/app_settings.dart';
import '../models/history_item.dart';
import '../models/subtitle_segment.dart';
import '../models/translation_state.dart';
import '../services/history_service.dart';
import '../services/settings_service.dart';
import '../services/translation_service.dart';
import '../services/youtube_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gold_button.dart';
import '../widgets/language_options_dialog.dart';
import 'about_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'translation_progress_screen.dart';
import 'watch_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _settingsService = SettingsService();
  final _youtubeService = YoutubeService();
  final _historyService = HistoryService();

  int _currentTabIndex = 0;
  AppSettings _settings = AppSettings.defaults;
  StreamSubscription? _sharingSubscription;

  // Active video input & preview state
  final _urlController = TextEditingController();
  String? _detectedVideoId;
  String? _detectedTitle;
  bool _isFetchingPreview = false;
  bool _isTranslating = false;

  // Translation State
  List<SubtitleSegment> _activeSegments = [];
  bool _cancelRequested = false;

  // Selected language preferences for current session
  late String _activeDialect;
  late String _activeScript;
  late double _activeFontSize;
  late double _activeSpeed;

  @override
  void initState() {
    super.initState();
    _activeDialect = _settings.defaultDialect;
    _activeScript = _settings.defaultScript;
    _activeFontSize = _settings.subtitleFontSize;
    _activeSpeed = _settings.playbackSpeed;

    _loadSettings();
    _initSharingIntent();
    _urlController.addListener(_onUrlChanged);
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsService.load();
    if (mounted) {
      setState(() {
        _settings = settings;
        _activeDialect = settings.defaultDialect;
        _activeScript = settings.defaultScript;
        _activeFontSize = settings.subtitleFontSize;
        _activeSpeed = settings.playbackSpeed;
      });
    }
  }

  void _initSharingIntent() {
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

  void _handleSharedUrl(String rawText) {
    if (!mounted) return;
    final id = _youtubeService.parseVideoId(rawText);
    if (id != null) {
      _urlController.text = 'https://youtu.be/$id';
      _fetchPreview(id);
    }
  }

  void _onUrlChanged() {
    final input = _urlController.text.trim();
    final id = _youtubeService.parseVideoId(input);
    if (id != null && id != _detectedVideoId) {
      _fetchPreview(id);
    } else if (input.isEmpty) {
      setState(() {
        _detectedVideoId = null;
        _detectedTitle = null;
      });
    }
  }

  Future<void> _fetchPreview(String videoId) async {
    setState(() {
      _detectedVideoId = videoId;
      _isFetchingPreview = true;
    });

    try {
      final info = await _youtubeService.extractTranscript(videoId);
      if (mounted && _detectedVideoId == videoId) {
        setState(() {
          _detectedTitle = info.title;
          _activeSegments = info.segments;
          _isFetchingPreview = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _detectedTitle = 'ڤیدیۆی یووتیوب';
          _isFetchingPreview = false;
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _urlController.text = text;
      _onUrlChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('بەستەر لە کلیپبۆردەوە دانرا.'),
            backgroundColor: AppTheme.cardSurface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openLanguageOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LanguageOptionsDialog(
        initialDialect: _activeDialect,
        initialScript: _activeScript,
        initialFontSize: _activeFontSize,
        initialSpeed: _activeSpeed,
        onApplied: (d, s, f, sp) {
          setState(() {
            _activeDialect = d;
            _activeScript = s;
            _activeFontSize = f;
            _activeSpeed = sp;
          });
        },
      ),
    );
  }

  Future<void> _startTranslation() async {
    final rawInput = _urlController.text.trim();
    final videoId = _youtubeService.parseVideoId(rawInput) ?? _detectedVideoId;

    if (videoId == null) {
      _showKurdishSnack('تکایە بەستەرێکی دروستی یووتیوب دابنێ.');
      return;
    }

    if (_settings.geminiApiKey.isEmpty) {
      _showApiKeyRequiredDialog();
      return;
    }

    // Check offline saved history first
    final existingHistory = await _historyService.getItem(videoId);
    if (existingHistory != null && existingHistory.isFullyTranslated) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WatchScreen(
              item: existingHistory,
              subtitleFontSize: _activeFontSize,
              apiKey: _settings.geminiApiKey,
              onRetranslate: () => _executeTranslation(videoId, forceNew: true),
            ),
          ),
        );
      }
      return;
    }

    _executeTranslation(videoId);
  }

  Future<void> _executeTranslation(String videoId, {bool forceNew = false}) async {
    setState(() {
      _isTranslating = true;
      _cancelRequested = false;
    });

    final progressNotifier = ValueNotifier<TranslationState>(
      const TranslationState(
        status: TranslationStatus.verifyingLink,
        currentProgress: 0.15, // Step 1 Done immediately: 15%
      ),
    );

    bool isProgressScreenActive = true;

    // Show Progress Screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TranslationProgressScreen(
          notifier: progressNotifier,
          videoTitle: _detectedTitle ?? 'ڤیدیۆی یووتیوب',
          canWatchPartial: _activeSegments.any((s) => s.translatedText != null),
          onWatchNow: () {
            isProgressScreenActive = false;
            _navigateToWatch(videoId);
          },
          onCancel: () {
            _cancelRequested = true;
            isProgressScreenActive = false;
            if (Navigator.canPop(context)) Navigator.pop(context);
            setState(() => _isTranslating = false);
          },
          onRetry: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
            _executeTranslation(videoId, forceNew: true);
          },
        ),
      ),
    ).then((_) {
      isProgressScreenActive = false;
    });

    try {
      if (_cancelRequested) return;

      // ── Step 2: Extract caption track (15% -> 40%) ──────────────────────────
      progressNotifier.value = progressNotifier.value.copyWith(
        status: TranslationStatus.extractingCaptions,
        currentProgress: 0.25,
      );

      final transcriptResult = await _youtubeService.extractTranscript(videoId);
      final title = transcriptResult.title;
      final segments = transcriptResult.segments;

      if (_cancelRequested || !mounted) return;

      setState(() {
        _detectedTitle = title;
        _activeSegments = segments;
      });

      // Captions successfully extracted -> Step 2 Done: 40%
      progressNotifier.value = progressNotifier.value.copyWith(
        status: TranslationStatus.extractingCaptions,
        currentProgress: 0.40,
      );

      // ── Step 3: Fast First-Batch Translation (40% -> 85%) ───────────────────
      // Translate only the first 15 segments while on the loading screen
      final firstBatchSize = math.min(15, segments.length);
      final totalBatches = (segments.length / 15).ceil();

      progressNotifier.value = progressNotifier.value.copyWith(
        status: TranslationStatus.translating,
        currentProgress: 0.60,
        totalBatches: totalBatches,
        completedBatches: 0,
        estimatedSecondsRemaining: 3,
      );

      final translationService = TranslationService(
        apiKey: _settings.geminiApiKey,
        dialect: _activeDialect,
        script: _activeScript,
      );

      await translationService.translateFirstBatch(
        segments,
        batchSize: firstBatchSize,
        videoTitle: title,
      );

      if (_cancelRequested || !mounted) return;

      // First batch translated -> Step 3 Done: 85%
      progressNotifier.value = progressNotifier.value.copyWith(
        status: TranslationStatus.translating,
        currentProgress: 0.85,
        completedBatches: 1,
      );

      // ── Step 4: Timestamp Sync & Transition to Player (85% -> 100%) ─────────
      progressNotifier.value = progressNotifier.value.copyWith(
        status: TranslationStatus.syncingTimestamps,
        currentProgress: 1.0,
      );

      final historyItem = HistoryItem(
        videoId: videoId,
        videoUrl: 'https://youtu.be/$videoId',
        title: title,
        thumbnailUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
        durationSeconds:
            segments.isNotEmpty ? segments.last.end.inSeconds : 0,
        translatedAt: DateTime.now(),
        dialect: _activeDialect,
        script: _activeScript,
        segments: segments,
      );

      await _historyService.saveOrUpdate(historyItem);

      if (_cancelRequested || !mounted) return;

      // Smooth completion tick before opening player
      await Future.delayed(const Duration(milliseconds: 350));

      if (mounted && isProgressScreenActive) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WatchScreen(
              item: historyItem,
              subtitleFontSize: _activeFontSize,
              apiKey: _settings.geminiApiKey,
              onRetranslate: () =>
                  _executeTranslation(videoId, forceNew: true),
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted || _cancelRequested) return;
      final rawError =
          e.toString().replaceFirst('Exception: ', '').trim();
      progressNotifier.value = progressNotifier.value.copyWith(
        status: TranslationStatus.error,
        errorMessage: rawError.isNotEmpty
            ? rawError
            : 'هەڵەیەک ڕوویدا لە کاتی دەرهێنان یان وەرگێڕاندا.',
      );
    } finally {
      if (mounted) {
        setState(() => _isTranslating = false);
      }
    }
  }

  void _navigateToWatch(String videoId) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    final historyItem = HistoryItem(
      videoId: videoId,
      videoUrl: 'https://youtu.be/$videoId',
      title: _detectedTitle ?? 'ڤیدیۆی یووتیوب',
      thumbnailUrl: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      durationSeconds:
          _activeSegments.isNotEmpty ? _activeSegments.last.end.inSeconds : 0,
      translatedAt: DateTime.now(),
      dialect: _activeDialect,
      script: _activeScript,
      segments: _activeSegments,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WatchScreen(
          item: historyItem,
          subtitleFontSize: _activeFontSize,
          apiKey: _settings.geminiApiKey,
          onRetranslate: () => _executeTranslation(videoId, forceNew: true),
        ),
      ),
    );
  }

  void _showKurdishSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(msg),
        ),
        backgroundColor: AppTheme.cardSurface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showApiKeyRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.key_rounded, color: AppTheme.goldPrimary),
            SizedBox(width: 8),
            Text('کلیلی API پێویستە'),
          ],
        ),
        content: const Text(
          'بۆ بەکارهێنانی وەرگێڕانی زیرەکی دەستکرد، تکایە سەرەتا کلیلی بێبەرامبەری Gemini لە بەشی ڕێکخستنەکان دابنێ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('پاشان', style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.goldPrimary),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _currentTabIndex = 3); // Switch to Settings tab
            },
            child: const Text('چوون بۆ ڕێکخستنەکان',
                style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sharingSubscription?.cancel();
    _urlController.dispose();
    _youtubeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.bgDarkNavy,
        body: IndexedStack(
          index: _currentTabIndex,
          children: [
            _buildHomeTab(),
            HistoryScreen(
              onRetranslateUrl: (url) {
                setState(() => _currentTabIndex = 0);
                _urlController.text = url;
                _onUrlChanged();
                _startTranslation();
              },
            ),
            const AboutScreen(),
            SettingsScreen(
              currentSettings: _settings,
              onSettingsChanged: (updated) {
                setState(() {
                  _settings = updated;
                  _activeDialect = updated.defaultDialect;
                  _activeScript = updated.defaultScript;
                  _activeFontSize = updated.subtitleFontSize;
                  _activeSpeed = updated.playbackSpeed;
                });
              },
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  // ── SCREEN 1: Home Tab Matching Mockup ────────────────────────────────────
  Widget _buildHomeTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        children: [
          // Top bar brand header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded,
                    color: AppTheme.goldPrimary),
                onPressed: () => setState(() => _currentTabIndex = 2), // About
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ژێرنووس',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.goldPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        size: 22, color: AppTheme.textDark),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Hero title with stars
          Center(
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('✦', style: TextStyle(color: AppTheme.goldPrimary, fontSize: 14)),
                    SizedBox(width: 6),
                    Text(
                      'هەر ڤیدیۆیەک،',
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.goldPrimary,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text('✦', style: TextStyle(color: AppTheme.goldPrimary, fontSize: 14)),
                  ],
                ),
                const Text(
                  'بە ژێرنووسی کوردی',
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.goldAccent,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'ژێرنووسی کوردی بۆ هەر ڤیدیۆیەکی یووتیوب',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── URL Input Card ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: AppTheme.cardDecoration(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgDarkNavy,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.paste_rounded,
                      size: 20, color: AppTheme.goldPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'بەستەری ڤیدیۆکەت لێرە بکە...',
                      hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_urlController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded,
                        size: 18, color: AppTheme.textMuted),
                    onPressed: () {
                      _urlController.clear();
                      setState(() {
                        _detectedVideoId = null;
                        _detectedTitle = null;
                      });
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Detected Video Preview Card ──────────────────────────────────
          if (_detectedVideoId != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: AppTheme.cardDecoration(glow: true),
              child: Row(
                children: [
                  // YouTube Red Play Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF0000),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        size: 28, color: Colors.white),
                  ),
                  const SizedBox(width: 12),

                  // Video info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _detectedTitle ?? 'ڤیدیۆی دەستنیشانکراو',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textWhite,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'youtu.be/$_detectedVideoId',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Ready Badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.goldPrimary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.goldBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'ئامادەیە',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.goldPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (_isFetchingPreview)
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppTheme.goldPrimary),
                          )
                        else
                          const Icon(Icons.check_circle_rounded,
                              size: 14, color: AppTheme.goldPrimary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ── 3 Quick Action Cards Row ─────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.content_paste_go_rounded,
                  label: 'بەستەر لە\nکلیپبۆرد',
                  onTap: _pasteFromClipboard,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.history_rounded,
                  label: 'لە\nمێژوو',
                  onTap: () => setState(() => _currentTabIndex = 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickActionCard(
                  icon: Icons.translate_rounded,
                  label: 'زمان\nهەڵبژێرە',
                  onTap: _openLanguageOptions,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ── Big Gold CTA Button: دەستپێکە ← ──────────────────────────────
          GoldButton(
            label: 'دەستپێکە',
            icon: Icons.arrow_back_rounded, // In RTL, back arrow points forward
            isLoading: _isTranslating,
            onPressed: _startTranslation,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 96,
      decoration: AppTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: AppTheme.goldPrimary),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textWhite,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom Navigation Bar (4 Items) ───────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardSurface,
        border: Border(
          top: BorderSide(color: AppTheme.goldBorder, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (i) => setState(() => _currentTabIndex = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.goldPrimary,
          unselectedItemColor: AppTheme.textMuted,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'NotoNaskhArabic',
            fontSize: 11,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'سەرەکی',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'مێژوو',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.info_outline_rounded),
              label: 'دەربارە',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              label: 'ڕێکخستن',
            ),
          ],
        ),
      ),
    );
  }
}
