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

  /// Fires when the user taps a notification and the app opens.
  /// The data map contains formId/watchId/eventType.
  final StreamController<Map<String, String>> _onTapController =
      StreamController<Map<String, String>>.broadcast();

  /// Tracks the token most recently sent to the backend so we can DELETE it
  /// on sign-out (calling getToken on a logged-out FCM instance can return null).
  String? _lastRegisteredToken;
  String? get lastRegisteredToken => _lastRegisteredToken;

  NotificationService(this._api);

  Stream<Map<String, String>> get onNotificationTap => _onTapController.stream;

  /// Call once at app startup BEFORE sign-in. Sets up local notifications
  /// channel and message listeners. Does NOT request permission here —
  /// permission is requested at sign-in time.
  Future<void> init() async {
    // Configure flutter_local_notifications. Channel "form_responses" matches
    // the channelId the backend sets in android notification payload.
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // We request permissions explicitly in [registerForUser], not here.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Payload is JSON-ish "formId=...&watchId=...&eventType=..."
        final data = _parsePayload(response.payload);
        if (data.isNotEmpty) _onTapController.add(data);
      },
    );

    // iOS only — make sure foreground notifications still show a banner.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground messages: FCM doesn't show them automatically; mirror them to
    // the local notifications plugin so the user sees a banner.
    _msgSub = FirebaseMessaging.onMessage.listen(_showLocalForForeground);

    // App was in background and the user tapped the notification.
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final data = _mapFromData(msg.data);
      if (data.isNotEmpty) _onTapController.add(data);
    });

    // App was terminated and the user tapped the notification.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      final data = _mapFromData(initial.data);
      if (data.isNotEmpty) {
        // Defer to next frame so listeners can attach.
        scheduleMicrotask(() => _onTapController.add(data));
      }
    }
  }

  /// Call after sign-in. Requests permission (if not already granted),
  /// fetches the FCM token, and registers it with our backend. Idempotent.
  Future<void> registerForUser() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[notifications] permission denied');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('[notifications] FCM token null');
        return;
      }
      await _api.registerDevice(
        fcmToken: token,
        platform: Platform.isIOS ? 'ios' : 'android',
      );
      _lastRegisteredToken = token;

      // Re-register on token refresh (FCM occasionally rotates).
      _tokenSub?.cancel();
      _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          await _api.registerDevice(
            fcmToken: newToken,
            platform: Platform.isIOS ? 'ios' : 'android',
          );
          _lastRegisteredToken = newToken;
        } catch (e) {
          debugPrint('[notifications] token refresh register failed: $e');
        }
      });
    } catch (e) {
      debugPrint('[notifications] registerForUser failed: $e');
    }
  }

  /// Call on sign-out. Unregisters the current device's token from the backend
  /// (other devices' tokens stay registered) and stops listeners.
  Future<void> unregisterForUser() async {
    try {
      final token = _lastRegisteredToken ?? await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _api.unregisterDevice(token);
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
