function applySettings(formId, settings) {
  if (!formId || typeof formId !== 'string') {
    throw new Error('formId is required');
  }
  if (!settings || typeof settings !== 'object') {
    throw new Error('settings is required');mak
  }

  var form = FormApp.openById(formId);
  var applied = [];

  if (settings.shuffleQuestions !== undefined) {
    form.setShuffleQuestions(Boolean(settings.shuffleQuestions));
    applied.push('shuffleQuestions');
  }
  if (settings.limitOneResponsePerUser !== undefined) {
    form.setLimitOneResponsePerUser(Boolean(settings.limitOneResponsePerUser));
    applied.push('limitOneResponsePerUser');
  }
  if (settings.allowResponseEdits !== undefined) {
    form.setAllowResponseEdits(Boolean(settings.allowResponseEdits));
    applied.push('allowResponseEdits');
  }
  if (settings.progressBar !== undefined) {
    form.setProgressBar(Boolean(settings.progressBar));
    applied.push('progressBar');
  }
  if (settings.showLinkToRespondAgain !== undefined) {
    form.setShowLinkToRespondAgain(Boolean(settings.showLinkToRespondAgain));
    applied.push('showLinkToRespondAgain');
  }
  if (settings.publishingSummary !== undefined) {
    form.setPublishingSummary(Boolean(settings.publishingSummary));
    applied.push('publishingSummary');
  }
  if (settings.requireLogin !== undefined) {
    form.setRequireLogin(Boolean(settings.requireLogin));
    applied.push('requireLogin');
  }
  if (settings.confirmationMessage !== undefined) {
    form.setConfirmationMessage(String(settings.confirmationMessage));
    applied.push('confirmationMessage');
  }
  if (settings.customClosedFormMessage !== undefined) {
    form.setCustomClosedFormMessage(String(settings.customClosedFormMessage));
    applied.push('customClosedFormMessage');
  }

  return { ok: true, applied: applied, state: readState_(form) };
}

function readSettings(formId) {
  if (!formId || typeof formId !== 'string') {
    throw new Error('formId is required');
  }
  return readState_(FormApp.openById(formId));
}

function readState_(form) {
  return {
    shuffleQuestions:        readSafe_(function() { return form.getShuffleQuestions(); }),
    limitOneResponsePerUser: readSafe_(function() { return form.hasLimitOneResponsePerUser(); }),
    allowResponseEdits:      readSafe_(function() { return form.canEditResponse(); }),
    progressBar:             readSafe_(function() { return form.hasProgressBar(); }),
    showLinkToRespondAgain:  readSafe_(function() { return form.hasRespondAgainLink(); }),
    publishingSummary:       readSafe_(function() { return form.isPublishingSummary(); }),
    requireLogin:            readSafe_(function() { return form.requiresLogin(); }),
    confirmationMessage:     readSafe_(function() { return form.getConfirmationMessage(); }),
    customClosedFormMessage: readSafe_(function() { return form.getCustomClosedFormMessage(); }),
  };
}

function readSafe_(getter) {
  try {
    return getter();
  } catch (err) {
    console.warn('readSafe_ getter threw: ' + err);
    return null;
  }
}
