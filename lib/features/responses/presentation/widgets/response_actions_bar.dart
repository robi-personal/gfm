import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/forms_client.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/models/form_doc.dart';
import '../../../../core/models/form_response.dart';
import '../../../../core/models/item_content.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/widgets/error_modal.dart';
import '../../../ai_form_builder/domain/usecases/get_user_status.dart';
import '../../../editor/presentation/cubit/editor_cubit.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';

/// Action row shown inside the Responses tab, above the Summary/Individual
/// sub-tabs. Two column-style buttons (icon top, label bottom): Export CSV
/// and Print (opens the form's responder URL so the user can print a blank
/// form for paper distribution).
class ResponseActionsBar extends StatefulWidget {
  final String formId;

  const ResponseActionsBar({super.key, required this.formId});

  @override
  State<ResponseActionsBar> createState() => _ResponseActionsBarState();
}

class _ResponseActionsBarState extends State<ResponseActionsBar> {
  bool _isExporting = false;

  Future<void> _exportCsv() async {
    if (_isExporting) return;
    final statusResult = await getIt<GetUserStatus>().call(const NoParams());
    if (!mounted) return;
    final isPremium = statusResult.fold((_) => false, (s) => s.isPremium);
    if (!isPremium) {
      await PaywallPage.show(context);
      return;
    }

    final editorState = context.read<EditorCubit>().state;
    if (editorState is! EditorLoaded) return;
    final form = editorState.form;

    setState(() => _isExporting = true);
    try {
      final client = getIt<FormsClient>();
      final responses = <FormResponse>[];
      String? pageToken;
      do {
        final result = await client.api.forms.responses.list(
          widget.formId,
          pageSize: 100,
          pageToken: pageToken,
        );
        responses.addAll((result.responses ?? []).map(FormResponse.fromApi));
        pageToken = result.nextPageToken;
      } while (pageToken != null);
      responses.sort((a, b) => a.createTime.compareTo(b.createTime));

      final csv = buildCsv(form, responses);

      final dir = await getTemporaryDirectory();
      final title = form.info.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final file = File('${dir.path}/${title}_responses.csv');
      await file.writeAsString(csv);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: '${form.info.title} — Responses',
      );
      AnalyticsService.logCsvExported();
    } catch (_) {
      if (!mounted) return;
      ErrorModal.show(
        context,
        title: 'Export failed.',
        body: 'Check your connection and try again.',
        primaryLabel: 'OK',
        onPrimary: () {},
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _print() async {
    final editorState = context.read<EditorCubit>().state;
    if (editorState is! EditorLoaded) return;
    final url = editorState.form.responderUri;
    if (url.isEmpty) {
      ErrorModal.show(
        context,
        title: 'Cannot print',
        body: 'This form has no public link yet. Publish it first and try again.',
        primaryLabel: 'OK',
        onPrimary: () {},
      );
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _ActionTile(
              icon: CupertinoIcons.arrow_down_doc,
              label: 'Export CSV',
              isLoading: _isExporting,
              onTap: _isExporting ? null : _exportCsv,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              icon: CupertinoIcons.printer,
              label: 'Print',
              onTap: _print,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5EA), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: isLoading
                  ? const CupertinoActivityIndicator(radius: 9, color: AppColors.purple)
                  : Icon(
                      icon,
                      size: 18,
                      color: disabled ? AppColors.textSecondary : AppColors.purple,
                    ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: disabled ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── CSV builder ──────────────────────────────────────────────────────────────

String buildCsv(FormDoc form, List<FormResponse> responses) {
  final cols = <({String title, String questionId})>[];
  for (final item in form.items) {
    final itemTitle =
        item.title?.isNotEmpty == true ? item.title! : 'Untitled';
    switch (item.content) {
      case QuestionItemContent(:final question):
        cols.add((title: itemTitle, questionId: question.questionId));
      case QuestionGroupItemContent(:final questions):
        for (final q in questions) {
          cols.add((title: itemTitle, questionId: q.questionId));
        }
      default:
        break;
    }
  }
  final questions = cols;

  String escape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  final buffer = StringBuffer();
  buffer.write('Timestamp,Email');
  for (final q in questions) {
    buffer.write(',${escape(q.title)}');
  }
  buffer.writeln();

  for (final r in responses) {
    buffer.write(escape(r.createTime.toIso8601String()));
    buffer.write(',${escape(r.respondentEmail ?? '')}');
    for (final q in questions) {
      final vals = r.answers[q.questionId] ?? [];
      buffer.write(',${escape(vals.join('; '))}');
    }
    buffer.writeln();
  }
  return buffer.toString();
}
