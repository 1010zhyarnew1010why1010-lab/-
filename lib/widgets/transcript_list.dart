// lib/widgets/transcript_list.dart
import 'package:flutter/material.dart';
import '../models/subtitle_segment.dart';

class TranscriptList extends StatefulWidget {
  final List<SubtitleSegment> segments;
  final int activeIndex;
  final void Function(Duration position) onSeek;

  const TranscriptList({
    super.key,
    required this.segments,
    required this.activeIndex,
    required this.onSeek,
  });

  @override
  State<TranscriptList> createState() => _TranscriptListState();
}

class _TranscriptListState extends State<TranscriptList> {
  final ScrollController _scrollController = ScrollController();
  int _lastScrolledIndex = -1;

  @override
  void didUpdateWidget(TranscriptList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeIndex != _lastScrolledIndex &&
        widget.activeIndex >= 0 &&
        widget.activeIndex < widget.segments.length) {
      _lastScrolledIndex = widget.activeIndex;
      _scrollToActive();
    }
  }

  void _scrollToActive() {
    if (!_scrollController.hasClients) return;
    // Each card is approximately 100px tall; this is a reasonable estimate.
    const estimatedCardHeight = 100.0;
    final offset = widget.activeIndex * estimatedCardHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = offset - viewportHeight / 2 + estimatedCardHeight / 2;
    _scrollController.animateTo(
      targetOffset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (widget.segments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No transcript segments to display.'),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: widget.segments.length,
      itemBuilder: (context, i) {
        final seg = widget.segments[i];
        final isActive = i == widget.activeIndex;

        return GestureDetector(
          onTap: () => widget.onSeek(seg.start),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: isActive
                  ? colorScheme.primary.withOpacity(0.18)
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withOpacity(0.4),
                width: isActive ? 1.5 : 0.8,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timestamp chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatDuration(seg.start),
                      style: textTheme.labelSmall?.copyWith(
                        fontFamily: 'monospace',
                        color: isActive
                            ? colorScheme.onPrimary
                            : colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Kurdish translation (RTL, prominent)
                        if (seg.translatedText != null &&
                            seg.translatedText!.isNotEmpty)
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              seg.translatedText!,
                              textAlign: TextAlign.right,
                              style: textTheme.bodyMedium?.copyWith(
                                fontFamily: 'NotoNaskhArabic',
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isActive
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                                height: 1.6,
                              ),
                            ),
                          )
                        else
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '...',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        // Original English text (smaller, muted)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            seg.originalText,
                            textAlign: TextAlign.left,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.55),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
