// lib/screens/about_screen.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.bgDarkNavy,
        appBar: AppBar(
          title: const Text('دەربارەی ژێرنووس'),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // ── App Brand Card ──────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: AppTheme.goldGradient,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.goldPrimary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        size: 46, color: AppTheme.textDark),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'ژێرنووس - Zhirnoos',
                    style: TextStyle(
                      fontFamily: 'NotoNaskhArabic',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.goldPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'هەر ڤیدیۆیەک، بە ژێرنووسی کوردی',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.goldPrimary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.goldBorder),
                    ),
                    child: const Text(
                      'وەشانی فەرمی v2.0.0',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.goldPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Workflow Steps Card ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          size: 20, color: AppTheme.goldPrimary),
                      SizedBox(width: 8),
                      Text(
                        'چۆنیەتی کارکردنی بەرنامەکە',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textWhite,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildStepRow(
                    stepNum: '١',
                    title: 'بەستەری ڤیدیۆ',
                    description:
                        'بەستەری هەر ڤیدیۆیەکی یووتیوب دابنێ، یان ڕاستەوخۆ لە ناو بەرنامەی فەرمی یووتیوبەوە کلیک لە Share بکە و ژێرنووس هەڵبژێرە.',
                  ),
                  const SizedBox(height: 12),
                  _buildStepRow(
                    stepNum: '٢',
                    title: 'دەرهێنانی دەقی ڤیدیۆ',
                    description:
                        'بەرنامەکە ڕاستەوخۆ دەقی فەرمی یاخود خۆکارانەی ڤیدیۆکە لە یووتیوبەوە دەهێنێت بە کاتی دروستەوە.',
                  ),
                  const SizedBox(height: 12),
                  _buildStepRow(
                    stepNum: '٣',
                    title: 'وەرگێڕانی زیرەکی دەستکرد',
                    description:
                        'بە بەکارهێنانی مۆدێلی خێرای Gemini 2.5 Flash، دەقەکە بە شێوەیەکی واتایی و بەپێی ڕستەی تەواو وەردەگێڕدرێت بۆ کوردی (سۆرانی یان کرمانجی).',
                  ),
                  const SizedBox(height: 12),
                  _buildStepRow(
                    stepNum: '٤',
                    title: 'هاوکاتکردن و هەناردە',
                    description:
                        'ژێرنووسەکە لە کاتی خۆیدا لەسەر ڤیدیۆکە نیشان دەدرێت، هەروەها دەتوانیت وەک فایلی SRT یان VTT هەڵیگریت و هاوبەشی پێبکەیت.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Privacy & Guarantee Card ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 20, color: AppTheme.goldPrimary),
                      SizedBox(width: 8),
                      Text(
                        'پاراستنی زانیاری و تایبەتمەندی',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textWhite,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ئەم بەرنامەیە بە شێوەی ١٠٠٪ سەربەخۆ لەسەر ئامێرەکەت کاردەکات. هیچ سێرڤەرێکی نێوەندگیر نییە، و کلیلی API و مێژووی ڤیدیۆکانت تەنها لەسەر مۆبایلەکەت دەمێننەوە.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textMuted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required String stepNum,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppTheme.goldPrimary.withOpacity(0.18),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: AppTheme.goldBorder),
          ),
          alignment: Alignment.center,
          child: Text(
            stepNum,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppTheme.goldPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.textWhite,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
