import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/auth/google_auth_datasource.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/generated_form.dart';
import '../../domain/entities/quota_snapshot.dart';
import '../../domain/entities/user_status.dart';
import '../../domain/repositories/ai_form_repository.dart';

const String _kBaseUrl = 'http://177.7.51.7:3002';

class PdfPageInfo {
  final int pages;
  final int quotaCost;
  final int pagesPerQuota;
  const PdfPageInfo({required this.pages, required this.quotaCost, required this.pagesPerQuota});
}

class AiFormDataSource {
  final GoogleAuthDataSource _auth;
  final http.Client _httpClient;

  AiFormDataSource({
    required GoogleAuthDataSource auth,
    http.Client? httpClient,
  })  : _auth = auth,
        _httpClient = httpClient ?? http.Client();

  Future<String> _getIdToken() => _auth.getIdToken();

  Map<String, String> _authHeaders(String idToken) => {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      };

  Future<UserStatus> getUserStatus() async {
    final idToken = await _getIdToken();
    final uri = Uri.parse('$_kBaseUrl/user/status');

    final response = await _httpClient.get(uri, headers: _authHeaders(idToken));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return UserStatus.fromJson(json);
    }

    _throwFromResponse(response);
  }

  Future<GenerateFormResult> generateForm({
    required Map<String, dynamic> requestBody,
    required String idempotencyKey,
  }) async {
    final idToken = await _getIdToken();
    final uri = Uri.parse('$_kBaseUrl/ai/generate');

    final headers = {
      ..._authHeaders(idToken),
      'Idempotency-Key': idempotencyKey,
    };

    final response = await _httpClient.post(
      uri,
      headers: headers,
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status'] as String;

      if (status != 'completed') {
        // Forward-compat guard for future async (status='pending').
        // Treat as a transient service error — server should not return this today.
        throw AiServiceFailure(code: 'gemini_unavailable');
      }

      final formJson = json['form'] as Map<String, dynamic>?;
      if (formJson == null) {
        throw AiServiceFailure(code: 'gemini_unavailable');
      }

      return GenerateFormResult(
        generationId: json['generationId'] as String,
        form: GeneratedForm.fromJson(formJson),
        quota: json['quota'] != null
            ? QuotaSnapshot.fromJson(json['quota'] as Map<String, dynamic>)
            : null,
      );
    }

    _throwFromResponse(response);
  }

  Future<PdfPageInfo> getPdfPageCount({
    required String fileBase64,
    required String inputType,
  }) async {
    final idToken = await _getIdToken();
    final uri = Uri.parse('$_kBaseUrl/ai/pdf-page-count');

    final response = await _httpClient.post(
      uri,
      headers: _authHeaders(idToken),
      body: jsonEncode({'fileBase64': fileBase64, 'inputType': inputType}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return PdfPageInfo(
        pages: (json['pages'] as num).toInt(),
        quotaCost: (json['quotaCost'] as num).toInt(),
        pagesPerQuota: (json['pagesPerQuota'] as num).toInt(),
      );
    }
    _throwFromResponse(response);
  }

  /// Parses the error envelope and throws the appropriate [Failure].
  Never _throwFromResponse(http.Response response) {
    Map<String, dynamic>? errorJson;
    try {
      errorJson = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // Non-JSON error body — treat as generic server failure.
    }

    final code = errorJson?['code'] as String? ?? '';
    final details = errorJson?['details'] as Map<String, dynamic>? ?? {};

    switch (response.statusCode) {
      case 401:
        throw const AuthFailure('Session expired.');
      case 403:
        if (code == 'premium_required') {
          throw PremiumRequiredFailure(
            requestedInputType: details['requestedInputType'] as String?,
          );
        }
        if (code == 'user_blocked') throw const UserBlockedFailure();
        throw const PermissionFailure();
      case 409:
        if (code == 'idempotency_in_flight') {
          throw const IdempotencyInFlightFailure();
        }
        if (code == 'quota_cost_changed') {
          throw AiServiceFailure(code: 'quota_cost_changed');
        }
        throw const IdempotencyConflictFailure();
      case 429:
        if (code == 'rate_limited') {
          throw RateLimitedFailure(
            retryAfterSeconds: (details['retryAfter'] as num?)?.toInt(),
          );
        }
        // quota_exceeded
        throw QuotaExceededFailure(
          tier:      details['tier']      as String? ?? 'free',
          balance:   (details['balance']  as num?)?.toInt() ?? 0,
          quotaCost: (details['quotaCost'] as num?)?.toInt() ?? 1,
        );
      case 503:
        // Known AI service error codes
        const knownCodes = {
          'gemini_unavailable',
          'gemini_timeout',
          'validation_error',
          'service_disabled',
          'service_busy',
          'daily_budget_exceeded',
          'database_unavailable',
        };
        final effectiveCode =
            knownCodes.contains(code) ? code : 'gemini_unavailable';
        throw AiServiceFailure(code: effectiveCode);
      case 400:
        // Only known 400 codes are routed through AiServiceFailure for
        // per-code modal text. Unknown codes fall through to generic4xx.
        const known400Codes = {
          'invalid_input',
          'missing_idempotency_key',
          'file_too_large',
          'unsupported_input_type',
          'url_fetch_failed',
          'youtube_unavailable',
        };
        if (known400Codes.contains(code)) throw AiServiceFailure(code: code);
        throw const PermissionFailure();
      default:
        if (response.statusCode >= 500) {
          throw AiServiceFailure(
            code: code.isNotEmpty ? code : 'gemini_unavailable',
          );
        }
        // Unknown 4xx (402, 405, 422, etc.) → generic4xx modal.
        throw const PermissionFailure();
    }
  }
}

