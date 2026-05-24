import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin wrapper around the native iOS Method Channel that returns the
/// Apple `originalTransactionId` of the first active auto-renewable
/// subscription on this device, or null if there isn't one.
///
/// Used by the paywall pre-check to detect "this Apple ID is already
/// linked to another Google account" before initiating a new purchase.
class AppleSubscriptionChannel {
  static const _channel = MethodChannel('com.rashed.gfm/apple_subscription');

  /// Returns null on non-iOS platforms, when there's no active subscription,
  /// or on any platform error — callers should treat null as "let the
  /// purchase proceed" (fail-open).
  Future<String?> getOriginalTransactionId() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      final id = await _channel.invokeMethod<String>('getOriginalTransactionId');
      debugPrint('[apple_channel] getOriginalTransactionId → $id');
      return id;
    } on PlatformException catch (e) {
      debugPrint('[apple_channel] PlatformException: ${e.code} ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[apple_channel] unexpected error: $e');
      return null;
    }
  }
}
