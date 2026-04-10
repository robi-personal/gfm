import 'package:googleapis/drive/v3.dart' show File;

import '../../../../core/api/drive_client.dart';
import '../../domain/entities/form_entry.dart';
import '../models/form_entry_model.dart';

class DriveDataSource {
  final DriveClient _client;

  DriveDataSource(this._client);

  Future<List<FormEntry>> listForms({
    String query = '',
    String orderBy = 'modifiedTime desc',
  }) async {
    final q = StringBuffer(
        "mimeType='application/vnd.google-apps.form' and trashed=false");
    if (query.isNotEmpty) {
      final escaped = query.replaceAll("'", "\\'");
      q.write(" and name contains '$escaped'");
    }

    final result = await _client.api.files.list(
      q: q.toString(),
      orderBy: orderBy,
      $fields: 'files(id,name,modifiedTime,createdTime,webViewLink)',
    );

    return (result.files ?? []).map(FormEntryModel.fromDriveFile).toList();
  }

  Future<void> trashFile(String fileId) async {
    await _client.api.files.update(File()..trashed = true, fileId);
  }
}
