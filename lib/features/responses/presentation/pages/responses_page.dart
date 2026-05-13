import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/models/enums.dart';
import '../../../../core/models/form_response.dart';
import '../../../../core/models/item.dart';
import '../../../../core/models/item_content.dart';
import '../../../../core/models/question_kind.dart';
import '../cubit/responses_cubit.dart';

const _purple = Color(0xFF772FC0);
const _iosBg = Colors.white;
const _separator = Color(0xFFE8E8E8);
const _primaryText = Color(0xFF1C1C1E);
const _secondaryText = Color(0xFF8E8E93);
const _groupedBg = Color(0xFFF2F2F7);

// ── Entry point ────────────────────────────────────────────────────────────────

class ResponsesScreen extends StatelessWidget {
  final String formId;
  final List<Item> items;

  const ResponsesScreen({
    super.key,
    required this.formId,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return _ResponsesView(formId: formId, items: items);
  }
}

// ── Tabbed view ────────────────────────────────────────────────────────────────

class _ResponsesView extends StatefulWidget {
  final String formId;
  final List<Item> items;

  const _ResponsesView({required this.formId, required this.items});

  @override
  State<_ResponsesView> createState() => _ResponsesViewState();
}

class _ResponsesViewState extends State<_ResponsesView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ColoredBox(
          color: _iosBg,
          child: TabBar(
            controller: _tabController,
            dividerColor: _separator,
            tabs: const [Tab(text: 'Summary'), Tab(text: 'Individual')],
            labelColor: _purple,
            indicatorColor: _purple,
            indicatorSize: TabBarIndicatorSize.tab,
            unselectedLabelColor: _secondaryText,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: _groupedBg,
            child: BlocBuilder<ResponsesCubit, ResponsesState>(
              builder: (context, state) => switch (state) {
                ResponsesLoading() => const _ResponsesSkeleton(),
                ResponsesError(:final message) => _FullScreenError(
                    message: message,
                    onRetry: () => context
                        .read<ResponsesCubit>()
                        .loadResponses(widget.formId),
                  ),
                ResponsesLoaded(:final responses) => TabBarView(
                    controller: _tabController,
                    children: [
                      _SummaryTab(items: widget.items, responses: responses),
                      _IndividualTab(
                          responses: responses, items: widget.items),
                    ],
                  ),
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ── Loading skeleton ───────────────────────────────────────────────────────────

class _ResponsesSkeleton extends StatelessWidget {
  const _ResponsesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE5E5EA),
      highlightColor: _groupedBg,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: const Color(0xFFD1D1D6)),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: _secondaryText),
          ),
        ],
      ),
    );
  }
}

// ── Individual tab ─────────────────────────────────────────────────────────────

class _IndividualTab extends StatelessWidget {
  final List<FormResponse> responses;
  final List<Item> items;

  const _IndividualTab({required this.responses, required this.items});

  @override
  Widget build(BuildContext context) {
    if (responses.isEmpty) {
      return const _EmptyState(
        icon: CupertinoIcons.tray,
        message: 'No responses yet.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Text(
            '${responses.length} response${responses.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _secondaryText,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, 16 + MediaQuery.paddingOf(context).bottom),
            itemCount: responses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 1),
            itemBuilder: (context, i) => _ResponseTile(
              response: responses[i],
              isFirst: i == 0,
              isLast: i == responses.length - 1,
              onTap: () => _openDetail(context, responses[i]),
            ),
          ),
        ),
      ],
    );
  }

  void _openDetail(BuildContext context, FormResponse response) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ResponseDetailScreen(response: response, items: items),
    ));
  }
}

// ── Response tile ──────────────────────────────────────────────────────────────

class _ResponseTile extends StatelessWidget {
  final FormResponse response;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _ResponseTile({
    required this.response,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = response.respondentEmail?.isNotEmpty == true
        ? response.respondentEmail!
        : 'Anonymous';

    final radius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(14) : Radius.zero,
      bottom: isLast ? const Radius.circular(14) : Radius.zero,
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: _iosBg, borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _purple.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(CupertinoIcons.person,
                  size: 18, color: _purple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _primaryText),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(response.createTime),
                    style: const TextStyle(
                        fontSize: 12, color: _secondaryText),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 16, color: _secondaryText),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return 'Today ${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Summary tab ────────────────────────────────────────────────────────────────

typedef _QuestionEntry = ({
  String title,
  String questionId,
  QuestionKind kind,
});

class _SummaryTab extends StatelessWidget {
  final List<Item> items;
  final List<FormResponse> responses;

  const _SummaryTab({required this.items, required this.responses});

  @override
  Widget build(BuildContext context) {
    final questions = _buildQuestionEntries(items);

    if (questions.isEmpty) {
      return const _EmptyState(
        icon: CupertinoIcons.question_circle,
        message: 'No questions in this form.',
      );
    }

    if (responses.isEmpty) {
      return const _EmptyState(
        icon: CupertinoIcons.tray,
        message: 'No responses yet.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
      itemCount: questions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) =>
          _SummaryCard(entry: questions[i], responses: responses),
    );
  }

  List<_QuestionEntry> _buildQuestionEntries(List<Item> items) {
    final result = <_QuestionEntry>[];
    for (final item in items) {
      switch (item.content) {
        case QuestionItemContent(:final question):
          result.add((
            title: item.title?.isNotEmpty == true
                ? item.title!
                : 'Untitled question',
            questionId: question.questionId,
            kind: question.kind,
          ));
        case QuestionGroupItemContent(:final questions):
          for (final q in questions) {
            final groupTitle = item.title?.isNotEmpty == true
                ? item.title!
                : 'Untitled question';
            final rowTitle = q.kind is RowQuestion
                ? (q.kind as RowQuestion).title
                : groupTitle;
            result.add((
              title: rowTitle.isNotEmpty ? rowTitle : groupTitle,
              questionId: q.questionId,
              kind: q.kind,
            ));
          }
        default:
          break;
      }
    }
    return result;
  }
}

// ── Summary card ───────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final _QuestionEntry entry;
  final List<FormResponse> responses;

  const _SummaryCard({required this.entry, required this.responses});

  List<List<String>> get _allAnswers => responses
      .map((r) => r.answers[entry.questionId] ?? <String>[])
      .toList();

  @override
  Widget build(BuildContext context) {
    final allAnswers = _allAnswers;
    final answeredCount = allAnswers.where((a) => a.isNotEmpty).length;

    return Container(
      decoration: BoxDecoration(
        color: _iosBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _primaryText),
          ),
          const SizedBox(height: 3),
          Text(
            '$answeredCount of ${responses.length} answered',
            style: const TextStyle(fontSize: 12, color: _secondaryText),
          ),
          const SizedBox(height: 14),
          _buildBody(allAnswers),
        ],
      ),
    );
  }

  Widget _buildBody(List<List<String>> allAnswers) {
    final kind = entry.kind;
    return switch (kind) {
      ChoiceQuestion(:final type, :final options) => _ChoiceSummaryBody(
          allAnswers: allAnswers,
          options: options.map((o) => o.value).toList(),
          isMultiSelect: type == ChoiceType.checkbox,
        ),
      ScaleQuestion(:final low, :final high, :final lowLabel, :final highLabel) =>
        _NumericSummaryBody(
          allAnswers: allAnswers,
          label: _scaleLabel(low, high, lowLabel, highLabel),
        ),
      RatingQuestion(:final ratingScaleLevel, :final iconType) =>
        _NumericSummaryBody(
          allAnswers: allAnswers,
          label: 'avg out of $ratingScaleLevel',
          ratingIcon: _ratingIcon(iconType),
        ),
      _ => _TextSummaryBody(allAnswers: allAnswers),
    };
  }

  String _scaleLabel(
      int low, int high, String? lowLabel, String? highLabel) {
    if (lowLabel != null && highLabel != null) return '$lowLabel → $highLabel';
    return 'avg ($low–$high)';
  }

  IconData _ratingIcon(RatingIconType iconType) => switch (iconType) {
        RatingIconType.heart => Icons.favorite_rounded,
        RatingIconType.thumbUp => Icons.thumb_up_rounded,
        _ => Icons.star_rounded,
      };
}

// ── Choice summary body ────────────────────────────────────────────────────────

class _ChoiceSummaryBody extends StatelessWidget {
  final List<List<String>> allAnswers;
  final List<String> options;
  final bool isMultiSelect;

  const _ChoiceSummaryBody({
    required this.allAnswers,
    required this.options,
    required this.isMultiSelect,
  });

  @override
  Widget build(BuildContext context) {
    final tally = {for (final o in options) o: 0};
    final totalResponded = allAnswers.where((a) => a.isNotEmpty).length;

    for (final ans in allAnswers) {
      for (final v in ans) {
        if (tally.containsKey(v)) tally[v] = tally[v]! + 1;
      }
    }

    final maxCount = tally.values.fold(0, (a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final option in options) ...[
          _ChoiceBar(
            label: option,
            count: tally[option] ?? 0,
            totalResponded: totalResponded,
            maxCount: maxCount,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ChoiceBar extends StatelessWidget {
  final String label;
  final int count;
  final int totalResponded;
  final int maxCount;

  const _ChoiceBar({
    required this.label,
    required this.count,
    required this.totalResponded,
    required this.maxCount,
  });

  @override
  Widget build(BuildContext context) {
    final barFraction = maxCount > 0 ? count / maxCount : 0.0;
    final pct =
        totalResponded > 0 ? (count / totalResponded * 100).round() : 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: _primaryText)),
              const SizedBox(height: 5),
              LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Container(
                      height: 6,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Container(
                      height: 6,
                      width: constraints.maxWidth * barFraction,
                      decoration: BoxDecoration(
                        color: _purple,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 52,
          child: Text(
            '$count ($pct%)',
            style: const TextStyle(fontSize: 12, color: _secondaryText),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ── Text summary body ──────────────────────────────────────────────────────────

class _TextSummaryBody extends StatelessWidget {
  final List<List<String>> allAnswers;

  const _TextSummaryBody({required this.allAnswers});

  @override
  Widget build(BuildContext context) {
    final flat = [
      for (final ans in allAnswers)
        if (ans.isNotEmpty) ans.first,
    ];

    if (flat.isEmpty) {
      return const Text(
        'No answers yet.',
        style: TextStyle(
            fontSize: 13, color: _secondaryText, fontStyle: FontStyle.italic),
      );
    }

    const maxShown = 5;
    final shown = flat.take(maxShown).toList();
    final overflow = flat.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final v in shown)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: _groupedBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(v,
                style: const TextStyle(
                    fontSize: 13, color: _primaryText)),
          ),
        if (overflow > 0)
          Text(
            '+ $overflow more',
            style: const TextStyle(fontSize: 12, color: _secondaryText),
          ),
      ],
    );
  }
}

// ── Numeric summary body (scale / rating) ──────────────────────────────────────

class _NumericSummaryBody extends StatelessWidget {
  final List<List<String>> allAnswers;
  final String label;
  final IconData? ratingIcon;

  const _NumericSummaryBody({
    required this.allAnswers,
    required this.label,
    this.ratingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final ans in allAnswers)
        if (ans.isNotEmpty) double.tryParse(ans.first),
    ].whereType<double>().toList();

    if (values.isEmpty) {
      return const Text(
        'No answers yet.',
        style: TextStyle(
            fontSize: 13, color: _secondaryText, fontStyle: FontStyle.italic),
      );
    }

    final avg = values.reduce((a, b) => a + b) / values.length;

    return Center(
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (ratingIcon != null) ...[
                Icon(ratingIcon, color: _purple, size: 28),
                const SizedBox(width: 4),
              ],
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: _purple,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: _secondaryText),
          ),
        ],
      ),
    );
  }
}

// ── Detail screen ──────────────────────────────────────────────────────────────

class ResponseDetailScreen extends StatelessWidget {
  final FormResponse response;
  final List<Item> items;

  const ResponseDetailScreen({
    super.key,
    required this.response,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final label = response.respondentEmail?.isNotEmpty == true
        ? response.respondentEmail!
        : 'Anonymous';
    final questions = _buildQuestionIndex(items);

    return Scaffold(
      backgroundColor: _groupedBg,
      appBar: AppBar(
        backgroundColor: _iosBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.arrow_left,
              color: _purple, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _primaryText,
          ),
        ),
      ),
      body: questions.isEmpty
          ? const _EmptyState(
              icon: CupertinoIcons.question_circle,
              message: 'No questions in this form.',
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
              itemCount: questions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final q = questions[i];
                final values = response.answers[q.questionId];
                return _AnswerTile(
                  questionTitle: q.title,
                  values: values,
                );
              },
            ),
    );
  }

  List<({String title, String questionId})> _buildQuestionIndex(
      List<Item> items) {
    final result = <({String title, String questionId})>[];
    for (final item in items) {
      switch (item.content) {
        case QuestionItemContent(:final question):
          result.add((
            title: item.title?.isNotEmpty == true
                ? item.title!
                : 'Untitled question',
            questionId: question.questionId,
          ));
        case QuestionGroupItemContent(:final questions):
          final groupTitle = item.title?.isNotEmpty == true
              ? item.title!
              : 'Untitled group';
          for (final q in questions) {
            result.add((
              title: groupTitle,
              questionId: q.questionId,
            ));
          }
        default:
          break;
      }
    }
    return result;
  }
}

// ── Answer tile ────────────────────────────────────────────────────────────────

class _AnswerTile extends StatelessWidget {
  final String questionTitle;
  final List<String>? values;

  const _AnswerTile({required this.questionTitle, required this.values});

  @override
  Widget build(BuildContext context) {
    final answered = values != null && values!.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _iosBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionTitle,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _secondaryText),
          ),
          const SizedBox(height: 6),
          if (!answered)
            const Text(
              '— No answer —',
              style: TextStyle(
                  fontSize: 15,
                  color: _secondaryText,
                  fontStyle: FontStyle.italic),
            )
          else
            ...values!.map((v) => Text(
                  v,
                  style: const TextStyle(
                      fontSize: 15, color: _primaryText),
                )),
        ],
      ),
    );
  }
}

// ── Full screen error ──────────────────────────────────────────────────────────

class _FullScreenError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FullScreenError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: _primaryText),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _purple),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
