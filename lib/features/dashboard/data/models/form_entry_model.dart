import '../../domain/entities/form_entry.dart';

class FormEntryModel extends FormEntry {
  const FormEntryModel({
    required super.id,
    required super.name,
    super.modifiedTime,
    super.createdTime,
    super.webViewLink,
  });

  factory FormEntryModel.fromDriveFile(dynamic file) => FormEntryModel(
        id: file.id as String,
        name: (file.name as String?) ?? '(Untitled)',
        modifiedTime: file.modifiedTime as DateTime?,
        createdTime: file.createdTime as DateTime?,
        webViewLink: file.webViewLink as String?,
      );
}
