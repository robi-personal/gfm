import '../../../../../../../../core/models/form_settings.dart';

sealed class SettingsState {
  const SettingsState();
}

class SettingsLoading extends SettingsState {
  const SettingsLoading();
}

class SettingsLoaded extends SettingsState {
  final FormSettings settings;
  final bool isSaving;
  final bool saveFailed;

  const SettingsLoaded({
    required this.settings,
    this.isSaving = false,
    this.saveFailed = false,
  });

  SettingsLoaded copyWith({
    FormSettings? settings,
    bool? isSaving,
    bool? saveFailed,
  }) =>
      SettingsLoaded(
        settings: settings ?? this.settings,
        isSaving: isSaving ?? this.isSaving,
        saveFailed: saveFailed ?? this.saveFailed,
      );
}
