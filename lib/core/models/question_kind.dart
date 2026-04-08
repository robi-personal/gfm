import 'package:flutter/foundation.dart';

import 'choice_option.dart';
import 'enums.dart';
import 'form_image.dart';

/// Discriminated union for the question type. Each variant corresponds to one
/// of the `*Question` keys in the Forms API JSON.
@immutable
sealed class QuestionKind {
  const QuestionKind();

  /// Deserialises from the parent question JSON map. Checks which
  /// `*Question` key is present.
  factory QuestionKind.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('choiceQuestion')) {
      return ChoiceQuestion.fromJson(
          json['choiceQuestion'] as Map<String, dynamic>);
    }
    if (json.containsKey('textQuestion')) {
      return TextQuestion.fromJson(
          json['textQuestion'] as Map<String, dynamic>);
    }
    if (json.containsKey('scaleQuestion')) {
      return ScaleQuestion.fromJson(
          json['scaleQuestion'] as Map<String, dynamic>);
    }
    if (json.containsKey('dateQuestion')) {
      return DateQuestion.fromJson(
          json['dateQuestion'] as Map<String, dynamic>);
    }
    if (json.containsKey('timeQuestion')) {
      return TimeQuestion.fromJson(
          json['timeQuestion'] as Map<String, dynamic>);
    }
    if (json.containsKey('ratingQuestion')) {
      return RatingQuestion.fromJson(
          json['ratingQuestion'] as Map<String, dynamic>);
    }
    if (json.containsKey('rowQuestion')) {
      return RowQuestion.fromJson(json['rowQuestion'] as Map<String, dynamic>);
    }
    if (json.containsKey('fileUploadQuestion')) {
      return const FileUploadQuestion();
    }
    throw ArgumentError('No recognised *Question key in JSON: ${json.keys}');
  }

  /// Serialises back to the key/value pair used in the parent question map.
  MapEntry<String, dynamic> toJsonEntry();
}

@immutable
final class ChoiceQuestion extends QuestionKind {
  final ChoiceType type;
  final List<ChoiceOption> options;
  final bool shuffle;

  const ChoiceQuestion({
    required this.type,
    required this.options,
    this.shuffle = false,
  });

  factory ChoiceQuestion.fromJson(Map<String, dynamic> json) => ChoiceQuestion(
        type: ChoiceType.fromJson(json['type'] as String?),
        options: (json['options'] as List<dynamic>? ?? [])
            .map((e) => ChoiceOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        shuffle: json['shuffle'] as bool? ?? false,
      );

  @override
  MapEntry<String, dynamic> toJsonEntry() => MapEntry('choiceQuestion', {
        'type': type.toJson(),
        'options': options.map((o) => o.toJson()).toList(),
        'shuffle': shuffle,
      });

  ChoiceQuestion copyWith({
    ChoiceType? type,
    List<ChoiceOption>? options,
    bool? shuffle,
  }) =>
      ChoiceQuestion(
        type: type ?? this.type,
        options: options ?? this.options,
        shuffle: shuffle ?? this.shuffle,
      );

  @override
  bool operator ==(Object other) =>
      other is ChoiceQuestion &&
      other.type == type &&
      listEquals(other.options, options) &&
      other.shuffle == shuffle;

  @override
  int get hashCode => Object.hash(type, options, shuffle);
}

@immutable
final class TextQuestion extends QuestionKind {
  final bool paragraph;

  const TextQuestion({this.paragraph = false});

  factory TextQuestion.fromJson(Map<String, dynamic> json) =>
      TextQuestion(paragraph: json['paragraph'] as bool? ?? false);

  @override
  MapEntry<String, dynamic> toJsonEntry() =>
      MapEntry('textQuestion', {'paragraph': paragraph});

  TextQuestion copyWith({bool? paragraph}) =>
      TextQuestion(paragraph: paragraph ?? this.paragraph);

  @override
  bool operator ==(Object other) =>
      other is TextQuestion && other.paragraph == paragraph;

  @override
  int get hashCode => paragraph.hashCode;
}

@immutable
final class ScaleQuestion extends QuestionKind {
  final int low;
  final int high;
  final String? lowLabel;
  final String? highLabel;

  const ScaleQuestion({
    required this.low,
    required this.high,
    this.lowLabel,
    this.highLabel,
  });

  factory ScaleQuestion.fromJson(Map<String, dynamic> json) => ScaleQuestion(
        low: json['low'] as int? ?? 1,
        high: json['high'] as int? ?? 5,
        lowLabel: json['lowLabel'] as String?,
        highLabel: json['highLabel'] as String?,
      );

  @override
  MapEntry<String, dynamic> toJsonEntry() => MapEntry('scaleQuestion', {
        'low': low,
        'high': high,
        if (lowLabel != null) 'lowLabel': lowLabel,
        if (highLabel != null) 'highLabel': highLabel,
      });

  ScaleQuestion copyWith({
    int? low,
    int? high,
    String? lowLabel,
    String? highLabel,
  }) =>
      ScaleQuestion(
        low: low ?? this.low,
        high: high ?? this.high,
        lowLabel: lowLabel ?? this.lowLabel,
        highLabel: highLabel ?? this.highLabel,
      );

  @override
  bool operator ==(Object other) =>
      other is ScaleQuestion &&
      other.low == low &&
      other.high == high &&
      other.lowLabel == lowLabel &&
      other.highLabel == highLabel;

  @override
  int get hashCode => Object.hash(low, high, lowLabel, highLabel);
}

@immutable
final class DateQuestion extends QuestionKind {
  final bool includeTime;
  final bool includeYear;

  const DateQuestion({this.includeTime = false, this.includeYear = true});

  factory DateQuestion.fromJson(Map<String, dynamic> json) => DateQuestion(
        includeTime: json['includeTime'] as bool? ?? false,
        includeYear: json['includeYear'] as bool? ?? true,
      );

  @override
  MapEntry<String, dynamic> toJsonEntry() => MapEntry('dateQuestion', {
        'includeTime': includeTime,
        'includeYear': includeYear,
      });

  DateQuestion copyWith({bool? includeTime, bool? includeYear}) => DateQuestion(
        includeTime: includeTime ?? this.includeTime,
        includeYear: includeYear ?? this.includeYear,
      );

  @override
  bool operator ==(Object other) =>
      other is DateQuestion &&
      other.includeTime == includeTime &&
      other.includeYear == includeYear;

  @override
  int get hashCode => Object.hash(includeTime, includeYear);
}

@immutable
final class TimeQuestion extends QuestionKind {
  /// When true this is a "duration" question (HH:MM:SS), otherwise time-of-day.
  final bool duration;

  const TimeQuestion({this.duration = false});

  factory TimeQuestion.fromJson(Map<String, dynamic> json) =>
      TimeQuestion(duration: json['duration'] as bool? ?? false);

  @override
  MapEntry<String, dynamic> toJsonEntry() =>
      MapEntry('timeQuestion', {'duration': duration});

  TimeQuestion copyWith({bool? duration}) =>
      TimeQuestion(duration: duration ?? this.duration);

  @override
  bool operator ==(Object other) =>
      other is TimeQuestion && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;
}

@immutable
final class RatingQuestion extends QuestionKind {
  final int ratingScaleLevel;
  final RatingIconType iconType;

  const RatingQuestion({
    required this.ratingScaleLevel,
    this.iconType = RatingIconType.star,
  });

  factory RatingQuestion.fromJson(Map<String, dynamic> json) => RatingQuestion(
        ratingScaleLevel: json['ratingScaleLevel'] as int? ?? 5,
        iconType: RatingIconType.fromJson(json['iconType'] as String?),
      );

  @override
  MapEntry<String, dynamic> toJsonEntry() => MapEntry('ratingQuestion', {
        'ratingScaleLevel': ratingScaleLevel,
        'iconType': iconType.toJson(),
      });

  RatingQuestion copyWith({int? ratingScaleLevel, RatingIconType? iconType}) =>
      RatingQuestion(
        ratingScaleLevel: ratingScaleLevel ?? this.ratingScaleLevel,
        iconType: iconType ?? this.iconType,
      );

  @override
  bool operator ==(Object other) =>
      other is RatingQuestion &&
      other.ratingScaleLevel == ratingScaleLevel &&
      other.iconType == iconType;

  @override
  int get hashCode => Object.hash(ratingScaleLevel, iconType);
}

/// Row inside a [QuestionGroupItem]. The title is on the parent [Question].
@immutable
final class RowQuestion extends QuestionKind {
  final String title;

  const RowQuestion({required this.title});

  factory RowQuestion.fromJson(Map<String, dynamic> json) =>
      RowQuestion(title: json['title'] as String? ?? '');

  @override
  MapEntry<String, dynamic> toJsonEntry() =>
      MapEntry('rowQuestion', {'title': title});

  RowQuestion copyWith({String? title}) =>
      RowQuestion(title: title ?? this.title);

  @override
  bool operator ==(Object other) =>
      other is RowQuestion && other.title == title;

  @override
  int get hashCode => title.hashCode;
}

/// File-upload question — read-only (API does not support creating these).
@immutable
final class FileUploadQuestion extends QuestionKind {
  const FileUploadQuestion();

  @override
  MapEntry<String, dynamic> toJsonEntry() =>
      const MapEntry('fileUploadQuestion', <String, dynamic>{});

  @override
  bool operator ==(Object other) => other is FileUploadQuestion;

  @override
  int get hashCode => runtimeType.hashCode;
}

// ignore: unused_import
// FormImage is imported for future use in question image fields.
// ignore: unused_element
FormImage? _unused;
