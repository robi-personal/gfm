import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
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
const _iosBg = Color(0xFFF2F2F7);
const _cardBg = Colors.white;

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

  void _submitText(AiFormBuilderCubit cubit, int? questionCountHint, bool isQuiz) {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;
    _promptDirty = false;
    cubit.submit({
      'inputType': 'text',
      'prompt': prompt,
      'isQuiz': isQuiz,
      if (questionCountHint != null) 'questionCountHint': questionCountHint,
    });
  }

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
              builder: (_) => EditorPage(formId: state.formId, formName: state.formTitle),
            ),
            (route) => route.isFirst,
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<AiFormBuilderCubit>();
        return Scaffold(
          backgroundColor: _iosBg,
          appBar: AppBar(
            backgroundColor: _iosBg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text(
              'AI Form Builder',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: Color(0xFF1C1C1E),
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF772FC0)),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
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
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }

    if (state is AiFormBuilderCreatingForm) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoActivityIndicator(radius: 14),
            SizedBox(height: 16),
            Text(
              'Creating your form…',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF3C3C43),
              ),
            ),
          ],
        ),
      );
    }

    if (state is AiFormBuilderPreview || state is AiFormBuilderEditorHandoff) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }

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
      onSubmitText: isSubmitting ? null : (hint, isQuiz) => _submitText(cubit, hint, isQuiz),
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
  final void Function(int? questionCountHint, bool isQuiz)? onSubmitText;
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
  final _youtubeController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final List<TextEditingController> _urlControllers;

  String? _fileName;
  String? _fileBase64;
  String? _fileError;

  int? _questionCountHint = 10;
  bool _isQuiz = false;

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
        widget.onSubmitText?.call(_questionCountHint, _isQuiz);
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
          'isQuiz': _isQuiz,
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
          'isQuiz': _isQuiz,
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

    final isUnlimited = widget.status.unlimited;
    final balance = widget.status.quotaBalance;
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
              isUnlimited ? 'You have unlimited quota.' : 'You have $balance quota remaining.',
              style: TextStyle(
                color: (!isUnlimited && balance < info.quotaCost) ? Colors.red : Theme.of(ctx).textTheme.bodySmall?.color,
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
            onPressed: (isUnlimited || balance >= info.quotaCost) ? () => Navigator.of(ctx).pop(true) : null,
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
        'isQuiz': _isQuiz,
        if (description.isNotEmpty) 'description': description,
        if (questionCountHint != null) 'questionCountHint': questionCountHint,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final isQuotaExhausted = status.isQuotaExhausted;
    final isPremium = status.isPremium;
    final selectedType = widget.selectedType;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quota counter card
          _QuotaCounter(status: status, onUpgradeTap: widget.onUpgrade),
          const SizedBox(height: 12),

          // Grace period banner
          if (status.gracePeriodUntil != null) ...[
            _GracePeriodBanner(until: status.gracePeriodUntil!),
            const SizedBox(height: 12),
          ],

          // Upgrade banner
          if (!status.unlimited && isQuotaExhausted) ...[
            _UpgradeBanner(onUpgrade: widget.onUpgrade),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 4),

          // Input type segmented picker (premium only)
          if (isPremium) ...[
            _InputTypePicker(
              selected: selectedType,
              enabled: !widget.isSubmitting,
              onChanged: (type) {
                if (type == AiInputType.book &&
                    _descriptionController.text.trim().isEmpty) {
                  _descriptionController.text =
                      'Generate a comprehension quiz from this material.';
                }
                widget.cubit.setSelectedType(type);
              },
            ),
            const SizedBox(height: 14),
          ],

          // Input area card
          _IosCard(child: _inputArea()),
          const SizedBox(height: 12),

          // Question count + quiz toggle card
          _IosCard(
            child: Column(
              children: [
                _QuestionCountRow(
                  value: _questionCountHint,
                  enabled: !widget.isSubmitting,
                  onChanged: (v) => setState(() => _questionCountHint = v),
                ),
                const Divider(height: 24, color: Color(0xFFF2F2F7)),
                _QuizToggleRow(
                  value: _isQuiz,
                  enabled: !widget.isSubmitting,
                  onChanged: (v) {
                    setState(() => _isQuiz = v);
                    _notifyBodyChanged();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Loading state
          if (widget.isSubmitting) ...[
            Center(
              child: Column(
                children: [
                  const CupertinoActivityIndicator(radius: 13),
                  const SizedBox(height: 12),
                  Text(
                    _loadingLabel(widget.elapsed),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Generate button
          _GenerateButton(
            enabled: _canGenerate,
            onPressed: _onGeneratePressed,
          ),
        ],
      ),
    );
  }

  Widget _inputArea() {
    switch (widget.selectedType) {
      case AiInputType.text:
        return _textInputArea();
      case AiInputType.pdf:
        return _pdfInputArea(
          label: 'Upload a PDF',
          hint: 'Up to 5 MB. Chapter PDFs work best.',
        );
      case AiInputType.youtube:
        return _youtubeInputArea();
      case AiInputType.urls:
        return _urlsInputArea();
      case AiInputType.book:
        return _pdfInputArea(
          label: 'Upload an extracted chapter',
          hint: 'Up to 5 MB',
        );
    }
  }

  Widget _textInputArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Describe the form you want'),
        const SizedBox(height: 10),
        _IosTextField(
          controller: widget.promptController,
          onChanged: (_) => widget.onPromptChanged(),
          minLines: 4,
          maxLines: 8,
          maxLength: 4000,
          enabled: !widget.isSubmitting,
          hintText: 'e.g. "Customer feedback survey for a small bakery"',
        ),
      ],
    );
  }

  Widget _pdfInputArea({required String label, required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label),
        const SizedBox(height: 10),
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
            style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13),
          )
        else
          Text(
            hint,
            style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
          ),
        _descriptionField(),
      ],
    );
  }

  Widget _youtubeInputArea() {
    final remaining = widget.status.youtubeMinutesRemaining;
    final limit = widget.status.youtubeMinutesLimit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Paste a YouTube URL'),
        const SizedBox(height: 10),
        _IosTextField(
          controller: _youtubeController,
          onChanged: (_) => setState(() {}),
          enabled: !widget.isSubmitting,
          keyboardType: TextInputType.url,
          hintText: 'https://www.youtube.com/watch?v=…',
          prefixIcon: const Icon(Icons.play_circle_outline, color: Color(0xFF8E8E93), size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          '$remaining / $limit minutes remaining this month',
          style: TextStyle(
            color: remaining < 10 ? const Color(0xFFFF3B30) : const Color(0xFF8E8E93),
            fontSize: 13,
          ),
        ),
        _descriptionField(),
      ],
    );
  }

  Widget _urlsInputArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionLabel('Paste a website or blog link'),
        const SizedBox(height: 10),
        for (var i = 0; i < _urlControllers.length; i++) ...[
          _IosTextField(
            controller: _urlControllers[i],
            onChanged: (_) => setState(() {}),
            enabled: !widget.isSubmitting,
            keyboardType: TextInputType.url,
            hintText: 'https://…',
            prefixIcon: const Icon(Icons.link, color: Color(0xFF8E8E93), size: 20),
            suffixIcon: _urlControllers.length > 1
                ? GestureDetector(
                    onTap: widget.isSubmitting ? null : () => _removeUrlField(i),
                    child: const Icon(Icons.cancel, color: Color(0xFFC7C7CC), size: 20),
                  )
                : null,
          ),
          if (i != _urlControllers.length - 1) const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        if (_urlControllers.length < 5)
          GestureDetector(
            onTap: widget.isSubmitting ? null : _addUrlField,
            child: const Row(
              children: [
                Icon(Icons.add_circle_outline, color: _purple, size: 18),
                SizedBox(width: 6),
                Text(
                  'Add another URL',
                  style: TextStyle(color: _purple, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        _descriptionField(),
      ],
    );
  }

  Widget _descriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const _SectionLabel('What kind of form do you want?'),
        const SizedBox(height: 4),
        const Text(
          'Optional — e.g. "quiz style" or "customer feedback"',
          style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13),
        ),
        const SizedBox(height: 10),
        _IosTextField(
          controller: _descriptionController,
          onChanged: (_) => setState(() {}),
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          enabled: !widget.isSubmitting,
          hintText: '',
        ),
      ],
    );
  }

  String _loadingLabel(Duration elapsed) {
    final isYoutube = widget.selectedType == AiInputType.youtube;
    if (elapsed.inSeconds < 8) return 'Generating your form…';
    if (elapsed.inSeconds < 30) return 'This is taking a moment…';
    if (isYoutube && elapsed.inSeconds < 120) return 'Analysing video content…';
    return 'Almost there…';
  }
}

// ── Shared iOS-style card wrapper ────────────────────────────────────────────

class _IosCard extends StatelessWidget {
  final Widget child;

  const _IosCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1C1C1E),
      ),
    );
  }
}

// ── iOS-style text field ──────────────────────────────────────────────────────

class _IosTextField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int minLines;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final String hintText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const _IosTextField({
    required this.controller,
    this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    required this.hintText,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      enabled: enabled,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1C1C1E)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 15),
        filled: true,
        fillColor: const Color(0xFFF2F2F7),
        counterText: '',
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding: EdgeInsets.symmetric(
          horizontal: prefixIcon != null ? 0 : 14,
          vertical: minLines > 1 ? 12 : 0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _purple, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ── Generate button ───────────────────────────────────────────────────────────

class _GenerateButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _GenerateButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? _purple : const Color(0xFFD1D1D6),
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: _purple.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                color: enabled ? Colors.white : const Color(0xFF8E8E93),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Generate',
                style: TextStyle(
                  color: enabled ? Colors.white : const Color(0xFF8E8E93),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Question count row ────────────────────────────────────────────────────────

class _QuestionCountRow extends StatefulWidget {
  final int? value;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  const _QuestionCountRow({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  State<_QuestionCountRow> createState() => _QuestionCountRowState();
}

class _QuestionCountRowState extends State<_QuestionCountRow> {
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
        const Text(
          'Number of questions',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1C1C1E),
          ),
        ),
        const Spacer(),
        _StepperButton(
          icon: CupertinoIcons.minus,
          enabled: widget.enabled && _current > _min,
          onTap: _decrement,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: TextField(
            controller: _controller,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Color(0xFF1C1C1E),
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              filled: true,
              fillColor: const Color(0xFFF2F2F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _purple, width: 1.5),
              ),
            ),
            onSubmitted: _onFieldSubmitted,
            onTapOutside: (_) => _onFieldSubmitted(_controller.text),
          ),
        ),
        const SizedBox(width: 8),
        _StepperButton(
          icon: CupertinoIcons.plus,
          enabled: widget.enabled && _current < _max,
          onTap: _increment,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled ? _purpleLight : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? _purple : const Color(0xFFC7C7CC),
        ),
      ),
    );
  }
}

// ── Quiz toggle row ───────────────────────────────────────────────────────────

class _QuizToggleRow extends StatelessWidget {
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _QuizToggleRow({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate as quiz',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1C1C1E),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Adds correct answers and grading',
                style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeTrackColor: _purple,
        ),
      ],
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

  static const _items = <(AiInputType, String, IconData)>[
    (AiInputType.text, 'Text', CupertinoIcons.text_alignleft),
    (AiInputType.pdf, 'PDF', CupertinoIcons.doc_text),
    (AiInputType.youtube, 'YouTube', CupertinoIcons.play_rectangle),
    (AiInputType.urls, 'URLs', CupertinoIcons.link),
    (AiInputType.book, 'Book', CupertinoIcons.book),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.0, 0.75, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(4, 4, 36, 4),
            child: Row(
              children: [
                for (final (type, label, icon) in _items)
                  _TypeChip(
                    label: label,
                    icon: icon,
                    selected: selected == type,
                    enabled: enabled,
                    onTap: () => onChanged(type),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _purple : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : const Color(0xFF8E8E93),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF3C3C43),
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _purpleLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.doc_text_fill, color: _purple, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                fileName!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _purple,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            GestureDetector(
              onTap: enabled ? onClear : null,
              child: const Icon(CupertinoIcons.xmark_circle_fill, color: _purple, size: 20),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: enabled ? onPick : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFD1D1D6),
            style: BorderStyle.solid,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.arrow_up_doc, color: _purple, size: 20),
            SizedBox(width: 8),
            Text(
              'Choose PDF',
              style: TextStyle(
                color: _purple,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
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
    final isUnlimited = status.unlimited;
    final balance     = status.quotaBalance;
    final isExhausted = status.isQuotaExhausted;

    final counterText = isUnlimited
        ? 'Unlimited generations'
        : '$balance generations remaining';

    final barColor = isExhausted
        ? const Color(0xFFFF3B30)
        : isUnlimited || balance > 5
            ? _purple
            : const Color(0xFFFF9500);

    final fraction = isUnlimited ? 1.0 : (balance / 10.0).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: (!isUnlimited && isExhausted) ? onUpgradeTap : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: _purple, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    counterText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isExhausted ? const Color(0xFFFF3B30) : const Color(0xFF1C1C1E),
                    ),
                  ),
                ),
                if (!isUnlimited && !status.isPremium)
                  const Icon(Icons.chevron_right, color: Color(0xFFC7C7CC), size: 18),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 5,
                backgroundColor: const Color(0xFFF2F2F7),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
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
    return GestureDetector(
      onTap: onUpgrade,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9B4FE8), Color(0xFF5E24A8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _purple.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upgrade to Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '50 generations · PDF, YouTube & more',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(
                  color: _purple,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC00).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.exclamationmark_circle_fill,
              color: Color(0xFFFF9500), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Billing issue — service active until ${_formatDate(until)}',
              style: const TextStyle(
                color: Color(0xFF7D4E00),
                fontSize: 13,
                fontWeight: FontWeight.w500,
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
