import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math' show Random;

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../paywall/data/services/purchase_activation_service.dart';
import '../../domain/entities/generated_form.dart';
import '../../domain/entities/quota_snapshot.dart';
import '../../domain/entities/user_status.dart';
import '../../domain/usecases/create_form_from_ai.dart';
import '../../domain/usecases/generate_form.dart';
import '../../domain/usecases/get_user_status.dart';

part 'ai_form_builder_state.dart';

/// Drives the AI Form Builder screen.
///
/// State machine and idempotency-key lifecycle defined in
/// `docs/feature-spec-flutter.md §2`. Errors are not states — they are
/// transient side-effect events on [events] (§2.4).
class AiFormBuilderCubit extends Cubit<AiFormBuilderState> {
  final GetUserStatus _getUserStatus;
  final GenerateForm _generateForm;
  final CreateFormFromAi _createFormFromAi;
  final PurchaseActivationService _activation;

  final StreamController<AiFormBuilderEvent> _eventsController =
      StreamController<AiFormBuilderEvent>.broadcast();

  /// Side-effect events the presentation layer should observe via
  /// `BlocListener` / `StreamBuilder` to show modals or the paywall.
  Stream<AiFormBuilderEvent> get events => _eventsController.stream;

  Timer? _elapsedTimer;
  Timer? _autoRetryTimer;

  /// Current Idempotency-Key. Rotated only on the events listed in §2.3
  /// (fresh mount, post-paywall re-entry, body change, key-conflict errors).
  /// NOT rotated on retryable errors.
  String _idempotencyKey;

  /// Snapshot of the last submitted body (JSON-encoded). Used to detect
  /// "user edited the request body" between submissions.
  String? _lastSubmittedBodyJson;

  /// The exact body of the last submission, replayed by [retrySubmit].
  Map<String, dynamic>? _lastRequestBody;

  AiFormBuilderCubit({
    required GetUserStatus getUserStatus,
    required GenerateForm generateForm,
    required CreateFormFromAi createFormFromAi,
    required PurchaseActivationService activation,
  })  : _getUserStatus = getUserStatus,
        _generateForm = generateForm,
        _createFormFromAi = createFormFromAi,
        _activation = activation,
        _idempotencyKey = _generateIdempotencyKey(),
        super(const AiFormBuilderStatusLoading()) {
    loadStatus();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Fetches `/user/status`. Called on construction and after a paywall
  /// dismissal. On failure, emits an error event but stays in
  /// [AiFormBuilderStatusLoading] — the UI's modal-dismissal pops the screen.
  ///
  /// Pre-flight: if the first fetch returns `isPremium=false` but the RC SDK
  /// on this device thinks the user is premium, a missed/lagging webhook is
  /// the likely cause. Trigger one reconcile and refetch once.
  Future<void> loadStatus() async {
    if (state is! AiFormBuilderStatusLoading) {
      emit(const AiFormBuilderStatusLoading());
    }
    var result = await _getUserStatus(const NoParams());
    if (isClosed) return;

    final firstStatus = result.fold((_) => null, (s) => s);
    if (firstStatus != null && !firstStatus.isPremium) {
      final reconciled = await _activation.reconcileIfClientPremium();
      if (isClosed) return;
      if (reconciled) {
        result = await _getUserStatus(const NoParams());
        if (isClosed) return;
      }
    }

    result.fold(
      (failure) => _eventsController.add(
        ShowErrorModalEvent(
          AiErrorModalConfig(kind: _failureToErrorKind(failure)),
        ),
      ),
      (status) => emit(AiFormBuilderReady(
        status: status,
        idempotencyKey: _idempotencyKey,
      )),
    );
  }

  /// Silent refresh — fetches `/user/status` without emitting a loading state,
  /// so the UI stays interactive. Used by the inline refresh button.
  Future<void> refreshStatus() async {
    final result = await _getUserStatus(const NoParams());
    if (isClosed) return;
    result.fold(
      (_) {},
      (status) {
        final s = state;
        if (s is AiFormBuilderReady) {
          emit(s.copyWith(status: status));
        } else if (s is AiFormBuilderPreview) {
          emit(AiFormBuilderPreview(
            status: status,
            form: s.form,
            generationId: s.generationId,
            quota: s.quota,
          ));
        }
      },
    );
  }

  // ── Input selection ────────────────────────────────────────────────────────

  /// Updates the selected input type. Rotates the idempotency key per §2.3
  /// because the request body shape changes with the type.
  void setSelectedType(AiInputType type) {
    final s = state;
    if (s is! AiFormBuilderReady) return;
    if (s.selectedType == type) return;
    _rotateKey();
    emit(s.copyWith(idempotencyKey: _idempotencyKey, selectedType: type));
  }

  /// UI calls this whenever any input field is edited (prompt text, URL,
  /// file selection, etc.). Rotates the idempotency key per §2.3 — this is
  /// a "new logical attempt" once the user submits.
  void notifyRequestBodyChanged() {
    final s = state;
    if (s is! AiFormBuilderReady) return;
    _rotateKey();
    emit(s.copyWith(idempotencyKey: _idempotencyKey));
  }

  // ── Submission ─────────────────────────────────────────────────────────────

  /// Sends `POST /ai/generate` with [requestBody] and the current
  /// idempotency key.
  ///
  /// If the user is on the free tier with quota exhausted, emits
  /// [ShowPaywallEvent] instead of submitting.
  ///
  /// If the body differs from the last submitted body, the key is rotated
  /// before sending.
  Future<void> submit(Map<String, dynamic> requestBody) async {
    final s = state;
    if (s is! AiFormBuilderReady) return;

    if (!s.status.unlimited && s.status.isQuotaExhausted) {
      _eventsController.add(const ShowPaywallEvent());
      return;
    }

    final bodyJson = jsonEncode(requestBody);
    if (_lastSubmittedBodyJson != null &&
        _lastSubmittedBodyJson != bodyJson) {
      _rotateKey();
    }
    _lastSubmittedBodyJson = bodyJson;
    _lastRequestBody = requestBody;

    await _executeGenerate(s.status, s.selectedType);
  }

  /// Replays the last submission with the same idempotency key.
  /// Used by the "Try Again" CTA on retryable error modals (§2.3).
  Future<void> retrySubmit() async {
    if (_lastRequestBody == null) return;
    final s = state;
    if (s is! AiFormBuilderReady) return;
    await _executeGenerate(s.status, s.selectedType);
  }

  Future<void> _executeGenerate(
    UserStatus status,
    AiInputType selectedType,
  ) async {
    _autoRetryTimer?.cancel();

    emit(AiFormBuilderSubmitting(
      status: status,
      idempotencyKey: _idempotencyKey,
      selectedType: selectedType,
    ));
    _startElapsedTimer();

    final result = await _generateForm(GenerateFormParams(
      requestBody: _lastRequestBody!,
      idempotencyKey: _idempotencyKey,
    ));
    if (isClosed) return;
    _stopElapsedTimer();

    result.fold(
      (failure) => _handleGenerateFailure(failure, status, selectedType),
      (success) {
        final updatedStatus = success.quota != null
            ? _applyQuota(status, success.quota!)
            : status;
        emit(AiFormBuilderPreview(
          status: updatedStatus,
          form: success.form,
          generationId: success.generationId,
          quota: success.quota,
        ));
      },
    );
  }

  // ── Preview / create ───────────────────────────────────────────────────────

  /// Back from preview → Ready. Per §1.2 the idempotency key is retained
  /// so an immediate re-submit with the same body hits the server cache.
  void backFromPreview() {
    final s = state;
    if (s is! AiFormBuilderPreview) return;
    emit(AiFormBuilderReady(
      status: s.status,
      idempotencyKey: _idempotencyKey,
    ));
  }

  /// User tapped "Create Form" on the preview. Runs forms.create →
  /// setPublishSettings → batchUpdate; on success transitions to
  /// [AiFormBuilderEditorHandoff].
  Future<void> createForm() async {
    final s = state;
    if (s is! AiFormBuilderPreview) return;
    final form = s.form;
    final preview = s;

    emit(AiFormBuilderCreatingForm(form: form));

    final result = await _createFormFromAi(
      CreateFormFromAiParams(generatedForm: form),
    );
    if (isClosed) return;

    result.fold(
      (failure) {
        dev.log('[AiFormBuilderCubit] createForm failed: $failure',
            name: 'AI');
        emit(preview);
        _eventsController.add(ShowErrorModalEvent(
          AiErrorModalConfig(kind: _failureToErrorKind(failure)),
        ));
      },
      (formId) => emit(AiFormBuilderEditorHandoff(formId: formId, formTitle: form.title)),
    );
  }

  // ── Error / paywall callbacks ──────────────────────────────────────────────

  /// UI calls this after the error modal closes (any CTA). Cancels any
  /// pending auto-retry. The cubit's state was already restored by the
  /// failure handler, so nothing else is needed here.
  void dismissError() {
    _autoRetryTimer?.cancel();
  }

  /// UI calls this after `PaywallPage.show()` returns. Per §6 we re-fetch
  /// `/user/status`, and per §2.3 the idempotency key is rotated for the
  /// fresh re-entry.
  Future<void> paywallDismissed() async {
    _rotateKey();
    _lastSubmittedBodyJson = null;
    _lastRequestBody = null;
    await loadStatus();
  }

  // ── Failure handling ───────────────────────────────────────────────────────

  void _handleGenerateFailure(
    Failure failure,
    UserStatus status,
    AiInputType selectedType,
  ) {
    // 403 premium_required → paywall, no error modal (§4 / §6).
    if (failure is PremiumRequiredFailure) {
      emit(AiFormBuilderReady(
        status: status,
        idempotencyKey: _idempotencyKey,
        selectedType: selectedType,
      ));
      _eventsController.add(const ShowPaywallEvent());
      return;
    }

    final kind = _failureToErrorKind(failure);

    // Per §4: certain errors imply the current key is unrecoverable and
    // must be rotated before any retry is attempted.
    const rotateOnKinds = {
      AiErrorKind.missingIdempotencyKey,
      AiErrorKind.unsupportedInputType,
      AiErrorKind.idempotencyConflict,
    };
    if (rotateOnKinds.contains(kind)) {
      _rotateKey();
      _lastSubmittedBodyJson = null;
    }

    final config = switch (failure) {
      QuotaExceededFailure() => AiErrorModalConfig(
          kind: failure.tier == 'free'
              ? AiErrorKind.quotaExceededFree
              : AiErrorKind.quotaExceededPremium,
          quotaUsed: failure.balance,
          quotaLimit: failure.quotaCost,
        ),
      RateLimitedFailure() => AiErrorModalConfig(
          kind: AiErrorKind.rateLimited,
          retryAfterSeconds: failure.retryAfterSeconds,
        ),
      IdempotencyInFlightFailure() => const AiErrorModalConfig(
          kind: AiErrorKind.idempotencyInFlight,
          retryAfterSeconds: 1,
        ),
      _ => AiErrorModalConfig(kind: kind),
    };

    // Restore Ready before emitting the modal event (§2.4: cubit returns
    // to the underlying state, errors are not state).
    emit(AiFormBuilderReady(
      status: status,
      idempotencyKey: _idempotencyKey,
      selectedType: selectedType,
    ));

    _eventsController.add(ShowErrorModalEvent(config));

    // §4: idempotency_in_flight auto-retries after 1 second.
    if (kind == AiErrorKind.idempotencyInFlight) {
      _autoRetryTimer = Timer(const Duration(seconds: 1), () {
        if (isClosed) return;
        retrySubmit();
      });
    }
  }

  AiErrorKind _failureToErrorKind(Failure failure) {
    return switch (failure) {
      NetworkFailure() => AiErrorKind.noConnection,
      AuthFailure() => AiErrorKind.invalidToken,
      AuthCancelledFailure() => AiErrorKind.invalidToken,
      UserBlockedFailure() => AiErrorKind.userBlocked,
      IdempotencyConflictFailure() => AiErrorKind.idempotencyConflict,
      IdempotencyInFlightFailure() => AiErrorKind.idempotencyInFlight,
      QuotaExceededFailure(:final tier) => tier == 'free'
          ? AiErrorKind.quotaExceededFree
          : AiErrorKind.quotaExceededPremium, // ignore: unnecessary_cast
      RateLimitedFailure() => AiErrorKind.rateLimited,
      AiServiceFailure(:final code) => switch (code) {
          'gemini_unavailable' => AiErrorKind.geminiUnavailable,
          'gemini_timeout' => AiErrorKind.geminiTimeout,
          'validation_error' => AiErrorKind.validationError,
          'service_disabled' => AiErrorKind.serviceDisabled,
          'service_busy' => AiErrorKind.serviceBusy,
          'daily_budget_exceeded' => AiErrorKind.dailyBudgetExceeded,
          'database_unavailable' => AiErrorKind.databaseUnavailable,
          'invalid_input' => AiErrorKind.invalidInput,
          'missing_idempotency_key' => AiErrorKind.missingIdempotencyKey,
          'file_too_large' => AiErrorKind.fileTooLarge,
          'unsupported_input_type' => AiErrorKind.unsupportedInputType,
          'url_fetch_failed' => AiErrorKind.urlFetchFailed,
          'youtube_unavailable'       => AiErrorKind.youtubeUnavailable,
          'youtube_minutes_exceeded'  => AiErrorKind.youtubeMinutesExceeded,
          'quota_cost_changed'        => AiErrorKind.quotaCostChanged,
          _ => AiErrorKind.generic5xx,
        },
      PermissionFailure() => AiErrorKind.generic4xx,
      NotFoundFailure() => AiErrorKind.generic4xx,
      RevisionMismatchFailure() => AiErrorKind.generic5xx,
      ServerFailure() => AiErrorKind.generic5xx,
      PremiumRequiredFailure() => AiErrorKind.generic4xx,
    };
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _rotateKey() {
    _idempotencyKey = _generateIdempotencyKey();
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isClosed) {
        _stopElapsedTimer();
        return;
      }
      final s = state;
      if (s is AiFormBuilderSubmitting) {
        emit(s.copyWith(elapsed: s.elapsed + const Duration(seconds: 1)));
      } else {
        _stopElapsedTimer();
      }
    });
  }

  void _stopElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
  }

  /// UUIDv4 generated from `Random.secure()` — the `uuid` package is not
  /// in pubspec and this is the only place we need it.
  static String _generateIdempotencyKey() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-'
        '${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-'
        '${h.substring(20)}';
  }

  /// Folds a fresh [QuotaSnapshot] (from the `/ai/generate` 200 envelope)
  /// into the existing [UserStatus] so the Ready/Preview UI can render the
  /// updated counter without an extra `/user/status` round-trip (§3.2).
  static UserStatus _applyQuota(UserStatus current, QuotaSnapshot q) {
    return UserStatus(
      isPremium:    current.isPremium,
      quotaBalance: q.balance,
      unlimited:    q.unlimited,
      gracePeriodUntil:      current.gracePeriodUntil,
      subscriptionProductId: current.subscriptionProductId,
      youtubeMinutesUsed:    current.youtubeMinutesUsed,
      youtubeMinutesLimit:   current.youtubeMinutesLimit,
    );
  }

  @override
  Future<void> close() {
    _elapsedTimer?.cancel();
    _autoRetryTimer?.cancel();
    _eventsController.close();
    return super.close();
  }
}
