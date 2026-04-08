import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/di/injection.dart';
import '../../core/widgets/error_modal.dart';
import 'form_detail_cubit.dart';

/// Temporary JSON-dump screen for step 2 of the build order.
/// Will be replaced by the real editor in step 5.
class FormDetailScreen extends StatelessWidget {
  final String formId;
  final String formName;

  const FormDetailScreen({
    super.key,
    required this.formId,
    required this.formName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FormDetailCubit(getIt())..loadForm(formId),
      child: _FormDetailView(formName: formName, formId: formId),
    );
  }
}

class _FormDetailView extends StatelessWidget {
  final String formName;
  final String formId;

  const _FormDetailView({required this.formName, required this.formId});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FormDetailCubit, FormDetailState>(
      listener: (context, state) {
        if (state case FormDetailError(:final kind)) {
          switch (kind) {
            case FormDetailErrorKind.notFound:
              ErrorModal.show(
                context,
                title: 'This form was deleted.',
                body: "It's no longer available in your Drive.",
                primaryLabel: 'OK',
                onPrimary: () => Navigator.of(context).pop(),
              );
            case FormDetailErrorKind.permissionDenied:
              ErrorModal.show(
                context,
                title: "You don't have access to this form.",
                body: 'The owner may have revoked your access.',
                primaryLabel: 'OK',
                onPrimary: () => Navigator.of(context).pop(),
              );
            case FormDetailErrorKind.network:
              break; // handled inline below
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(formName),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    context.read<FormDetailCubit>().loadForm(formId),
              ),
            ],
          ),
          body: switch (state) {
            FormDetailLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            FormDetailError(:final message, kind: FormDetailErrorKind.network) =>
              _FullScreenError(
                message: message,
                onRetry: () =>
                    context.read<FormDetailCubit>().loadForm(formId),
              ),
            FormDetailError() => const SizedBox.shrink(),
            FormDetailLoaded(:final form) => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ')
                      .convert(form.toJson()),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
          },
        );
      },
    );
  }
}

class _FullScreenError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FullScreenError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
