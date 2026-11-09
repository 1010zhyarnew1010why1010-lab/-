// lib/widgets/settings_dialog.dart
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';

class SettingsDialog extends StatefulWidget {
  final AppSettings current;
  final SettingsService settingsService;
  final void Function(AppSettings) onSaved;

  const SettingsDialog({
    super.key,
    required this.current,
    required this.settingsService,
    required this.onSaved,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _apiKeyController;
  late double _fontSize;
  bool _obscureKey = true;
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController =
        TextEditingController(text: widget.current.geminiApiKey);
    _fontSize = widget.current.subtitleFontSize;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    await widget.settingsService.clearAllCaches();
    if (mounted) {
      setState(() => _isClearingCache = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translation cache cleared.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _save() {
    final updated = AppSettings(
      geminiApiKey: _apiKeyController.text.trim(),
      subtitleFontSize: _fontSize,
    );
    widget.onSaved(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.settings_rounded, color: colorScheme.primary),
          const SizedBox(width: 10),
          const Text('Settings'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // API Key section
            Text(
              'Gemini API Key',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                hintText: 'AIza...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscureKey = !_obscureKey),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Get a free API key at ai.google.dev',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 20),

            // Font size section
            Text(
              'Subtitle Font Size: ${_fontSize.toStringAsFixed(0)}px',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                  ),
            ),
            Slider(
              value: _fontSize,
              min: 12,
              max: 28,
              divisions: 8,
              label: '${_fontSize.toStringAsFixed(0)}px',
              onChanged: (v) => setState(() => _fontSize = v),
            ),

            const Divider(height: 24),

            // Clear cache section
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isClearingCache ? null : _clearCache,
                icon: _isClearingCache
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_sweep_rounded),
                label: const Text('Clear Translation Cache'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Clears locally saved translations. '
              'Next view will re-use API tokens.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_rounded),
          label: const Text('Save'),
        ),
      ],
    );
  }
}
