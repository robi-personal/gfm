import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_responses.dart';
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
}
