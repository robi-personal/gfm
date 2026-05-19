import 'package:flutter/widgets.dart';

class EditorScope extends InheritedWidget {
  final bool readOnly;

  const EditorScope({
    super.key,
    required this.readOnly,
    required super.child,
  });

  static bool isReadOnly(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EditorScope>()?.readOnly ?? false;

  @override
  bool updateShouldNotify(EditorScope oldWidget) => readOnly != oldWidget.readOnly;
}
