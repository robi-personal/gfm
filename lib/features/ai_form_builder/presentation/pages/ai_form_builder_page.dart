import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/error_modal.dart';
import '../../../editor/presentation/pages/editor_page.dart';
import '../../../paywall/data/services/purchase_activation_service.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';
import '../../../sign_in/presentation/cubit/sign_in_cubit.dart';
import '../../domain/entities/user_status.dart';
import '../../domain/usecases/get_user_status.dart';
import '../cubit/ai_form_builder_cubit.dart';
import '../widgets/ai_ready_body.dart';
import 'ai_form_preview_page.dart';

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
  late final PurchaseActivationService _activation;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<AiFormBuilderCubit>();
    _eventSub = cubit.events.listen(_handleEvent);
    _promptController.addListener(() {
      if (!_promptDirty) return;
      cubit.notifyRequestBodyChanged();
    });
    _activation = getIt<PurchaseActivationService>();
    _activation.isActivating.addListener(_onActivationChanged);
  }

  @override
  void dispose() {
    _activation.isActivating.removeListener(_onActivationChanged);
    _eventSub.cancel();
    _promptController.dispose();
    super.dispose();
  }

  /// Refresh status when the background reconcile finishes so the quota
  /// counter, upgrade banner, and locked input types drop the moment the
  /// backend catches up — even if pollUntilPremium gave up earlier.
  void _onActivationChanged() {
    if (!mounted) return;
    if (_activation.isActivating.value) return;
    context.read<AiFormBuilderCubit>().loadStatus();
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
        return _ModalParams(
          title: 'No generations left',
          body: 'You\'ve used all ${config.quotaLimit ?? 3} free generations this month. '
              'Upgrade for 50 generations per month.',
          primaryLabel: 'Upgrade',
          onPrimary: () {
            dismissError();
            _showPaywall(cubit);
          },
          secondaryLabel: 'Remind me later',
          onSecondary: dismissError,
        );
      case AiErrorKind.quotaExceededPremium:
        return _ModalParams(
          title: 'Monthly limit reached',
          body: 'You\'ve used all ${config.quotaLimit ?? 50} generations this month.',
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
    await pollUntilPremium(
      useCase: getIt<GetUserStatus>(),
      onPremiumConfirmed: () async {
        if (mounted) await cubit.paywallDismissed();
      },
    );
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
          backgroundColor: AppColors.bg,
          appBar: AppBar(
            backgroundColor: AppColors.bg,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: const Text(
              'AI Form Builder',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AppColors.ink,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.purple600),
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
                color: AppColors.ink2,
              ),
            ),
          ],
        ),
      );
    }

    if (state is AiFormBuilderPreview || state is AiFormBuilderEditorHandoff) {
      return const Center(child: CupertinoActivityIndicator(radius: 14));
    }

    final UserStatus userStatus;
    final AiInputType selectedType;
    final bool isSubmitting;
    final Duration elapsed;

    if (state is AiFormBuilderReady) {
      userStatus = state.status;
      selectedType = state.selectedType;
      isSubmitting = false;
      elapsed = Duration.zero;
    } else if (state is AiFormBuilderSubmitting) {
      userStatus = state.status;
      selectedType = state.selectedType;
      isSubmitting = true;
      elapsed = state.elapsed;
    } else {
      return const SizedBox.shrink();
    }

    return AiReadyBody(
      cubit: cubit,
      status: userStatus,
      selectedType: selectedType,
      isSubmitting: isSubmitting,
      elapsed: elapsed,
      promptController: _promptController,
      onPromptChanged: () {
        _promptDirty = true;
      },
      onSubmitText: isSubmitting ? null : (hint, isQuiz) => _submitText(cubit, hint, isQuiz),
      onUpgrade: () => _showPaywall(cubit),
      onRefresh: () => cubit.refreshStatus(),
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

