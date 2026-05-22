import 'package:bloc/bloc.dart';

import '../../../../../../../../core/models/form_settings.dart';
import '../../../../../../domain/usecases/update_editor_settings.dart';
import 'settings_state.dart';

export 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final UpdateEditorSettings _updateSettings;

  SettingsCubit(this._updateSettings) : super(const SettingsLoading());

  void init(FormSettings settings) {
    emit(SettingsLoaded(settings: settings));
  }

  Future<void> updateSettings(String formId, FormSettings settings) async {
    if (state is! SettingsLoaded) return;
    final prev = state as SettingsLoaded;
    emit(SettingsLoaded(settings: settings, isSaving: true));
    final result = await _updateSettings(
      UpdateSettingsParams(formId: formId, settings: settings),
    );
    if (isClosed) return;
    result.fold(
      (_) => emit(prev.copyWith(saveFailed: true)),
      (_) => emit((state as SettingsLoaded).copyWith(isSaving: false)),
    );
  }

  void clearSaveFailed() {
    if (state is SettingsLoaded) {
      emit((state as SettingsLoaded).copyWith(saveFailed: false));
    }
  }
}
