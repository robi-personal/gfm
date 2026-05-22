import 'package:flutter/foundation.dart';

/// Form-level settings that the public Forms REST API does NOT expose.
/// Mutated and read via our Apps Script project (`scripts.run` →
/// `applySettings` / `readSettings`).
///
/// Every field is nullable so a partial update only sends the keys the user
/// actually changed — matches the Apps Script's "undefined keys are skipped"
/// contract.
@immutable
class ExtendedFormSettings {
  final bool? shuffleQuestions;
  final bool? limitOneResponsePerUser;
  final bool? allowResponseEdits;
  final bool? progressBar;
  final bool? showLinkToRespondAgain;
  final bool? publishingSummary;
  final bool? requireLogin;
  final String? confirmationMessage;
  final String? customClosedFormMessage;

  const ExtendedFormSettings({
    this.shuffleQuestions,
    this.limitOneResponsePerUser,
    this.allowResponseEdits,
    this.progressBar,
    this.showLinkToRespondAgain,
    this.publishingSummary,
    this.requireLogin,
    this.confirmationMessage,
    this.customClosedFormMessage,
  });

  factory ExtendedFormSettings.fromJson(Map<String, dynamic> json) =>
      ExtendedFormSettings(
        shuffleQuestions:        json['shuffleQuestions']        as bool?,
        limitOneResponsePerUser: json['limitOneResponsePerUser'] as bool?,
        allowResponseEdits:      json['allowResponseEdits']      as bool?,
        progressBar:             json['progressBar']             as bool?,
        showLinkToRespondAgain:  json['showLinkToRespondAgain']  as bool?,
        publishingSummary:       json['publishingSummary']       as bool?,
        requireLogin:            json['requireLogin']            as bool?,
        confirmationMessage:     json['confirmationMessage']     as String?,
        customClosedFormMessage: json['customClosedFormMessage'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (shuffleQuestions        != null) 'shuffleQuestions':        shuffleQuestions,
        if (limitOneResponsePerUser != null) 'limitOneResponsePerUser': limitOneResponsePerUser,
        if (allowResponseEdits      != null) 'allowResponseEdits':      allowResponseEdits,
        if (progressBar             != null) 'progressBar':             progressBar,
        if (showLinkToRespondAgain  != null) 'showLinkToRespondAgain':  showLinkToRespondAgain,
        if (publishingSummary       != null) 'publishingSummary':       publishingSummary,
        if (requireLogin            != null) 'requireLogin':            requireLogin,
        if (confirmationMessage     != null) 'confirmationMessage':     confirmationMessage,
        if (customClosedFormMessage != null) 'customClosedFormMessage': customClosedFormMessage,
      };
}
