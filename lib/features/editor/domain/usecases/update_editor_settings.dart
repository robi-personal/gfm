import 'package:dartz/dartz.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/models/form_settings.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/editor_repository.dart';

class UpdateSettingsParams {
  final String formId;
  final FormSettings settings;

  const UpdateSettingsParams({required this.formId, required this.settings});
}

/// Applies quiz settings and email collection type to a form.
class UpdateEditorSettings extends UseCase<void, UpdateSettingsParams> {
  final EditorRepository _repo;
  UpdateEditorSettings(this._repo);

  @override
  Future<Either<Failure, void>> call(UpdateSettingsParams params) =>
      _repo.updateSettings(params.formId, params.settings);
}
