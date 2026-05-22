import '../../../../../../../core/models/extended_form_settings.dart';

sealed class ExtendedSettingsState {
  const ExtendedSettingsState();
}

class ExtendedSettingsLoading extends ExtendedSettingsState {
  const ExtendedSettingsLoading();
}

class ExtendedSettingsLoaded extends ExtendedSettingsState {
  final ExtendedFormSettings settings;
  final bool isSaving;
  final bool saveFailed;

  const ExtendedSettingsLoaded({
    required this.settings,
    this.isSaving = false,
    this.saveFailed = false,
  });

  ExtendedSettingsLoaded copyWith({
    ExtendedFormSettings? settings,
    bool? isSaving,
    bool? saveFailed,
  }) =>
      ExtendedSettingsLoaded(
        settings: settings ?? this.settings,
        isSaving: isSaving ?? this.isSaving,
        saveFailed: saveFailed ?? this.saveFailed,
      );
}

class ExtendedSettingsError extends ExtendedSettingsState {
  final String message;
  const ExtendedSettingsError(this.message);
}
