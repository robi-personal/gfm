import 'package:flutter/foundation.dart';

import 'form_info.dart';
import 'form_settings.dart';
import 'item.dart';
import 'publish_settings.dart';

/// Top-level form document. Mirrors `forms/v1/Form` from the Forms REST API.
///
/// [revisionId] is CRITICAL for optimistic concurrency — always pass it as
/// `writeControl.requiredRevisionId` on every batchUpdate call.
@immutable
class FormDoc {
  final String formId;
  final FormInfo info;
  final FormSettings settings;
  final List<Item> items;
  final String revisionId;
  final String responderUri;
  final String? linkedSheetId;
  final PublishSettings publishSettings;

  const FormDoc({
    required this.formId,
    required this.info,
    required this.settings,
    required this.items,
    required this.revisionId,
    required this.responderUri,
    this.linkedSheetId,
    required this.publishSettings,
  });

  factory FormDoc.fromJson(Map<String, dynamic> json) => FormDoc(
        formId: json['formId'] as String,
        info: FormInfo.fromJson(json['info'] as Map<String, dynamic>),
        settings: json['settings'] == null
            ? const FormSettings()
            : FormSettings.fromJson(json['settings'] as Map<String, dynamic>),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => Item.fromJson(e as Map<String, dynamic>))
            .toList(),
        revisionId: json['revisionId'] as String? ?? '',
        responderUri: json['responderUri'] as String? ?? '',
        linkedSheetId: json['linkedSheetId'] as String?,
        publishSettings: json['publishSettings'] == null
            ? const PublishSettings()
            : PublishSettings.fromJson(
                json['publishSettings'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'formId': formId,
        'info': info.toJson(),
        'settings': settings.toJson(),
        'items': items.map((i) => i.toJson()).toList(),
        'revisionId': revisionId,
        'responderUri': responderUri,
        if (linkedSheetId != null) 'linkedSheetId': linkedSheetId,
        'publishSettings': publishSettings.toJson(),
      };

  FormDoc copyWith({
    String? formId,
    FormInfo? info,
    FormSettings? settings,
    List<Item>? items,
    String? revisionId,
    String? responderUri,
    String? linkedSheetId,
    PublishSettings? publishSettings,
  }) =>
      FormDoc(
        formId: formId ?? this.formId,
        info: info ?? this.info,
        settings: settings ?? this.settings,
        items: items ?? this.items,
        revisionId: revisionId ?? this.revisionId,
        responderUri: responderUri ?? this.responderUri,
        linkedSheetId: linkedSheetId ?? this.linkedSheetId,
        publishSettings: publishSettings ?? this.publishSettings,
      );

  @override
  bool operator ==(Object other) =>
      other is FormDoc &&
      other.formId == formId &&
      other.info == info &&
      other.settings == settings &&
      listEquals(other.items, items) &&
      other.revisionId == revisionId &&
      other.responderUri == responderUri &&
      other.linkedSheetId == linkedSheetId &&
      other.publishSettings == publishSettings;

  @override
  int get hashCode => Object.hash(
        formId,
        info,
        settings,
        items,
        revisionId,
        responderUri,
        linkedSheetId,
        publishSettings,
      );
}
