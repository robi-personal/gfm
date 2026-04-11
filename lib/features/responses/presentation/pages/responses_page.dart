import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/form_response.dart';
import '../../../../core/models/item.dart';
import '../../../../core/models/item_content.dart';
import '../../../../core/models/question_kind.dart';
import '../../../../core/widgets/skeleton_bone.dart';
import '../cubit/responses_cubit.dart';

const _purple = Color(0xFF772FC0);

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
    return BlocProvider(
      create: (_) => getIt<ResponsesCubit>()..loadResponses(formId),
      child: _ResponsesView(formId: formId, items: items),
    );
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
        _buildTabBar(context),
        Expanded(
          child: BlocBuilder<ResponsesCubit, ResponsesState>(
            builder: (context, state) => switch (state) {
              ResponsesLoading() => const _ResponsesSkeleton(),
              ResponsesError(:final message) => _FullScreenError(
                  message: message,
                  onRetry: () =>
                      context.read<ResponsesCubit>().loadResponses(widget.formId),
                ),
              ResponsesLoaded(:final responses) => TabBarView(
                  controller: _tabController,
                  children: [
                    _SummaryTab(items: widget.items, responses: responses),
                    _IndividualTab(responses: responses, items: widget.items),
                  ],
                ),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        tabs: const [Tab(text: 'Summary'), Tab(text: 'Individual')],
        labelColor: _purple,
        indicatorColor: _purple,
        indicatorSize: TabBarIndicatorSize.label,
        unselectedLabelColor: Colors.grey,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
      ),
    );
  }
}

// ── Loading skeleton ───────────────────────────────────────────────────────────

class _ResponsesSkeleton extends StatelessWidget {
  const _ResponsesSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = Theme.of(context).colorScheme.surface;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.separated(
        itemCount: 6,
        separatorBuilder: (context, i) => const Divider(height: 1),
        itemBuilder: (context, i) => const ListTile(
          leading: SkeletonBone(width: 24, height: 24, radius: 12),
          title: SkeletonBone(width: double.infinity, height: 14, radius: 4),
          subtitle: SkeletonBone(width: 100, height: 11, radius: 4),
          trailing: SkeletonBone(width: 16, height: 16, radius: 4),
        ),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('No responses yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${responses.length} response${responses.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom),
            itemCount: responses.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _ResponseTile(
              response: responses[i],
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
  final VoidCallback onTap;

  const _ResponseTile({required this.response, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = response.respondentEmail?.isNotEmpty == true
        ? response.respondentEmail!
        : 'Anonymous';
    return ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_formatDate(response.createTime)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No questions in this form.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    if (responses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 12),
              Text('No responses yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          12, 12, 12, 12 + MediaQuery.paddingOf(context).bottom),
      itemCount: questions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
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
    final theme = Theme.of(context);
    final allAnswers = _allAnswers;
    final answeredCount = allAnswers.where((a) => a.isNotEmpty).length;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              '$answeredCount of ${responses.length} answered',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _buildBody(allAnswers),
          ],
        ),
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
    // Tally each defined option
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
          const SizedBox(height: 8),
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
    final theme = Theme.of(context);
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
              Text(label, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Container(
                      height: 6,
                      width: constraints.maxWidth,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
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
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          child: Text(
            '$count ($pct%)',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
    final theme = Theme.of(context);
    final flat = [
      for (final ans in allAnswers)
        if (ans.isNotEmpty) ans.first,
    ];

    if (flat.isEmpty) {
      return Text(
        'No answers yet.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(v, style: theme.textTheme.bodySmall),
          ),
        if (overflow > 0)
          Text(
            '+ $overflow more',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
    final theme = Theme.of(context);
    final values = [
      for (final ans in allAnswers)
        if (ans.isNotEmpty) double.tryParse(ans.first),
    ].whereType<double>().toList();

    if (values.isEmpty) {
      return Text(
        'No answers yet.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
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
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: _purple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
      appBar: AppBar(title: Text(label, overflow: TextOverflow.ellipsis)),
      body: questions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.help_outline, size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('No questions in this form.',
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: questions.length,
              separatorBuilder: (context, _) => const Divider(height: 1),
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
    final theme = Theme.of(context);
    final answered = values != null && values!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionTitle,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          if (!answered)
            Text(
              '— No answer —',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...values!.map((v) => Text(v, style: theme.textTheme.bodyMedium)),
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
