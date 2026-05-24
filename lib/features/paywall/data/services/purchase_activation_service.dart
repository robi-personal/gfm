import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../../notifications/data/datasources/notifications_api.dart';
import 'apple_subscription_channel.dart';
import 'subscription_service.dart';

/// Tracks the post-purchase reconciliation with the GFM backend.
///
/// The RevenueCat webhook is the eventual source of truth, but it can lag.
/// The app surfaces this state with a banner so the user understands why
/// quota hasn't appeared yet — they paid, but the backend hasn't caught up.
class PurchaseActivationService {
  PurchaseActivationService(this._api, this._subscription, this._appleChannel);

  final NotificationsApi _api;
  final SubscriptionService _subscription;
  final AppleSubscriptionChannel _appleChannel;

  /// `true` while a background reconciliation is in flight after a failed
  /// foreground sync. The dashboard observes this to render the banner.
  final ValueNotifier<bool> isActivating = ValueNotifier(false);

  Completer<void>? _backgroundRun;

  /// Single foreground sync attempt — awaited by the paywall cubit so the
  /// happy path (which is the common case) closes the modal in ~1 s.
  Future<bool> syncOnce() async {
    debugPrint('[purchase] syncOnce start');
    try {
      await _api.syncPurchase();
      debugPrint('[purchase] syncOnce success');
      return true;
    } catch (err, stack) {
      debugPrint('[purchase] syncOnce failed: $err');
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
    debugPrint('[purchase] reconcileIfClientPremium start');
    final clientPremium = await _subscription.isPremium();
    debugPrint('[purchase] reconcileIfClientPremium — clientPremium=$clientPremium');
    if (!clientPremium) return false;
    final ok = await syncOnce();
    if (!ok) startBackgroundRetries();
    return true;
  }

  /// Pre-purchase check: returns false + a message if the Apple ID on this
  /// device already has a subscription bound to a different Google account.
  /// Fails open (allowed:true) on any error so connectivity issues never
  /// block a legitimate purchase. If StoreKit reports no active subscription
  /// on the device, skips the API call entirely.
  Future<({bool allowed, String? message})> checkAppleBinding() async {
    final txId = await _appleChannel.getOriginalTransactionId();
    if (txId == null) {
      debugPrint('[purchase] checkAppleBinding — no active sub on device, allowed');
      return (allowed: true, message: null);
    }
    try {
      final result = await _api.checkAppleSubscription(txId);
      debugPrint('[purchase] checkAppleBinding — server says allowed=${result.allowed}');
      return result;
    } catch (err, stack) {
      debugPrint('[purchase] checkAppleBinding failed (proceeding): $err');
      _recordSyncFailure(err, stack, phase: 'apple_binding_check');
      return (allowed: true, message: null);
    }
  }

  /// Fire-and-forget background reconciliation. Delays 5 s, 15 s, 30 s, 60 s.
  /// The webhook is still the real backstop — these retries just shrink the
  /// window during which the user sees premium without quota.
  void startBackgroundRetries() {
    if (_backgroundRun != null) {
      debugPrint('[purchase] startBackgroundRetries — already running, skipped');
      return;
    }
    debugPrint('[purchase] startBackgroundRetries — starting');
    final completer = Completer<void>();
    _backgroundRun = completer;
    isActivating.value = true;
    _runRetries().whenComplete(() {
      isActivating.value = false;
      _backgroundRun = null;
      completer.complete();
      debugPrint('[purchase] background retries finished');
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
    for (final (i, delay) in delays.indexed) {
      debugPrint('[purchase] retry ${i + 1}/${delays.length} — waiting ${delay.inSeconds}s');
      await Future.delayed(delay);
      try {
        await _api.syncPurchase();
        debugPrint('[purchase] retry ${i + 1} success');
        return;
      } catch (err, stack) {
        debugPrint('[purchase] retry ${i + 1} failed: $err');
        lastErr = err;
        lastStack = stack;
      }
    }
    // All retries exhausted. The webhook is still the real backstop, but
    // record the failure so we can see if this becomes a class of bugs.
    debugPrint('[purchase] all retries exhausted');
    if (lastErr != null) {
      _recordSyncFailure(lastErr, lastStack, phase: 'background_exhausted');
    }
  }

  void _recordSyncFailure(Object err, StackTrace? stack, {required String phase}) {
    debugPrint('[purchase] _recordSyncFailure phase=$phase err=$err');
    FirebaseCrashlytics.instance.recordError(
      err,
      stack,
      reason: 'purchase_sync_failed',
      information: ['phase=$phase'],
      fatal: false,
    );
  }
}
