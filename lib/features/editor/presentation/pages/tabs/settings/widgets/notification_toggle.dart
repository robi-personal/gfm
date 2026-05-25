import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:googleapis/forms/v1.dart' show CloudPubsubTopic, CreateWatchRequest, Watch, WatchTarget;

import '../../../../../../../core/api/forms_client.dart';
import '../../../../../../../core/design.dart';
import '../../../../../../../core/di/injection.dart';
import '../../../../../../../core/widgets/error_modal.dart';
import '../../../../../../ai_form_builder/data/services/user_status_service.dart';
import '../../../../../../notifications/data/datasources/notifications_api.dart';
import '../../../../../../notifications/data/services/notification_service.dart';
import '../../../../../../paywall/presentation/pages/paywall_page.dart';
import '../../../../widgets/toggle_confirm_sheet.dart';

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
  bool _pushUnavailable = false;
  String? _watchId;

  static const String _topicResource = 'projects/form-manager-493310/topics/forms-responses';

  static final Map<String, ({bool isEnabled, String? watchId})> _cache = {};

  bool get _isPremium => getIt<UserStatusService>().status?.isPremium ?? false;

  @override
  void initState() {
    super.initState();
    if (_isPremium) {
      final cached = _cache[widget.formId];
      if (cached != null) {
        _loading = false;
        _isEnabled = cached.isEnabled;
        _watchId = cached.watchId;
      } else {
        _loadInitial();
      }
    } else {
      _loading = false;
    }
  }

  Future<void> _loadInitial() async {
    final pushAvailable = await getIt<NotificationService>().isPushAvailable();
    if (!mounted) return;
    if (!pushAvailable) {
      setState(() {
        _pushUnavailable = true;
        _loading = false;
      });
      return;
    }

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
    if (!_isPremium) return _lockedRow();

    final busy = _loading || _isWorking;
    final subtitle = _pushUnavailable
        ? 'Push notifications are not available on this device'
        : 'Get a push notification when this form receives a new response';
    return Opacity(
      opacity: _pushUnavailable ? 0.4 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New responses', style: AppTextStyles.body.copyWith(fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.meta),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 51,
                child: Center(
                  child: CupertinoActivityIndicator(radius: 10, color: AppColors.purple),
                ),
              )
            else
              CupertinoSwitch(
                value: _isEnabled,
                activeTrackColor: AppColors.purple,
                onChanged: _pushUnavailable ? null : _onToggle,
              ),
          ],
        ),
      ),
    );
  }

  Widget _lockedRow() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => PaywallPage.show(context),
      child: Opacity(
        opacity: 0.6,
        child: Padding(
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
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.purple600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.purple600.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/dashboard_premium.svg',
                      width: 11,
                      height: 11,
                      colorFilter: const ColorFilter.mode(AppColors.purple600, BlendMode.srcIn),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Premium',
                      style: TextStyle(
                        color: AppColors.purple600,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
