import 'package:bloc/bloc.dart';

import '../../../../../../../core/api/apps_script_client.dart';
import '../../../../../../../core/models/extended_form_settings.dart';
import 'extended_settings_state.dart';

export 'extended_settings_state.dart';

class ExtendedSettingsCubit extends Cubit<ExtendedSettingsState> {
  final AppsScriptClient _client;

  ExtendedSettingsCubit(this._client) : super(const ExtendedSettingsLoading());

  Future<void> load(String formId) async {
    emit(const ExtendedSettingsLoading());
    try {
      final settings = await _client.readSettings(formId);
      if (isClosed) return;
      emit(ExtendedSettingsLoaded(settings: settings));
    } catch (e) {
      if (isClosed) return;
      emit(ExtendedSettingsError(_friendlyError(e)));
    }
  }

  /// Optimistic apply: emit the patched view, send to Apps Script, roll back
  /// on failure. The script returns authoritative state, so on success we
  /// replace local with what Google confirmed.
  Future<void> apply(String formId, ExtendedFormSettings patch) async {
    final current = state;
    if (current is! ExtendedSettingsLoaded) return;
    final optimistic = _merge(current.settings, patch);
    emit(current.copyWith(settings: optimistic, isSaving: true));
    try {
      final confirmed = await _client.applySettings(formId, patch);
      if (isClosed) return;
      emit(ExtendedSettingsLoaded(settings: confirmed));
    } catch (_) {
      if (isClosed) return;
      emit(current.copyWith(saveFailed: true, isSaving: false));
    }
  }

  void clearSaveFailed() {
    final s = state;
    if (s is ExtendedSettingsLoaded) {
      emit(s.copyWith(saveFailed: false));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  ExtendedFormSettings _merge(ExtendedFormSettings base, ExtendedFormSettings patch) =>
      ExtendedFormSettings(
        shuffleQuestions:        patch.shuffleQuestions        ?? base.shuffleQuestions,
        limitOneResponsePerUser: patch.limitOneResponsePerUser ?? base.limitOneResponsePerUser,
        allowResponseEdits:      patch.allowResponseEdits      ?? base.allowResponseEdits,
        progressBar:             patch.progressBar             ?? base.progressBar,
        showLinkToRespondAgain:  patch.showLinkToRespondAgain  ?? base.showLinkToRespondAgain,
        publishingSummary:       patch.publishingSummary       ?? base.publishingSummary,
        requireLogin:            patch.requireLogin            ?? base.requireLogin,
        confirmationMessage:     patch.confirmationMessage     ?? base.confirmationMessage,
        customClosedFormMessage: patch.customClosedFormMessage ?? base.customClosedFormMessage,
      );

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('PERMISSION_DENIED') || msg.contains('Authorization is required')) {
      return 'This form needs to be re-authorized. Sign out and in again.';
    }
    if (msg.contains('NOT_FOUND') || msg.contains('Requested entity was not found')) {
      return 'Form not found.';
    }
    return 'Could not load advanced settings. Tap to retry.';
  }
}
