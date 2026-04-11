import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';

/// Thin wrapper around Firebase Analytics + Crashlytics.
/// All event names are defined here — no raw strings scattered in the codebase.
class AnalyticsService {
  static final _analytics = FirebaseAnalytics.instance;
  static final _crashlytics = FirebaseCrashlytics.instance;

  // ── User identity ──────────────────────────────────────────────────────────

  static Future<void> setUser(String userId) async {
    await _analytics.setUserId(id: userId);
    await _crashlytics.setUserIdentifier(userId);
  }

  static Future<void> clearUser() async {
    await _analytics.setUserId(id: null);
    await _crashlytics.setUserIdentifier('');
  }

  // ── Screen tracking ────────────────────────────────────────────────────────

  static NavigatorObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ── Form events ────────────────────────────────────────────────────────────

  static Future<void> logFormCreated() =>
      _analytics.logEvent(name: 'form_created');

  static Future<void> logFormOpened() =>
      _analytics.logEvent(name: 'form_opened');

  static Future<void> logFormSaved() =>
      _analytics.logEvent(name: 'form_saved');

  // ── Editor item events ─────────────────────────────────────────────────────

  static Future<void> logQuestionAdded() =>
      _analytics.logEvent(name: 'question_added');

  static Future<void> logImageAdded({required String source}) =>
      _analytics.logEvent(name: 'image_added', parameters: {'source': source});

  static Future<void> logVideoAdded() =>
      _analytics.logEvent(name: 'video_added');

  // ── Responses + export ─────────────────────────────────────────────────────

  static Future<void> logResponsesViewed() =>
      _analytics.logEvent(name: 'responses_viewed');

  static Future<void> logCsvExported() =>
      _analytics.logEvent(name: 'csv_exported');
}
