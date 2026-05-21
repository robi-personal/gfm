import 'dart:convert';

import 'package:googleapis/drive/v3.dart';

import '../../../../core/api/drive_client.dart';
import '../../domain/entities/form_entry.dart';
import '../models/form_entry_model.dart';

const _kAppDataFileName = 'gfm_data.json';

/// Reference to a form the user imported from outside the app's
/// `drive.file` scope. [importedAt] is the time the user added it; the Forms
/// API doesn't expose the form's real created/modified time without a wider
/// Drive scope, so we use this as a stand-in for sort ordering.
typedef ImportedFormRef = ({String id, DateTime? importedAt});

class DriveDataSource {
  final DriveClient _client;
  String? _appDataFileId;

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
      $fields: 'files(id,name,modifiedTime,createdTime,webViewLink,ownedByMe)',
    );

    return (result.files ?? []).map(FormEntryModel.fromDriveFile).toList();
  }

  Future<void> trashFile(String fileId) async {
    await _client.api.files.update(File()..trashed = true, fileId);
  }

  Future<void> renameFile(String fileId, String name) async {
    await _client.api.files.update(File()..name = name, fileId);
  }

  // ── App data (imported forms list) ─────────────────────────────────────────

  /// Reads imported form refs from the app-data file. Accepts both the legacy
  /// `["formId", ...]` string-array format and the current
  /// `[{"id": "...", "importedAt": "..."}, ...]` object format. Legacy entries
  /// surface with [ImportedFormRef.importedAt] = null and get persisted in the
  /// new shape on the next write.
  Future<List<ImportedFormRef>> readImportedForms() async {
    final fileId = await _findAppDataFileId();
    if (fileId == null) return [];
    try {
      final media = await _client.api.files.get(
        fileId,
        downloadOptions: DownloadOptions.fullMedia,
      ) as Media;
      final bytes = await media.stream
          .fold<List<int>>([], (buf, chunk) => buf..addAll(chunk));
      final json =
          jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final raw = json['importedForms'] as List<dynamic>? ?? [];
      return raw
          .map<ImportedFormRef?>((entry) {
            if (entry is String) {
              return (id: entry, importedAt: null);
            }
            if (entry is Map<String, dynamic>) {
              final id = entry['id'] as String?;
              if (id == null) return null;
              final tsStr = entry['importedAt'] as String?;
              final ts = tsStr != null ? DateTime.tryParse(tsStr) : null;
              return (id: id, importedAt: ts);
            }
            return null;
          })
          .whereType<ImportedFormRef>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> writeImportedForms(List<ImportedFormRef> refs) async {
    final payload = {
      'importedForms': refs
          .map((r) => {
                'id': r.id,
                if (r.importedAt != null)
                  'importedAt': r.importedAt!.toUtc().toIso8601String(),
              })
          .toList(),
    };
    final bytes = utf8.encode(jsonEncode(payload));
    // Stream.value is single-subscription — create a fresh Media for each
    // upload attempt so the stream isn't already consumed on the retry path.
    Media buildMedia() => Media(
          Stream.value(bytes),
          bytes.length,
          contentType: 'application/json',
        );

    final existingId = await _findAppDataFileId();
    if (existingId != null) {
      try {
        await _client.api.files.update(File(), existingId, uploadMedia: buildMedia());
        return;
      } on DetailedApiRequestError catch (e) {
        if (e.status != 404) rethrow;
        // Cached file was deleted externally — clear cache and recreate below.
        _appDataFileId = null;
      }
    }

    final created = await _client.api.files.create(
      File()
        ..name = _kAppDataFileName
        ..mimeType = 'application/json',
      uploadMedia: buildMedia(),
    );
    _appDataFileId = created.id;
  }

  Future<String?> _findAppDataFileId() async {
    if (_appDataFileId != null) return _appDataFileId;
    final result = await _client.api.files.list(
      q: "name='$_kAppDataFileName' and trashed=false",
      $fields: 'files(id)',
      spaces: 'drive',
    );
    _appDataFileId = result.files?.firstOrNull?.id;
    return _appDataFileId;
  }
}
