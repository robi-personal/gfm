import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../../../../core/models/form_doc.dart';
import '../../../../../../../core/models/form_response.dart';
import '../../../../../../../core/models/item_content.dart';
import '../../../../../../../core/models/question_kind.dart';

const _purple = PdfColor.fromInt(0xFF772FC0);
const _grey100 = PdfColors.grey100;
const _grey400 = PdfColors.grey400;
const _grey700 = PdfColors.grey700;

// ── Question index helper ────────────────────────────────────────────────────

class _IndexedQuestion {
  final String title;
  final String questionId;
  final QuestionKind kind;
  _IndexedQuestion(this.title, this.questionId, this.kind);
}

List<_IndexedQuestion> _indexQuestions(FormDoc form) {
  final out = <_IndexedQuestion>[];
  for (final item in form.items) {
    final t = item.title?.isNotEmpty == true ? item.title! : 'Untitled';
    switch (item.content) {
      case QuestionItemContent(:final question):
        out.add(_IndexedQuestion(t, question.questionId, question.kind));
      case QuestionGroupItemContent(:final questions):
        for (final q in questions) {
          out.add(_IndexedQuestion(t, q.questionId, q.kind));
        }
      default:
        break;
    }
  }
  return out;
}

// ── 1) Table PDF ─────────────────────────────────────────────────────────────

Future<Uint8List> buildResponsesPdf(
  FormDoc form,
  List<FormResponse> responses,
  PdfPageFormat landscape,
) async {
  final qs = _indexQuestions(form);

  final headers = <String>['Timestamp', 'Email', ...qs.map((q) => q.title)];
  final rows = responses.map((r) {
    return <String>[
      r.createTime.toLocal().toString().split('.').first,
      r.respondentEmail ?? '',
      ...qs.map((q) => (r.answers[q.questionId] ?? const []).join('; ')),
    ];
  }).toList();

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: landscape,
      margin: const pw.EdgeInsets.all(24),
      build: (context) => [
        pw.Text(
          form.info.title.isEmpty ? 'Responses' : form.info.title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          '${responses.length} response${responses.length == 1 ? '' : 's'}',
          style: pw.TextStyle(fontSize: 10, color: _grey700),
        ),
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(color: _purple),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.topLeft,
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          border: pw.TableBorder.all(color: _grey400, width: 0.4),
          oddRowDecoration: const pw.BoxDecoration(color: _grey100),
        ),
      ],
    ),
  );
  return doc.save();
}

// ── 2) Questionnaire PDF ─────────────────────────────────────────────────────

/// One respondent per page section. Each page has form title, submitted
/// timestamp, respondent email, separator, then numbered questions with
/// compact answers below. Page footer shows "page X of Y".
Future<Uint8List> buildQuestionnairePdf(
  FormDoc form,
  List<FormResponse> responses,
  PdfPageFormat portrait,
) async {
  final qs = _indexQuestions(form);
  final formTitle =
      form.info.title.isEmpty ? 'Form Responses' : form.info.title;

  final doc = pw.Document();
  for (var i = 0; i < responses.length; i++) {
    final r = responses[i];
    doc.addPage(
      pw.MultiPage(
        pageFormat: portrait,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'page ${i + 1} of ${responses.length}',
            style: pw.TextStyle(fontSize: 9, color: _grey700),
          ),
        ),
        build: (context) => [
          pw.Text(
            formTitle,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Submitted: ${_formatTimestamp(r.createTime.toLocal())}',
            style: pw.TextStyle(fontSize: 10, color: _grey700),
          ),
          if ((r.respondentEmail ?? '').isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              'By: ${r.respondentEmail}',
              style: pw.TextStyle(fontSize: 10, color: _grey700),
            ),
          ],
          pw.SizedBox(height: 10),
          pw.Divider(color: _grey400, thickness: 0.6),
          pw.SizedBox(height: 14),
          for (var qi = 0; qi < qs.length; qi++)
            _questionBlock(qs[qi], qi + 1, r.answers[qs[qi].questionId] ?? const []),
        ],
      ),
    );
  }
  return doc.save();
}

pw.Widget _questionBlock(_IndexedQuestion q, int number, List<String> answer) {
  final answerText = answer.isEmpty ? '—' : answer.join(', ');
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 14),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Q$number.  ${q.title}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 18),
          child: pw.Text(
            answerText,
            style: pw.TextStyle(
              fontSize: 11,
              color: answer.isEmpty ? _grey700 : PdfColors.black,
              fontStyle:
                  answer.isEmpty ? pw.FontStyle.italic : pw.FontStyle.normal,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── 3) Summary PDF ───────────────────────────────────────────────────────────

/// Mirrors the on-screen Summary tab: one card per question with answered
/// count + visualisation. Choice questions get proportional purple bars,
/// scale/rating get a numeric average, text gets a preview of recent answers.
Future<Uint8List> buildSummaryPdf(
  FormDoc form,
  List<FormResponse> responses,
  PdfPageFormat portrait,
) async {
  final qs = _indexQuestions(form);
  final formTitle =
      form.info.title.isEmpty ? 'Form Responses' : form.info.title;

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: portrait,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Text(
          formTitle,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Summary · ${responses.length} response${responses.length == 1 ? '' : 's'}',
          style: pw.TextStyle(fontSize: 10, color: _grey700),
        ),
        pw.SizedBox(height: 18),
        for (final q in qs) ...[
          _summaryCard(q, responses),
          pw.SizedBox(height: 14),
        ],
      ],
    ),
  );
  return doc.save();
}

pw.Widget _summaryCard(_IndexedQuestion q, List<FormResponse> responses) {
  final allAnswers = responses
      .map((r) => r.answers[q.questionId] ?? const <String>[])
      .toList();
  final answeredCount = allAnswers.where((a) => a.isNotEmpty).length;

  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border.all(color: _grey400, width: 0.5),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          q.title,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '$answeredCount of ${responses.length} answered',
          style: pw.TextStyle(fontSize: 9, color: _grey700),
        ),
        pw.SizedBox(height: 10),
        _summaryBody(q.kind, allAnswers),
      ],
    ),
  );
}

pw.Widget _summaryBody(QuestionKind kind, List<List<String>> allAnswers) {
  switch (kind) {
    case ChoiceQuestion(:final options):
      return _choiceBars(options.map((o) => o.value).toList(), allAnswers);
    case ScaleQuestion(:final low, :final high, :final lowLabel, :final highLabel):
      return _numericAverage(
        allAnswers,
        label: (lowLabel != null && highLabel != null)
            ? '$lowLabel → $highLabel'
            : 'avg ($low–$high)',
      );
    case RatingQuestion(:final ratingScaleLevel):
      return _numericAverage(
        allAnswers,
        label: 'avg out of $ratingScaleLevel',
      );
    default:
      return _textPreview(allAnswers);
  }
}

pw.Widget _choiceBars(List<String> options, List<List<String>> allAnswers) {
  final tally = {for (final o in options) o: 0};
  final totalResponded = allAnswers.where((a) => a.isNotEmpty).length;
  for (final ans in allAnswers) {
    for (final v in ans) {
      if (tally.containsKey(v)) tally[v] = tally[v]! + 1;
    }
  }
  final maxCount = tally.values.fold(0, (a, b) => a > b ? a : b);

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final option in options) ...[
        _choiceBar(
          label: option,
          count: tally[option] ?? 0,
          totalResponded: totalResponded,
          maxCount: maxCount,
        ),
        pw.SizedBox(height: 8),
      ],
    ],
  );
}

pw.Widget _choiceBar({
  required String label,
  required int count,
  required int totalResponded,
  required int maxCount,
}) {
  final pct =
      totalResponded > 0 ? (count / totalResponded * 100).round() : 0;
  // Use Row + flex to render proportional bars — pdf has no FractionallySizedBox.
  // Multiply by 100 to get integer flex values; remainder is the empty track.
  final filledFlex = maxCount > 0 ? ((count / maxCount) * 100).round() : 0;
  final emptyFlex = 100 - filledFlex;

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 3),
            pw.Row(
              children: [
                if (filledFlex > 0)
                  pw.Expanded(
                    flex: filledFlex,
                    child: pw.Container(
                      height: 5,
                      decoration: pw.BoxDecoration(
                        color: _purple,
                        borderRadius: pw.BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                if (emptyFlex > 0)
                  pw.Expanded(
                    flex: emptyFlex,
                    child: pw.Container(
                      height: 5,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300,
                        borderRadius: pw.BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(width: 10),
      pw.SizedBox(
        width: 56,
        child: pw.Text(
          '$count ($pct%)',
          style: pw.TextStyle(fontSize: 9, color: _grey700),
          textAlign: pw.TextAlign.right,
        ),
      ),
    ],
  );
}

pw.Widget _numericAverage(List<List<String>> allAnswers, {required String label}) {
  final nums = <double>[];
  for (final ans in allAnswers) {
    for (final v in ans) {
      final d = double.tryParse(v);
      if (d != null) nums.add(d);
    }
  }
  if (nums.isEmpty) {
    return pw.Text(
      'No numeric answers yet.',
      style: pw.TextStyle(
        fontSize: 10,
        color: _grey700,
        fontStyle: pw.FontStyle.italic,
      ),
    );
  }
  final avg = nums.reduce((a, b) => a + b) / nums.length;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.end,
    children: [
      pw.Text(
        avg.toStringAsFixed(1),
        style: pw.TextStyle(
          fontSize: 22,
          fontWeight: pw.FontWeight.bold,
          color: _purple,
        ),
      ),
      pw.SizedBox(width: 6),
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(label,
            style: pw.TextStyle(fontSize: 10, color: _grey700)),
      ),
    ],
  );
}

pw.Widget _textPreview(List<List<String>> allAnswers) {
  final flat = [
    for (final ans in allAnswers)
      if (ans.isNotEmpty) ans.first,
  ];
  if (flat.isEmpty) {
    return pw.Text(
      'No answers yet.',
      style: pw.TextStyle(
        fontSize: 10,
        color: _grey700,
        fontStyle: pw.FontStyle.italic,
      ),
    );
  }
  const maxShown = 5;
  final shown = flat.take(maxShown).toList();
  final overflow = flat.length - shown.length;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final v in shown)
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 5),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: pw.BoxDecoration(
            color: _grey100,
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Text(v, style: const pw.TextStyle(fontSize: 10)),
        ),
      if (overflow > 0)
        pw.Text(
          '+$overflow more',
          style: pw.TextStyle(fontSize: 9, color: _grey700),
        ),
    ],
  );
}

// ── 4) CSV builder (also moved here for colocation) ──────────────────────────

String buildCsv(FormDoc form, List<FormResponse> responses) {
  final qs = _indexQuestions(form);

  String escape(String v) {
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  final buffer = StringBuffer();
  buffer.write('Timestamp,Email');
  for (final q in qs) {
    buffer.write(',${escape(q.title)}');
  }
  buffer.writeln();

  for (final r in responses) {
    buffer.write(escape(r.createTime.toIso8601String()));
    buffer.write(',${escape(r.respondentEmail ?? '')}');
    for (final q in qs) {
      final vals = r.answers[q.questionId] ?? [];
      buffer.write(',${escape(vals.join('; '))}');
    }
    buffer.writeln();
  }
  return buffer.toString();
}

// ── Timestamp formatter ──────────────────────────────────────────────────────

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatTimestamp(DateTime dt) {
  final m = _months[dt.month - 1];
  final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
  final ampm = dt.hour < 12 ? 'AM' : 'PM';
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$m ${dt.day}, ${dt.year} $hour12:$mm $ampm';
}
