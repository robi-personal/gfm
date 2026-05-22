import 'dart:developer' as dev;

import 'package:googleapis/script/v1.dart' as gs;

import '../auth/google_auth_datasource.dart';
import '../models/extended_form_settings.dart';

/// Calls our deployed Apps Script project to read / write extended form
/// settings that the Forms REST API doesn't expose (shuffle questions,
/// limit one response per user, etc.).
///
/// Auth: uses the same OAuth client as `FormsClient` — the script declares
/// `forms.body` in its manifest, which we already request at sign-in. The
/// script runs *as the calling user*, so each request only mutates forms
/// the signed-in Google account can access.
class AppsScriptClient {
  AppsScriptClient(this._authService);

  // Deployment ID for the GFM Form Settings script. Not a secret —
  // execution requires a valid OAuth token covering the script's scopes.
  // Set this after deploying the Apps Script project as an API Executable.
  static const String _deploymentId = 'AKfycbwLOs9BU8zseZX-dc64MZC8nbvLNJ9b5Tzah1gbhkmfRCsIj8NLddc0g9pUBLEz2CySew';

  final GoogleAuthDataSource _authService;
  gs.ScriptApi? _api;

  gs.ScriptApi get _scriptApi {
    _api ??= gs.ScriptApi(_authService.buildAuthClient());
    return _api!;
  }

  void reset() => _api = null;

  /// Apply a partial set of extended settings. Returns the authoritative
  /// state after mutation (read back inside the script in the same call).
  Future<ExtendedFormSettings> applySettings(
    String formId,
    ExtendedFormSettings patch,
  ) async {
    final op = await _scriptApi.scripts.run(
      gs.ExecutionRequest(
        function: 'applySettings',
        parameters: [formId, patch.toJson()],
      ),
      _deploymentId,
    );
    _logOperation('applySettings', op);
    return _parseStateResult(op);
  }

  /// Read the current value of every extended setting. The Forms REST API
  /// doesn't expose these, so we go through Apps Script.
  Future<ExtendedFormSettings> readSettings(String formId) async {
    final op = await _scriptApi.scripts.run(
      gs.ExecutionRequest(
        function: 'readSettings',
        parameters: [formId],
      ),
      _deploymentId,
    );
    _logOperation('readSettings', op);
    return _parseReadResult(op);
  }

  void _logOperation(String fn, gs.Operation op) {
    dev.log(
      '$fn → done=${op.done} '
      'error=${op.error?.toJson()} '
      'response=${op.response}',
      name: 'AppsScript',
    );
  }

  // ── Result envelope handling ─────────────────────────────────────────────

  // scripts.run returns an Operation. On success the response contains a
  // result; on script-side throw, it contains an error.
  ExtendedFormSettings _parseStateResult(gs.Operation op) {
    final result = _unwrap(op);
    final state = result['state'];
    if (state is! Map) {
      throw AppsScriptException('Missing state in response');
    }
    return ExtendedFormSettings.fromJson(Map<String, dynamic>.from(state));
  }

  ExtendedFormSettings _parseReadResult(gs.Operation op) {
    final result = _unwrap(op);
    return ExtendedFormSettings.fromJson(Map<String, dynamic>.from(result));
  }

  Map<String, dynamic> _unwrap(gs.Operation op) {
    final error = op.error;
    if (error != null) {
      throw AppsScriptException(
        error.message ?? 'Apps Script error',
        code: error.code,
        details: error.details,
      );
    }
    final response = op.response;
    if (response == null) {
      throw AppsScriptException('Empty response from Apps Script');
    }
    // scripts.run wraps the function's return value in {result: ...}.
    final raw = response['result'];
    if (raw is! Map) {
      throw AppsScriptException('Apps Script returned non-object result');
    }
    return Map<String, dynamic>.from(raw);
  }
}

class AppsScriptException implements Exception {
  final String message;
  final int? code;
  final List<Map<String, Object?>>? details;

  AppsScriptException(this.message, {this.code, this.details});

  @override
  String toString() => 'AppsScriptException($code): $message';
}
