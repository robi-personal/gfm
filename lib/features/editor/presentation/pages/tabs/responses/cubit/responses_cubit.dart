import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../domain/usecases/get_responses.dart';
import 'responses_state.dart';

export 'responses_state.dart';

class ResponsesCubit extends Cubit<ResponsesState> {
  final GetResponses _getResponses;

  ResponsesCubit(this._getResponses) : super(ResponsesLoading());

  Future<void> loadResponses(String formId) async {
    emit(ResponsesLoading());
    final result = await _getResponses(formId);
    result.fold(
      (failure) => emit(ResponsesError(failure.message)),
      (responses) => emit(ResponsesLoaded(responses)),
    );
  }

  /// Refreshes without emitting a loading state — used for silent background refreshes.
  Future<void> refreshResponses(String formId) async {
    debugPrint('[responses] silent refresh for $formId');
    final result = await _getResponses(formId);
    result.fold(
      (failure) => debugPrint('[responses] refresh failed: ${failure.message}'),
      (responses) {
        debugPrint('[responses] refresh success: ${responses.length} responses');
        emit(ResponsesLoaded(responses));
      },
    );
  }
}
