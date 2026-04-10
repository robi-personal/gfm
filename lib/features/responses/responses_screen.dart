import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/di/injection.dart';
import '../../core/models/form_response.dart';
import '../../core/models/item.dart';
import '../../core/models/item_content.dart';
import '../../core/widgets/skeleton_bone.dart';
import 'responses_cubit.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

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
      create: (_) => ResponsesCubit(getIt())..loadResponses(formId),
      child: _ResponsesView(formId: formId, items: items),
    );
  }
}

// ── List view ─────────────────────────────────────────────────────────────────

class _ResponsesView extends StatelessWidget {
  final String formId;
  final List<Item> items;

  const _ResponsesView({
    required this.formId,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ResponsesCubit, ResponsesState>(
      builder: (context, state) => switch (state) {
        ResponsesLoading() => const _ResponsesSkeleton(),
        ResponsesError(:final message) => _FullScreenError(
            message: message,
            onRetry: () =>
                context.read<ResponsesCubit>().loadResponses(formId),
          ),
        ResponsesLoaded(:final responses) =>
          _ResponseList(responses: responses, items: items),
      },
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

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

// ── Response list ─────────────────────────────────────────────────────────────

class _ResponseList extends StatelessWidget {
  final List<FormResponse> responses;
  final List<Item> items;

  const _ResponseList({required this.responses, required this.items});

  @override
  Widget build(BuildContext context) {
    if (responses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No responses yet.',
            textAlign: TextAlign.center,
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
            itemCount: responses.length,
            separatorBuilder: (context, _) => const Divider(height: 1),
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

// ── Response tile ─────────────────────────────────────────────────────────────

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

// ── Detail screen ─────────────────────────────────────────────────────────────

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
          ? const Center(child: Text('No questions in this form.'))
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

  /// Flattens all answerable questions from the form items into an ordered list.
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
          final groupTitle =
              item.title?.isNotEmpty == true ? item.title! : 'Untitled group';
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

// ── Answer tile ───────────────────────────────────────────────────────────────

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
            ...values!.map(
              (v) => Text(v, style: theme.textTheme.bodyMedium),
            ),
        ],
      ),
    );
  }
}

// ── Full screen error ─────────────────────────────────────────────────────────

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
