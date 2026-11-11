// lib/screens/translation_progress_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/translation_state.dart';
import '../theme/app_theme.dart';
import '../widgets/gold_button.dart';

class TranslationProgressScreen extends StatefulWidget {
  final TranslationState state;
  final String videoTitle;
  final bool canWatchPartial;
  final VoidCallback onWatchNow;
  final VoidCallback onCancel;

  const TranslationProgressScreen({
    super.key,
    required this.state,
    required this.videoTitle,
    this.canWatchPartial = false,
    required this.onWatchNow,
    required this.onCancel,
  });

  @override
  State<TranslationProgressScreen> createState() =>
      _TranslationProgressScreenState();
}

class _TranslationProgressScreenState extends State<TranslationProgressScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final percent = state.percentage;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.bgDarkNavy,
        appBar: AppBar(
          title: const Text('وەرگێڕان'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, color: AppTheme.textWhite),
            onPressed: widget.onCancel,
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 1),

                // ── Large Gold Circular Progress Ring ───────────────────────
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 170,
                        height: 170,
                        child: CircularProgressIndicator(
                          value: state.progress,
                          strokeWidth: 10,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.goldPrimary),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$percent%',
                            style: const TextStyle(
                              fontFamily: 'NotoNaskhArabic',
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.goldPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'وەرگێڕان بەردەوامە...',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Animated Gold Audio Waveform Bars ──────────────────────
                _buildAnimatedWaveform(),

                const SizedBox(height: 24),

                // ── 4-Step Checklist ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  decoration: AppTheme.cardDecoration(),
                  child: Column(
                    children: [
                      _buildChecklistRow(
                        title: 'ناردنی بەستەر',
                        isDone: state.step1Done,
                        isInProgress: false,
                        icon: Icons.link_rounded,
                      ),
                      const Divider(height: 20, color: Colors.white10),
                      _buildChecklistRow(
                        title: 'دەرهێنانی دەق',
                        isDone: state.step2Done,
                        isInProgress: state.status ==
                            TranslationStatus.extractingCaptions,
                        icon: Icons.article_rounded,
                      ),
                      const Divider(height: 20, color: Colors.white10),
                      _buildChecklistRow(
                        title: state.totalBatches > 0
                            ? 'وەرگێڕان بۆ کوردی (${state.completedBatches} لە ${state.totalBatches})'
                            : 'وەرگێڕان بۆ کوردی',
                        isDone: state.step3Done,
                        isInProgress: state.step3InProgress,
                        icon: Icons.translate_rounded,
                      ),
                      const Divider(height: 20, color: Colors.white10),
                      _buildChecklistRow(
                        title: 'هاوکاتکردنی کاتی',
                        isDone: state.step4Done,
                        isInProgress: false,
                        icon: Icons.access_time_rounded,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Time Remaining Card ─────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 18, color: AppTheme.goldPrimary),
                      const SizedBox(width: 8),
                      Text(
                        state.estimatedSecondsRemaining > 0
                            ? 'خایەنی تەواوبوون: نزیکەی ${state.estimatedSecondsRemaining} چرکە'
                            : 'خایەنی تەواوبوون: کەمتر لە خولەکێک',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textWhite,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // ── Action Buttons ──────────────────────────────────────────
                if (widget.canWatchPartial) ...[
                  GoldButton(
                    label: 'سەیرکردنی ڤیدیۆ (دەقی ئامادە)',
                    onPressed: widget.onWatchNow,
                    icon: Icons.play_arrow_rounded,
                  ),
                  const SizedBox(height: 10),
                ],

                OutlinedButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppTheme.textMuted),
                  label: const Text(
                    'پاشگەزبوونەوە',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.white12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedWaveform() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        const barCount = 28;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(barCount, (i) {
            final phase = (i / barCount) * 2 * math.pi;
            final animValue = math.sin(_waveController.value * 2 * math.pi + phase);
            final height = (10 + (animValue.abs() * 26)).clamp(6.0, 36.0);

            return Container(
              width: 3.5,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2.2),
              decoration: BoxDecoration(
                color: AppTheme.goldPrimary.withOpacity(0.4 + (animValue.abs() * 0.6)),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildChecklistRow({
    required String title,
    required bool isDone,
    required bool isInProgress,
    required IconData icon,
  }) {
    Color badgeColor;
    String badgeText;
    Widget statusWidget;

    if (isDone) {
      badgeColor = AppTheme.successGreen;
      badgeText = 'تەواو';
      statusWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(badgeText,
              style: TextStyle(
                  fontSize: 12,
                  color: badgeColor,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Icon(Icons.check_circle_rounded, size: 16, color: badgeColor),
        ],
      );
    } else if (isInProgress) {
      badgeColor = AppTheme.goldPrimary;
      badgeText = 'بەردەوامە';
      statusWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(badgeText,
              style: TextStyle(
                  fontSize: 12,
                  color: badgeColor,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
            ),
          ),
        ],
      );
    } else {
      badgeColor = AppTheme.textMuted;
      badgeText = 'چاوەڕوان';
      statusWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(badgeText,
              style: TextStyle(
                  fontSize: 12,
                  color: badgeColor,
                  fontWeight: FontWeight.normal)),
          const SizedBox(width: 4),
          Icon(Icons.access_time_rounded, size: 16, color: badgeColor),
        ],
      );
    }

    return Row(
      children: [
        Icon(icon, size: 20, color: isDone || isInProgress ? AppTheme.goldPrimary : AppTheme.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: isDone || isInProgress ? AppTheme.textWhite : AppTheme.textMuted,
              fontWeight: isDone || isInProgress ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        statusWidget,
      ],
    );
  }
}
