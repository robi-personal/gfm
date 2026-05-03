import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/error_modal.dart';
import '../../../editor/presentation/pages/editor_page.dart';
import '../cubit/dashboard_cubit.dart';
import 'template_data.dart';

const _purple = Color(0xFF772FC0);
const _bgGray = Color(0xFFF5F5F5);

class TemplatePickerPage extends StatelessWidget {
  const TemplatePickerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<DashboardCubit, DashboardState>(
      listenWhen: (prev, curr) {
        final prevNav = prev is DashboardLoaded ? prev.createNav : null;
        final currNav = curr is DashboardLoaded ? curr.createNav : null;
        return currNav != null && currNav != prevNav;
      },
      listener: (context, state) {
        if (state case DashboardLoaded(:final createNav?)) {
          _handleNavigation(context, createNav);
        }
      },
      child: Scaffold(
        backgroundColor: _bgGray,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          title: const Text(
            'Create New Form',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ),
        body: _TemplatePickerBody(),
      ),
    );
  }

  void _handleNavigation(BuildContext context, CreateNavigation nav) {
    final cubit = context.read<DashboardCubit>();
    cubit.clearNavigation();

    void goToEditor() async {
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => EditorPage(formId: nav.formId, formName: nav.formName),
      ));
      if (context.mounted) {
        cubit.loadForms();
      }
    }

    if (nav.publishFailed && context.mounted) {
      ErrorModal.show(
        context,
        title: 'Form created but not published.',
        body: "Responders can't submit until it's published. Publish now?",
        secondaryLabel: 'Later',
        onSecondary: goToEditor,
        primaryLabel: 'Publish',
        onPrimary: goToEditor,
      );
      return;
    }

    goToEditor();
  }
}

class _TemplatePickerBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isCreating = context.select<DashboardCubit, bool>((c) {
      final s = c.state;
      return switch (s) {
        DashboardLoaded(:final isCreating) => isCreating,
        DashboardError(:final isCreating) => isCreating,
        _ => false,
      };
    });

    return AbsorbPointer(
      absorbing: isCreating,
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Start from scratch ─────────────────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Text(
                    'Start from scratch',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                sliver: SliverToBoxAdapter(child: _BlankCardsRow()),
              ),
              // ── Template Gallery banner ────────────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 28),
                  child: _TemplateGalleryBanner(),
                ),
              ),
              // ── Category sections ──────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.only(top: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final category = kTemplateCategories[index];
                      final templates = kFormTemplates
                          .where((t) => t.category == category)
                          .toList();
                      return _CategorySection(
                          category: category, templates: templates);
                    },
                    childCount: kTemplateCategories.length,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
          if (isCreating)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator(color: _purple)),
              ),
            ),
        ],
      ),
    );
  }
}

class _TemplateGalleryBanner extends StatelessWidget {
  const _TemplateGalleryBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _purple,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: const Center(
        child: Text(
          'Template Gallery',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _BlankCardsRow extends StatelessWidget {
  const _BlankCardsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _BlankCard(
          icon: Icons.add,
          title: 'Blank form',
          onCreate: (context) => _create(context, quiz: false),
        )),
        const SizedBox(width: 12),
        Expanded(child: _BlankCard(
          icon: Icons.quiz_outlined,
          title: 'Blank quiz',
          onCreate: (context) => _create(context, quiz: true),
        )),
      ],
    );
  }

  void _create(BuildContext context, {required bool quiz}) async {
    final cubit = context.read<DashboardCubit>();
    try {
      if (quiz) {
        await cubit.createForm(
          title: 'Untitled quiz',
          items: kBlankQuizTemplate.items,
          enableQuiz: true,
        );
      } else {
        await cubit.createForm(title: 'Untitled form');
      }
    } catch (_) {
      if (!context.mounted) return;
      ErrorModal.show(
        context,
        title: "Couldn't create form.",
        body: 'Check your connection and try again.',
        secondaryLabel: 'Cancel',
        onSecondary: () {},
        primaryLabel: 'Retry',
        onPrimary: () => _create(context, quiz: quiz),
      );
    }
  }
}

class _BlankCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final void Function(BuildContext) onCreate;

  const _BlankCard({
    required this.icon,
    required this.title,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: () => onCreate(context),
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              decoration: BoxDecoration(
                color: const Color(0xFFEDE7F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFD1C4E9), width: 1),
              ),
              height: 96,
              child: Center(child: Icon(icon, color: _purple, size: 40)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String category;
  final List<FormTemplate> templates;

  const _CategorySection({required this.category, required this.templates});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_categoryIcon(category), color: _purple, size: 20),
                const SizedBox(width: 8),
                Text(
                  category,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: templates.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemBuilder: (context, index) =>
                  _TemplateCard(template: templates[index]),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) => switch (category) {
        'Work' => Icons.work_outline,
        'Personal' => Icons.person_outline,
        'Education' => Icons.school_outlined,
        _ => Icons.folder_outlined,
      };
}

class _TemplateCard extends StatelessWidget {
  final FormTemplate template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _createFromTemplate(context, template),
        borderRadius: BorderRadius.circular(10),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(10),
                  ),
                  child: Image.asset(
                    template.imagePath,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: const Color(0xFFF3F0FA),
                      child: const Center(
                        child: Icon(Icons.description_outlined,
                            color: _purple, size: 32),
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF3F0FA),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(10),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Text(
                  template.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
    );
  }

  void _createFromTemplate(
      BuildContext context, FormTemplate template) async {
    final cubit = context.read<DashboardCubit>();
    try {
      await cubit.createForm(
          title: template.title,
          items: template.items,
          enableQuiz: template.quizMode);
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
