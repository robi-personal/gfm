import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:googleapis/forms/v1.dart' show CloudPubsubTopic, CreateWatchRequest, Watch, WatchTarget;
import 'package:url_launcher/url_launcher.dart';

import '../../../../../../../../core/api/forms_client.dart';
import '../../../../../../../../core/di/injection.dart';
import '../../../../../../../../core/models/enums.dart';
import '../../../../../../../../core/models/form_settings.dart';
import '../../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../../../core/usecases/usecase.dart';
import '../../../../../../../../core/widgets/error_modal.dart';
import '../../../../../../../ai_form_builder/domain/usecases/get_user_status.dart';
import '../../../../../../../notifications/data/datasources/notifications_api.dart';
import '../../../../../../../notifications/data/services/notification_service.dart';
import '../../../../../../../paywall/presentation/pages/paywall_page.dart';
import '../../../../../cubit/editor_cubit.dart';

// ── Settings tab page ─────────────────────────────────────────────────────────

class EditorSettingsTab extends StatelessWidget {
  final String formId;

  const EditorSettingsTab({super.key, required this.formId});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<EditorCubit, EditorState,
        ({FormSettings? settings, String? linkedSheetId})>(
      selector: (state) => (
        settings: state is EditorLoaded ? state.form.settings : null,
        linkedSheetId: state is EditorLoaded ? state.form.linkedSheetId : null,
      ),
      builder: (context, data) {
        if (data.settings == null) {
          return const Center(child: CupertinoActivityIndicator());
        }
        return _SettingsContent(
          initialSettings: data.settings!,
          formId: formId,
          linkedSheetId: data.linkedSheetId,
        );
      },
    );
  }
}

class _SettingsContent extends StatefulWidget {
  final FormSettings initialSettings;
  final String formId;
  final String? linkedSheetId;

  const _SettingsContent({
    required this.initialSettings,
    required this.formId,
    this.linkedSheetId,
  });

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  late EmailCollectionType _emailType;
  late bool _isQuiz;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _emailType = widget.initialSettings.emailCollectionType;
    _isQuiz = widget.initialSettings.quizSettings.isQuiz;
  }

  Future<void> _save({required EmailCollectionType emailType, required bool isQuiz}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await context.read<EditorCubit>().updateSettings(
          FormSettings(
            quizSettings: QuizSettings(isQuiz: isQuiz),
            emailCollectionType: emailType,
          ),
        );
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _onQuizToggle(bool value) async {
    if (!value) {
      bool? confirmed;
      await ErrorModal.show(
        context,
        title: 'Turn off quiz mode?',
        body: 'All answer keys and point values will be permanently removed.',
        primaryLabel: 'Turn off',
        onPrimary: () => confirmed = true,
        secondaryLabel: 'Cancel',
        onSecondary: () => confirmed = false,
      );
      if (confirmed != true) return;
    }
    setState(() => _isQuiz = value);
    await _save(emailType: _emailType, isQuiz: value);
  }

  Future<void> _onEmailTypeChange(EmailCollectionType value) async {
    setState(() => _emailType = value);
    await _save(emailType: value, isQuiz: _isQuiz);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16, 20, 16, MediaQuery.viewPaddingOf(context).bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Email collection ───────────────────────────────────────────────
          _IosGroupLabel(
            label: 'COLLECT EMAIL ADDRESSES',
            trailing: _isSaving
                ? const CupertinoActivityIndicator(radius: 7)
                : null,
          ),
          _IosCard(children: [
            _IosRadioTile(
              label: "Don't collect",
              selected: _emailType == EmailCollectionType.doNotCollect,
              onTap: _isSaving
                  ? null
                  : () => _onEmailTypeChange(EmailCollectionType.doNotCollect),
            ),
            _IosRadioTile(
              label: 'Verified (Workspace accounts only)',
              selected: _emailType == EmailCollectionType.verified,
              onTap: _isSaving
                  ? null
                  : () => _onEmailTypeChange(EmailCollectionType.verified),
            ),
            _IosRadioTile(
              label: 'Ask respondents',
              selected: _emailType == EmailCollectionType.responderInput,
              isLast: true,
              onTap: _isSaving
                  ? null
                  : () =>
                      _onEmailTypeChange(EmailCollectionType.responderInput),
            ),
          ]),
          const SizedBox(height: 28),

          // ── Quiz mode ──────────────────────────────────────────────────────
          const _IosGroupLabel(label: 'QUIZ'),
          _IosCard(children: [
            _IosSwitchTile(
              label: 'Quiz mode',
              subtitle: 'Assign point values and set correct answers',
              value: _isQuiz,
              isLast: true,
              onChanged: _isSaving ? null : _onQuizToggle,
            ),
          ]),
          const SizedBox(height: 28),

          // ── Notifications ──────────────────────────────────────────────────
          const _IosGroupLabel(label: 'NOTIFICATIONS'),
          _IosCard(children: [
            _NotificationToggle(
              formId: widget.formId,
              formTitle: context.read<EditorCubit>().state is EditorLoaded
                  ? (context.read<EditorCubit>().state as EditorLoaded).form.info.title
                  : '',
            ),
          ]),
          const SizedBox(height: 28),

          // ── Data ───────────────────────────────────────────────────────────
          // CSV export was moved to the action bar above the tabs. The DATA
          // section now only appears when there's something else to put in it
          // (currently: linked Google Sheet shortcut).
          if (widget.linkedSheetId != null) ...[
            const _IosGroupLabel(label: 'DATA'),
            _IosCard(children: [
              _IosActionTile(
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
  }
}

// ── Notification toggle (per-form push opt-in) ───────────────────────────────

class _NotificationToggle extends StatefulWidget {
  final String formId;
  final String formTitle;

  const _NotificationToggle({required this.formId, required this.formTitle});

  @override
  State<_NotificationToggle> createState() => _NotificationToggleState();
}

class _NotificationToggleState extends State<_NotificationToggle> {
  bool _loading = true;
  bool _isEnabled = false;
  bool _isWorking = false;
  String? _watchId;

  static const String _topicResource = 'projects/form-manager-493310/topics/forms-responses';

  /// Process-wide cache keyed by formId. The parent EditorCubit emits an
  /// `isSaving` state that swaps the TabBarView for a skeleton on every
  /// settings change, which tears down this widget. Without a cache,
  /// forms.watches.list would re-fire on every save. The cache is updated
  /// after enable/disable so it stays accurate.
  static final Map<String, ({bool isEnabled, String? watchId})> _cache = {};

  @override
  void initState() {
    super.initState();
    final cached = _cache[widget.formId];
    if (cached != null) {
      _loading = false;
      _isEnabled = cached.isEnabled;
      _watchId = cached.watchId;
    } else {
      _loadInitial();
    }
  }

  /// Derive the toggle state from forms.watches.list — Google is the source
  /// of truth, so this stays accurate even across reinstalls.
  Future<void> _loadInitial() async {
    try {
      final client = getIt<FormsClient>();
      final res = await client.api.forms.watches.list(widget.formId);
      final watch = res.watches?.firstWhere(
        (w) => w.eventType == 'RESPONSES' && (w.state == 'ACTIVE' || w.state == null),
        orElse: () => Watch(),
      );
      final isEnabled = watch?.id != null;
      final watchId = watch?.id;
      _cache[widget.formId] = (isEnabled: isEnabled, watchId: watchId);
      if (!mounted) return;
      setState(() {
        _isEnabled = isEnabled;
        _watchId = watchId;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _onToggle(bool value) async {
    if (_isWorking) return;

    // Premium gate (uses server as source of truth).
    final statusResult = await getIt<GetUserStatus>().call(const NoParams());
    if (!mounted) return;
    final isPremium = statusResult.fold((_) => false, (s) => s.isPremium);
    if (!isPremium) {
      await PaywallPage.show(context);
      return;
    }

    setState(() => _isWorking = true);
    try {
      if (value) {
        await _enable();
      } else {
        await _disable();
      }
    } catch (e) {
      if (!mounted) return;
      ErrorModal.show(
        context,
        title: value ? 'Could not enable notifications' : 'Could not disable notifications',
        body: e.toString(),
        primaryLabel: 'OK',
        onPrimary: () {},
      );
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _enable() async {
    // Make sure this device is registered with FCM before creating the watch —
    // in case the user dismissed the dashboard rationale earlier and never
    // granted permission. Idempotent if already registered.
    await getIt<NotificationService>().registerForUser();

    final client = getIt<FormsClient>();
    final req = CreateWatchRequest(
      watch: Watch(
        target: WatchTarget(topic: CloudPubsubTopic(topicName: _topicResource)),
        eventType: 'RESPONSES',
      ),
    );
    final created = await client.api.forms.watches.create(req, widget.formId);
    final watchId = created.id;
    final expire = created.expireTime;
    if (watchId == null || expire == null) {
      throw Exception('Forms API returned an incomplete watch object.');
    }

    await getIt<NotificationsApi>().registerWatch(
      formId: widget.formId,
      watchId: watchId,
      formTitle: widget.formTitle,
      expiresAt: DateTime.parse(expire),
    );

    _cache[widget.formId] = (isEnabled: true, watchId: watchId);
    if (!mounted) return;
    setState(() {
      _isEnabled = true;
      _watchId = watchId;
    });
  }

  Future<void> _disable() async {
    final id = _watchId;
    if (id == null) {
      _cache[widget.formId] = (isEnabled: false, watchId: null);
      if (mounted) setState(() => _isEnabled = false);
      return;
    }
    final client = getIt<FormsClient>();
    try {
      await client.api.forms.watches.delete(widget.formId, id);
    } catch (_) {
      // 404 means it was already deleted on Google's side — ignore.
    }
    await getIt<NotificationsApi>().unregisterWatch(id);
    _cache[widget.formId] = (isEnabled: false, watchId: null);
    if (!mounted) return;
    setState(() {
      _isEnabled = false;
      _watchId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _loading || _isWorking;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New responses',
                  style: AppTextStyles.body.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Get a push notification when this form receives a new response',
                  style: AppTextStyles.meta,
                ),
              ],
            ),
          ),
          if (disabled)
            const SizedBox(
              width: 51, // matches default CupertinoSwitch width so layout doesn't shift
              child: Center(
                child: CupertinoActivityIndicator(radius: 10, color: AppColors.purple),
              ),
            )
          else
            CupertinoSwitch(
              value: _isEnabled,
              activeTrackColor: AppColors.purple,
              onChanged: _onToggle,
            ),
        ],
      ),
    );
  }
}

// ── iOS settings helpers ──────────────────────────────────────────────────────

class _IosGroupLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const _IosGroupLabel({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: AppTextStyles.meta.copyWith(letterSpacing: 0.4),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _IosCard extends StatelessWidget {
  final List<Widget> children;

  const _IosCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _IosRadioTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isLast;
  final VoidCallback? onTap;

  const _IosRadioTile({
    required this.label,
    required this.selected,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(fontSize: 15),
                  ),
                ),
                if (selected)
                  const Icon(CupertinoIcons.checkmark, size: 18, color: AppColors.purple),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Divider(height: 1, color: AppColors.separator),
          ),
      ],
    );
  }
}

class _IosSwitchTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final bool isLast;
  final ValueChanged<bool>? onChanged;

  const _IosSwitchTile({
    required this.label,
    required this.value,
    this.subtitle,
    this.isLast = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.body.copyWith(fontSize: 15),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTextStyles.meta,
                      ),
                    ],
                  ],
                ),
              ),
              CupertinoSwitch(
                value: value,
                activeTrackColor: AppColors.purple,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Divider(height: 1, color: AppColors.separator),
          ),
      ],
    );
  }
}

class _IosActionTile extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Widget? trailing;
  final bool isLast;
  final VoidCallback? onTap;

  const _IosActionTile({
    this.icon,
    required this.label,
    this.trailing,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final leading = icon != null
        ? Icon(icon, size: 20, color: AppColors.purple)
        : const SizedBox(width: 20);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.body.copyWith(fontSize: 15),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 48),
            child: Divider(height: 1, color: AppColors.separator),
          ),
      ],
    );
  }
}
