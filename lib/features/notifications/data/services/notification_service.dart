import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../datasources/notifications_api.dart';

/// Central FCM + local notifications lifecycle for the app.
///
/// Responsibilities:
///   • request notification permission on first sign-in
///   • fetch the FCM device token and register it with the backend
///   • re-register on token refresh
///   • show foreground notifications via flutter_local_notifications
///     (FCM only auto-shows them in background/terminated state)
///   • surface tapped-notification payloads via [onMessageOpenedApp]
class NotificationService {
  final NotificationsApi _api;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _msgSub;
  StreamSubscription<RemoteMessage>? _openedSub;
  bool _registering = false;


  /// Fires when the user taps a notification and the app opens.
  /// The data map contains formId/watchId/eventType.
  final StreamController<Map<String, String>> _onTapController =
      StreamController<Map<String, String>>.broadcast();

  /// Holds a tap event that fired before any listener attached (typically
  /// from a terminated-app launch). Replayed to the first subscriber.
  Map<String, String>? _pendingInitialTap;

  /// Tracks the token most recently sent to the backend so we can DELETE it
  /// on sign-out (calling getToken on a logged-out FCM instance can return null).
  String? _lastRegisteredToken;
  String? get lastRegisteredToken => _lastRegisteredToken;

  NotificationService(this._api);

  /// Emits notification-tap events. The first listener will receive any
  /// pending initial tap (from a terminated-app launch) as soon as it
  /// subscribes; subsequent events come live from the broadcast controller.
  Stream<Map<String, String>> get onNotificationTap {
    return Stream.multi((controller) {
      if (_pendingInitialTap != null) {
        controller.add(_pendingInitialTap!);
        _pendingInitialTap = null;
      }
      final sub = _onTapController.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = () => sub.cancel();
    });
  }

  /// Call once at app startup BEFORE sign-in. Sets up local notifications
  /// channel and message listeners. Does NOT request permission here —
  /// permission is requested at sign-in time. Best-effort: any individual
  /// failure is swallowed so a single broken step can't block init().
  Future<void> init() async {
    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _local.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          final data = _parsePayload(response.payload);
          if (data.isNotEmpty) _onTapController.add(data);
        },
      );
    } catch (e) {
      debugPrint('[notifications] _local.initialize failed: $e');
    }

    try {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('[notifications] setForegroundNotificationPresentationOptions failed: $e');
    }

    _msgSub = FirebaseMessaging.onMessage.listen(_showLocalForForeground);
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final data = _mapFromData(msg.data);
      if (data.isNotEmpty) _onTapController.add(data);
    });

    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        final data = _mapFromData(initial.data);
        if (data.isNotEmpty) {
          // Buffer until the dashboard listener attaches (sign-in completes).
          _pendingInitialTap = data;
        }
      }
    } catch (e) {
      debugPrint('[notifications] getInitialMessage failed: $e');
    }
  }

  /// Returns true if the device can receive push notifications.
  /// On iOS this requires the APNs token to be available; on Android always true.
  Future<bool> isPushAvailable() async {
    if (!Platform.isIOS) return true;
    try {
      return await FirebaseMessaging.instance.getAPNSToken() != null;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if the platform permission state is "notDetermined" — i.e.,
  /// the user has never been asked. UI should show a soft-ask rationale before
  /// calling [registerForUser]. iOS HIG and Android 13+ both recommend this.
  Future<bool> shouldShowRationale() async {
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.notDetermined;
    } catch (_) {
      return false;
    }
  }

  /// Call after sign-in. Requests permission, then registers the device
  /// with our backend once the FCM token is available. If the token is not
  /// ready yet (iOS APNs handshake still in progress), [onTokenRefresh]
  /// will fire when it arrives and register at that point.
  Future<void> registerForUser() async {
    if (_lastRegisteredToken != null) return;
    if (_registering) return;
    _registering = true;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      // Subscribe BEFORE getToken so we never miss a token that arrives later.
      _tokenSub?.cancel();
      _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
    } catch (e) {
      debugPrint('[notifications] registerForUser failed: $e');
    } finally {
      _registering = false;
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await _api.registerDevice(
        fcmToken: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      _lastRegisteredToken = token;
    } catch (e) {
      debugPrint('[notifications] backend register failed: $e');
    }
  }

  /// Schedules permanent account deletion on the backend, then returns so the
  /// caller can sign out. Throws on failure — caller handles the error.
  Future<void> deleteAccount() => _api.deleteAccount();

  /// Call on sign-out. Unregisters the current device's token from the backend
  /// (other devices' tokens stay registered) and stops listeners.
  ///
  /// Pass `skipBackend: true` to skip the HTTP unregister call. Used on the
  /// account-deletion sign-out path: the backend unregister request would
  /// otherwise trigger the auth middleware's cancel-pending-deletion side
  /// effect and silently undo the deletion request that was just inserted.
  Future<void> unregisterForUser({bool skipBackend = false}) async {
    try {
      if (!skipBackend) {
        final token = _lastRegisteredToken ?? await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await _api.unregisterDevice(token);
        }
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[notifications] unregisterForUser failed: $e');
    } finally {
      _lastRegisteredToken = null;
      await _tokenSub?.cancel();
      _tokenSub = null;
    }
  }

  Future<void> _showLocalForForeground(RemoteMessage msg) async {
    final n = msg.notification;
    if (n == null) return;
    // iOS handles foreground presentation natively via willPresent in AppDelegate.
    // flutter_local_notifications is only needed on Android, where FCM does not
    // auto-display notifications while the app is in the foreground.
    if (Platform.isIOS) return;
    await _local.show(
      msg.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'form_responses',
          'Form Responses',
          channelDescription: 'New responses to your Google Forms',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _encodePayload(msg.data),
    );
  }

  // ── Payload helpers ──────────────────────────────────────────────────────

  String _encodePayload(Map<String, dynamic> data) {
    final entries = data.entries
        .where((e) => e.value is String)
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value as String)}');
    return entries.join('&');
  }

  Map<String, String> _parsePayload(String? payload) {
    if (payload == null || payload.isEmpty) return const {};
    final out = <String, String>{};
    for (final part in payload.split('&')) {
      final eq = part.indexOf('=');
      if (eq <= 0) continue;
      out[part.substring(0, eq)] = Uri.decodeComponent(part.substring(eq + 1));
    }
    return out;
  }

  Map<String, String> _mapFromData(Map<String, dynamic> data) {
    final out = <String, String>{};
    data.forEach((k, v) {
      if (v is String) out[k] = v;
    });
    return out;
  }

  Future<void> dispose() async {
    await _tokenSub?.cancel();
    await _msgSub?.cancel();
    await _openedSub?.cancel();
    await _onTapController.close();
  }
}
