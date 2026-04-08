import 'package:flutter/foundation.dart';

/// Lightweight representation of a Google Form as returned by
/// `DriveApi.files.list`. Contains only the fields requested via `$fields`.
@immutable
class DriveFormEntry {
  final String id;
  final String name;
  final DateTime? modifiedTime;
  final DateTime? createdTime;
  final String? webViewLink;

  const DriveFormEntry({
    required this.id,
    required this.name,
    this.modifiedTime,
    this.createdTime,
    this.webViewLink,
  });

  /// Build from a `googleapis File` object. Uses dynamic access so we don't
  /// need to import the entire Drive API type into every consumer.
  factory DriveFormEntry.fromDriveFile(dynamic file) => DriveFormEntry(
        id: file.id as String,
        name: (file.name as String?) ?? '(Untitled)',
        modifiedTime: file.modifiedTime as DateTime?,
        createdTime: file.createdTime as DateTime?,
        webViewLink: file.webViewLink as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is DriveFormEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
