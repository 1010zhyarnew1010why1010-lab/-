// lib/screens/watch_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/history_item.dart';
import '../models/subtitle_segment.dart';
import '../services/history_service.dart';
import '../services/translation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/subtitle_overlay.dart';

class WatchScreen extends StatefulWidget {
  final HistoryItem item;
  final double subtitleFontSize;
  final String? apiKey;
  final VoidCallback? onRetranslate;

  const WatchScreen({
    super.key,
    required this.item,
    this.subtitleFontSize = 16.0,
    this.apiKey,
    this.onRetranslate,
  });

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  final HistoryService _historyService = HistoryService();
  final ScrollController _scrollController = ScrollController();

  YoutubePlayerController? _controller;
  Timer? _positionTimer;
  int _activeSegmentIndex = -1;
  int _lastScrolledIndex = -1;
  bool _isExporting = false;

  bool _isBackgroundTranslating = false;
  String? _backgroundStatusText;
  bool _isBackgroundCancelled = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndStartBackgroundTranslation();
      }
    });
  }

  void _checkAndStartBackgroundTranslation() {
    final apiKey = widget.apiKey;
    if (apiKey == null || apiKey.isEmpty) return;
    if (widget.item.isFullyTranslated) return;

    final firstUntranslated = widget.item.segments.indexWhere(
      (s) => s.translatedText == null || s.translatedText!.isEmpty,
    );
    if (firstUntranslated == -1) return;

    setState(() {
      _isBackgroundTranslating = true;
      _backgroundStatusText = 'وەرگێڕانی بەشەکانی تر لە باکگراوند...';
    });

    final translationService = TranslationService(
      apiKey: apiKey,
      dialect: widget.item.dialect,
      script: widget.item.script,
    );

    translationService.translateRemainingBatches(
      widget.item.segments,
      startIndex: firstUntranslated,
      batchSize: 15,
      videoTitle: widget.item.title,
      isCancelled: () => _isBackgroundCancelled || !mounted,
      onBatchComplete: (completed, total) {
        if (!mounted || _isBackgroundCancelled) return;
        setState(() {
          _backgroundStatusText =
              'وەرگێڕانی باکگراوند: بەشی $completed لە $total';
          if (completed >= total) {
            _isBackgroundTranslating = false;
            _backgroundStatusText = 'هەموو ژێرنووسەکان ئامادەن ✅';
          }
        });
        _historyService.saveOrUpdate(widget.item);
      },
    ).then((_) {
      if (mounted && !_isBackgroundCancelled) {
        setState(() {
          _isBackgroundTranslating = false;
          _backgroundStatusText = 'هەموو ژێرنووسەکان ئامادەن ✅';
        });
        _historyService.saveOrUpdate(widget.item);
      }
    });
  }

  void _initPlayer() {
    _controller = YoutubePlayerController(
      initialVideoId: widget.item.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        enableCaption: false, // We render our own Kurdish subtitles
        loop: false,
      ),
    );

    _positionTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _updateActiveSegment(),
    );
  }

  void _updateActiveSegment() {
    if (_controller == null || widget.item.segments.isEmpty) return;
    final pos = _controller!.value.position;
    int found = -1;
    for (int i = 0; i < widget.item.segments.length; i++) {
      if (widget.item.segments[i].isActiveAt(pos)) {
        found = i;
        break;
      }
    }
    if (found != _activeSegmentIndex && mounted) {
      setState(() => _activeSegmentIndex = found);
      if (found != -1 && found != _lastScrolledIndex) {
        _lastScrolledIndex = found;
        _scrollToActive(found);
      }
    }
  }

  void _scrollToActive(int index) {
    if (!_scrollController.hasClients) return;
    const cardHeight = 88.0;
    final targetOffset = (index * cardHeight) - 100.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _seekTo(Duration d) {
    _controller?.seekTo(d);
  }

  Future<void> _exportSrt() async {
    setState(() => _isExporting = true);
    await _historyService.exportAndShareSrt(widget.item);
    if (mounted) {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ژێرنووسی SRT ئامادەکرا و نێردرا.'),
          backgroundColor: AppTheme.cardSurface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _exportVtt() async {
    setState(() => _isExporting = true);
    await _historyService.exportAndShareVtt(widget.item);
    if (mounted) {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ژێرنووسی VTT ئامادەکرا و نێردرا.'),
          backgroundColor: AppTheme.cardSurface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _isBackgroundCancelled = true;
    _positionTimer?.cancel();
    _controller?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeText = (_activeSegmentIndex >= 0 &&
            _activeSegmentIndex < widget.item.segments.length)
        ? widget.item.segments[_activeSegmentIndex].translatedText
        : null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.bgDarkNavy,
        appBar: AppBar(
          title: const Text('سەیرکردن و هەڵگرتن'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.textWhite),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (widget.onRetranslate != null)
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.goldPrimary),
                tooltip: 'وەرگێڕانەوە',
                onPressed: widget.onRetranslate,
              ),
          ],
        ),
        body: Column(
          children: [
            // ── Embedded YouTube Player with Subtitle Overlay ─────────────
            if (_controller != null)
              YoutubePlayerBuilder(
                player: YoutubePlayer(
                  controller: _controller!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: AppTheme.goldPrimary,
                ),
                builder: (context, player) {
                  return Stack(
                    children: [
                      player,
                      SubtitleOverlay(
                        text: activeText,
                        fontSize: widget.subtitleFontSize,
                      ),
                    ],
                  );
                },
              ),

            // ── Video Title & Duration Info Pill ─────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.bgSecondaryNavy,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textWhite,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.goldBorder),
                    ),
                    child: Text(
                      widget.item.formattedDuration,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.goldPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Background Translation Progress Pill ─────────────────────
            if (_isBackgroundTranslating || _backgroundStatusText != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: const BoxDecoration(
                  color: AppTheme.cardSurface,
                  border: Border(
                    bottom: BorderSide(color: Colors.white10, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    if (_isBackgroundTranslating) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.goldPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      const Icon(Icons.check_circle_rounded,
                          size: 14, color: AppTheme.successGreen),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        _backgroundStatusText ??
                            'وەرگێڕانی بەشەکانی تر لە باکگراوند...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.goldPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Dual-Language Interactive Transcript List ────────────────
            Expanded(
              child: widget.item.segments.isEmpty
                  ? const Center(
                      child: Text(
                        'دەقی ژێرنووس بەردەست نییە.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      itemCount: widget.item.segments.length,
                      itemBuilder: (context, i) {
                        final seg = widget.item.segments[i];
                        final isActive = i == _activeSegmentIndex;

                        return GestureDetector(
                          onTap: () => _seekTo(seg.start),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppTheme.goldPrimary.withOpacity(0.12)
                                  : AppTheme.cardSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActive
                                    ? AppTheme.goldPrimary
                                    : AppTheme.goldBorder.withOpacity(0.4),
                                width: isActive ? 1.5 : 0.8,
                              ),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.goldPrimary
                                            .withOpacity(0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Timestamp badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppTheme.goldPrimary
                                        : Colors.white10,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    seg.formatTimestamp(),
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isActive
                                          ? AppTheme.textDark
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Dual language text column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // English original (top, soft white)
                                      Text(
                                        seg.originalText,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textWhite
                                              .withOpacity(0.7),
                                          height: 1.3,
                                        ),
                                        textAlign: TextAlign.left,
                                      ),
                                      const SizedBox(height: 4),

                                      // Kurdish translation (bottom, bold gold)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          seg.translatedText ?? '...',
                                          style: const TextStyle(
                                            fontFamily: 'NotoNaskhArabic',
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.goldAccent,
                                            height: 1.5,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // ── Bottom Action Bar (SRT, VTT, Share) ────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface,
                border: const Border(
                  top: BorderSide(color: AppTheme.goldBorder, width: 1.0),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      label: 'هەڵگرتنی SRT',
                      icon: Icons.subtitles_outlined,
                      onTap: _isExporting ? null : _exportSrt,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      label: 'هەڵگرتنی VTT',
                      icon: Icons.video_file_outlined,
                      onTap: _isExporting ? null : _exportVtt,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      label: 'هاوبەشکردن',
                      icon: Icons.share_rounded,
                      onTap: _isExporting ? null : _exportSrt,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: AppTheme.cardSurfaceLight,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.goldBorder.withOpacity(0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: AppTheme.goldPrimary),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
