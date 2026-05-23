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
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) => _TemplateCard(
        template: templates[index],
        category: category,
      ),
    );
  }
}

// ── Template card ─────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final FormTemplate template;
  final String category;

  const _TemplateCard({required this.template, required this.category});

  @override
  Widget build(BuildContext context) {
    final colors = _categoryColors(category);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppShapes.cardRadius,
        border: Border.all(color: AppColors.hairline),
        boxShadow: AppShapes.cardShadow,
      ),
      child: InkWell(
        onTap: () => _createFromTemplate(context, template),
        borderRadius: AppShapes.cardRadius,
        splashColor: colors.accent.withValues(alpha: 0.06),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildThumbnail(),
            _buildLabel(),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return Expanded(
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        child: Image.asset(
          template.imagePath,
          fit: BoxFit.cover,
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
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          height: 1.35,
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

// ── Category helpers ──────────────────────────────────────────────────────────

IconData _categoryIcon(String category) => switch (category) {
      'Work'      => CupertinoIcons.briefcase,
      'Personal'  => CupertinoIcons.person,
      'Education' => CupertinoIcons.book,
      _           => CupertinoIcons.doc_text,
    };

class _CategoryColors {
  final Color bg;
  final Color accent;
  const _CategoryColors({required this.bg, required this.accent});
}

_CategoryColors _categoryColors(String category) => switch (category) {
      'Work'      => const _CategoryColors(bg: Color(0xFFEEF2FF), accent: Color(0xFF4F6CDE)),
      'Personal'  => const _CategoryColors(bg: Color(0xFFF0FDF4), accent: Color(0xFF2E9E5B)),
      'Education' => const _CategoryColors(bg: Color(0xFFFFF7ED), accent: Color(0xFFD97706)),
      _           => _CategoryColors(bg: AppColors.purple50,     accent: AppColors.purple600),
    };
