import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/forms/v1.dart' show CloudPubsubTopic, CreateWatchRequest, Watch, WatchTarget;

import '../../../../../../../core/api/forms_client.dart';
import '../../../../../../../core/di/injection.dart';
import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/theme/app_text_styles.dart';
import '../../../../../../../core/usecases/usecase.dart';
import '../../../../../../../core/widgets/error_modal.dart';
import '../../../../../../ai_form_builder/domain/usecases/get_user_status.dart';
import '../../../../../../notifications/data/datasources/notifications_api.dart';
import '../../../../../../notifications/data/services/notification_service.dart';
import '../../../../../../paywall/presentation/pages/paywall_page.dart';
import 'toggle_confirm_sheet.dart';

class NotificationToggle extends StatefulWidget {
  final String formId;
  final String formTitle;

  const NotificationToggle({super.key, required this.formId, required this.formTitle});

  @override
  State<NotificationToggle> createState() => _NotificationToggleState();
}

class _NotificationToggleState extends State<NotificationToggle> {
  bool _loading = true;
  bool _isEnabled = false;
  bool _isWorking = false;
  String? _watchId;

  static const String _topicResource = 'projects/form-manager-493310/topics/forms-responses';

  /// Process-wide cache keyed by formId. Without a cache, forms.watches.list
  /// would re-fire whenever this widget is torn down and rebuilt (e.g. after a
  /// settings save). Updated after each enable/disable to stay accurate.
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

  /// Derives toggle state from forms.watches.list — Google is the source of
  /// truth, so this stays accurate even across reinstalls.
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

    final confirmed = await showToggleConfirmSheet(
      context,
      icon: value ? CupertinoIcons.bell : CupertinoIcons.bell_slash,
      title: value ? 'Enable Notifications' : 'Turn Off Notifications',
      subtitle: 'New responses',
      body: value
          ? 'Get a push notification whenever this form receives a new response.'
          : "You'll stop receiving push notifications for this form.",
      continueLabel: value ? 'Enable' : 'Turn off',
    );
    if (confirmed != true || !mounted) return;

    // Premium gate — uses server as source of truth.
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
    // Registers device with FCM first — idempotent if already registered.
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
      // 404 means already deleted on Google's side — ignore.
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
                Text('New responses', style: AppTextStyles.body.copyWith(fontSize: 15)),
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
              width: 51, // matches CupertinoSwitch width to prevent layout shift
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
