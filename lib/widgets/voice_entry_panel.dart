import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/expense_provider.dart';
import '../services/voice_input_controller.dart';
import '../theme/app_theme.dart';
import '../utils/voice_expense_parser.dart';

class VoiceEntryPanel extends StatefulWidget {
  const VoiceEntryPanel({
    super.key,
    required this.onApply,
    required this.onClose,
    this.controller,
  });
  final void Function(VoiceExpenseDraft draft, String currency) onApply;
  final VoidCallback onClose;
  final VoiceInputController? controller;
  @override
  State<VoiceEntryPanel> createState() => _VoiceEntryPanelState();
}

class _VoiceEntryPanelState extends State<VoiceEntryPanel>
    with WidgetsBindingObserver {
  late final VoiceInputController _voice;
  String? _chosenCurrency;
  bool _showOptions = false;
  String? _settingsError;
  @override
  void initState() {
    super.initState();
    _voice = widget.controller ?? VoiceInputController.shared;
    _voice.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _start() {
    final provider = context.read<ExpenseProvider>();
    _chosenCurrency = null;
    unawaited(
      _voice.start(
        locale: provider.voiceLocale,
        onDevice: provider.voiceOnDevice,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voice.removeListener(_changed);
    unawaited(_voice.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      unawaited(_voice.cancel());
    }
  }

  Future<void> _preferences({String? locale, bool? onDevice}) async {
    final provider = context.read<ExpenseProvider>();
    await _voice.cancel();
    final saved = await provider.setVoicePreferences(
      locale: locale ?? provider.voiceLocale,
      onDevice: onDevice ?? provider.voiceOnDevice,
    );
    if (mounted) {
      setState(() => _settingsError = saved ? null : provider.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();
    final busy = _voice.isStarting || _voice.isListening;
    final draft = _voice.transcript.trim().isEmpty
        ? null
        : VoiceExpenseParser.parse(_voice.transcript, now: provider.now);
    final currency =
        _chosenCurrency ?? draft?.currency ?? (provider.isUSD ? 'USD' : 'YER');
    final locales = [..._voice.locales]
      ..sort((a, b) => a.name.compareTo(b.name));
    final locale = locales.any((l) => l.localeId == provider.voiceLocale)
        ? provider.voiceLocale
        : '';
    return Container(
      key: const ValueKey('voice-review'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.medium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _voice.isListening ? 'Listening…' : 'Voice entry',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Voice options',
                icon: const Icon(Icons.tune, size: 20),
                onPressed: () => setState(() => _showOptions = !_showOptions),
              ),
              IconButton(
                tooltip: 'Close voice entry',
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onClose,
              ),
            ],
          ),
          Text(
            provider.voiceOnDevice
                ? 'On-device recognition · review before applying'
                : 'Your phone’s speech service may process audio online.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_showOptions) ...[
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              key: ValueKey(locale),
              initialValue: locale,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Speech language'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Device language'),
                ),
                ...locales.map(
                  (l) => DropdownMenuItem(
                    value: l.localeId,
                    child: Text(l.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: provider.isSaving
                  ? null
                  : (value) => _preferences(locale: value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('On-device only'),
              subtitle: const Text(
                'Needs an installed offline speech pack. No automatic online fallback.',
              ),
              value: provider.voiceOnDevice,
              onChanged: provider.isSaving
                  ? null
                  : (value) => _preferences(onDevice: value),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              _voice.transcript.isEmpty
                  ? 'Try “قهوة عشرين ريال” or “coffee four dollars”.'
                  : _voice.transcript,
              textDirection:
                  RegExp(r'[\u0600-\u06FF]').hasMatch(_voice.transcript)
                  ? TextDirection.rtl
                  : TextDirection.ltr,
            ),
          ),
          if (_voice.error != null || _settingsError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                _settingsError ?? _voice.error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          ],
          if (draft != null && !busy) ...[
            const Divider(height: 24),
            Text(draft.title, style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${draft.category} · ${MaterialLocalizations.of(context).formatMediumDate(draft.date)}',
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    draft.amount?.toStringAsFixed(2) ?? 'Amount unclear',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'USD', label: Text('USD')),
                    ButtonSegment(value: 'YER', label: Text('YER')),
                  ],
                  selected: {currency},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _chosenCurrency = value.first),
                ),
              ],
            ),
            if (draft.currency == null && draft.issues.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Currency was not heard. Confirm $currency above.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ...draft.issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  issue,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _voice.isStarting
                      ? null
                      : busy
                      ? _voice.stop
                      : _start,
                  icon: Icon(
                    busy ? Icons.stop_rounded : Icons.mic_none_rounded,
                  ),
                  label: Text(
                    _voice.isStarting
                        ? 'Starting…'
                        : busy
                        ? 'Stop'
                        : 'Try again',
                  ),
                ),
              ),
              if (draft != null && !busy) ...[
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: draft.canApply
                        ? () => widget.onApply(draft, currency)
                        : null,
                    child: const Text('Use entry'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
