// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'grading.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Feedback _$FeedbackFromJson(Map<String, dynamic> json) {
  return _Feedback.fromJson(json);
}

/// @nodoc
mixin _$Feedback {
  String get text => throw _privateConstructorUsedError;

  /// Serializes this Feedback to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Feedback
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeedbackCopyWith<Feedback> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeedbackCopyWith<$Res> {
  factory $FeedbackCopyWith(Feedback value, $Res Function(Feedback) then) =
      _$FeedbackCopyWithImpl<$Res, Feedback>;
  @useResult
  $Res call({String text});
}

/// @nodoc
class _$FeedbackCopyWithImpl<$Res, $Val extends Feedback>
    implements $FeedbackCopyWith<$Res> {
  _$FeedbackCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Feedback
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? text = null}) {
    return _then(
      _value.copyWith(
            text: null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FeedbackImplCopyWith<$Res>
    implements $FeedbackCopyWith<$Res> {
  factory _$$FeedbackImplCopyWith(
    _$FeedbackImpl value,
    $Res Function(_$FeedbackImpl) then,
  ) = __$$FeedbackImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String text});
}

/// @nodoc
class __$$FeedbackImplCopyWithImpl<$Res>
    extends _$FeedbackCopyWithImpl<$Res, _$FeedbackImpl>
    implements _$$FeedbackImplCopyWith<$Res> {
  __$$FeedbackImplCopyWithImpl(
    _$FeedbackImpl _value,
    $Res Function(_$FeedbackImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Feedback
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? text = null}) {
    return _then(
      _$FeedbackImpl(
        text: null == text
            ? _value.text
            : text // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FeedbackImpl implements _Feedback {
  const _$FeedbackImpl({required this.text});

  factory _$FeedbackImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeedbackImplFromJson(json);

  @override
  final String text;

  @override
  String toString() {
    return 'Feedback(text: $text)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeedbackImpl &&
            (identical(other.text, text) || other.text == text));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, text);

  /// Create a copy of Feedback
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeedbackImplCopyWith<_$FeedbackImpl> get copyWith =>
      __$$FeedbackImplCopyWithImpl<_$FeedbackImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FeedbackImplToJson(this);
  }
}

abstract class _Feedback implements Feedback {
  const factory _Feedback({required final String text}) = _$FeedbackImpl;

  factory _Feedback.fromJson(Map<String, dynamic> json) =
      _$FeedbackImpl.fromJson;

  @override
  String get text;

  /// Create a copy of Feedback
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeedbackImplCopyWith<_$FeedbackImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CorrectAnswer _$CorrectAnswerFromJson(Map<String, dynamic> json) {
  return _CorrectAnswer.fromJson(json);
}

/// @nodoc
mixin _$CorrectAnswer {
  String get value => throw _privateConstructorUsedError;

  /// Serializes this CorrectAnswer to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CorrectAnswer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CorrectAnswerCopyWith<CorrectAnswer> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CorrectAnswerCopyWith<$Res> {
  factory $CorrectAnswerCopyWith(
    CorrectAnswer value,
    $Res Function(CorrectAnswer) then,
  ) = _$CorrectAnswerCopyWithImpl<$Res, CorrectAnswer>;
  @useResult
  $Res call({String value});
}

/// @nodoc
class _$CorrectAnswerCopyWithImpl<$Res, $Val extends CorrectAnswer>
    implements $CorrectAnswerCopyWith<$Res> {
  _$CorrectAnswerCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CorrectAnswer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? value = null}) {
    return _then(
      _value.copyWith(
            value: null == value
                ? _value.value
                : value // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CorrectAnswerImplCopyWith<$Res>
    implements $CorrectAnswerCopyWith<$Res> {
  factory _$$CorrectAnswerImplCopyWith(
    _$CorrectAnswerImpl value,
    $Res Function(_$CorrectAnswerImpl) then,
  ) = __$$CorrectAnswerImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String value});
}

/// @nodoc
class __$$CorrectAnswerImplCopyWithImpl<$Res>
    extends _$CorrectAnswerCopyWithImpl<$Res, _$CorrectAnswerImpl>
    implements _$$CorrectAnswerImplCopyWith<$Res> {
  __$$CorrectAnswerImplCopyWithImpl(
    _$CorrectAnswerImpl _value,
    $Res Function(_$CorrectAnswerImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CorrectAnswer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? value = null}) {
    return _then(
      _$CorrectAnswerImpl(
        value: null == value
            ? _value.value
            : value // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CorrectAnswerImpl implements _CorrectAnswer {
  const _$CorrectAnswerImpl({required this.value});

  factory _$CorrectAnswerImpl.fromJson(Map<String, dynamic> json) =>
      _$$CorrectAnswerImplFromJson(json);

  @override
  final String value;

  @override
  String toString() {
    return 'CorrectAnswer(value: $value)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CorrectAnswerImpl &&
            (identical(other.value, value) || other.value == value));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, value);

  /// Create a copy of CorrectAnswer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CorrectAnswerImplCopyWith<_$CorrectAnswerImpl> get copyWith =>
      __$$CorrectAnswerImplCopyWithImpl<_$CorrectAnswerImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CorrectAnswerImplToJson(this);
  }
}

abstract class _CorrectAnswer implements CorrectAnswer {
  const factory _CorrectAnswer({required final String value}) =
      _$CorrectAnswerImpl;

  factory _CorrectAnswer.fromJson(Map<String, dynamic> json) =
      _$CorrectAnswerImpl.fromJson;

  @override
  String get value;

  /// Create a copy of CorrectAnswer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CorrectAnswerImplCopyWith<_$CorrectAnswerImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CorrectAnswers _$CorrectAnswersFromJson(Map<String, dynamic> json) {
  return _CorrectAnswers.fromJson(json);
}

/// @nodoc
mixin _$CorrectAnswers {
  List<CorrectAnswer> get answers => throw _privateConstructorUsedError;

  /// Serializes this CorrectAnswers to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CorrectAnswers
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CorrectAnswersCopyWith<CorrectAnswers> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CorrectAnswersCopyWith<$Res> {
  factory $CorrectAnswersCopyWith(
    CorrectAnswers value,
    $Res Function(CorrectAnswers) then,
  ) = _$CorrectAnswersCopyWithImpl<$Res, CorrectAnswers>;
  @useResult
  $Res call({List<CorrectAnswer> answers});
}

/// @nodoc
class _$CorrectAnswersCopyWithImpl<$Res, $Val extends CorrectAnswers>
    implements $CorrectAnswersCopyWith<$Res> {
  _$CorrectAnswersCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CorrectAnswers
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? answers = null}) {
    return _then(
      _value.copyWith(
            answers: null == answers
                ? _value.answers
                : answers // ignore: cast_nullable_to_non_nullable
                      as List<CorrectAnswer>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$CorrectAnswersImplCopyWith<$Res>
    implements $CorrectAnswersCopyWith<$Res> {
  factory _$$CorrectAnswersImplCopyWith(
    _$CorrectAnswersImpl value,
    $Res Function(_$CorrectAnswersImpl) then,
  ) = __$$CorrectAnswersImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<CorrectAnswer> answers});
}

/// @nodoc
class __$$CorrectAnswersImplCopyWithImpl<$Res>
    extends _$CorrectAnswersCopyWithImpl<$Res, _$CorrectAnswersImpl>
    implements _$$CorrectAnswersImplCopyWith<$Res> {
  __$$CorrectAnswersImplCopyWithImpl(
    _$CorrectAnswersImpl _value,
    $Res Function(_$CorrectAnswersImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of CorrectAnswers
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? answers = null}) {
    return _then(
      _$CorrectAnswersImpl(
        answers: null == answers
            ? _value._answers
            : answers // ignore: cast_nullable_to_non_nullable
                  as List<CorrectAnswer>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$CorrectAnswersImpl implements _CorrectAnswers {
  const _$CorrectAnswersImpl({final List<CorrectAnswer> answers = const []})
    : _answers = answers;

  factory _$CorrectAnswersImpl.fromJson(Map<String, dynamic> json) =>
      _$$CorrectAnswersImplFromJson(json);

  final List<CorrectAnswer> _answers;
  @override
  @JsonKey()
  List<CorrectAnswer> get answers {
    if (_answers is EqualUnmodifiableListView) return _answers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_answers);
  }

  @override
  String toString() {
    return 'CorrectAnswers(answers: $answers)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CorrectAnswersImpl &&
            const DeepCollectionEquality().equals(other._answers, _answers));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_answers));

  /// Create a copy of CorrectAnswers
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CorrectAnswersImplCopyWith<_$CorrectAnswersImpl> get copyWith =>
      __$$CorrectAnswersImplCopyWithImpl<_$CorrectAnswersImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$CorrectAnswersImplToJson(this);
  }
}

abstract class _CorrectAnswers implements CorrectAnswers {
  const factory _CorrectAnswers({final List<CorrectAnswer> answers}) =
      _$CorrectAnswersImpl;

  factory _CorrectAnswers.fromJson(Map<String, dynamic> json) =
      _$CorrectAnswersImpl.fromJson;

  @override
  List<CorrectAnswer> get answers;

  /// Create a copy of CorrectAnswers
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CorrectAnswersImplCopyWith<_$CorrectAnswersImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Grading _$GradingFromJson(Map<String, dynamic> json) {
  return _Grading.fromJson(json);
}

/// @nodoc
mixin _$Grading {
  int get pointValue => throw _privateConstructorUsedError;
  CorrectAnswers? get correctAnswers => throw _privateConstructorUsedError;
  Feedback? get whenRight => throw _privateConstructorUsedError;
  Feedback? get whenWrong => throw _privateConstructorUsedError;
  Feedback? get generalFeedback => throw _privateConstructorUsedError;

  /// Serializes this Grading to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Grading
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GradingCopyWith<Grading> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GradingCopyWith<$Res> {
  factory $GradingCopyWith(Grading value, $Res Function(Grading) then) =
      _$GradingCopyWithImpl<$Res, Grading>;
  @useResult
  $Res call({
    int pointValue,
    CorrectAnswers? correctAnswers,
    Feedback? whenRight,
    Feedback? whenWrong,
    Feedback? generalFeedback,
  });

  $CorrectAnswersCopyWith<$Res>? get correctAnswers;
  $FeedbackCopyWith<$Res>? get whenRight;
  $FeedbackCopyWith<$Res>? get whenWrong;
  $FeedbackCopyWith<$Res>? get generalFeedback;
}

/// @nodoc
class _$GradingCopyWithImpl<$Res, $Val extends Grading>
    implements $GradingCopyWith<$Res> {
  _$GradingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Grading
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pointValue = null,
    Object? correctAnswers = freezed,
    Object? whenRight = freezed,
    Object? whenWrong = freezed,
    Object? generalFeedback = freezed,
  }) {
    return _then(
      _value.copyWith(
            pointValue: null == pointValue
                ? _value.pointValue
                : pointValue // ignore: cast_nullable_to_non_nullable
                      as int,
            correctAnswers: freezed == correctAnswers
                ? _value.correctAnswers
                : correctAnswers // ignore: cast_nullable_to_non_nullable
                      as CorrectAnswers?,
            whenRight: freezed == whenRight
                ? _value.whenRight
                : whenRight // ignore: cast_nullable_to_non_nullable
                      as Feedback?,
            whenWrong: freezed == whenWrong
                ? _value.whenWrong
                : whenWrong // ignore: cast_nullable_to_non_nullable
                      as Feedback?,
            generalFeedback: freezed == generalFeedback
                ? _value.generalFeedback
                : generalFeedback // ignore: cast_nullable_to_non_nullable
                      as Feedback?,
          )
          as $Val,
    );
  }

  /// Create a copy of Grading
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CorrectAnswersCopyWith<$Res>? get correctAnswers {
    if (_value.correctAnswers == null) {
      return null;
    }

    return $CorrectAnswersCopyWith<$Res>(_value.correctAnswers!, (value) {
      return _then(_value.copyWith(correctAnswers: value) as $Val);
    });
  }

  /// Create a copy of Grading
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeedbackCopyWith<$Res>? get whenRight {
    if (_value.whenRight == null) {
      return null;
    }

    return $FeedbackCopyWith<$Res>(_value.whenRight!, (value) {
      return _then(_value.copyWith(whenRight: value) as $Val);
    });
  }

  /// Create a copy of Grading
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeedbackCopyWith<$Res>? get whenWrong {
    if (_value.whenWrong == null) {
      return null;
    }

    return $FeedbackCopyWith<$Res>(_value.whenWrong!, (value) {
      return _then(_value.copyWith(whenWrong: value) as $Val);
    });
  }

  /// Create a copy of Grading
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeedbackCopyWith<$Res>? get generalFeedback {
    if (_value.generalFeedback == null) {
      return null;
    }

    return $FeedbackCopyWith<$Res>(_value.generalFeedback!, (value) {
      return _then(_value.copyWith(generalFeedback: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$GradingImplCopyWith<$Res> implements $GradingCopyWith<$Res> {
  factory _$$GradingImplCopyWith(
    _$GradingImpl value,
    $Res Function(_$GradingImpl) then,
  ) = __$$GradingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int pointValue,
    CorrectAnswers? correctAnswers,
    Feedback? whenRight,
    Feedback? whenWrong,
    Feedback? generalFeedback,
  });

  @override
  $CorrectAnswersCopyWith<$Res>? get correctAnswers;
  @override
  $FeedbackCopyWith<$Res>? get whenRight;
  @override
  $FeedbackCopyWith<$Res>? get whenWrong;
  @override
  $FeedbackCopyWith<$Res>? get generalFeedback;
}

/// @nodoc
class __$$GradingImplCopyWithImpl<$Res>
    extends _$GradingCopyWithImpl<$Res, _$GradingImpl>
    implements _$$GradingImplCopyWith<$Res> {
  __$$GradingImplCopyWithImpl(
    _$GradingImpl _value,
    $Res Function(_$GradingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Grading
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pointValue = null,
    Object? correctAnswers = freezed,
    Object? whenRight = freezed,
    Object? whenWrong = freezed,
    Object? generalFeedback = freezed,
  }) {
    return _then(
      _$GradingImpl(
        pointValue: null == pointValue
            ? _value.pointValue
            : pointValue // ignore: cast_nullable_to_non_nullable
                  as int,
        correctAnswers: freezed == correctAnswers
            ? _value.correctAnswers
            : correctAnswers // ignore: cast_nullable_to_non_nullable
                  as CorrectAnswers?,
        whenRight: freezed == whenRight
            ? _value.whenRight
            : whenRight // ignore: cast_nullable_to_non_nullable
                  as Feedback?,
        whenWrong: freezed == whenWrong
            ? _value.whenWrong
            : whenWrong // ignore: cast_nullable_to_non_nullable
                  as Feedback?,
        generalFeedback: freezed == generalFeedback
            ? _value.generalFeedback
            : generalFeedback // ignore: cast_nullable_to_non_nullable
                  as Feedback?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GradingImpl implements _Grading {
  const _$GradingImpl({
    this.pointValue = 0,
    this.correctAnswers,
    this.whenRight,
    this.whenWrong,
    this.generalFeedback,
  });

  factory _$GradingImpl.fromJson(Map<String, dynamic> json) =>
      _$$GradingImplFromJson(json);

  @override
  @JsonKey()
  final int pointValue;
  @override
  final CorrectAnswers? correctAnswers;
  @override
  final Feedback? whenRight;
  @override
  final Feedback? whenWrong;
  @override
  final Feedback? generalFeedback;

  @override
  String toString() {
    return 'Grading(pointValue: $pointValue, correctAnswers: $correctAnswers, whenRight: $whenRight, whenWrong: $whenWrong, generalFeedback: $generalFeedback)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GradingImpl &&
            (identical(other.pointValue, pointValue) ||
                other.pointValue == pointValue) &&
            (identical(other.correctAnswers, correctAnswers) ||
                other.correctAnswers == correctAnswers) &&
            (identical(other.whenRight, whenRight) ||
                other.whenRight == whenRight) &&
            (identical(other.whenWrong, whenWrong) ||
                other.whenWrong == whenWrong) &&
            (identical(other.generalFeedback, generalFeedback) ||
                other.generalFeedback == generalFeedback));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    pointValue,
    correctAnswers,
    whenRight,
    whenWrong,
    generalFeedback,
  );

  /// Create a copy of Grading
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GradingImplCopyWith<_$GradingImpl> get copyWith =>
      __$$GradingImplCopyWithImpl<_$GradingImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GradingImplToJson(this);
  }
}

abstract class _Grading implements Grading {
  const factory _Grading({
    final int pointValue,
    final CorrectAnswers? correctAnswers,
    final Feedback? whenRight,
    final Feedback? whenWrong,
    final Feedback? generalFeedback,
  }) = _$GradingImpl;

  factory _Grading.fromJson(Map<String, dynamic> json) = _$GradingImpl.fromJson;

  @override
  int get pointValue;
  @override
  CorrectAnswers? get correctAnswers;
  @override
  Feedback? get whenRight;
  @override
  Feedback? get whenWrong;
  @override
  Feedback? get generalFeedback;

  /// Create a copy of Grading
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GradingImplCopyWith<_$GradingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
