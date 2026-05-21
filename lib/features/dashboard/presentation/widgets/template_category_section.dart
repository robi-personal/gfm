import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design.dart';
import '../../../../core/utils/layout.dart';
import '../../../../core/widgets/error_modal.dart';
import '../cubit/dashboard_cubit.dart';
import '../pages/template_data.dart';
import 'dashboard_dialogs.dart';

// ── Category section ──────────────────────────────────────────────────────────

class TemplateCategorySection extends StatelessWidget {
  final String category;
  final List<FormTemplate> templates;

  const TemplateCategorySection({
    super.key,
    required this.category,
    required this.templates,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppShapes.cardRadius2,
          boxShadow: AppShapes.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 1, color: AppColors.hairline),
              const SizedBox(height: 14),
              _buildGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.purple600.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _categoryIcon(category),
            color: AppColors.purple600,
            size: 15,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          category,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: templates.length,
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet(context) ? 4 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) =>
          _TemplateCard(template: templates[index]),
    );
  }
}

// ── Template card ─────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final FormTemplate template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: AppShapes.cardRadius,
        border: Border.all(color: AppColors.hairline),
      ),
      child: InkWell(
        onTap: () => _createFromTemplate(context, template),
        borderRadius: AppShapes.cardRadius,
        splashColor: AppColors.purple600.withValues(alpha: 0.06),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildThumbnail()),
            _buildLabel(),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      child: Image.asset(
        template.imagePath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Container(
          color: AppColors.purple600.withValues(alpha: 0.06),
          child: const Center(
            child: Icon(
              CupertinoIcons.doc_text,
              color: AppColors.purple600,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Text(
        template.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          height: 1.3,
        ),
      ),
    );
  }

  void _createFromTemplate(BuildContext context, FormTemplate template) async {
    final name = await showFormNameSheet(context, prefill: template.title);
    if (name == null || !context.mounted) return;

    final cubit = context.read<DashboardCubit>();
    try {
      await cubit.createForm(
        title: name,
        items: template.items,
        enableQuiz: template.quizMode,
      );
    } catch (_) {
      if (!context.mounted) return;
      ErrorModal.show(
        context,
        title: "Couldn't create form.",
        body: 'Check your connection and try again.',
        secondaryLabel: 'Cancel',
        onSecondary: () {},
        primaryLabel: 'Retry',
        onPrimary: () => _createFromTemplate(context, template),
      );
    }
  }
}

// ── Category icon helper ──────────────────────────────────────────────────────

IconData _categoryIcon(String category) => switch (category) {
      'Work'      => CupertinoIcons.briefcase,
      'Personal'  => CupertinoIcons.person,
      'Education' => CupertinoIcons.book,
      _           => CupertinoIcons.doc_text,
    };
