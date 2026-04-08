part of 'form_detail_cubit.dart';

sealed class FormDetailState {
  const FormDetailState();
}

class FormDetailLoading extends FormDetailState {
  const FormDetailLoading();
}

class FormDetailLoaded extends FormDetailState {
  final FormDoc form;
  const FormDetailLoaded(this.form);
}

class FormDetailError extends FormDetailState {
  final String message;
  final FormDetailErrorKind kind;
  const FormDetailError(this.message, {this.kind = FormDetailErrorKind.network});
}

enum FormDetailErrorKind { notFound, permissionDenied, network }
