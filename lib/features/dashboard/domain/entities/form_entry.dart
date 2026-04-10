import 'package:flutter/foundation.dart';

enum SortOrder { modifiedDesc, createdDesc }

@immutable
class FormEntry {
  final String id;
  final String name;
  final DateTime? modifiedTime;
  final DateTime? createdTime;
  final String? webViewLink;

  const FormEntry({
    required this.id,
    required this.name,
    this.modifiedTime,
    this.createdTime,
    this.webViewLink,
  });

  @override
  bool operator ==(Object other) => other is FormEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class CreateFormResult {
  final FormEntry entry;
  final bool publishFailed;

  const CreateFormResult({required this.entry, this.publishFailed = false});
}
