import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/item.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/models/item_content.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/editor_cubit.dart';
import '../widgets/form_header_card.dart';
import '../widgets/question_card.dart';
import '../widgets/section_card.dart';
import '../widgets/text_block_card.dart';
import 'editor_media_cards.dart';

// ── Value objects for BlocSelectors ──────────────────────────────────────────

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

class _ItemData {
  final Item? item;
  final List<Item> sections;
  final bool isQuiz;

  const _ItemData({required this.item, required this.sections, this.isQuiz = false});

  @override
  bool operator ==(Object other) =>
      other is _ItemData &&
      other.item == item &&
      other.isQuiz == isQuiz &&
      listEquals(other.sections, sections);

  @override
  int get hashCode => Object.hash(item, isQuiz, Object.hashAll(sections));
}

// ── Editor body (Questions tab) ───────────────────────────────────────────────

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
    return BlocListener<EditorCubit, EditorState>(
      listenWhen: (prev, curr) {
        if (curr is! EditorLoaded) return false;
        final prevCount =
            prev is EditorLoaded ? prev.form.items.length : _prevItemCount;
        return curr.form.items.length > prevCount;
      },
      listener: (context, state) {
        if (state is EditorLoaded) {
          _prevItemCount = state.form.items.length;
          _scrollToBottom();
        }
      },
      child: BlocSelector<EditorCubit, EditorState, _BodyData>(
        selector: (state) {
          if (state is! EditorLoaded) return _BodyData.empty;
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
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.question_circle,
                            size: 56,
                            color: AppColors.iconInactive,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No questions yet.',
                            style: AppTextStyles.cardTitle.copyWith(color: AppColors.ink2),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Tap + below to add your first question.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
                    context.read<EditorCubit>().moveItem(oldIndex, newIndex);
                  },
                  itemBuilder: (context, i) {
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(data.itemIds[i]),
                      index: i,
                      child: BlocProvider.value(
                        value: context.read<EditorCubit>(),
                        child: _ItemRow(itemId: data.itemIds[i]),
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

// ── Per-item row ──────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final String itemId;

  const _ItemRow({required this.itemId});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<EditorCubit, EditorState, _ItemData>(
      selector: (state) {
        if (state is! EditorLoaded) {
          return const _ItemData(item: null, sections: []);
        }
        final items = state.form.items;
        final idx = items.indexWhere((i) => i.itemId == itemId);
        final item = idx == -1 ? null : items[idx];
        final sections = items
            .where((i) => i.content is PageBreakItemContent)
            .toList(growable: false);
        return _ItemData(
          item: item,
          sections: sections,
          isQuiz: state.form.settings.quizSettings.isQuiz,
        );
      },
      builder: (context, data) {
        final item = data.item;
        if (item == null) return const SizedBox.shrink();
        return switch (item.content) {
          QuestionItemContent() || QuestionGroupItemContent() =>
            QuestionCard(item: item, sections: data.sections, isQuiz: data.isQuiz),
          PageBreakItemContent() => SectionCard(item: item),
          TextItemContent() => TextBlockCard(item: item),
          ImageItemContent() => EditorImageCard(item: item),
          VideoItemContent() => EditorVideoCard(item: item),
        };
      },
    );
  }
}
