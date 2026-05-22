import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/auth/google_auth_datasource.dart';

const String _kBaseUrl = 'https://gfm.robi-dev.tech';

/// HTTP client for the GFM middleware push-notification endpoints.
class NotificationsApi {
  final GoogleAuthDataSource _auth;
  final http.Client _httpClient;

  NotificationsApi({
    required GoogleAuthDataSource auth,
    http.Client? httpClient,
  })  : _auth = auth,
        _httpClient = httpClient ?? http.Client();

  Future<Map<String, String>> _authHeaders() async {
    final idToken = await _auth.getIdToken();
    return {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    };
  }

  /// Register/refresh this device's FCM token.
  Future<void> registerDevice({
    required String fcmToken,
    required String platform, // 'ios' | 'android'
  }) async {
    final res = await _httpClient.post(
      Uri.parse('$_kBaseUrl/devices'),
      headers: await _authHeaders(),
      body: jsonEncode({'fcmToken': fcmToken, 'platform': platform}),
    );
    if (res.statusCode != 204) {
      throw Exception('registerDevice failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Unregister this device's FCM token (called on sign-out).
  Future<void> unregisterDevice(String fcmToken) async {
    final res = await _httpClient.delete(
      Uri.parse('$_kBaseUrl/devices/${Uri.encodeComponent(fcmToken)}'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 204 && res.statusCode != 404) {
      throw Exception('unregisterDevice failed: ${res.statusCode}');
    }
  }

  /// Store the (formId, userId) → watchId mapping after the app creates the
  /// watch via the Forms API. Premium-gated on the server.
  Future<void> registerWatch({
    required String formId,
    required String watchId,
    required String formTitle,
    required DateTime expiresAt,
  }) async {
    final res = await _httpClient.post(
      Uri.parse('$_kBaseUrl/watches'),
      headers: await _authHeaders(),
      body: jsonEncode({
        'formId': formId,
        'watchId': watchId,
        'formTitle': formTitle,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      }),
    );
    if (res.statusCode == 403) {
      throw const PremiumRequiredException();
    }
    if (res.statusCode != 204) {
      throw Exception('registerWatch failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Syncs the most recent purchase with the GFM backend so premium is
  /// reflected immediately, even if the RC webhook was delayed or missed.
  Future<void> syncPurchase() async {
    final res = await _httpClient.post(
      Uri.parse('$_kBaseUrl/user/purchase/sync'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 200) {
      throw Exception('syncPurchase failed: ${res.statusCode} ${res.body}');
    }
  }

  /// Remove the mapping after the app deletes the watch on Google's side.
  Future<void> unregisterWatch(String watchId) async {
    final res = await _httpClient.delete(
      Uri.parse('$_kBaseUrl/watches/${Uri.encodeComponent(watchId)}'),
      headers: await _authHeaders(),
    );
    if (res.statusCode != 204 && res.statusCode != 404) {
      throw Exception('unregisterWatch failed: ${res.statusCode}');
    }
  }
}

class PremiumRequiredException implements Exception {
  const PremiumRequiredException();
  @override
  String toString() => 'Premium subscription required.';
}
