import '../../../../core/models/form_response.dart';

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
