import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:form_manager/core/models/enums.dart';
import 'package:form_manager/core/models/form_doc.dart';
import 'package:form_manager/core/models/item_content.dart';
import 'package:form_manager/core/models/question_kind.dart';

Map<String, dynamic> _loadFixture(String name) {
  final file = File('test/fixtures/forms_api/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('FormDoc — simple_form.json', () {
    late FormDoc form;

    setUpAll(() {
      form = FormDoc.fromJson(_loadFixture('simple_form.json'));
    });

    test('top-level fields', () {
      expect(form.formId, '1FAIpQLSabc123');
      expect(form.revisionId, '00000001');
      expect(form.responderUri, contains('viewform'));
    });

    test('info', () {
      expect(form.info.title, 'Simple Survey');
      expect(form.info.documentTitle, 'Simple Survey');
      expect(form.info.description, 'A short survey for testing');
    });

    test('settings — not a quiz, do not collect email', () {
      expect(form.settings.quizSettings.isQuiz, isFalse);
      expect(form.settings.emailCollectionType, EmailCollectionType.doNotCollect);
    });

    test('publishSettings', () {
      expect(form.publishSettings.publishState.isPublished, isTrue);
      expect(form.publishSettings.publishState.isAcceptingResponses, isTrue);
    });

    test('item count', () => expect(form.items.length, 10));

    test('short-answer question (item001)', () {
      final item = form.items[0];
      expect(item.itemId, 'item001');
      expect(item.title, 'What is your name?');
      final content = item.content as QuestionItemContent;
      expect(content.question.questionId, 'q001');
      expect(content.question.required, isTrue);
      final kind = content.question.kind as TextQuestion;
      expect(kind.paragraph, isFalse);
    });

    test('paragraph question (item002)', () {
      final item = form.items[1];
      expect(item.description, 'At least 2 sentences');
      final kind =
          (item.content as QuestionItemContent).question.kind as TextQuestion;
      expect(kind.paragraph, isTrue);
    });

    test('radio choice question with isOther option (item003)', () {
      final kind = (form.items[2].content as QuestionItemContent)
          .question
          .kind as ChoiceQuestion;
      expect(kind.type, ChoiceType.radio);
      expect(kind.options.length, 4);
      expect(kind.options.last.isOther, isTrue);
    });

    test('checkbox question with shuffle (item004)', () {
      final kind = (form.items[3].content as QuestionItemContent)
          .question
          .kind as ChoiceQuestion;
      expect(kind.type, ChoiceType.checkbox);
      expect(kind.shuffle, isTrue);
    });

    test('page break item (item005)', () {
      final item = form.items[4];
      expect(item.content, isA<PageBreakItemContent>());
      expect(item.title, 'Section 2');
    });

    test('dropdown question (item006)', () {
      final kind = (form.items[5].content as QuestionItemContent)
          .question
          .kind as ChoiceQuestion;
      expect(kind.type, ChoiceType.dropDown);
      expect(kind.options.map((o) => o.value), contains('Australia'));
    });

    test('scale question (item007)', () {
      final kind = (form.items[6].content as QuestionItemContent)
          .question
          .kind as ScaleQuestion;
      expect(kind.low, 1);
      expect(kind.high, 5);
      expect(kind.lowLabel, 'Very poor');
      expect(kind.highLabel, 'Excellent');
    });

    test('date question (item008)', () {
      final kind = (form.items[7].content as QuestionItemContent)
          .question
          .kind as DateQuestion;
      expect(kind.includeTime, isFalse);
      expect(kind.includeYear, isTrue);
    });

    test('time question (item009)', () {
      final kind = (form.items[8].content as QuestionItemContent)
          .question
          .kind as TimeQuestion;
      expect(kind.duration, isFalse);
    });

    test('text item (item010)', () {
      expect(form.items[9].content, isA<TextItemContent>());
    });

    test('round-trip: toJson → fromJson preserves equality', () {
      final json = form.toJson();
      final roundTripped = FormDoc.fromJson(json);
      expect(roundTripped, equals(form));
    });
  });

  group('FormDoc — quiz_form.json', () {
    late FormDoc form;

    setUpAll(() {
      form = FormDoc.fromJson(_loadFixture('quiz_form.json'));
    });

    test('quiz settings', () {
      expect(form.settings.quizSettings.isQuiz, isTrue);
      expect(form.settings.emailCollectionType, EmailCollectionType.verified);
    });

    test('graded radio question with feedback (qi001)', () {
      final q = (form.items[0].content as QuestionItemContent).question;
      expect(q.grading, isNotNull);
      expect(q.grading!.pointValue, 2);
      expect(q.grading!.correctAnswers!.answers.first.value, 'Paris');
      expect(q.grading!.whenRight, isNotNull);
      expect(q.grading!.whenWrong, isNotNull);
    });

    test('graded text question with general feedback (qi002)', () {
      final q = (form.items[1].content as QuestionItemContent).question;
      expect(q.grading!.pointValue, 3);
      expect(q.grading!.generalFeedback!.text, contains('Tokyo'));
    });

    test('rating question (qi003)', () {
      final kind = (form.items[2].content as QuestionItemContent)
          .question
          .kind as RatingQuestion;
      expect(kind.ratingScaleLevel, 5);
      expect(kind.iconType, RatingIconType.star);
    });

    test('question group item with grid (qi004)', () {
      final content =
          form.items[3].content as QuestionGroupItemContent;
      expect(content.questions.length, 3);
      expect(content.questions[0].kind, isA<RowQuestion>());
      expect((content.questions[0].kind as RowQuestion).title, 'Brazil');
      expect(content.grid, isNotNull);
      expect(content.grid!.columns.options.length, 4);
      expect(content.grid!.shuffleQuestions, isFalse);
    });

    test('round-trip: toJson → fromJson preserves equality', () {
      final json = form.toJson();
      final roundTripped = FormDoc.fromJson(json);
      expect(roundTripped, equals(form));
    });
  });

  group('FormSettings defaults', () {
    test('missing settings block uses defaults', () {
      final form = FormDoc.fromJson({
        'formId': 'x',
        'info': {'title': 'T', 'documentTitle': 'T'},
        'revisionId': '1',
        'responderUri': 'https://example.com',
        'publishSettings': {
          'publishState': {'isPublished': false, 'isAcceptingResponses': false}
        },
      });
      expect(form.settings.quizSettings.isQuiz, isFalse);
      expect(form.items, isEmpty);
    });
  });
}
