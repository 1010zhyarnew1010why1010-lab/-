// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gold_button.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings currentSettings;
  final ValueChanged<AppSettings> onSettingsChanged;

  const SettingsScreen({
    super.key,
    required this.currentSettings,
    required this.onSettingsChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final HistoryService _historyService = HistoryService();

  late final TextEditingController _apiKeyController;
  late double _fontSize;
  late String _dialect;
  late String _script;
  bool _obscureKey = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initialKeys = widget.currentSettings.geminiApiKeys.join('\n');
    _apiKeyController = TextEditingController(text: initialKeys);
    _fontSize = widget.currentSettings.subtitleFontSize;
    _dialect = widget.currentSettings.defaultDialect;
    _script = widget.currentSettings.defaultScript;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final updated = widget.currentSettings.copyWith(
      geminiApiKeys: _apiKeyController.text.trim(),
      subtitleFontSize: _fontSize,
      defaultDialect: _dialect,
      defaultScript: _script,
    );

    await _settingsService.save(updated);
    widget.onSettingsChanged(updated);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ڕێکخستنەکان بە سەرکەوتوویی پاشەکەوت کران.'),
          backgroundColor: AppTheme.cardSurface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openGeminiApiKeyUrl() async {
    final uri = Uri.parse('https://ai.google.dev/');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _clearCache() async {
    await _settingsService.clearAllCaches();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('کاشی وەرگێڕان پاککرایەوە.'),
          backgroundColor: AppTheme.cardSurface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سڕینەوەی مێژوو'),
        content: const Text('ئایا دڵنیایت دەتەوێت هەموو مێژووی ڤیدیۆکان بسڕیتەوە؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('نەخێر', style: TextStyle(color: AppTheme.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('بسڕەوە'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _historyService.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هەموو مێژوو سڕایەوە.'),
            backgroundColor: AppTheme.cardSurface,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.bgDarkNavy,
        appBar: AppBar(
          title: const Text('ڕێکخستنەکان'),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── Section 1: Gemini API Key ─────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.key_rounded,
                          size: 20, color: AppTheme.goldPrimary),
                      SizedBox(width: 8),
                      Text(
                        'کلیلەکانی Gemini API (پشتیوانی فرە-کلیل)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textWhite,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'دەتوانیت یەک یان چەندین کلیلی Gemini لێرە بنووسیت (بە دێڕی نوێ یان فاریزە جیاکراوە). بەرنامەکە لە کاتی تەواوبوونی پشک (Quota) خۆکارانە لە نێوان کلیلەکان و مۆدێلەکان دەگۆڕێت.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _apiKeyController,
                    obscureText: _obscureKey,
                    maxLines: _obscureKey ? 1 : 3,
                    minLines: 1,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppTheme.textWhite,
                        fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'کلیلەکان بە دێڕی نوێ بنووسە...',
                      hintStyle:
                          const TextStyle(color: Colors.white24, fontSize: 13),
                      filled: true,
                      fillColor: AppTheme.bgDarkNavy,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: AppTheme.goldPrimary, width: 1.5),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureKey
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppTheme.textMuted,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _openGeminiApiKeyUrl,
                    icon: const Icon(Icons.open_in_new_rounded,
                        size: 16, color: AppTheme.goldPrimary),
                    label: const Text(
                      'وەرگرتنی کلیلی بێبەرامبەر لە ai.google.dev',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.goldPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerRight,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Section 2: Subtitle Font Size ─────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.format_size_rounded,
                              size: 20, color: AppTheme.goldPrimary),
                          SizedBox(width: 8),
                          Text(
                            'قەبارەی فۆنتی ژێرنووس',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textWhite,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${_fontSize.toInt()} px',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.goldPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Slider(
                    value: _fontSize,
                    min: 12.0,
                    max: 26.0,
                    divisions: 7,
                    activeColor: AppTheme.goldPrimary,
                    inactiveColor: Colors.white12,
                    onChanged: (val) => setState(() => _fontSize = val),
                  ),
                  const SizedBox(height: 8),

                  // Preview container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xE60A101C),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.goldBorder),
                    ),
                    child: Text(
                      'ئەمە نموونەی دەرکەوتنی ژێرنووسی کوردییە لەسەر ڤیدیۆ.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'NotoNaskhArabic',
                        color: AppTheme.goldPrimary,
                        fontSize: _fontSize,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Section 3: Default Dialect & Script ────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.translate_rounded,
                          size: 20, color: AppTheme.goldPrimary),
                      SizedBox(width: 8),
                      Text(
                        'شێوازی زمانی بنەڕەتی',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textWhite,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('سۆرانی (Sorani)')),
                          selected: _dialect == 'sorani',
                          selectedColor: AppTheme.goldPrimary,
                          labelStyle: TextStyle(
                            color: _dialect == 'sorani'
                                ? AppTheme.textDark
                                : AppTheme.textWhite,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setState(() => _dialect = 'sorani'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('کرمانجی (Kurmanji)')),
                          selected: _dialect == 'kurmanji',
                          selectedColor: AppTheme.goldPrimary,
                          labelStyle: TextStyle(
                            color: _dialect == 'kurmanji'
                                ? AppTheme.textDark
                                : AppTheme.textWhite,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setState(() => _dialect = 'kurmanji'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('پیتەکانی عەرەبی')),
                          selected: _script == 'arabic',
                          selectedColor: AppTheme.goldPrimary,
                          labelStyle: TextStyle(
                            color: _script == 'arabic'
                                ? AppTheme.textDark
                                : AppTheme.textWhite,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setState(() => _script = 'arabic'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('پیتەکانی لاتینی (Latin)')),
                          selected: _script == 'latin',
                          selectedColor: AppTheme.goldPrimary,
                          labelStyle: TextStyle(
                            color: _script == 'latin'
                                ? AppTheme.textDark
                                : AppTheme.textWhite,
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (_) => setState(() => _script = 'latin'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Section 4: Data & Cache Management ─────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storage_rounded,
                          size: 20, color: AppTheme.goldPrimary),
                      SizedBox(width: 8),
                      Text(
                        'داتا و پاشەکەوتکردن',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textWhite,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('پاککردنەوەی کاشی وەرگێڕان',
                        style: TextStyle(fontSize: 14, color: AppTheme.textWhite)),
                    subtitle: const Text(
                        'سڕینەوەی وەرگێڕانە کاتییەکان بێ دەستکاری مێژوو.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.goldBorder),
                      ),
                      onPressed: _clearCache,
                      child: const Text('پاککردنەوە',
                          style: TextStyle(color: AppTheme.goldPrimary, fontSize: 12)),
                    ),
                  ),
                  const Divider(color: Colors.white10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('سڕینەوەی تەواوی مێژووی ڤیدیۆکان',
                        style: TextStyle(fontSize: 14, color: AppTheme.errorRed)),
                    subtitle: const Text(
                        'هەموو ئەو ڤیدیۆیانەی پێشتر وەرگێڕدراون دەسڕێتەوە.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.errorRed.withOpacity(0.5)),
                      ),
                      onPressed: _clearHistory,
                      child: const Text('سڕینەوە',
                          style: TextStyle(color: AppTheme.errorRed, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Save button
            GoldButton(
              label: 'پاشەکەوتکردنی ڕێکخستنەکان',
              icon: Icons.save_rounded,
              isLoading: _isSaving,
              onPressed: _saveSettings,
            ),

            const SizedBox(height: 16),
            const Center(
              child: Text(
                'ژێرنووس - Zhirnoos v2.0.0',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
