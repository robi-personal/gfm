part of 'ai_form_builder_cubit.dart';

// ── Input type selection ──────────────────────────────────────────────────────

/// Maps 1:1 to the `inputType` field of `POST /ai/generate` per
/// `docs/api-contract.md §3`.
enum AiInputType { text, pdf, youtube, urls, book }

// ── Error → Modal mapping ─────────────────────────────────────────────────────

/// Discriminator for the modal config the UI renders. One value per row of
/// `docs/feature-spec-flutter.md §4`.
enum AiErrorKind {
  invalidInput,
  missingIdempotencyKey,
  fileTooLarge,
  unsupportedInputType,
  urlFetchFailed,
  youtubeUnavailable,
  youtubeMinutesExceeded,
  quotaCostChanged,
  invalidToken,
  userBlocked,
  idempotencyConflict,
  idempotencyInFlight,
  quotaExceededFree,
  quotaExceededPremium,
  rateLimited,
  geminiUnavailable,
  geminiTimeout,
  validationError,
  serviceDisabled,
  serviceBusy,
  dailyBudgetExceeded,
  databaseUnavailable,
  noConnection,
  generic4xx,
  generic5xx,
}

@immutable
class AiErrorModalConfig {
  final AiErrorKind kind;
  final int? retryAfterSeconds;
  final DateTime? resetsAt;
  final int? quotaUsed;
  final int? quotaLimit;

  const AiErrorModalConfig({
    required this.kind,
    this.retryAfterSeconds,
    this.resetsAt,
    this.quotaUsed,
    this.quotaLimit,
  });
}

// ── Cubit states ──────────────────────────────────────────────────────────────

sealed class AiFormBuilderState {
  const AiFormBuilderState();
}

/// `/user/status` request in flight (initial state on cubit construction).
class AiFormBuilderStatusLoading extends AiFormBuilderState {
  const AiFormBuilderStatusLoading();
}

/// Idle screen — waiting for user input. Returned to after a request fails
/// or after the user backs out of preview.
class AiFormBuilderReady extends AiFormBuilderState {
  final UserStatus status;
  final String idempotencyKey;
  final AiInputType selectedType;

  const AiFormBuilderReady({
    required this.status,
    required this.idempotencyKey,
    this.selectedType = AiInputType.text,
  });

  AiFormBuilderReady copyWith({
    UserStatus? status,
    String? idempotencyKey,
    AiInputType? selectedType,
  }) =>
      AiFormBuilderReady(
        status: status ?? this.status,
        idempotencyKey: idempotencyKey ?? this.idempotencyKey,
        selectedType: selectedType ?? this.selectedType,
      );
}

/// `/ai/generate` request in flight. UI shows the loading spinner with a
/// label that switches at 8s and 20s based on [elapsed] (per §5).
class AiFormBuilderSubmitting extends AiFormBuilderState {
  final UserStatus status;
  final String idempotencyKey;
  final AiInputType selectedType;
  final Duration elapsed;

  const AiFormBuilderSubmitting({
    required this.status,
    required this.idempotencyKey,
    required this.selectedType,
    this.elapsed = Duration.zero,
  });

  AiFormBuilderSubmitting copyWith({Duration? elapsed}) =>
      AiFormBuilderSubmitting(
        status: status,
        idempotencyKey: idempotencyKey,
        selectedType: selectedType,
        elapsed: elapsed ?? this.elapsed,
      );
}

/// `/ai/generate` returned 200 status=completed. UI shows the AI-generated
/// form for the user to confirm before creation.
class AiFormBuilderPreview extends AiFormBuilderState {
  final UserStatus status;
  final GeneratedForm form;
  final String generationId;
  final QuotaSnapshot? quota;

  const AiFormBuilderPreview({
    required this.status,
    required this.form,
    required this.generationId,
    this.quota,
  });
}

/// User tapped "Create Form" on the preview. `forms.create` +
/// `setPublishSettings` + `batchUpdate` calls in flight.
class AiFormBuilderCreatingForm extends AiFormBuilderState {
  final GeneratedForm form;

  const AiFormBuilderCreatingForm({required this.form});
}

/// Transient terminal state — UI's BlocListener observes this and pushes
/// the editor for [formId], replacing the AI builder route.
class AiFormBuilderEditorHandoff extends AiFormBuilderState {
  final String formId;

  const AiFormBuilderEditorHandoff({required this.formId});
}

// ── Side-effect events ────────────────────────────────────────────────────────

sealed class AiFormBuilderEvent {
  const AiFormBuilderEvent();
}

/// Emitted when an error needs to be shown to the user. The cubit has
/// already restored the underlying state — the UI just needs to render
/// the modal and dispatch dismissal back to the cubit.
class ShowErrorModalEvent extends AiFormBuilderEvent {
  final AiErrorModalConfig config;
  const ShowErrorModalEvent(this.config);
}

/// Emitted when the paywall should be presented. The UI calls
/// `paywallDismissed()` after the paywall closes (subscribed or not).
class ShowPaywallEvent extends AiFormBuilderEvent {
  const ShowPaywallEvent();
}
