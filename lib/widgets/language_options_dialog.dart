// lib/widgets/language_options_dialog.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'gold_button.dart';

class LanguageOptionsDialog extends StatefulWidget {
  final String initialDialect; // 'sorani' or 'kurmanji'
  final String initialScript; // 'arabic' or 'latin'
  final double initialFontSize;
  final double initialSpeed;
  final void Function(String dialect, String script, double fontSize, double speed)
      onApplied;

  const LanguageOptionsDialog({
    super.key,
    required this.initialDialect,
    required this.initialScript,
    required this.initialFontSize,
    required this.initialSpeed,
    required this.onApplied,
  });

  @override
  State<LanguageOptionsDialog> createState() => _LanguageOptionsDialogState();
}

class _LanguageOptionsDialogState extends State<LanguageOptionsDialog> {
  late String _dialect;
  late String _script;
  late double _fontSize;
  late double _speed;

  @override
  void initState() {
    super.initState();
    _dialect = widget.initialDialect;
    _script = widget.initialScript;
    _fontSize = widget.initialFontSize;
    _speed = widget.initialSpeed;
  }

  String get _previewText {
    if (_dialect == 'kurmanji') {
      return _script == 'latin'
          ? 'Ev mînakek ji jêrnavê kurdî ye.'
          : 'ئەڤ میناکەک ژ ژێرناڤێ کوردی یە.';
    } else {
      return _script == 'latin'
          ? 'Eme nmûneyek le jêrnûsî kurdî ye.'
          : 'ئەمە نموونەیەک لە ژێرنووسی کوردی.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.bgDarkNavy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag indicator & header
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'زمان هەڵبژێرە',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Section 1: Video Language ───────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.video_library_rounded,
                                size: 18, color: AppTheme.goldPrimary),
                            SizedBox(width: 8),
                            Text(
                              'زمانی ڤیدیۆ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.textWhite,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.goldPrimary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'خۆکارانە دیارکرا',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.goldPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.bgDarkNavy,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.language_rounded,
                              size: 18, color: AppTheme.goldPrimary),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'ئینگلیزی (English) 98%',
                              style: TextStyle(
                                color: AppTheme.textWhite,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Icon(Icons.check_circle_rounded,
                              size: 16, color: AppTheme.successGreen),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              const Center(
                child: Icon(Icons.arrow_downward_rounded,
                    size: 20, color: AppTheme.goldPrimary),
              ),
              const SizedBox(height: 10),

              // ── Section 2: Subtitle Language ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: AppTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.subtitles_rounded,
                            size: 18, color: AppTheme.goldPrimary),
                        SizedBox(width: 8),
                        Text(
                          'زمانی ژێرنووس',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.textWhite,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dialect selection chips
                    Row(
                      children: [
                        Expanded(
                          child: _buildDialectCard(
                            id: 'sorani',
                            title: 'سۆرانی',
                            subtitle: 'Central Kurdish',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildDialectCard(
                            id: 'kurmanji',
                            title: 'کرمانجی',
                            subtitle: 'Northern Kurdish',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Script toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ئەلفوبێ (پیت):',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('عەرەبی'),
                              selected: _script == 'arabic',
                              selectedColor: AppTheme.goldPrimary,
                              labelStyle: TextStyle(
                                color: _script == 'arabic'
                                    ? AppTheme.textDark
                                    : AppTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() => _script = 'arabic'),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('لاتینی (Latin)'),
                              selected: _script == 'latin',
                              selectedColor: AppTheme.goldPrimary,
                              labelStyle: TextStyle(
                                color: _script == 'latin'
                                    ? AppTheme.textDark
                                    : AppTheme.textWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              onSelected: (_) => setState(() => _script = 'latin'),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Live Subtitle Preview
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgDarkNavy,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.goldBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.cardSurface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'A',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.goldPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _previewText,
                              style: TextStyle(
                                fontFamily: _script == 'latin' ? 'Roboto' : 'NotoNaskhArabic',
                                color: AppTheme.goldAccent,
                                fontSize: _fontSize,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── 3 Quick Preference Pills ─────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildInfoPill(
                      title: 'شێوازی دەق',
                      value: _fontSize >= 18 ? 'گەورە' : (_fontSize <= 14 ? 'بچووک' : 'ناوەند'),
                      onTap: () {
                        setState(() {
                          if (_fontSize == 16) {
                            _fontSize = 20;
                          } else if (_fontSize == 20) {
                            _fontSize = 14;
                          } else {
                            _fontSize = 16;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoPill(
                      title: 'خێرایی فێرکردن',
                      value: '${_speed.toStringAsFixed(1)}x',
                      onTap: () {
                        setState(() {
                          if (_speed == 1.0) {
                            _speed = 1.25;
                          } else if (_speed == 1.25) {
                            _speed = 0.75;
                          } else {
                            _speed = 1.0;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoPill(
                      title: 'جۆری زمان',
                      value: _script == 'latin' ? 'چەپ بۆ ڕاست' : 'ڕاست بۆ چەپ',
                      onTap: null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // CTA Continue button
              GoldButton(
                label: 'بەردەوامبە',
                onPressed: () {
                  widget.onApplied(_dialect, _script, _fontSize, _speed);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialectCard({
    required String id,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _dialect == id;
    return GestureDetector(
      onTap: () => setState(() => _dialect = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.goldPrimary.withOpacity(0.15)
              : AppTheme.cardSurfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.goldPrimary : Colors.white12,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isSelected ? AppTheme.goldPrimary : AppTheme.textWhite,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? AppTheme.goldAccent : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  size: 20, color: AppTheme.goldPrimary)
            else
              const Icon(Icons.circle_outlined,
                  size: 20, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required String title,
    required String value,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.goldPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
