import 'dart:developer' as dev;
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:googleapis/forms/v1.dart' as forms_api;

import '../../../../core/error/failure.dart';
import '../../domain/entities/generated_form.dart';
import '../../domain/entities/user_status.dart';
import '../../domain/repositories/ai_form_repository.dart';
import '../datasources/ai_form_datasource.dart';
import '../../../dashboard/data/datasources/forms_datasource.dart';

class AiFormRepositoryImpl implements AiFormRepository {
  final AiFormDataSource _aiDataSource;
  final FormsDataSource _formsDataSource;

  AiFormRepositoryImpl({
    required AiFormDataSource aiDataSource,
    required FormsDataSource formsDataSource,
  })  : _aiDataSource = aiDataSource,
        _formsDataSource = formsDataSource;

  @override
  Future<Either<Failure, UserStatus>> getUserStatus() async {
    try {
      return Right(await _aiDataSource.getUserStatus());
    } on SocketException {
      return const Left(NetworkFailure());
    } on Failure catch (f) {
      return Left(f);
    } catch (e, st) {
      dev.log('[AiFormRepo] getUserStatus error: $e',
          name: 'AI', error: e, stackTrace: st);
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, GenerateFormResult>> generateForm({
    required Map<String, dynamic> requestBody,
    required String idempotencyKey,
  }) async {
    try {
      return Right(await _aiDataSource.generateForm(
        requestBody: requestBody,
        idempotencyKey: idempotencyKey,
      ));
    } on SocketException {
      return const Left(NetworkFailure());
    } on Failure catch (f) {
      return Left(f);
    } catch (e, st) {
      dev.log('[AiFormRepo] generateForm error: $e',
          name: 'AI', error: e, stackTrace: st);
      return const Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, String>> createFormFromAi(
      GeneratedForm generatedForm) async {
    try {
      // Step 1: Create form — documentTitle (Drive name) can only be set here.
      final created = await _formsDataSource.createForm(
        generatedForm.title,
        documentTitle: generatedForm.title,
      );
      final formId = created.formId!;

      // Step 2: Publish the form (required since March 31 2026)
      await _formsDataSource.publishForm(formId);

      // Step 3: Enable quiz mode before adding questions so grading is accepted.
      if (generatedForm.isQuiz) {
        await _formsDataSource.enableQuizMode(formId);
      }

      // Step 4: Build requests — title + description + questions — then batchUpdate once.
      final requests = <forms_api.Request>[];

      requests.add(forms_api.Request(
        updateFormInfo: forms_api.UpdateFormInfoRequest(
          info: forms_api.Info(title: generatedForm.title),
          updateMask: 'title',
        ),
      ));

      if (generatedForm.description?.isNotEmpty == true) {
        requests.add(forms_api.Request(
          updateFormInfo: forms_api.UpdateFormInfoRequest(
            info: forms_api.Info(description: generatedForm.description),
            updateMask: 'description',
          ),
        ));
      }

      requests.addAll(generatedForm.questions
          .asMap()
          .entries
          .map((e) => _buildCreateItemRequest(e.value, e.key)));

      if (requests.isNotEmpty) {
        await _formsDataSource.batchUpdate(formId, requests);
      }

      return Right(formId);
    } on SocketException {
      return const Left(NetworkFailure());
    } on Failure catch (f) {
      return Left(f);
    } catch (e, st) {
      dev.log('[AiFormRepo] createFormFromAi error: $e',
          name: 'AI', error: e, stackTrace: st);
      return const Left(ServerFailure("Couldn't create form."));
    }
  }

  /// Maps an [AiQuestion] to a [forms_api.Request] createItem call.
  /// Per feature-spec-flutter.md §7.5.
  forms_api.Request _buildCreateItemRequest(AiQuestion q, int index) {
    final item = forms_api.Item(
      title: q.title,
      description: q.description?.isNotEmpty == true ? q.description : null,
      questionItem: forms_api.QuestionItem(
        question: _buildQuestion(q),
      ),
    );

    return forms_api.Request(
      createItem: forms_api.CreateItemRequest(
        item: item,
        location: forms_api.Location(index: index),
      ),
    );
  }
}

forms_api.Question _buildQuestion(AiQuestion q) {
  return switch (q.type) {
    AiQuestionType.shortAnswer => forms_api.Question(
        required: q.required,
        textQuestion: forms_api.TextQuestion(paragraph: false),
        grading: _buildGrading(q),
      ),
    AiQuestionType.paragraph => forms_api.Question(
        required: q.required,
        textQuestion: forms_api.TextQuestion(paragraph: true),
      ),
    AiQuestionType.multipleChoice => forms_api.Question(
        required: q.required,
        choiceQuestion: forms_api.ChoiceQuestion(
          type: 'RADIO',
          options: (q.options ?? [])
              .map((v) => forms_api.Option(value: v))
              .toList(),
        ),
        grading: _buildGrading(q),
      ),
    AiQuestionType.checkboxes => forms_api.Question(
        required: q.required,
        choiceQuestion: forms_api.ChoiceQuestion(
          type: 'CHECKBOX',
          options: (q.options ?? [])
              .map((v) => forms_api.Option(value: v))
              .toList(),
        ),
        grading: _buildGrading(q),
      ),
    AiQuestionType.dropdown => forms_api.Question(
        required: q.required,
        choiceQuestion: forms_api.ChoiceQuestion(
          type: 'DROP_DOWN',
          options: (q.options ?? [])
              .map((v) => forms_api.Option(value: v))
              .toList(),
        ),
        grading: _buildGrading(q),
      ),
    AiQuestionType.linearScale => forms_api.Question(
        required: q.required,
        scaleQuestion: forms_api.ScaleQuestion(
          low: q.scaleMin,
          high: q.scaleMax,
          lowLabel: q.scaleMinLabel?.isNotEmpty == true ? q.scaleMinLabel : null,
          highLabel: q.scaleMaxLabel?.isNotEmpty == true ? q.scaleMaxLabel : null,
        ),
      ),
    AiQuestionType.date => forms_api.Question(
        required: q.required,
        dateQuestion: forms_api.DateQuestion(
          includeTime: false,
          includeYear: true,
        ),
      ),
    AiQuestionType.time => forms_api.Question(
        required: q.required,
        timeQuestion: forms_api.TimeQuestion(duration: false),
      ),
    AiQuestionType.rating => forms_api.Question(
        required: q.required,
        ratingQuestion: forms_api.RatingQuestion(
          ratingScaleLevel: q.ratingScale,
          iconType: 'STAR',
        ),
      ),
  };
}

/// Builds the Forms API Grading object from AiQuestion.grading.
///
/// Per the Forms API: whenRight/whenWrong are only valid on choice questions
/// (RADIO/CHECKBOX/DROP_DOWN); for SHORT_ANSWER they must be expressed as
/// generalFeedback instead.
forms_api.Grading? _buildGrading(AiQuestion q) {
  final g = q.grading;
  if (g == null) return null;

  final correct = forms_api.CorrectAnswers(
    answers: g.correctAnswers
        .map((v) => forms_api.CorrectAnswer(value: v))
        .toList(),
  );

  if (q.type == AiQuestionType.shortAnswer) {
    final feedbackText = g.whenWrong ?? g.whenRight;
    return forms_api.Grading(
      correctAnswers: correct,
      pointValue: g.pointValue,
      generalFeedback: feedbackText == null
          ? null
          : forms_api.Feedback(text: feedbackText),
    );
  }

  return forms_api.Grading(
    correctAnswers: correct,
    pointValue: g.pointValue,
    whenRight: g.whenRight == null ? null : forms_api.Feedback(text: g.whenRight),
    whenWrong: g.whenWrong == null ? null : forms_api.Feedback(text: g.whenWrong),
  );
}
