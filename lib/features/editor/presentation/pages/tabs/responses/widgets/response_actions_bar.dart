import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../../../core/api/forms_client.dart';
import '../../../../../../../core/di/injection.dart';
import '../../../../../../../core/models/form_response.dart';
import '../../../../../../../core/services/analytics_service.dart';
import '../../../../../../../core/theme/app_colors.dart';
import '../../../../../../../core/usecases/usecase.dart';
import '../../../../../../../core/widgets/error_modal.dart';
import '../../../../../../ai_form_builder/domain/usecases/get_user_status.dart';
import '../../questions/cubit/questions_cubit.dart';
import '../../../../../../paywall/presentation/pages/paywall_page.dart';
import '../../../../../data/pdf_builders.dart';
import '../cubit/responses_cubit.dart';
import 'print_options_sheet.dart';

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
  bool _isPrinting = false;
  final _csvButtonKey = GlobalKey();

  /// Shortcut: returns true if the Responses tab has loaded at least one
  /// response. Quick local check using the cubit so we can short-circuit
  /// both the CSV export and the Print flow without a network round-trip.
  bool _hasAnyResponses() {
    final state = context.read<ResponsesCubit>().state;
    return state is ResponsesLoaded && state.responses.isNotEmpty;
  }

  void _showNoResponsesDialog() {
    ErrorModal.show(
      context,
      title: 'No responses yet',
      body: 'This form has not received any responses to export or print.',
      primaryLabel: 'OK',
      onPrimary: () {},
    );
  }

  Future<List<FormResponse>> _fetchAllResponses() async {
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
    return responses;
  }

  Future<void> _exportCsv() async {
    if (_isExporting) return;
    if (!_hasAnyResponses()) {
      _showNoResponsesDialog();
      return;
    }
    final statusResult = await getIt<GetUserStatus>().call(const NoParams());
    if (!mounted) return;
    final isPremium = statusResult.fold((_) => false, (s) => s.isPremium);
    if (!isPremium) {
      await PaywallPage.show(context);
      return;
    }

    final editorState = context.read<QuestionsCubit>().state;
    if (editorState is! QuestionsLoaded) return;
    final form = editorState.form;

    setState(() => _isExporting = true);
    try {
      final responses = await _fetchAllResponses();
      final csv = buildCsv(form, responses);

      final dir = await getTemporaryDirectory();
      final title = form.info.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final file = File('${dir.path}/${title}_responses.csv');
      await file.writeAsString(csv);

      if (!mounted) return;
      final box = _csvButtonKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: '${form.info.title} — Responses',
        sharePositionOrigin: origin,
      ));
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

  /// Tap → fetch responses → format chooser sheet → optional individual
  /// picker → OS print dialog. Responses are fetched BEFORE the format sheet
  /// so the individual picker can open instantly with the data in hand.
  Future<void> _print() async {
    if (_isPrinting) return;
    if (!_hasAnyResponses()) {
      _showNoResponsesDialog();
      return;
    }

    final editorState = context.read<QuestionsCubit>().state;
    if (editorState is! QuestionsLoaded) return;
    final form = editorState.form;

    // ── 1. Fetch all responses (loader visible on Print button) ─────────────
    setState(() => _isPrinting = true);
    final List<FormResponse> responses;
    try {
      responses = await _fetchAllResponses();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPrinting = false);
      ErrorModal.show(
        context,
        title: 'Print failed.',
        body: 'Check your connection and try again.',
        primaryLabel: 'OK',
        onPrimary: () {},
      );
      return;
    }
    if (!mounted) return;
    setState(() => _isPrinting = false);

    // ── 2. Format chooser ───────────────────────────────────────────────────
    final format = await showPrintOptionsSheet(context);
    if (format == null || !mounted) return;

    // ── 3. Individual picker (in-memory list, opens instantly) ──────────────
    List<FormResponse>? selected;
    if (format == PrintFormat.individual) {
      selected = await showIndividualPickerSheet(
        context,
        allResponses: responses,
      );
      if (selected == null || selected.isEmpty || !mounted) return;
    }

    // ── 4. System print dialog ──────────────────────────────────────────────
    try {
      await Printing.layoutPdf(
        name: '${form.info.title} — Responses',
        onLayout: (PdfPageFormat pageFormat) {
          switch (format) {
            case PrintFormat.table:
              return buildResponsesPdf(form, responses, pageFormat.landscape);
            case PrintFormat.questionnaire:
              return buildQuestionnairePdf(form, responses, pageFormat);
            case PrintFormat.summary:
              return buildSummaryPdf(form, responses, pageFormat);
            case PrintFormat.individual:
              return buildQuestionnairePdf(form, selected!, pageFormat);
          }
        },
      );
    } catch (_) {
      if (!mounted) return;
      ErrorModal.show(
        context,
        title: 'Print failed.',
        body: 'Check your connection and try again.',
        primaryLabel: 'OK',
        onPrimary: () {},
      );
    }
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
              key: _csvButtonKey,
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
              isLoading: _isPrinting,
              onTap: _isPrinting ? null : _print,
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
    super.key,
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

// CSV + PDF builders moved to lib/features/responses/data/pdf_builders.dart.
