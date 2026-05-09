import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/widgets/error_modal.dart';
import '../../data/datasources/ai_form_datasource.dart';
import '../../../editor/presentation/pages/editor_page.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';
import '../../../sign_in/presentation/cubit/sign_in_cubit.dart';
import '../../domain/entities/user_status.dart';
import '../cubit/ai_form_builder_cubit.dart';
import 'ai_form_preview_page.dart';

const _purple = Color(0xFF772FC0);
const _purpleLight = Color(0xFFF3EBFC);

class AiFormBuilderPage extends StatelessWidget {
  const AiFormBuilderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AiFormBuilderCubit>(),
      child: const _AiFormBuilderView(),
    );
  }
}

class _AiFormBuilderView extends StatefulWidget {
  const _AiFormBuilderView();

  @override
  State<_AiFormBuilderView> createState() => _AiFormBuilderViewState();
}

class _AiFormBuilderViewState extends State<_AiFormBuilderView> {
  late final StreamSubscription<AiFormBuilderEvent> _eventSub;
  final _promptController = TextEditingController();
  bool _promptDirty = false;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<AiFormBuilderCubit>();
    _eventSub = cubit.events.listen(_handleEvent);
    _promptController.addListener(() {
      if (!_promptDirty) return;
      cubit.notifyRequestBodyChanged();
    });
  }

  @override
  void dispose() {
    _eventSub.cancel();
    _promptController.dispose();
    super.dispose();
  }

  // ── Event stream handler ──────────────────────────────────────────────────

  void _handleEvent(AiFormBuilderEvent event) {
    if (!mounted) return;
    final cubit = context.read<AiFormBuilderCubit>();
    switch (event) {
      case ShowErrorModalEvent(:final config):
        _showErrorModal(config, cubit);
      case ShowPaywallEvent():
        _showPaywall(cubit);
    }
  }

  void _showErrorModal(AiErrorModalConfig config, AiFormBuilderCubit cubit) {
    final isStatusLoad = cubit.state is AiFormBuilderStatusLoading;
    if (isStatusLoad) {
      ErrorModal.show(
        context,
        title: 'Couldn\'t load quota',
        body: 'Couldn\'t load your quota. Check your connection and try again.',
        primaryLabel: 'Retry',
        onPrimary: () => cubit.loadStatus(),
        secondaryLabel: 'Cancel',
        onSecondary: () {
          if (mounted) Navigator.of(context).pop();
        },
      );
      return;
    }

    final params = _modalParams(config, cubit);
    ErrorModal.show(
      context,
      title: params.title,
      body: params.body,
      primaryLabel: params.primaryLabel,
      onPrimary: params.onPrimary,
      secondaryLabel: params.secondaryLabel,
      onSecondary: params.onSecondary,
    );
  }

  _ModalParams _modalParams(
    AiErrorModalConfig config,
    AiFormBuilderCubit cubit,
  ) {
    void dismissError() => cubit.dismissError();
    void retrySubmit() => cubit.retrySubmit();

    switch (config.kind) {
      case AiErrorKind.invalidInput:
        return _ModalParams(
          title: 'Invalid request',
          body: 'Something looks wrong with your input. Please check and try again.',
          primaryLabel: 'OK',
          onPrimary: dismissError,
        );
      case AiErrorKind.missingIdempotencyKey:
      case AiErrorKind.idempotencyConflict:
        return _ModalParams(
          title: 'App error',
          body: 'An internal error occurred. Please try again.',
          primaryLabel: 'Try Again',
          onPrimary: () {
            dismissError();
            retrySubmit();
          },
        );
      case AiErrorKind.fileTooLarge:
        return _ModalParams(
          title: 'File too large',
          body: 'Your file is too large. Please use a file under 5 MB.',
          primaryLabel: 'OK',
          onPrimary: dismissError,
        );
      case AiErrorKind.unsupportedInputType:
        return _ModalParams(
          title: 'App error',
          body: 'An internal error occurred. Please try again.',
          primaryLabel: 'OK',
          onPrimary: dismissError,
        );
      case AiErrorKind.urlFetchFailed:
        return _ModalParams(
          title: 'Couldn\'t read URL',
          body: 'We couldn\'t access one of your links. Make sure it\'s publicly accessible and try again.',
          primaryLabel: 'OK',
          onPrimary: dismissError,
        );
      case AiErrorKind.youtubeUnavailable:
        return _ModalParams(
          title: 'Video unavailable',
          body: 'This YouTube video is private, removed, or region-locked. Please try a different video.',
          primaryLabel: 'OK',
          onPrimary: dismissError,
        );
      case AiErrorKind.youtubeMinutesExceeded:
        return _ModalParams(
          title: 'YouTube limit reached',
          body: 'You\'ve used your monthly YouTube video minutes. Your limit resets in 30 days.',
          primaryLabel: 'OK',
          onPrimary: dismissError,
        );
      case AiErrorKind.quotaCostChanged:
        return _ModalParams(
          title: 'Quota cost changed',
          body: 'The quota cost for this document changed since the confirmation step. Please try generating again.',
          primaryLabel: 'Try again',
          onPrimary: dismissError,
        );
      case AiErrorKind.invalidToken:
        return _ModalParams(
          title: 'Session expired',
          body: 'Your session has expired. Please sign in again.',
          primaryLabel: 'Sign in',
          onPrimary: () {
            dismissError();
            if (mounted) {
              // signOut() causes _AuthGate to rebuild to SignInScreen;
              // pop() removes this page so that screen becomes visible.
              context.read<SignInCubit>().signOut();
              Navigator.of(context).pop();
            }
          },
        );
      case AiErrorKind.userBlocked:
        return _ModalParams(
          title: 'Account restricted',
          body: 'Your account has been restricted. Contact support if you think this is a mistake.',
          primaryLabel: 'OK',
          onPrimary: dismissError,
          secondaryLabel: 'Contact Support',
          onSecondary: dismissError,
        );
      case AiErrorKind.idempotencyInFlight:
        return _ModalParams(
          title: 'Already generating',
          body: 'Your last request is still in progress. Please wait a moment and try again.',
          primaryLabel: 'Try Again',
          onPrimary: () {
            dismissError();
            retrySubmit();
          },
        );
      case AiErrorKind.quotaExceededFree:
        final resetsAtStr = config.resetsAt != null
            ? ' Your free quota resets on ${_formatDate(config.resetsAt!)}.'
            : '';
        return _ModalParams(
          title: 'No generations left',
          body: 'You\'ve used all ${config.quotaLimit ?? 3} free generations this month. '
              'Upgrade for 50 generations per month.$resetsAtStr',
          primaryLabel: 'Upgrade',
          onPrimary: () {
            dismissError();
            _showPaywall(cubit);
          },
          secondaryLabel: 'Remind me later',
          onSecondary: dismissError,
        );
      case AiErrorKind.quotaExceededPremium:
        final resetStr = config.resetsAt != null
            ? ' Your limit resets on ${_formatDate(config.resetsAt!)}.'
            : '';
        return _ModalParams(
          title: 'Monthly limit reached',
          body: 'You\'ve used all ${config.quotaLimit ?? 50} generations this month.$resetStr',
          primaryLabel: 'OK',
          onPrimary: dismissError,
        );
      case AiErrorKind.rateLimited:
        final rs = config.retryAfterSeconds;
        final waitStr = rs != null
            ? ' Try again in $rs ${rs == 1 ? 'second' : 'seconds'}.'
            : '';
        return _ModalParams(
          title: 'Slow down',
          body: 'You\'re generating forms too quickly.$waitStr',
          primaryLabel: 'OK',
          onPrimary: dismissError,
        );
      case AiErrorKind.geminiUnavailable:
        return _ModalParams(
          title: 'AI service unavailable',
          body: 'The AI service is temporarily unavailable. Please try again in a moment.',
          primaryLabel: 'Try Again',
          onPrimary: () {
            dismissError();
            retrySubmit();
          },
          secondaryLabel: 'Cancel',
          onSecondary: dismissError,
        );
      case AiErrorKind.geminiTimeout:
        return _ModalParams(
          title: 'Taking too long',
          body: 'The AI is taking longer than expected. Your request may still be processing — '
              'tapping \'Try Again\' will resume it if possible.',
          primaryLabel: 'Try Again',
          onPrimary: () {
            dismissError();
            retrySubmit();
          },
          secondaryLabel: 'Cancel',
          onSecondary: dismissError,
        );
      case AiErrorKind.validationError:
        return _ModalParams(
          title: 'Generation failed',
          body: 'The AI produced an unexpected result. Please try again, or try rephrasing your input.',
          primaryLabel: 'Try Again',
          onPrimary: () {
            dismissError();
            retrySubmit();
          },
          secondaryLabel: 'Cancel',
          onSecondary: dismissError,
        );
      case AiErrorKind.serviceDisabled:
        return _ModalParams(
          title: 'Feature unavailable',
          body: 'AI form generation is temporarily unavailable. Please try again later.',
          primaryLabel: 'OK',
          onPrimary: dismissError,
        );
      case AiErrorKind.serviceBusy:
        final sb = config.retryAfterSeconds;
        final waitStr = sb != null
            ? ' Please try again in $sb ${sb == 1 ? 'second' : 'seconds'}.'
            : ' Please try again in a moment.';
        return _ModalParams(
          title: 'Service is busy',
          body: 'The service is unusually busy right now.$waitStr',
          primaryLabel: 'Try Again',
          onPrimary: () {
            dismissError();
            retrySubmit();
          },
          secondaryLabel: 'Cancel',
          onSecondary: dismissError,
        );
      case AiErrorKind.dailyBudgetExceeded:
        return _ModalParams(
          title: 'Service is unavailable',
          body: 'AI form generation is temporarily unavailable. Please try again tomorrow.',
          primaryLabel: 'OK',
          onPrimary: dismissError,
        );
      case AiErrorKind.databaseUnavailable:
        return _ModalParams(
          title: 'Service error',
          body: 'A temporary error occurred. Please try again.',
          primaryLabel: 'Try Again',
          onPrimary: () {
            dismissError();
            retrySubmit();
          },
          secondaryLabel: 'Cancel',
          onSecondary: dismissError,
        );
      case AiErrorKind.noConnection:
        return _ModalParams(
          title: 'No connection',
          body: 'Check your internet connection and try again.',
          primaryLabel: 'Try Again',
          onPrimary: () {
            dismissError();
            retrySubmit();
          },
          secondaryLabel: 'Cancel',
          onSecondary: dismissError,
        );
      case AiErrorKind.generic4xx:
        return _ModalParams(
          title: 'Request error',
          body: 'Request error. Please try again.',
          primaryLabel: 'OK',
          onPrimary: dismissError,
        );
      case AiErrorKind.generic5xx:
        return _ModalParams(
          title: 'Server error',
          body: 'A server error occurred. Please try again later.',
          primaryLabel: 'OK',
          onPrimary: dismissError,
        );
    }
  }

  Future<void> _showPaywall(AiFormBuilderCubit cubit) async {
    await PaywallPage.show(context);
    if (!mounted) return;
    await cubit.paywallDismissed();
  }

  // ── Submission ────────────────────────────────────────────────────────────

  void _submitText(AiFormBuilderCubit cubit, int? questionCountHint) {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    _promptDirty = false;
    cubit.submit({
      'inputType': 'text',
      'prompt': prompt,
      if (questionCountHint != null) 'questionCountHint': questionCountHint,
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AiFormBuilderCubit, AiFormBuilderState>(
      listenWhen: (_, curr) =>
          curr is AiFormBuilderPreview ||
          curr is AiFormBuilderEditorHandoff,
      listener: (context, state) {
        final cubit = context.read<AiFormBuilderCubit>();
        if (state is AiFormBuilderPreview) {
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
              value: cubit,
              child: const AiFormPreviewPage(),
            ),
          ));
        } else if (state is AiFormBuilderEditorHandoff) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) => EditorPage(formId: state.formId, formName: ''),
            ),
            (route) => route.isFirst,
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<AiFormBuilderCubit>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('AI Form Builder'),
            backgroundColor: _purple,
            foregroundColor: Colors.white,
          ),
          body: _buildBody(context, state, cubit),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    AiFormBuilderState state,
    AiFormBuilderCubit cubit,
  ) {
    if (state is AiFormBuilderStatusLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is AiFormBuilderCreatingForm) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Creating your form…'),
          ],
        ),
      );
    }

    // AiFormBuilderPreview and AiFormBuilderEditorHandoff are handled by
    // the BlocConsumer listener — show a loading indicator while transitioning.
    if (state is AiFormBuilderPreview ||
        state is AiFormBuilderEditorHandoff) {
      return const Center(child: CircularProgressIndicator());
    }

    // Ready or Submitting
    final UserStatus status;
    final AiInputType selectedType;
    final bool isSubmitting;
    final Duration elapsed;

    if (state is AiFormBuilderReady) {
      status = state.status;
      selectedType = state.selectedType;
      isSubmitting = false;
      elapsed = Duration.zero;
    } else if (state is AiFormBuilderSubmitting) {
      status = state.status;
      selectedType = state.selectedType;
      isSubmitting = true;
      elapsed = state.elapsed;
    } else {
      return const SizedBox.shrink();
    }

    return _ReadyBody(
      cubit: cubit,
      status: status,
      selectedType: selectedType,
      isSubmitting: isSubmitting,
      elapsed: elapsed,
      promptController: _promptController,
      onPromptChanged: () {
        _promptDirty = true;
      },
      onSubmitText: isSubmitting ? null : (hint) => _submitText(cubit, hint),
      onUpgrade: () => _showPaywall(cubit),
    );
  }
}

// ── Ready / Submitting body ───────────────────────────────────────────────────

class _ReadyBody extends StatefulWidget {
  final AiFormBuilderCubit cubit;
  final UserStatus status;
  final AiInputType selectedType;
  final bool isSubmitting;
  final Duration elapsed;
  final TextEditingController promptController;
  final VoidCallback onPromptChanged;
  final void Function(int? questionCountHint)? onSubmitText;
  final VoidCallback onUpgrade;

  const _ReadyBody({
    required this.cubit,
    required this.status,
    required this.selectedType,
    required this.isSubmitting,
    required this.elapsed,
    required this.promptController,
    required this.onPromptChanged,
    required this.onSubmitText,
    required this.onUpgrade,
  });

  @override
  State<_ReadyBody> createState() => _ReadyBodyState();
}

class _ReadyBodyState extends State<_ReadyBody> {
  // YouTube
  final _youtubeController = TextEditingController();
  // Description (shared across pdf, youtube, urls, book)
  final _descriptionController = TextEditingController();
  // URLs (1..5)
  late final List<TextEditingController> _urlControllers;

  // PDF / Book file selection
  String? _fileName;
  String? _fileBase64;
  String? _fileError;

  // Question count hint (null sends no hint, AI uses default 10-15)
  int? _questionCountHint = 10;

  @override
  void initState() {
    super.initState();
    _urlControllers = [TextEditingController()];
    _youtubeController.addListener(_notifyBodyChanged);
    _descriptionController.addListener(_notifyBodyChanged);
    for (final c in _urlControllers) {
      c.addListener(_notifyBodyChanged);
    }
  }

  @override
  void dispose() {
    _youtubeController.dispose();
    _descriptionController.dispose();
    for (final c in _urlControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _notifyBodyChanged() {
    widget.cubit.notifyRequestBodyChanged();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.size > 5 * 1024 * 1024) {
      setState(() {
        _fileError = 'File too large (max 5 MB)';
        _fileName = null;
        _fileBase64 = null;
      });
      return;
    }

    final bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        _fileError = 'Couldn\'t read the file. Try again.';
        _fileName = null;
        _fileBase64 = null;
      });
      return;
    }

    setState(() {
      _fileError = null;
      _fileName = file.name;
      _fileBase64 = base64Encode(bytes);
    });
    _notifyBodyChanged();
  }

  void _clearFile() {
    setState(() {
      _fileName = null;
      _fileBase64 = null;
      _fileError = null;
    });
    _notifyBodyChanged();
  }

  void _addUrlField() {
    if (_urlControllers.length >= 5) return;
    final c = TextEditingController();
    c.addListener(_notifyBodyChanged);
    setState(() => _urlControllers.add(c));
    _notifyBodyChanged();
  }

  void _removeUrlField(int index) {
    if (_urlControllers.length <= 1) return;
    final removed = _urlControllers.removeAt(index);
    removed.dispose();
    setState(() {});
    _notifyBodyChanged();
  }

  bool get _canGenerate {
    if (widget.isSubmitting) return false;
    if (widget.status.isQuotaExhausted) return false;
    switch (widget.selectedType) {
      case AiInputType.text:
        return widget.promptController.text.trim().isNotEmpty;
      case AiInputType.pdf:
      case AiInputType.book:
        return _fileBase64 != null;
      case AiInputType.youtube:
        return _youtubeController.text.trim().isNotEmpty;
      case AiInputType.urls:
        return _urlControllers.any((c) => c.text.trim().isNotEmpty);
    }
  }

  void _onGeneratePressed() {
    switch (widget.selectedType) {
      case AiInputType.text:
        widget.onSubmitText?.call(_questionCountHint);
      case AiInputType.pdf:
        if (_fileBase64 == null || _fileName == null) return;
        _submitWithPdfConfirmation(
          inputType: 'pdf',
          fileBase64: _fileBase64!,
          fileName: _fileName!,
          description: _descriptionController.text.trim(),
          questionCountHint: _questionCountHint,
        );
      case AiInputType.book:
        if (_fileBase64 == null || _fileName == null) return;
        _submitWithPdfConfirmation(
          inputType: 'book',
          fileBase64: _fileBase64!,
          fileName: _fileName!,
          description: _descriptionController.text.trim(),
          questionCountHint: _questionCountHint,
        );
      case AiInputType.youtube:
        final url = _youtubeController.text.trim();
        if (url.isEmpty) return;
        final ytDesc = _descriptionController.text.trim();
        widget.cubit.submit({
          'inputType': 'youtube',
          'youtubeUrl': url,
          if (ytDesc.isNotEmpty) 'description': ytDesc,
          if (_questionCountHint != null) 'questionCountHint': _questionCountHint,
        });
      case AiInputType.urls:
        final urls = _urlControllers
            .map((c) => c.text.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (urls.isEmpty) return;
        final urlsDesc = _descriptionController.text.trim();
        widget.cubit.submit({
          'inputType': 'urls',
          'urls': urls,
          if (urlsDesc.isNotEmpty) 'description': urlsDesc,
          if (_questionCountHint != null) 'questionCountHint': _questionCountHint,
        });
    }
  }

  Future<void> _submitWithPdfConfirmation({
    required String inputType,
    required String fileBase64,
    required String fileName,
    required String description,
    required int? questionCountHint,
  }) async {
    final context = this.context;

    // Show a loading indicator while fetching page count
    if (!context.mounted) return;

    PdfPageInfo info;
    try {
      final dataSource = getIt<AiFormDataSource>();
      info = await dataSource.getPdfPageCount(
        fileBase64: fileBase64,
        inputType: inputType,
      );
    } catch (_) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unable to check document'),
          content: const Text(
            'Could not calculate the quota cost for this document. '
            'Please check your connection and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;

    final remaining = widget.status.effectiveRemaining;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Generation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This ${inputType == 'book' ? 'book' : 'PDF'} has ${info.pages} pages.'),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: Theme.of(ctx).textTheme.bodyMedium,
                children: [
                  const TextSpan(text: 'Quota cost: '),
                  TextSpan(
                    text: '${info.quotaCost} quota',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' (${info.pagesPerQuota} pages per quota unit)'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You have $remaining quota remaining.',
              style: TextStyle(
                color: remaining < info.quotaCost
                    ? Colors.red
                    : Theme.of(ctx).textTheme.bodySmall?.color,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: remaining >= info.quotaCost
                ? () => Navigator.of(ctx).pop(true)
                : null,
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.cubit.submit({
        'inputType': inputType,
        'fileBase64': fileBase64,
        'fileName': fileName,
        'confirmedQuotaCost': info.quotaCost,
        if (description.isNotEmpty) 'description': description,
        if (questionCountHint != null) 'questionCountHint': questionCountHint,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = widget.status;
    final isQuotaExhausted = status.isQuotaExhausted;
    final isPremium = status.isPremium;
    final selectedType = widget.selectedType;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quota counter
          _QuotaCounter(status: status, onUpgradeTap: widget.onUpgrade),
          const SizedBox(height: 12),

          // Grace period banner
          if (status.gracePeriodUntil != null) ...[
            _GracePeriodBanner(until: status.gracePeriodUntil!),
            const SizedBox(height: 12),
          ],

          // Upgrade banner (free, quota exhausted)
          if (!isPremium && isQuotaExhausted) ...[
            _UpgradeBanner(onUpgrade: widget.onUpgrade),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 4),

          // Premium-only: input type picker
          if (isPremium) ...[
            _InputTypePicker(
              selected: selectedType,
              enabled: !widget.isSubmitting,
              onChanged: widget.cubit.setSelectedType,
            ),
            const SizedBox(height: 16),
          ],

          // Per-type input area
          _inputArea(theme),
          const SizedBox(height: 16),

          // Question count picker
          _QuestionCountPicker(
            value: _questionCountHint,
            enabled: !widget.isSubmitting,
            onChanged: (v) => setState(() => _questionCountHint = v),
          ),
          const SizedBox(height: 16),

          // Loading phase text (while submitting)
          if (widget.isSubmitting) ...[
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    _loadingLabel(widget.elapsed),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Generate button
          FilledButton(
            onPressed: _canGenerate ? _onGeneratePressed : null,
            style: FilledButton.styleFrom(
              backgroundColor: _purple,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Generate', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _inputArea(ThemeData theme) {
    switch (widget.selectedType) {
      case AiInputType.text:
        return _textInputArea(theme);
      case AiInputType.pdf:
        return _pdfInputArea(
          theme,
          label: 'Upload a PDF',
          hint: 'Up to 5 MB. Chapter PDFs work best.',
        );
      case AiInputType.youtube:
        return _youtubeInputArea(theme);
      case AiInputType.urls:
        return _urlsInputArea(theme);
      case AiInputType.book:
        return _bookInputArea(theme);
    }
  }

  Widget _textInputArea(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Describe the form you want', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: widget.promptController,
          onChanged: (_) => widget.onPromptChanged(),
          minLines: 4,
          maxLines: 8,
          maxLength: 4000,
          enabled: !widget.isSubmitting,
          decoration: const InputDecoration(
            hintText: 'e.g. "Customer feedback survey for a small bakery"',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _pdfInputArea(
    ThemeData theme, {
    required String label,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        _FilePickerButton(
          fileName: _fileName,
          enabled: !widget.isSubmitting,
          onPick: _pickPdf,
          onClear: _clearFile,
        ),
        const SizedBox(height: 6),
        if (_fileError != null)
          Text(
            _fileError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.red.shade700,
            ),
          )
        else
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        _descriptionField(theme),
      ],
    );
  }

  Widget _youtubeInputArea(ThemeData theme) {
    final remaining = widget.status.youtubeMinutesRemaining;
    final limit     = widget.status.youtubeMinutesLimit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Paste a YouTube URL', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _youtubeController,
          onChanged: (_) => setState(() {}),
          enabled: !widget.isSubmitting,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://www.youtube.com/watch?v=…',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.play_circle_outline),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$remaining / $limit minutes remaining this month',
          style: theme.textTheme.bodySmall?.copyWith(
            color: remaining < 10
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        _descriptionField(theme),
      ],
    );
  }

  Widget _urlsInputArea(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Paste a website or blog link', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        for (var i = 0; i < _urlControllers.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _urlControllers[i],
                  onChanged: (_) => setState(() {}),
                  enabled: !widget.isSubmitting,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    hintText: 'https://…',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.link),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    suffixIcon: _urlControllers.length > 1
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Remove',
                            onPressed: widget.isSubmitting
                                ? null
                                : () => _removeUrlField(i),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          if (i != _urlControllers.length - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        if (_urlControllers.length < 5)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.isSubmitting ? null : _addUrlField,
              icon: const Icon(Icons.add, size: 18, color: _purple),
              label: const Text('Add URL', style: TextStyle(color: _purple)),
            ),
          ),
        _descriptionField(theme),
      ],
    );
  }

  Widget _bookInputArea(ThemeData theme) {
    return _pdfInputArea(
      theme,
      label: 'Upload an extracted chapter',
      hint: 'Upload an extracted chapter (≤ 5 MB)',
    );
  }

  Widget _descriptionField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text('What kind of form do you want? (optional)',
            style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          onChanged: (_) => setState(() {}),
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          enabled: !widget.isSubmitting,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  String _loadingLabel(Duration elapsed) {
    final isYoutube = widget.selectedType == AiInputType.youtube;
    if (elapsed.inSeconds < 8)  return 'Generating your form…';
    if (elapsed.inSeconds < 30) return 'This is taking a moment…';
    if (isYoutube && elapsed.inSeconds < 120) return 'Analysing video content…';
    return 'Almost there…';
  }
}

// ── Question count picker ─────────────────────────────────────────────────────

class _QuestionCountPicker extends StatefulWidget {
  final int? value;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  const _QuestionCountPicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_QuestionCountPicker> createState() => _QuestionCountPickerState();
}

class _QuestionCountPickerState extends State<_QuestionCountPicker> {
  late final TextEditingController _controller;

  static const _min = 3;
  static const _max = 50;
  static const _default = 10;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value != null ? '${widget.value}' : '$_default',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _current => widget.value ?? _default;

  void _increment() {
    final next = (_current + 1).clamp(_min, _max);
    _controller.text = '$next';
    widget.onChanged(next);
  }

  void _decrement() {
    final next = (_current - 1).clamp(_min, _max);
    _controller.text = '$next';
    widget.onChanged(next);
  }

  void _onFieldSubmitted(String raw) {
    final n = int.tryParse(raw);
    if (n == null) {
      _controller.text = '$_current';
      return;
    }
    final clamped = n.clamp(_min, _max);
    _controller.text = '$clamped';
    widget.onChanged(clamped);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Number of questions',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        _CounterButton(
          icon: Icons.remove,
          enabled: widget.enabled && _current > _min,
          onTap: _decrement,
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 48,
          child: TextField(
            controller: _controller,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _purple.withValues(alpha: 0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _purple),
              ),
            ),
            style: const TextStyle(fontWeight: FontWeight.w600),
            onSubmitted: _onFieldSubmitted,
            onTapOutside: (_) => _onFieldSubmitted(_controller.text),
          ),
        ),
        const SizedBox(width: 4),
        _CounterButton(
          icon: Icons.add,
          enabled: widget.enabled && _current < _max,
          onTap: _increment,
        ),
      ],
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _CounterButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled ? _purpleLight : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? _purple.withValues(alpha: 0.4) : Colors.grey.shade300,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? _purple : Colors.grey.shade400,
        ),
      ),
    );
  }
}

// ── Input type picker ─────────────────────────────────────────────────────────

class _InputTypePicker extends StatelessWidget {
  final AiInputType selected;
  final bool enabled;
  final ValueChanged<AiInputType> onChanged;

  const _InputTypePicker({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const items = <(AiInputType, String)>[
      (AiInputType.text, 'Text'),
      (AiInputType.pdf, 'PDF'),
      (AiInputType.youtube, 'YouTube'),
      (AiInputType.urls, 'URLs'),
      (AiInputType.book, 'Book'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (type, label) in items) ...[
            ChoiceChip(
              label: Text(label),
              selected: selected == type,
              onSelected: enabled ? (_) => onChanged(type) : null,
              selectedColor: _purple,
              backgroundColor: _purpleLight,
              labelStyle: TextStyle(
                color: selected == type ? Colors.white : _purple,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(color: _purple.withValues(alpha: 0.3)),
              showCheckmark: false,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ── File picker button ───────────────────────────────────────────────────────

class _FilePickerButton extends StatelessWidget {
  final String? fileName;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _FilePickerButton({
    required this.fileName,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (fileName != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _purpleLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _purple.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: _purple, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fileName!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _purple,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: _purple),
              tooltip: 'Remove file',
              onPressed: enabled ? onClear : null,
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: enabled ? onPick : null,
      icon: const Icon(Icons.upload_file, color: _purple),
      label: const Text('Upload PDF', style: TextStyle(color: _purple)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: _purple.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

// ── Quota counter ─────────────────────────────────────────────────────────────

class _QuotaCounter extends StatelessWidget {
  final UserStatus status;
  final VoidCallback onUpgradeTap;

  const _QuotaCounter({required this.status, required this.onUpgradeTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = status.effectiveRemaining;
    final limit = status.effectiveLimit;
    final isExhausted = status.isQuotaExhausted;

    final counterText = status.isPremium
        ? '$remaining of $limit generations remaining'
        : '$remaining of $limit free generations remaining';

    final resetsAt = status.effectiveResetsAt;
    final subLine = resetsAt != null
        ? (status.isPremium ? 'Renews ${_formatDate(resetsAt)}' : 'Resets ${_formatDate(resetsAt)}')
        : null;

    return GestureDetector(
      onTap: (!status.isPremium && isExhausted) ? onUpgradeTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _purpleLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _purple.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: _purple, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    counterText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isExhausted ? Colors.red.shade700 : _purple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subLine != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subLine,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!status.isPremium)
              const Icon(Icons.chevron_right, color: _purple, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Upgrade banner ────────────────────────────────────────────────────────────

class _UpgradeBanner extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _UpgradeBanner({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _purpleLight,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onUpgrade,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _purple.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium, color: _purple, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Upgrade for 50 generations + PDF, YouTube & more',
                  style: TextStyle(
                    color: _purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _purple,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Upgrade',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grace period banner ───────────────────────────────────────────────────────

class _GracePeriodBanner extends StatelessWidget {
  final DateTime until;

  const _GracePeriodBanner({required this.until});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Billing issue — service active until ${_formatDate(until)}',
              style: TextStyle(
                color: Colors.orange.shade900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _ModalParams {
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const _ModalParams({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });
}

String _formatDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[dt.month - 1]} ${dt.day}';
}
