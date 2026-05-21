import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../../core/design.dart';
import '../../../../../core/di/injection.dart';
import '../../data/datasources/ai_form_datasource.dart';
import '../../domain/entities/user_status.dart';
import '../cubit/ai_form_builder_cubit.dart';
import 'ai_file_picker_button.dart';
import 'ai_generate_button.dart';
import 'ai_grace_period_banner.dart';
import 'ai_input_type_picker.dart';
import 'ai_question_count_row.dart';
import 'ai_quiz_toggle_row.dart';
import 'ai_quota_counter.dart';
import 'ai_upgrade_banner.dart';

class AiReadyBody extends StatefulWidget {
  final AiFormBuilderCubit cubit;
  final UserStatus status;
  final AiInputType selectedType;
  final bool isSubmitting;
  final Duration elapsed;
  final TextEditingController promptController;
  final VoidCallback onPromptChanged;
  final void Function(int? questionCountHint, bool isQuiz)? onSubmitText;
  final VoidCallback onUpgrade;

  const AiReadyBody({
    super.key,
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
  State<AiReadyBody> createState() => _AiReadyBodyState();
}

class _AiReadyBodyState extends State<AiReadyBody> {
  final _youtubeController    = TextEditingController();
  final _descriptionController = TextEditingController();
  late final List<TextEditingController> _urlControllers;

  String? _fileName;
  String? _fileBase64;
  String? _fileError;

  int? _questionCountHint = 5;
  bool _isQuiz = false;
  bool _isCheckingQuota = false;

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

    setState(() => _isCheckingQuota = true);
    PdfPageInfo info;
    try {
      final dataSource = getIt<AiFormDataSource>();
      info = await dataSource.getPdfPageCount(
        fileBase64: fileBase64,
        inputType: inputType,
      );
    } catch (_) {
      setState(() => _isCheckingQuota = false);
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
    setState(() => _isCheckingQuota = false);

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
                color: (!isUnlimited && balance < info.quotaCost)
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
            onPressed: (isUnlimited || balance >= info.quotaCost)
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
          AiQuotaCounter(status: status, onUpgradeTap: widget.onUpgrade),
          const SizedBox(height: 12),

          if (status.gracePeriodUntil != null) ...[
            AiGracePeriodBanner(until: status.gracePeriodUntil!),
            const SizedBox(height: 12),
          ],

          if (!status.unlimited && isQuotaExhausted) ...[
            AiUpgradeBanner(onUpgrade: widget.onUpgrade),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 4),

          AiInputTypePicker(
            selected: selectedType,
            enabled: !widget.isSubmitting,
            isPremium: isPremium,
            onChanged: (type) {
              if (type == AiInputType.book &&
                  _descriptionController.text.trim().isEmpty) {
                _descriptionController.text =
                    'Generate a comprehension quiz from this material.';
              }
              widget.cubit.setSelectedType(type);
            },
            onLockedTap: widget.onUpgrade,
          ),
          const SizedBox(height: 14),

          _IosCard(child: _buildInputArea()),
          const SizedBox(height: 12),

          _IosCard(
            child: Column(
              children: [
                AiQuestionCountRow(
                  value: _questionCountHint,
                  enabled: !widget.isSubmitting,
                  onChanged: (v) => setState(() => _questionCountHint = v),
                ),
                const Divider(height: 24, color: AppColors.bg),
                AiQuizToggleRow(
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
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          AiGenerateButton(
            enabled: _canGenerate && !_isCheckingQuota,
            isLoading: _isCheckingQuota,
            onPressed: _onGeneratePressed,
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    switch (widget.selectedType) {
      case AiInputType.text:
        return _buildTextInputArea();
      case AiInputType.pdf:
        return _buildPdfInputArea(
          label: 'Upload a PDF',
          hint: 'Up to 5 MB. Chapter PDFs work best.',
        );
      case AiInputType.youtube:
        return _buildYoutubeInputArea();
      case AiInputType.urls:
        return _buildUrlsInputArea();
      case AiInputType.book:
        return _buildPdfInputArea(
          label: 'Upload an extracted chapter',
          hint: 'Up to 5 MB',
        );
    }
  }

  Widget _buildTextInputArea() {
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

  Widget _buildPdfInputArea({required String label, required String hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label),
        const SizedBox(height: 10),
        AiFilePickerButton(
          fileName: _fileName,
          enabled: !widget.isSubmitting,
          onPick: _pickPdf,
          onClear: _clearFile,
        ),
        const SizedBox(height: 6),
        if (_fileError != null)
          Text(
            _fileError!,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          )
        else
          Text(
            hint,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        _buildDescriptionField(),
      ],
    );
  }

  Widget _buildYoutubeInputArea() {
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
          prefixIcon: const Icon(Icons.play_circle_outline, color: AppColors.muted, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          '$remaining / $limit minutes remaining this month',
          style: TextStyle(
            color: remaining < 10 ? AppColors.error : AppColors.muted,
            fontSize: 13,
          ),
        ),
        _buildDescriptionField(),
      ],
    );
  }

  Widget _buildUrlsInputArea() {
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
            prefixIcon: const Icon(Icons.link, color: AppColors.muted, size: 20),
            suffixIcon: _urlControllers.length > 1
                ? GestureDetector(
                    onTap: widget.isSubmitting ? null : () => _removeUrlField(i),
                    child: const Icon(Icons.cancel, color: AppColors.muted2, size: 20),
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
                Icon(Icons.add_circle_outline, color: AppColors.purple600, size: 18),
                SizedBox(width: 6),
                Text(
                  'Add another URL',
                  style: TextStyle(
                    color: AppColors.purple600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        _buildDescriptionField(),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        const _SectionLabel('What kind of form do you want?'),
        const SizedBox(height: 4),
        const Text(
          'Optional — e.g. "quiz style" or "customer feedback"',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
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

// ── Private layout helpers (only used within AiReadyBody) ─────────────────────

class _IosCard extends StatelessWidget {
  final Widget child;

  const _IosCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShapes.cardShadow,
      ),
      child: child,
    );
  }
}

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
        color: AppColors.ink,
      ),
    );
  }
}

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
      style: const TextStyle(fontSize: 15, color: AppColors.ink),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: AppColors.muted2, fontSize: 15),
        filled: true,
        fillColor: AppColors.bg,
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
          borderSide: const BorderSide(color: AppColors.purple600, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
