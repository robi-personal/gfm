import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../../../core/models/enums.dart';
import 'settings_tiles.dart';
import '../../../../widgets/toggle_confirm_sheet.dart';

class EmailCollectionCard extends StatefulWidget {
  final EmailCollectionType emailType;
  final bool isSaving;
  final ValueChanged<EmailCollectionType> onChanged;

  const EmailCollectionCard({
    super.key,
    required this.emailType,
    required this.isSaving,
    required this.onChanged,
  });

  @override
  State<EmailCollectionCard> createState() => _EmailCollectionCardState();
}

class _EmailCollectionCardState extends State<EmailCollectionCard> {
  late EmailCollectionType _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.emailType;
  }

  @override
  void didUpdateWidget(EmailCollectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.emailType != widget.emailType) {
      _selected = widget.emailType;
    }
  }

  Future<void> _onTap(EmailCollectionType value) async {
    if (widget.isSaving || value == _selected) return;
    final confirmed = await showToggleConfirmSheet(
      context,
      icon: CupertinoIcons.envelope,
      title: _sheetTitle(value),
      subtitle: 'Collect Email Addresses',
      body: _sheetBody(value),
      continueLabel: 'Update',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _selected = value);
    widget.onChanged(value);
  }

  String _sheetTitle(EmailCollectionType type) => switch (type) {
        EmailCollectionType.doNotCollect => "Don't Collect Emails",
        EmailCollectionType.verified => 'Verified Emails Only',
        EmailCollectionType.responderInput => 'Ask for Email Address',
        _ => 'Change Email Setting',
      };

  String _sheetBody(EmailCollectionType type) => switch (type) {
        EmailCollectionType.doNotCollect =>
          "Respondents won't be asked for their email address. This applies to all future submissions.",
        EmailCollectionType.verified =>
          'Only Workspace account holders can respond, and their email will be collected automatically.',
        EmailCollectionType.responderInput =>
          'Respondents will be prompted to enter their email address before submitting.',
        _ => 'This will update the email collection setting for your form.',
      };

  @override
  Widget build(BuildContext context) {
    return SettingsCard(children: [
      SettingsRadioTile(
        label: "Don't collect",
        selected: _selected == EmailCollectionType.doNotCollect,
        onTap: widget.isSaving
            ? null
            : () => _onTap(EmailCollectionType.doNotCollect),
      ),
      SettingsRadioTile(
        label: 'Verified (Workspace accounts only)',
        selected: _selected == EmailCollectionType.verified,
        onTap: widget.isSaving
            ? null
            : () => _onTap(EmailCollectionType.verified),
      ),
      SettingsRadioTile(
        label: 'Ask respondents',
        selected: _selected == EmailCollectionType.responderInput,
        isLast: true,
        onTap: widget.isSaving
            ? null
            : () => _onTap(EmailCollectionType.responderInput),
      ),
    ]);
  }
}
