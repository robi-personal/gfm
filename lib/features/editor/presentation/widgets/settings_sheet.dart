import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/models/form_settings.dart';
import '../cubit/editor_cubit.dart';

class SettingsSheet extends StatefulWidget {
  final FormSettings initialSettings;
  final String formId;

  const SettingsSheet({
    super.key,
    required this.initialSettings,
    required this.formId,
  });

  static Future<void> show(BuildContext context) async {
    final state = context.read<EditorCubit>().state;
    if (state is! EditorLoaded) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BlocProvider.value(
        value: context.read<EditorCubit>(),
        child: SettingsSheet(
          initialSettings: state.form.settings,
          formId: state.form.formId,
        ),
      ),
    );
  }

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late EmailCollectionType _emailType;
  late bool _isQuiz;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _emailType = widget.initialSettings.emailCollectionType;
    _isQuiz = widget.initialSettings.quizSettings.isQuiz;
  }

  bool get _isDirty =>
      _emailType != widget.initialSettings.emailCollectionType ||
      _isQuiz != widget.initialSettings.quizSettings.isQuiz;

  Future<void> _onQuizToggle(bool value) async {
    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Turn off quiz mode?'),
          content: const Text(
            'All answer keys and point values will be permanently removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Turn off'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _isQuiz = value);
  }

  Future<void> _applyAndClose() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _isSaving = true);
    await context.read<EditorCubit>().updateSettings(
          FormSettings(
            quizSettings: QuizSettings(isQuiz: _isQuiz),
            emailCollectionType: _emailType,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _openInBrowser() async {
    final url = Uri.parse(
      'https://docs.google.com/forms/d/${widget.formId}/edit',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text('Settings', style: theme.textTheme.titleLarge),
                ),
                if (_isSaving)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton(
                    onPressed: _applyAndClose,
                    child: const Text('Done'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Email collection
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Collect email addresses',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
          RadioGroup<EmailCollectionType>(
            groupValue: _emailType,
            onChanged: _isSaving
                ? (_) {}
                : (v) => setState(() => _emailType = v as EmailCollectionType),
            child: Column(
              children: [
                RadioListTile<EmailCollectionType>(
                  title: const Text("Don't collect"),
                  value: EmailCollectionType.doNotCollect,
                ),
                RadioListTile<EmailCollectionType>(
                  title: const Text('Verified (Workspace accounts only)'),
                  value: EmailCollectionType.verified,
                ),
                RadioListTile<EmailCollectionType>(
                  title: const Text('Ask respondents'),
                  value: EmailCollectionType.responderInput,
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          // Quiz mode
          SwitchListTile(
            title: const Text('Quiz mode'),
            subtitle: const Text('Assign point values and set correct answers'),
            value: _isQuiz,
            onChanged: _isSaving ? null : _onQuizToggle,
          ),
          const Divider(height: 24),
          // More settings
          ListTile(
            leading: const Icon(Icons.open_in_browser_outlined),
            title: const Text('More settings'),
            subtitle: const Text(
              'Confirmation message, shuffle, themes — edit in browser',
            ),
            onTap: _openInBrowser,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

