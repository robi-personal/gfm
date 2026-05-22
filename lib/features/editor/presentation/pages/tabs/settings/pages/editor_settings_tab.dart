import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../../../core/di/injection.dart';
import '../../../../../../../core/models/enums.dart';
import '../../../../../../../core/models/form_settings.dart';
import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/widgets/error_modal.dart';
import '../../questions/cubit/questions_cubit.dart';
import '../cubit/settings_cubit.dart';
import '../widgets/email_collection_card.dart';
import '../widgets/notification_toggle.dart';
import '../widgets/settings_tiles.dart';
import '../../../../widgets/toggle_confirm_sheet.dart';

// ── Settings tab page ─────────────────────────────────────────────────────────

class EditorSettingsTab extends StatefulWidget {
  final String formId;

  const EditorSettingsTab({super.key, required this.formId});

  @override
  State<EditorSettingsTab> createState() => _EditorSettingsTabState();
}

class _EditorSettingsTabState extends State<EditorSettingsTab> {
  late final SettingsCubit _settingsCubit;

  @override
  void initState() {
    super.initState();
    _settingsCubit = getIt<SettingsCubit>();
    final editorState = context.read<QuestionsCubit>().state;
    if (editorState is QuestionsLoaded) {
      _settingsCubit.init(editorState.form.settings);
    }
  }

  @override
  void dispose() {
    _settingsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _settingsCubit,
      child: BlocListener<SettingsCubit, SettingsState>(
        listenWhen: (_, curr) => curr is SettingsLoaded,
        listener: (context, state) {
          if (state is SettingsLoaded) {
            context.read<QuestionsCubit>().syncSettings(state.settings);
          }
        },
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, settingsState) {
            if (settingsState is SettingsLoading) {
              return const Center(child: CupertinoActivityIndicator());
            }
            return BlocSelector<QuestionsCubit, QuestionsState, String?>(
              selector: (s) => s is QuestionsLoaded ? s.form.linkedSheetId : null,
              builder: (context, linkedSheetId) => _SettingsContent(
                formId: widget.formId,
                linkedSheetId: linkedSheetId,
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Settings content ──────────────────────────────────────────────────────────

class _SettingsContent extends StatefulWidget {
  final String formId;
  final String? linkedSheetId;

  const _SettingsContent({required this.formId, this.linkedSheetId});

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  late bool _isQuiz;
  bool _isQuizWorking = false;

  @override
  void initState() {
    super.initState();
    final settings = (context.read<SettingsCubit>().state as SettingsLoaded).settings;
    _isQuiz = settings.quizSettings.isQuiz;
  }

  Future<void> _save({required EmailCollectionType emailType, required bool isQuiz}) async {
    final cubitState = context.read<SettingsCubit>().state;
    if (cubitState is SettingsLoaded && cubitState.isSaving) return;
    await context.read<SettingsCubit>().updateSettings(
          widget.formId,
          FormSettings(
            quizSettings: QuizSettings(isQuiz: isQuiz),
            emailCollectionType: emailType,
          ),
        );
  }

  Future<void> _onQuizToggle(bool value) async {
    if (_isQuizWorking) return;
    final confirmed = await showToggleConfirmSheet(
      context,
      icon: CupertinoIcons.star,
      title: value ? 'Enable Quiz Mode' : 'Turn Off Quiz Mode',
      subtitle: 'Quiz',
      body: value
          ? 'Assign point values and set correct answers to your questions.'
          : 'All answer keys and point values will be permanently removed.',
      continueLabel: value ? 'Enable' : 'Turn off',
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _isQuiz = value;
      _isQuizWorking = true;
    });
    final settings = (context.read<SettingsCubit>().state as SettingsLoaded).settings;
    await _save(emailType: settings.emailCollectionType, isQuiz: value);
    if (mounted) setState(() => _isQuizWorking = false);
  }

  Future<void> _onEmailTypeChange(EmailCollectionType value) async {
    final settings = (context.read<SettingsCubit>().state as SettingsLoaded).settings;
    await _save(emailType: value, isQuiz: settings.quizSettings.isQuiz);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsCubit, SettingsState>(
      listenWhen: (prev, curr) =>
          curr is SettingsLoaded &&
          curr.saveFailed &&
          prev is SettingsLoaded &&
          !prev.saveFailed,
      listener: (context, state) {
        if (state is! SettingsLoaded) return;
        setState(() {
          _isQuiz = state.settings.quizSettings.isQuiz;
        });
        context.read<SettingsCubit>().clearSaveFailed();
        ErrorModal.show(
          context,
          title: 'Could not save settings',
          body: 'Please try again.',
          primaryLabel: 'OK',
          onPrimary: () {},
        );
      },
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settingsState) {
          final isSaving = settingsState is SettingsLoaded && settingsState.isSaving;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16, 20, 16, MediaQuery.viewPaddingOf(context).bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Email collection ─────────────────────────────────────────
                SettingsGroupLabel(
                  label: 'COLLECT EMAIL ADDRESSES',
                  trailing: isSaving
                      ? const CupertinoActivityIndicator(radius: 7)
                      : null,
                ),
                EmailCollectionCard(
                  emailType: (settingsState as SettingsLoaded).settings.emailCollectionType,
                  isSaving: isSaving,
                  onChanged: _onEmailTypeChange,
                ),
                const SizedBox(height: 28),

                // ── Quiz mode ────────────────────────────────────────────────
                const SettingsGroupLabel(label: 'QUIZ'),
                SettingsCard(children: [
                  SettingsSwitchTile(
                    label: 'Quiz mode',
                    subtitle: 'Assign point values and set correct answers',
                    value: _isQuiz,
                    isLast: true,
                    isLoading: _isQuizWorking,
                    onChanged: (isSaving || _isQuizWorking) ? null : _onQuizToggle,
                  ),
                ]),
                const SizedBox(height: 28),

                // ── Notifications ────────────────────────────────────────────
                const SettingsGroupLabel(label: 'NOTIFICATIONS'),
                SettingsCard(children: [
                  NotificationToggle(
                    formId: widget.formId,
                    formTitle: context.read<QuestionsCubit>().state is QuestionsLoaded
                        ? (context.read<QuestionsCubit>().state as QuestionsLoaded).form.info.title
                        : '',
                  ),
                ]),
                const SizedBox(height: 28),

                // ── Data ─────────────────────────────────────────────────────
                if (widget.linkedSheetId != null) ...[
                  const SettingsGroupLabel(label: 'DATA'),
                  SettingsCard(children: [
                    SettingsActionTile(
                      icon: CupertinoIcons.table,
                      label: 'Open linked Google Sheet',
                      trailing: const Icon(
                        CupertinoIcons.arrow_up_right_square,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      isLast: true,
                      onTap: () => launchUrl(
                        Uri.parse(
                          'https://docs.google.com/spreadsheets/d/${widget.linkedSheetId}',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
