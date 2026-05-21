import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the in-app WebView's Google session aligned with the app's
/// signed-in account.
///
/// The import flow and the file-upload edit flow both load Google web pages
/// in [InAppWebView], which keeps its own cookie/storage jar — completely
/// independent of the native Google Sign-In token. Without this, a sign-out
/// followed by a sign-in as a different account would leave the previous
/// user's Google session intact, so User B opening Import would see User A's
/// Drive forms.
///
/// Strategy: on every sign-in success (silent or interactive), compare the
/// current Google `sub` against the one we associated with the WebView last
/// time. If different, wipe cookies/storage/cache. Always persist the current
/// sub so the next launch has a baseline to compare against.
///
/// Sign-out intentionally does NOT clear, so "sign out → sign back in as
/// the same account" preserves the WebView session.
class WebViewSessionManager {
  static const _kLastSubKey = 'gfm_webview_last_sub';

  final FlutterSecureStorage _storage;

  WebViewSessionManager({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Compare the current user against the previously remembered one;
  /// clear the WebView's Google session on mismatch; record the new sub.
  /// Awaited before emitting Authenticated so the dashboard never renders
  /// while a clear is still in flight.
  Future<void> syncWithUser(String currentGoogleSub) async {
    try {
      final stored = await _storage.read(key: _kLastSubKey);
      if (stored != null && stored != currentGoogleSub) {
        await _clearAll();
      }
      await _storage.write(key: _kLastSubKey, value: currentGoogleSub);
    } catch (e) {
      debugPrint('[webview-session] syncWithUser failed: $e');
    }
  }

  Future<void> _clearAll() async {
    try {
      await CookieManager.instance().deleteAllCookies();
    } catch (e) {
      debugPrint('[webview-session] deleteAllCookies failed: $e');
    }
    try {
      await WebStorageManager.instance().deleteAllData();
    } catch (e) {
      debugPrint('[webview-session] deleteAllData failed: $e');
    }
    try {
      await InAppWebViewController.clearAllCache();
    } catch (e) {
      debugPrint('[webview-session] clearAllCache failed: $e');
    }
  }
}
