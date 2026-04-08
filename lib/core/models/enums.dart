/// Email collection setting for a form.
enum EmailCollectionType {
  emailCollectionTypeUnspecified,
  doNotCollect,
  verified,
  responderInput;

  static EmailCollectionType fromJson(String? value) => switch (value) {
    'DO_NOT_COLLECT' => doNotCollect,
    'VERIFIED' => verified,
    'RESPONDER_INPUT' => responderInput,
    _ => emailCollectionTypeUnspecified,
  };

  String toJson() => switch (this) {
    emailCollectionTypeUnspecified => 'EMAIL_COLLECTION_TYPE_UNSPECIFIED',
    doNotCollect => 'DO_NOT_COLLECT',
    verified => 'VERIFIED',
    responderInput => 'RESPONDER_INPUT',
  };
}

/// Type of a choice question.
enum ChoiceType {
  radio,
  checkbox,
  dropDown;

  static ChoiceType fromJson(String? value) => switch (value) {
    'RADIO' => radio,
    'CHECKBOX' => checkbox,
    'DROP_DOWN' => dropDown,
    _ => radio,
  };

  String toJson() => switch (this) {
    radio => 'RADIO',
    checkbox => 'CHECKBOX',
    dropDown => 'DROP_DOWN',
  };
}

/// Navigation action for a choice option.
enum GoToAction {
  nextSection,
  restartForm,
  submitForm;

  static GoToAction fromJson(String? value) => switch (value) {
    'NEXT_SECTION' => nextSection,
    'RESTART_FORM' => restartForm,
    'SUBMIT_FORM' => submitForm,
    _ => nextSection,
  };

  String toJson() => switch (this) {
    nextSection => 'NEXT_SECTION',
    restartForm => 'RESTART_FORM',
    submitForm => 'SUBMIT_FORM',
  };
}

/// Icon type for a rating question.
enum RatingIconType {
  star,
  heart,
  thumbUp;

  static RatingIconType fromJson(String? value) => switch (value) {
    'STAR' => star,
    'HEART' => heart,
    'THUMB_UP' => thumbUp,
    _ => star,
  };

  String toJson() => switch (this) {
    star => 'STAR',
    heart => 'HEART',
    thumbUp => 'THUMB_UP',
  };
}
