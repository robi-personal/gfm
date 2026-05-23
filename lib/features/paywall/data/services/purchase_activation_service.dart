import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../../notifications/data/datasources/notifications_api.dart';
import 'subscription_service.dart';

/// Tracks the post-purchase reconciliation with the GFM backend.
///
/// The RevenueCat webhook is the eventual source of truth, but it can lag.
/// The app surfaces this state with a banner so the user understands why
/// quota hasn't appeared yet — they paid, but the backend hasn't caught up.
class PurchaseActivationService {
  PurchaseActivationService(this._api, this._subscription);

  final NotificationsApi _api;
  final SubscriptionService _subscription;

  /// `true` while a background reconciliation is in flight after a failed
  /// foreground sync. The dashboard observes this to render the banner.
  final ValueNotifier<bool> isActivating = ValueNotifier(false);

  Completer<void>? _backgroundRun;

  /// Single foreground sync attempt — awaited by the paywall cubit so the
  /// happy path (which is the common case) closes the modal in ~1 s.
  Future<bool> syncOnce() async {
    try {
      await _api.syncPurchase();
      return true;
    } catch (err, stack) {
      _recordSyncFailure(err, stack, phase: 'foreground');
      return false;
    }
  }

  /// Pre-flight check called by screens that gate on `/user/status.isPremium`.
  /// If the RC SDK on this device claims an active entitlement, runs the same
  /// reconcile dance (sync once, fall back to background retries) and returns
  /// true so the caller can refetch their status. Returns false if there's
  /// nothing to reconcile.
  Future<bool> reconcileIfClientPremium() async {
    final clientPremium = await _subscription.isPremium();
    if (!clientPremium) return false;
    final ok = await syncOnce();
    if (!ok) startBackgroundRetries();
    return true;
  }

  /// Fire-and-forget background reconciliation. Delays 5 s, 15 s, 30 s, 60 s.
  /// The webhook is still the real backstop — these retries just shrink the
  /// window during which the user sees premium without quota.
  void startBackgroundRetries() {
    if (_backgroundRun != null) return;
    final completer = Completer<void>();
    _backgroundRun = completer;
    isActivating.value = true;
    _runRetries().whenComplete(() {
      isActivating.value = false;
      _backgroundRun = null;
      completer.complete();
    });
  }

  Future<void> _runRetries() async {
    const delays = [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(minutes: 1),
    ];
    Object? lastErr;
    StackTrace? lastStack;
    for (final delay in delays) {
      await Future.delayed(delay);
      try {
        await _api.syncPurchase();
        return;
      } catch (err, stack) {
        lastErr = err;
        lastStack = stack;
      }
    }
    // All retries exhausted. The webhook is still the real backstop, but
    // record the failure so we can see if this becomes a class of bugs.
    if (lastErr != null) {
      _recordSyncFailure(lastErr, lastStack, phase: 'background_exhausted');
    }
  }

  void _recordSyncFailure(Object err, StackTrace? stack, {required String phase}) {
    FirebaseCrashlytics.instance.recordError(
      err,
      stack,
      reason: 'purchase_sync_failed',
      information: ['phase=$phase'],
      fatal: false,
    );
  }
}
