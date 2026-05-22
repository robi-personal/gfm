import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';

import '../cubit/questions_cubit.dart';
import 'questions_empty_state.dart';
import 'questions_item_row.dart';
import 'form_header_card.dart';

class _BodyData {
  final List<String> itemIds;
  final String title;
  final String description;

  const _BodyData({
    required this.itemIds,
    required this.title,
    required this.description,
  });

  static const empty = _BodyData(itemIds: [], title: '', description: '');

  @override
  bool operator ==(Object other) =>
      other is _BodyData &&
      other.title == title &&
      other.description == description &&
      listEquals(other.itemIds, itemIds);

  @override
  int get hashCode =>
      Object.hash(title, description, Object.hashAll(itemIds));
}

class EditorBody extends StatefulWidget {
  const EditorBody({super.key});

  @override
  State<EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends State<EditorBody> {
  final _scrollController = ScrollController();
  int _prevItemCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<QuestionsCubit, QuestionsState>(
      listenWhen: (prev, curr) {
        if (curr is! QuestionsLoaded) return false;
        final prevCount =
            prev is QuestionsLoaded ? prev.form.items.length : _prevItemCount;
        return curr.form.items.length > prevCount;
      },
      listener: (context, state) {
        if (state is QuestionsLoaded) {
          _prevItemCount = state.form.items.length;
          _scrollToBottom();
        }
      },
      child: BlocSelector<QuestionsCubit, QuestionsState, _BodyData>(
        selector: (state) {
          if (state is! QuestionsLoaded) return _BodyData.empty;
          final form = state.form;
          return _BodyData(
            itemIds: form.items.map((i) => i.itemId).toList(),
            title: form.info.title.isNotEmpty
                ? form.info.title
                : form.info.documentTitle,
            description: form.info.description,
          );
        },
        builder: (context, data) {
          final header = FormHeaderCard(
            key: const ValueKey('__header__'),
            initialTitle: data.title,
            initialDescription: data.description,
          );

          const physics = BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          );

          if (data.itemIds.isEmpty) {
            return CustomScrollView(
              controller: _scrollController,
              physics: physics,
              slivers: [
                SliverToBoxAdapter(child: header),
                const QuestionsEmptyState(),
              ],
            );
          }

          return CustomScrollView(
            controller: _scrollController,
            physics: physics,
            cacheExtent: 600,
            slivers: [
              SliverToBoxAdapter(child: header),
              SliverPadding(
                padding: const EdgeInsets.only(top: 4, bottom: 140),
                sliver: SliverReorderableList(
                  itemCount: data.itemIds.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    if (oldIndex == newIndex) return;
                    context.read<QuestionsCubit>().moveItem(oldIndex, newIndex);
                  },
                  itemBuilder: (context, i) {
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(data.itemIds[i]),
                      index: i,
                      child: BlocProvider.value(
                        value: context.read<QuestionsCubit>(),
                        child: QuestionsItemRow(itemId: data.itemIds[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
