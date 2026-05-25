import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../../../core/di/injection.dart';
import '../../../../../../../core/models/enums.dart';
import '../../../../../../../core/models/extended_form_settings.dart';
import '../../../../../../../core/models/form_settings.dart';
import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/widgets/error_modal.dart';
import '../../questions/cubit/questions_cubit.dart';
import '../cubit/extended_settings_cubit.dart';
import '../cubit/settings_cubit.dart';
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
  late final ExtendedSettingsCubit _extendedCubit;

  @override
  void initState() {
    super.initState();
    _settingsCubit = getIt<SettingsCubit>();
    _extendedCubit = getIt<ExtendedSettingsCubit>()..load(widget.formId);
    final editorState = context.read<QuestionsCubit>().state;
    if (editorState is QuestionsLoaded) {
      _settingsCubit.init(editorState.form.settings);
    }
  }

  @override
  void dispose() {
    _settingsCubit.close();
    _extendedCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _settingsCubit),
        BlocProvider.value(value: _extendedCubit),
      ],
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
                // ── Quiz ────────────────────────────────────────────────────
                const SettingsGroupLabel(label: 'QUIZ'),
                SettingsCard(children: [
                  SettingsSwitchTile(
                    label: 'Make this a quiz',
                    subtitle: 'Assign point values and set correct answers',
                    value: _isQuiz,
                    isLast: true,
                    isLoading: _isQuizWorking,
                    onChanged: (isSaving || _isQuizWorking) ? null : _onQuizToggle,
                  ),
                ]),
                const SizedBox(height: 28),

                // ── Responses ───────────────────────────────────────────────
                SettingsGroupLabel(
                  label: 'RESPONSES',
                  trailing: isSaving
                      ? const CupertinoActivityIndicator(radius: 7)
                      : null,
                ),
                _ResponsesCard(
                  formId: widget.formId,
                  formTitle: context.read<QuestionsCubit>().state is QuestionsLoaded
                      ? (context.read<QuestionsCubit>().state as QuestionsLoaded).form.info.title
                      : '',
                  emailType: (settingsState as SettingsLoaded).settings.emailCollectionType,
                  isSavingBase: isSaving,
                  onEmailTypeChange: _onEmailTypeChange,
                ),
                const SizedBox(height: 28),

                // ── Presentation ────────────────────────────────────────────
                _PresentationGroup(formId: widget.formId),
                const SizedBox(height: 28),

                // ── Data ────────────────────────────────────────────────────
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

// ── Extended-settings cards (via Apps Script) ─────────────────────────────────

void _applyExtended(BuildContext context, String formId, ExtendedFormSettings patch) {
  context.read<ExtendedSettingsCubit>().apply(formId, patch);
}

/// Listener at the top of either advanced card — wired once so a save-failed
/// modal isn't shown twice if both cards rebuild.
class _ExtendedSaveFailedListener extends StatelessWidget {
  final Widget child;
  const _ExtendedSaveFailedListener({required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExtendedSettingsCubit, ExtendedSettingsState>(
      listenWhen: (prev, curr) =>
          curr is ExtendedSettingsLoaded &&
          curr.saveFailed &&
          (prev is! ExtendedSettingsLoaded || !prev.saveFailed),
      listener: (context, state) {
        context.read<ExtendedSettingsCubit>().clearSaveFailed();
        ErrorModal.show(
          context,
          title: "Couldn't save",
          body: 'That setting could not be applied. Please try again.',
          primaryLabel: 'OK',
          onPrimary: () {},
        );
      },
      child: child,
    );
  }
}

/// Error card with a tap-to-retry tile.
Widget _errorCard(BuildContext context, String formId, String message) =>
    SettingsCard(children: [
      SettingsActionTile(
        icon: CupertinoIcons.exclamationmark_triangle,
        label: message,
        isLast: true,
        onTap: () => context.read<ExtendedSettingsCubit>().load(formId),
      ),
    ]);

/// Merged RESPONSES card: email-collection dropdown + allow-editing toggle +
/// REQUIRES SIGN IN sub-header + limit-one-response toggle. Mirrors Google
/// Forms web settings layout.
class _ResponsesCard extends StatelessWidget {
  final String formId;
  final String formTitle;
  final EmailCollectionType emailType;
  final bool isSavingBase;
  final ValueChanged<EmailCollectionType> onEmailTypeChange;

  const _ResponsesCard({
    required this.formId,
    required this.formTitle,
    required this.emailType,
    required this.isSavingBase,
    required this.onEmailTypeChange,
  });

  @override
  Widget build(BuildContext context) {
    return _ExtendedSaveFailedListener(
      child: BlocBuilder<ExtendedSettingsCubit, ExtendedSettingsState>(
        builder: (context, state) {
          final emailRow = _emailRow(context);
          return switch (state) {
            ExtendedSettingsLoading() => SettingsCard(children: [
                emailRow,
                const SettingsSwitchTile(
                  label: 'Allow response editing',
                  subtitle: 'Responses can be changed after being submitted',
                  value: false,
                  isLoading: true,
                  onChanged: null,
                ),
                const SettingsSubHeader(label: 'REQUIRES SIGN IN'),
                const SettingsSwitchTile(
                  label: 'Limit to 1 response',
                  subtitle: 'Respondents will be required to sign in to Google',
                  value: false,
                  isLoading: true,
                  onChanged: null,
                ),
                const SettingsSubHeader(label: 'NOTIFICATION'),
                NotificationToggle(formId: formId, formTitle: formTitle),
              ]),
            ExtendedSettingsError(:final message) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsCard(children: [
                    SettingsDropdownTile<EmailCollectionType>(
                      label: 'Collect email addresses',
                      value: emailType,
                      valueLabel: _shortEmailLabel(emailType),
                      options: _emailOptions,
                      onChanged: isSavingBase ? null : onEmailTypeChange,
                      isLast: true,
                    ),
                  ]),
                  const SizedBox(height: 8),
                  _errorCard(context, formId, message),
                ],
              ),
            ExtendedSettingsLoaded() => _buildLoaded(context, state, emailRow),
          };
        },
      ),
    );
  }

  Widget _emailRow(BuildContext context) {
    return SettingsDropdownTile<EmailCollectionType>(
      label: 'Collect email addresses',
      value: emailType,
      valueLabel: _shortEmailLabel(emailType),
      options: _emailOptions,
      onChanged: isSavingBase ? null : onEmailTypeChange,
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    ExtendedSettingsLoaded state,
    Widget emailRow,
  ) {
    final s = state.settings;
    final saving = state.isSaving;
    return SettingsCard(children: [
      emailRow,
      SettingsSwitchTile(
        label: 'Allow response editing',
        subtitle: 'Responses can be changed after being submitted',
        value: s.allowResponseEdits ?? false,
        onChanged: saving
            ? null
            : (v) => _applyExtended(
                context, formId, ExtendedFormSettings(allowResponseEdits: v)),
      ),
      const SettingsSubHeader(label: 'REQUIRES SIGN IN'),
      SettingsSwitchTile(
        label: 'Limit to 1 response',
        subtitle: 'Respondents will be required to sign in to Google',
        value: s.limitOneResponsePerUser ?? false,
        onChanged: saving
            ? null
            : (v) => _applyExtended(context, formId,
                ExtendedFormSettings(limitOneResponsePerUser: v)),
      ),
      const SettingsSubHeader(label: 'NOTIFICATION'),
      NotificationToggle(formId: formId, formTitle: formTitle),
    ]);
  }
}

const _emailOptions = <SettingsOption<EmailCollectionType>>[
  SettingsOption(
    value: EmailCollectionType.doNotCollect,
    label: "Don't collect",
    subtitle: "Respondents won't be asked for their email",
  ),
  SettingsOption(
    value: EmailCollectionType.verified,
    label: 'Verified',
    subtitle: 'Workspace accounts only; email collected automatically',
  ),
  SettingsOption(
    value: EmailCollectionType.responderInput,
    label: 'Ask respondents',
    subtitle: 'Respondents type in their email before submitting',
  ),
];

String _shortEmailLabel(EmailCollectionType t) => switch (t) {
      EmailCollectionType.doNotCollect => "Don't collect",
      EmailCollectionType.verified => 'Verified',
      EmailCollectionType.responderInput => 'Ask respondents',
      _ => 'Not set',
    };


/// PRESENTATION group: a label plus one card with FORM PRESENTATION and
/// AFTER SUBMISSION sub-headers.
class _PresentationGroup extends StatelessWidget {
  final String formId;
  const _PresentationGroup({required this.formId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExtendedSettingsCubit, ExtendedSettingsState>(
      builder: (context, state) {
        final trailing = state is ExtendedSettingsLoaded && state.isSaving
            ? const CupertinoActivityIndicator(radius: 7)
            : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SettingsGroupLabel(label: 'PRESENTATION', trailing: trailing),
            switch (state) {
              ExtendedSettingsLoading() => SettingsCard(children: [
                  const SettingsSubHeader(label: 'FORM PRESENTATION'),
                  const SettingsSwitchTile(
                    label: 'Show progress bar',
                    value: false,
                    isLoading: true,
                    onChanged: null,
                  ),
                  const SettingsSwitchTile(
                    label: 'Shuffle question order',
                    value: false,
                    isLoading: true,
                    onChanged: null,
                  ),
                  const SettingsSubHeader(label: 'AFTER SUBMISSION'),
                  SettingsActionTile(
                    label: 'Confirmation message',
                    trailing: const Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.muted2,
                      ),
                    ),
                    onTap: null,
                  ),
                  const SettingsSwitchTile(
                    label: 'Show link to submit another response',
                    value: false,
                    isLoading: true,
                    onChanged: null,
                  ),
                  const SettingsSwitchTile(
                    label: 'View results summary',
                    subtitle: 'Share results summary with respondents',
                    value: false,
                    isLast: true,
                    isLoading: true,
                    onChanged: null,
                  ),
                ]),
              ExtendedSettingsError(:final message) =>
                _errorCard(context, formId, message),
              ExtendedSettingsLoaded() => _buildLoaded(context, state),
            },
          ],
        );
      },
    );
  }

  Widget _buildLoaded(BuildContext context, ExtendedSettingsLoaded state) {
    final s = state.settings;
    final saving = state.isSaving;
    final limitOne = s.limitOneResponsePerUser ?? false;
    final confirmation = s.confirmationMessage ?? 'Your response has been recorded.';
    return SettingsCard(children: [
      const SettingsSubHeader(label: 'FORM PRESENTATION'),
      SettingsSwitchTile(
        label: 'Show progress bar',
        value: s.progressBar ?? false,
        onChanged: saving
            ? null
            : (v) => _applyExtended(
                context, formId, ExtendedFormSettings(progressBar: v)),
      ),
      SettingsSwitchTile(
        label: 'Shuffle question order',
        value: s.shuffleQuestions ?? false,
        onChanged: saving
            ? null
            : (v) => _applyExtended(
                context, formId, ExtendedFormSettings(shuffleQuestions: v)),
      ),
      const SettingsSubHeader(label: 'AFTER SUBMISSION'),
      SettingsActionTile(
        label: 'Confirmation message',
        subtitle: confirmation,
        subtitleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.italic,
          color: AppColors.muted,
        ),
        trailing: Text(
          'Edit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: saving ? AppColors.muted2 : AppColors.purple,
          ),
        ),
        onTap: saving
            ? null
            : () => _editConfirmationMessage(context, formId, confirmation),
      ),
      SettingsSwitchTile(
        label: 'Show link to submit another response',
        subtitle:
            limitOne ? 'Disabled by Limit to 1 response' : null,
        value: limitOne ? false : (s.showLinkToRespondAgain ?? false),
        onChanged: (saving || limitOne)
            ? null
            : (v) => _applyExtended(context, formId,
                ExtendedFormSettings(showLinkToRespondAgain: v)),
      ),
      SettingsSwitchTile(
        label: 'View results summary',
        subtitle: 'Share results summary with respondents',
        value: s.publishingSummary ?? false,
        isLast: true,
        onChanged: saving
            ? null
            : (v) => _applyExtended(
                context, formId, ExtendedFormSettings(publishingSummary: v)),
      ),
    ]);
  }

  Future<void> _editConfirmationMessage(
    BuildContext context,
    String formId,
    String current,
  ) async {
    final next = await showSettingsTextEdit(
      context,
      title: 'Confirmation message',
      initial: current,
      hint: 'Your response has been recorded.',
      maxLength: 1000,
    );
    if (next == null || !context.mounted) return;
    _applyExtended(
      context,
      formId,
      ExtendedFormSettings(confirmationMessage: next),
    );
  }
}
