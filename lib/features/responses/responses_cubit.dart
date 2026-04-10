import 'dart:developer' as dev;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/api/forms_client.dart';
import '../../core/models/form_response.dart';

// ── State ─────────────────────────────────────────────────────────────────────

sealed class ResponsesState {}

class ResponsesLoading extends ResponsesState {}

class ResponsesLoaded extends ResponsesState {
  final List<FormResponse> responses;
  ResponsesLoaded(this.responses);
}

class ResponsesError extends ResponsesState {
  final String message;
  ResponsesError(this.message);
}

// ── Cubit ─────────────────────────────────────────────────────────────────────

class ResponsesCubit extends Cubit<ResponsesState> {
  final FormsClient _client;

  ResponsesCubit(this._client) : super(ResponsesLoading());

  Future<void> loadResponses(String formId) async {
    emit(ResponsesLoading());
    try {
      final raw = <FormResponse>[];
      String? pageToken;
      do {
        final result = await _client.api.forms.responses.list(
          formId,
          pageSize: 100,
          pageToken: pageToken,
        );
        final batch = result.responses ?? [];
        raw.addAll(batch.map(FormResponse.fromApi));
        pageToken = result.nextPageToken;
      } while (pageToken != null);

      raw.sort((a, b) => b.createTime.compareTo(a.createTime));
      emit(ResponsesLoaded(raw));
    } catch (e, st) {
      dev.log('[ResponsesCubit] loadResponses error: $e', name: 'API', error: e, stackTrace: st);
      emit(ResponsesError("Couldn't load responses."));
    }
  }
}
