import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:googleapis/forms/v1.dart' as forms_api;

import '../../core/api/concurrency.dart';
import '../../core/api/forms_client.dart';
import '../../core/models/choice_option.dart';
import '../../core/models/enums.dart';
import '../../core/models/form_doc.dart';
import '../../core/models/item.dart';
import '../../core/models/item_content.dart';
import '../../core/models/question.dart';
import '../../core/models/question_kind.dart';

part 'editor_state.dart';

class EditorCubit extends Cubit<EditorState> {
  final FormsClient _formsClient;

  EditorCubit(this._formsClient) : super(const EditorLoading());

  // ── Revision / retry tracking ──────────────────────────────────────────────
  String _revisionId = '';
  int _mismatchCount = 0;

  // ── Info debounce ──────────────────────────────────────────────────────────
  Timer? _infoDebounce;
  String? _pendingTitle;
  String? _pendingDescription;

  // ── Per-item text debounce ─────────────────────────────────────────────────
  final Map<String, Timer> _itemDebounce = {};
  final Map<String, String> _pendingItemTitle = {};
  final Map<String, String> _pendingOptionText = {}; // key: '$itemId:$optIdx'

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> loadForm(String formId) async {
    emit(const EditorLoading());
    try {
      final apiForm = await _formsClient.api.forms.get(formId);
      final json =
          jsonDecode(jsonEncode(apiForm.toJson())) as Map<String, dynamic>;
      final doc = FormDoc.fromJson(json);
      _revisionId = doc.revisionId;
      _mismatchCount = 0;
      emit(EditorLoaded(doc));
    } on SocketException {
      emit(const EditorError("Couldn't load this form.",
          kind: EditorErrorKind.network));
    } catch (e) {
      emit(switch (_tryStatus(e)) {
        404 => const EditorError('This form was deleted.',
            kind: EditorErrorKind.notFound),
        403 => const EditorError("You don't have access to this form.",
            kind: EditorErrorKind.permissionDenied),
        _ => const EditorError("Couldn't load this form.",
            kind: EditorErrorKind.network),
      });
    }
  }

  // ── Form info (step 6) ─────────────────────────────────────────────────────

  void updateTitle(String title) {
    if (state is! EditorLoaded) return;
    _pendingTitle = title;
    _emitOptimisticInfo(title: title);
    _scheduleInfoFlush();
  }

  void updateDescription(String description) {
    if (state is! EditorLoaded) return;
    _pendingDescription = description;
    _emitOptimisticInfo(description: description);
    _scheduleInfoFlush();
  }

  void _emitOptimisticInfo({String? title, String? description}) {
    if (state is! EditorLoaded) return;
    final l = state as EditorLoaded;
    emit(l.copyWith(
      form: l.form.copyWith(
        info: l.form.info.copyWith(
          title: title ?? l.form.info.title,
          description: description ?? l.form.info.description,
        ),
      ),
      saveStatus: 'saving',
    ));
  }

  void _scheduleInfoFlush() {
    _infoDebounce?.cancel();
    _infoDebounce =
        Timer(const Duration(milliseconds: 600), _flushInfo);
  }

  Future<void> _flushInfo() async {
    final title = _pendingTitle;
    final desc = _pendingDescription;
    _pendingTitle = null;
    _pendingDescription = null;
    if (title == null && desc == null) return;
    if (state is! EditorLoaded) return;

    final fields = [
      if (title != null) 'title',
      if (desc != null) 'description',
    ];
    final snapshot = state as EditorLoaded;
    await _executeBatch(
      formId: snapshot.form.formId,
      snapshot: snapshot,
      requests: [
        forms_api.Request(
          updateFormInfo: forms_api.UpdateFormInfoRequest(
            info: forms_api.Info(title: title, description: desc),
            updateMask: fields.join(','),
          ),
        ),
      ],
    );
  }

  // ── Add section (step 10) ────────────────────────────────────────────────

  Future<void> addSection() async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final insertAt = loaded.form.items.length;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final placeholder = Item(
      itemId: '_pending_$ts',
      title: 'Section',
      content: const PageBreakItemContent(),
    );
    final newItems = [...loaded.form.items, placeholder];
    emit(loaded.copyWith(
        form: loaded.form.copyWith(items: newItems), saveStatus: 'saving'));

    await _executeBatch(
      formId: loaded.form.formId,
      snapshot: loaded,
      requests: [
        forms_api.Request(
          createItem: forms_api.CreateItemRequest(
            item: forms_api.Item(
              title: 'Section',
              pageBreakItem: forms_api.PageBreakItem(),
            ),
            location: forms_api.Location(index: insertAt),
          ),
        ),
      ],
      afterSuccess: () => _silentRefresh(loaded.form.formId),
    );
  }

  // ── Update item description (step 10) ─────────────────────────────────────

  final Map<String, String> _pendingItemDescription = {};

  void updateItemDescription(String itemId, String description) {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final index = loaded.form.items.indexWhere((i) => i.itemId == itemId);
    if (index == -1) return;

    _pendingItemDescription[itemId] = description;
    final newItems = [...loaded.form.items];
    newItems[index] = newItems[index].copyWith(description: description);
    emit(loaded.copyWith(
        form: loaded.form.copyWith(items: newItems), saveStatus: 'saving'));

    final key = '${itemId}_desc';
    _itemDebounce[key]?.cancel();
    _itemDebounce[key] = Timer(const Duration(milliseconds: 600), () {
      _flushItemDescription(itemId);
    });
  }

  Future<void> _flushItemDescription(String itemId) async {
    final description = _pendingItemDescription.remove(itemId);
    if (description == null || state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final index = loaded.form.items.indexWhere((i) => i.itemId == itemId);
    if (index == -1) return;

    await _executeBatch(
      formId: loaded.form.formId,
      snapshot: loaded,
      requests: [
        forms_api.Request(
          updateItem: forms_api.UpdateItemRequest(
            item: _toApiItem(loaded.form.items[index]),
            location: forms_api.Location(index: index),
            updateMask: 'description',
          ),
        ),
      ],
    );
  }

  // ── Update option go-to (step 10) ─────────────────────────────────────────

  /// [goTo] is either a [GoToAction] wire string ('NEXT_SECTION' etc.)
  /// or a section itemId — or null to clear branching.
  Future<void> updateOptionGoTo(
      String itemId, int optionIndex, String? goTo) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final index = loaded.form.items.indexWhere((i) => i.itemId == itemId);
    if (index == -1) return;

    final item = loaded.form.items[index];
    if (item.content is! QuestionItemContent) return;
    final content = item.content as QuestionItemContent;
    if (content.question.kind is! ChoiceQuestion) return;
    final cq = content.question.kind as ChoiceQuestion;

    GoToAction? goToAction;
    String? goToSectionId;
    if (goTo == 'NEXT_SECTION') {
      goToAction = GoToAction.nextSection;
    } else if (goTo == 'RESTART_FORM') {
      goToAction = GoToAction.restartForm;
    } else if (goTo == 'SUBMIT_FORM') {
      goToAction = GoToAction.submitForm;
    } else if (goTo != null) {
      goToSectionId = goTo;
    }

    final newOptions = [...cq.options];
    newOptions[optionIndex] = newOptions[optionIndex]
        .copyWith(goToAction: goToAction, goToSectionId: goToSectionId);
    final updated = item.copyWith(
      content: content.copyWith(
        question: content.question.copyWith(
          kind: cq.copyWith(options: newOptions),
        ),
      ),
    );
    final newItems = [...loaded.form.items]..[index] = updated;
    emit(loaded.copyWith(
        form: loaded.form.copyWith(items: newItems), saveStatus: 'saving'));

    await _executeBatch(
      formId: loaded.form.formId,
      snapshot: loaded,
      requests: [
        forms_api.Request(
          updateItem: forms_api.UpdateItemRequest(
            item: _toApiItem(updated),
            location: forms_api.Location(index: index),
            updateMask: 'questionItem.question.choiceQuestion',
          ),
        ),
      ],
    );
  }

  // ── Add question (step 7) ─────────────────────────────────────────────────

  Future<void> addQuestion({int? afterIndex}) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final insertAt =
        afterIndex != null ? afterIndex + 1 : loaded.form.items.length;

    // Optimistic placeholder — replaced by reload after API success.
    final ts = DateTime.now().millisecondsSinceEpoch;
    final placeholder = Item(
      itemId: '_pending_$ts',
      title: 'Question',
      content: QuestionItemContent(
        question: Question(
          questionId: '_pending_q_$ts',
          kind: const TextQuestion(),
        ),
      ),
    );
    final newItems = [...loaded.form.items]..insert(insertAt, placeholder);
    emit(loaded.copyWith(
        form: loaded.form.copyWith(items: newItems), saveStatus: 'saving'));

    await _executeBatch(
      formId: loaded.form.formId,
      snapshot: loaded,
      requests: [
        forms_api.Request(
          createItem: forms_api.CreateItemRequest(
            item: forms_api.Item(
              title: 'Question',
              questionItem: forms_api.QuestionItem(
                question: forms_api.Question(
                  required: false,
                  textQuestion: forms_api.TextQuestion(paragraph: false),
                ),
              ),
            ),
            location: forms_api.Location(index: insertAt),
          ),
        ),
      ],
      afterSuccess: () => _silentRefresh(loaded.form.formId),
    );
  }

  // ── Delete item (step 7) ──────────────────────────────────────────────────

  Future<void> deleteItem(String itemId) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final index = loaded.form.items.indexWhere((i) => i.itemId == itemId);
    if (index == -1) return;

    final newItems = [...loaded.form.items]..removeAt(index);
    emit(loaded.copyWith(
        form: loaded.form.copyWith(items: newItems), saveStatus: 'saving'));

    await _executeBatch(
      formId: loaded.form.formId,
      snapshot: loaded,
      requests: [
        forms_api.Request(
          deleteItem: forms_api.DeleteItemRequest(
              location: forms_api.Location(index: index)),
        ),
      ],
    );
  }

  // ── Move item (step 7) ────────────────────────────────────────────────────

  Future<void> moveItem(int fromIndex, int toIndex) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    if (fromIndex == toIndex) return;

    final items = [...loaded.form.items];
    final item = items.removeAt(fromIndex);
    items.insert(toIndex, item);
    emit(loaded.copyWith(
        form: loaded.form.copyWith(items: items), saveStatus: 'saving'));

    await _executeBatch(
      formId: loaded.form.formId,
      snapshot: loaded,
      requests: [
        forms_api.Request(
          moveItem: forms_api.MoveItemRequest(
            originalLocation: forms_api.Location(index: fromIndex),
            newLocation: forms_api.Location(index: toIndex),
          ),
        ),
      ],
    );
  }

  // ── Edit item title (step 8) ──────────────────────────────────────────────

  void updateItemTitle(String itemId, String title) {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final index = loaded.form.items.indexWhere((i) => i.itemId == itemId);
    if (index == -1) return;

    _pendingItemTitle[itemId] = title;
    final newItems = [...loaded.form.items];
    newItems[index] = newItems[index].copyWith(title: title);
    emit(loaded.copyWith(
        form: loaded.form.copyWith(items: newItems), saveStatus: 'saving'));

    _itemDebounce[itemId]?.cancel();
    _itemDebounce[itemId] = Timer(const Duration(milliseconds: 600), () {
      _flushItemTitle(itemId);
    });
  }

  Future<void> _flushItemTitle(String itemId) async {
    final title = _pendingItemTitle.remove(itemId);
    if (title == null || state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final index = loaded.form.items.indexWhere((i) => i.itemId == itemId);
    if (index == -1) return;

    await _executeBatch(
      formId: loaded.form.formId,
      snapshot: loaded,
      requests: [
        forms_api.Request(
          updateItem: forms_api.UpdateItemRequest(
            item: _toApiItem(loaded.form.items[index]),
            location: forms_api.Location(index: index),
            updateMask: 'title',
          ),
        ),
      ],
    );
  }

  // ── Toggle required (step 8) ──────────────────────────────────────────────

  Future<void> updateRequired(String itemId, bool required) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final index = loaded.form.items.indexWhere((i) => i.itemId == itemId);
    if (index == -1) return;

    final item = loaded.form.items[index];
    if (item.content is! QuestionItemContent) return;
    final content = item.content as QuestionItemContent;
    final updated = item.copyWith(
      content: content.copyWith(
          question: content.question.copyWith(required: required)),
    );
    final newItems = [...loaded.form.items]..[index] = updated;
    emit(loaded.copyWith(
        form: loaded.form.copyWith(items: newItems), saveStatus: 'saving'));

    await _executeBatch(
      formId: loaded.form.formId,
      snapshot: loaded,
      requests: [
        forms_api.Request(
          updateItem: forms_api.UpdateItemRequest(
            item: _toApiItem(updated),
            location: forms_api.Location(index: index),
            updateMask: 'questionItem.question.required',
          ),
        ),
      ],
    );
  }

  // ── Change question type (step 9) ─────────────────────────────────────────

  Future<void> updateQuestionType(String itemId, QuestionKind newKind) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final index = loaded.form.items.indexWhere((i) => i.itemId == itemId);
    if (index == -1) return;

    final item = loaded.form.items[index];
    if (item.content is! QuestionItemContent) return;
    final content = item.content as QuestionItemContent;
    final updated = item.copyWith(
      content: content.copyWith(
          question: content.question.copyWith(kind: newKind)),
    );
    final newItems = [...loaded.form.items]..[index] = updated;
    emit(loaded.copyWith(
        form: loaded.form.copyWith(items: newItems), saveStatus: 'saving'));

    await _executeBatch(
      formId: loaded.form.formId,
      snapshot: loaded,
      requests: [
        forms_api.Request(
          updateItem: forms_api.UpdateItemRequest(
            item: _toApiItem(updated),
            location: forms_api.Location(index: index),
            updateMask: 'questionItem.question',
          ),
        ),
      ],
    );
  }

  // ── Edit options (step 8) ─────────────────────────────────────────────────

  Future<void> addOption(String itemId) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final index = loaded.form.items.indexWhere((i) => i.itemId == itemId);
    if (index == -1) return;

    final item = loaded.form.items[index];
    if (item.content is! QuestionItemContent) return;
    final content = item.content as QuestionItemContent;
    if (content.question.kind is! ChoiceQuestion) return;
    final cq = content.question.kind as ChoiceQuestion;

    final newOptions = [
      ...cq.options,
      ChoiceOption(value: 'Option ${cq.options.length + 1}'),
    ];
    final updated = item.copyWith(
      content: content.copyWith(
        question: content.question.copyWith(
          kind: cq.copyWith(options: newOptions),
        ),
      ),
    );
    final newItems = [...loaded.form.items]..[index] = updated;
    emit(loaded.copyWith(
        form: loaded.form.copyWith(items: newItems), saveStatus: 'saving'));

    await _executeBatch(
      formId: loaded.form.formId,
      snapshot: loaded,
      requests: [
        forms_api.Request(
          updateItem: forms_api.UpdateItemRequest(
            item: _toApiItem(updated),
            location: forms_api.Location(index: index),
            updateMask: 'questionItem.question.choiceQuestion',
          ),
        ),
      ],
    );
  }

  Future<void> removeOption(String itemId, int optionIndex) async {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final index = loaded.form.items.indexWhere((i) => i.itemId == itemId);
    if (index == -1) return;

    final item = loaded.form.items[index];
    if (item.content is! QuestionItemContent) return;
    final content = item.content as QuestionItemContent;
    if (content.question.kind is! ChoiceQuestion) return;
    final cq = content.question.kind as ChoiceQuestion;

    final newOptions = [...cq.options]..removeAt(optionIndex);
    final updated = item.copyWith(
      content: content.copyWith(
        question: content.question.copyWith(
          kind: cq.copyWith(options: newOptions),
        ),
      ),
    );
    final newItems = [...loaded.form.items]..[index] = updated;
    emit(loaded.copyWith(
        form: loaded.form.copyWith(items: newItems), saveStatus: 'saving'));

    await _executeBatch(
      formId: loaded.form.formId,
      snapshot: loaded,
      requests: [
        forms_api.Request(
          updateItem: forms_api.UpdateItemRequest(
            item: _toApiItem(updated),
            location: forms_api.Location(index: index),
            updateMask: 'questionItem.question.choiceQuestion',
          ),
        ),
      ],
    );
  }

  void updateOptionText(String itemId, int optionIndex, String value) {
    if (state is! EditorLoaded) return;
    final loaded = state as EditorLoaded;
    final index = loaded.form.items.indexWhere((i) => i.itemId == itemId);
    if (index == -1) return;

    final item = loaded.form.items[index];
    if (item.content is! QuestionItemContent) return;
    final content = item.content as QuestionItemContent;
    if (content.question.kind is! ChoiceQuestion) return;
    final cq = content.question.kind as ChoiceQuestion;

    final newOptions = [...cq.options];
    newOptions[optionIndex] = newOptions[optionIndex].copyWith(value: value);
    final updated = item.copyWith(
      content: content.copyWith(
        question: content.question.copyWith(
          kind: cq.copyWith(options: newOptions),
        ),
      ),
    );
    final newItems = [...loaded.form.items]..[index] = updated;
    emit(loaded.copyWith(
        form: loaded.form.copyWith(items: newItems), saveStatus: 'saving'));

    final debounceKey = '$itemId:$optionIndex';
    _pendingOptionText[debounceKey] = value;
    _itemDebounce[debounceKey]?.cancel();
    _itemDebounce[debounceKey] =
        Timer(const Duration(milliseconds: 600), () async {
      _pendingOptionText.remove(debounceKey);
      if (state is! EditorLoaded) return;
      final current = state as EditorLoaded;
      final i = current.form.items.indexWhere((it) => it.itemId == itemId);
      if (i == -1) return;
      await _executeBatch(
        formId: current.form.formId,
        snapshot: current,
        requests: [
          forms_api.Request(
            updateItem: forms_api.UpdateItemRequest(
              item: _toApiItem(current.form.items[i]),
              location: forms_api.Location(index: i),
              updateMask: 'questionItem.question.choiceQuestion',
            ),
          ),
        ],
      );
    });
  }

  // ── Conflict resolution (step 6) ──────────────────────────────────────────

  void clearConflict() {
    if (state is EditorLoaded) {
      emit((state as EditorLoaded).copyWith(conflictPending: false));
    }
  }

  Future<void> resolveConflictKeepMine() async {
    if (state is! EditorLoaded) return;
    clearConflict();
    try {
      final fresh =
          await _formsClient.api.forms.get((state as EditorLoaded).form.formId);
      _revisionId = fresh.revisionId ?? _revisionId;
      _mismatchCount = 0;
      if (_pendingTitle != null || _pendingDescription != null) {
        _scheduleInfoFlush();
      }
    } catch (_) {
      if (state is EditorLoaded) {
        emit((state as EditorLoaded).copyWith(saveStatus: 'saved'));
      }
    }
  }

  Future<void> resolveConflictLoadLatest() async {
    if (state is! EditorLoaded) return;
    final formId = (state as EditorLoaded).form.formId;
    clearConflict();
    _pendingTitle = null;
    _pendingDescription = null;
    _infoDebounce?.cancel();
    for (final t in _itemDebounce.values) {
      t.cancel();
    }
    _itemDebounce.clear();
    await loadForm(formId);
  }

  // ── Core batch engine ──────────────────────────────────────────────────────

  Future<void> _executeBatch({
    required String formId,
    required EditorLoaded snapshot,
    required List<forms_api.Request> requests,
    Future<void> Function()? afterSuccess,
  }) async {
    // First attempt
    try {
      _revisionId = await runBatchUpdate(
        api: _formsClient.api.forms,
        formId: formId,
        revisionId: _revisionId,
        requests: requests,
      );
      _mismatchCount = 0;
      if (afterSuccess != null) {
        await afterSuccess();
      } else {
        _emitSaved();
      }
      return;
    } catch (e) {
      if (isRevisionMismatch(e)) {
        if (_mismatchCount == 0) {
          _mismatchCount++;
          _emitStatus('retrying');
          try {
            await _refreshRevisionId(formId);
          } catch (_) {
            _rollback(snapshot);
            return;
          }
          // fall through to retry below
        } else {
          _mismatchCount = 0;
          if (state is EditorLoaded) {
            emit((state as EditorLoaded).copyWith(conflictPending: true));
          }
          return;
        }
      } else {
        final status = _tryStatus(e);
        if (status == 403) {
          _rollback(snapshot);
          emit(const EditorError("You no longer have access to this form.",
              kind: EditorErrorKind.permissionDenied));
          return;
        }
        if (status == 400) {
          // Bug in request — roll back, no retry.
          _rollback(snapshot);
          return;
        }
        // Network / 5xx — fall through to backoff retries.
      }
    }

    // Backoff retries: 1s → 3s → 8s
    for (final delay in [
      const Duration(seconds: 1),
      const Duration(seconds: 3),
      const Duration(seconds: 8),
    ]) {
      await Future<void>.delayed(delay);
      _emitStatus('retrying');
      try {
        _revisionId = await runBatchUpdate(
          api: _formsClient.api.forms,
          formId: formId,
          revisionId: _revisionId,
          requests: requests,
        );
        _mismatchCount = 0;
        if (afterSuccess != null) {
          await afterSuccess();
        } else {
          _emitSaved();
        }
        return;
      } catch (_) {
        continue;
      }
    }

    // All retries exhausted.
    _rollback(snapshot);
  }

  void _emitSaved() {
    if (state is EditorLoaded) {
      final l = state as EditorLoaded;
      emit(l.copyWith(lastKnownGood: l.form, saveStatus: 'saved'));
    }
  }

  void _emitStatus(String status) {
    if (state is EditorLoaded) {
      emit((state as EditorLoaded).copyWith(saveStatus: status));
    }
  }

  void _rollback(EditorLoaded snapshot) {
    emit(snapshot.copyWith(saveStatus: 'saved'));
  }

  Future<void> _refreshRevisionId(String formId) async {
    final fresh = await _formsClient.api.forms.get(formId);
    _revisionId = fresh.revisionId ?? _revisionId;
  }

  /// Re-fetches the form without flashing [EditorLoading].
  /// Used after structural changes (add item) to sync real item IDs
  /// while preserving scroll position, expanded state, and focus.
  Future<void> _silentRefresh(String formId) async {
    try {
      final apiForm = await _formsClient.api.forms.get(formId);
      final json =
          jsonDecode(jsonEncode(apiForm.toJson())) as Map<String, dynamic>;
      final doc = FormDoc.fromJson(json);
      _revisionId = doc.revisionId;
      _mismatchCount = 0;
      if (state is EditorLoaded) {
        emit(EditorLoaded(doc, lastKnownGood: doc, saveStatus: 'saved'));
      }
    } catch (_) {
      // Silent — optimistic state is already in place.
      _emitSaved();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Converts a domain [Item] to a googleapis [forms_api.Item] for API writes.
  /// [_removeNulls] is required because freezed's toJson() includes null fields
  /// (e.g. `"image": null`) and googleapis crashes when it finds the key present
  /// with a null value rather than the key being absent.
  forms_api.Item _toApiItem(Item item) =>
      forms_api.Item.fromJson(_removeNulls(item.toJson()));

  static Map<String, dynamic> _removeNulls(Map<String, dynamic> map) {
    return Map.fromEntries(
      map.entries
          .where((e) => e.value != null)
          .map((e) => MapEntry(
                e.key,
                e.value is Map<String, dynamic>
                    ? _removeNulls(e.value as Map<String, dynamic>)
                    : e.value is List
                        ? _removeNullsFromList(e.value as List)
                        : e.value,
              )),
    );
  }

  static List<dynamic> _removeNullsFromList(List<dynamic> list) {
    return list
        .map((e) => e is Map<String, dynamic> ? _removeNulls(e) : e)
        .toList();
  }

  @override
  Future<void> close() {
    _infoDebounce?.cancel();
    for (final t in _itemDebounce.values) {
      t.cancel();
    }
    return super.close();
  }
}

int? _tryStatus(Object e) {
  try {
    return (e as dynamic).status as int?;
  } catch (_) {
    return null;
  }
}
