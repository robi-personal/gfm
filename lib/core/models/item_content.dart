import 'package:flutter/foundation.dart';

import 'form_image.dart';
import 'question.dart';
import 'question_kind.dart';

/// Discriminated union for the item content kind. Each variant maps to one
/// of the `*Item` keys in the Forms API JSON.
@immutable
sealed class ItemContent {
  const ItemContent();

  factory ItemContent.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('questionItem')) {
      return QuestionItemContent.fromJson(
          json['questionItem'] as Map<String, dynamic>);
    }
    if (json.containsKey('questionGroupItem')) {
      return QuestionGroupItemContent.fromJson(
          json['questionGroupItem'] as Map<String, dynamic>);
    }
    if (json.containsKey('pageBreakItem')) {
      return const PageBreakItemContent();
    }
    if (json.containsKey('textItem')) {
      return const TextItemContent();
    }
    if (json.containsKey('imageItem')) {
      return ImageItemContent.fromJson(
          json['imageItem'] as Map<String, dynamic>);
    }
    if (json.containsKey('videoItem')) {
      return VideoItemContent.fromJson(
          json['videoItem'] as Map<String, dynamic>);
    }
    throw ArgumentError('No recognised *Item key in JSON: ${json.keys}');
  }

  /// Returns the key/value pair to embed in the parent item JSON map.
  MapEntry<String, dynamic> toJsonEntry();
}

@immutable
final class QuestionItemContent extends ItemContent {
  final Question question;
  final FormImage? image;

  const QuestionItemContent({required this.question, this.image});

  factory QuestionItemContent.fromJson(Map<String, dynamic> json) =>
      QuestionItemContent(
        question: Question.fromJson(json['question'] as Map<String, dynamic>),
        image: json['image'] == null
            ? null
            : FormImage.fromJson(json['image'] as Map<String, dynamic>),
      );

  @override
  MapEntry<String, dynamic> toJsonEntry() => MapEntry('questionItem', {
        'question': question.toJson(),
        if (image != null) 'image': image!.toJson(),
      });

  QuestionItemContent copyWith({Question? question, FormImage? image}) =>
      QuestionItemContent(
        question: question ?? this.question,
        image: image ?? this.image,
      );

  @override
  bool operator ==(Object other) =>
      other is QuestionItemContent &&
      other.question == question &&
      other.image == image;

  @override
  int get hashCode => Object.hash(question, image);
}

/// Grid definition for [QuestionGroupItemContent].
@immutable
final class Grid {
  /// Columns use a [ChoiceQuestion] whose [ChoiceQuestion.type] is RADIO or
  /// CHECKBOX; only [ChoiceQuestion.options] and [ChoiceQuestion.type] matter.
  final ChoiceQuestion columns;
  final bool shuffleQuestions;

  const Grid({required this.columns, this.shuffleQuestions = false});

  factory Grid.fromJson(Map<String, dynamic> json) => Grid(
        columns: ChoiceQuestion.fromJson(
            json['columns'] as Map<String, dynamic>),
        shuffleQuestions: json['shuffleQuestions'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'columns': {
          'type': columns.type.toJson(),
          'options': columns.options.map((o) => o.toJson()).toList(),
        },
        'shuffleQuestions': shuffleQuestions,
      };

  Grid copyWith({ChoiceQuestion? columns, bool? shuffleQuestions}) => Grid(
        columns: columns ?? this.columns,
        shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
      );

  @override
  bool operator ==(Object other) =>
      other is Grid &&
      other.columns == columns &&
      other.shuffleQuestions == shuffleQuestions;

  @override
  int get hashCode => Object.hash(columns, shuffleQuestions);
}

@immutable
final class QuestionGroupItemContent extends ItemContent {
  /// Each question here has a [RowQuestion] kind.
  final List<Question> questions;
  final FormImage? image;
  final Grid? grid;

  const QuestionGroupItemContent({
    required this.questions,
    this.image,
    this.grid,
  });

  factory QuestionGroupItemContent.fromJson(Map<String, dynamic> json) =>
      QuestionGroupItemContent(
        questions: (json['questions'] as List<dynamic>? ?? [])
            .map((e) => Question.fromJson(e as Map<String, dynamic>))
            .toList(),
        image: json['image'] == null
            ? null
            : FormImage.fromJson(json['image'] as Map<String, dynamic>),
        grid: json['grid'] == null
            ? null
            : Grid.fromJson(json['grid'] as Map<String, dynamic>),
      );

  @override
  MapEntry<String, dynamic> toJsonEntry() => MapEntry('questionGroupItem', {
        'questions': questions.map((q) => q.toJson()).toList(),
        if (image != null) 'image': image!.toJson(),
        if (grid != null) 'grid': grid!.toJson(),
      });

  QuestionGroupItemContent copyWith({
    List<Question>? questions,
    FormImage? image,
    Grid? grid,
  }) =>
      QuestionGroupItemContent(
        questions: questions ?? this.questions,
        image: image ?? this.image,
        grid: grid ?? this.grid,
      );

  @override
  bool operator ==(Object other) =>
      other is QuestionGroupItemContent &&
      listEquals(other.questions, questions) &&
      other.image == image &&
      other.grid == grid;

  @override
  int get hashCode => Object.hash(questions, image, grid);
}

/// Section divider. Everything between two [PageBreakItemContent]s is one
/// logical section in the UI.
@immutable
final class PageBreakItemContent extends ItemContent {
  const PageBreakItemContent();

  @override
  MapEntry<String, dynamic> toJsonEntry() =>
      const MapEntry('pageBreakItem', <String, dynamic>{});

  @override
  bool operator ==(Object other) => other is PageBreakItemContent;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Inert title + description block.
@immutable
final class TextItemContent extends ItemContent {
  const TextItemContent();

  @override
  MapEntry<String, dynamic> toJsonEntry() =>
      const MapEntry('textItem', <String, dynamic>{});

  @override
  bool operator ==(Object other) => other is TextItemContent;

  @override
  int get hashCode => runtimeType.hashCode;
}

@immutable
final class ImageItemContent extends ItemContent {
  final FormImage image;

  const ImageItemContent({required this.image});

  factory ImageItemContent.fromJson(Map<String, dynamic> json) =>
      ImageItemContent(
        image: FormImage.fromJson(json['image'] as Map<String, dynamic>),
      );

  @override
  MapEntry<String, dynamic> toJsonEntry() =>
      MapEntry('imageItem', {'image': image.toJson()});

  ImageItemContent copyWith({FormImage? image}) =>
      ImageItemContent(image: image ?? this.image);

  @override
  bool operator ==(Object other) =>
      other is ImageItemContent && other.image == image;

  @override
  int get hashCode => image.hashCode;
}

@immutable
final class VideoItemContent extends ItemContent {
  final FormVideo video;
  final String? caption;

  const VideoItemContent({required this.video, this.caption});

  factory VideoItemContent.fromJson(Map<String, dynamic> json) =>
      VideoItemContent(
        video: FormVideo.fromJson(json['video'] as Map<String, dynamic>),
        caption: json['caption'] as String?,
      );

  @override
  MapEntry<String, dynamic> toJsonEntry() => MapEntry('videoItem', {
        'video': video.toJson(),
        if (caption != null) 'caption': caption,
      });

  VideoItemContent copyWith({FormVideo? video, String? caption}) =>
      VideoItemContent(
        video: video ?? this.video,
        caption: caption ?? this.caption,
      );

  @override
  bool operator ==(Object other) =>
      other is VideoItemContent &&
      other.video == video &&
      other.caption == caption;

  @override
  int get hashCode => Object.hash(video, caption);
}
