import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart';

import '../../../../../../../core/models/item.dart';
import '../../../../../../../core/models/item_content.dart';
import '../cubit/questions_cubit.dart';
import 'editor_media_cards.dart';
import 'question_card.dart';
import 'section_card.dart';
import 'text_block_card.dart';

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

class QuestionsItemRow extends StatelessWidget {
  final String itemId;

  const QuestionsItemRow({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<QuestionsCubit, QuestionsState, _ItemData>(
      selector: (state) {
        if (state is! QuestionsLoaded) return const _ItemData(item: null, sections: []);
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
