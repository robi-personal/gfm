import 'package:flutter/foundation.dart';

import 'item_content.dart';

/// A form item — either a question, a section break, or inert media.
/// Mirrors `forms/v1/Item` from the Forms REST API.
@immutable
class Item {
  final String itemId;
  final String? title;
  final String? description;
  final ItemContent content;

  const Item({
    required this.itemId,
    this.title,
    this.description,
    required this.content,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        itemId: json['itemId'] as String,
        title: json['title'] as String?,
        description: json['description'] as String?,
        content: ItemContent.fromJson(json),
      );

  Map<String, dynamic> toJson() {
    final contentEntry = content.toJsonEntry();
    return {
      'itemId': itemId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      contentEntry.key: contentEntry.value,
    };
  }

  Item copyWith({
    String? itemId,
    String? title,
    String? description,
    ItemContent? content,
  }) =>
      Item(
        itemId: itemId ?? this.itemId,
        title: title ?? this.title,
        description: description ?? this.description,
        content: content ?? this.content,
      );

  @override
  bool operator ==(Object other) =>
      other is Item &&
      other.itemId == itemId &&
      other.title == title &&
      other.description == description &&
      other.content == content;

  @override
  int get hashCode => Object.hash(itemId, title, description, content);
}
