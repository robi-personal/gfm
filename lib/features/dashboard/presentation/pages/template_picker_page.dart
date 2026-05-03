import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/error_modal.dart';
import '../../../editor/presentation/pages/editor_page.dart';
import '../cubit/dashboard_cubit.dart';
import 'template_data.dart';

const _purple = Color(0xFF772FC0);

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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          title: const Text(
            'New form',
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
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(child: _BlankCardsRow()),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 28, 16, 6),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Templates',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              SliverList(
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
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
          if (isCreating)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.white54,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
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
          subtitle: 'Start from scratch',
          onCreate: (context) => _create(context, quiz: false),
        )),
        const SizedBox(width: 12),
        Expanded(child: _BlankCard(
          icon: Icons.quiz_outlined,
          title: 'Blank quiz',
          subtitle: 'Auto-graded quiz',
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
  final String subtitle;
  final void Function(BuildContext) onCreate;

  const _BlankCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onCreate(context),
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0D6F5), width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F0FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _purple, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              category,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
                letterSpacing: 0.4,
              ),
            ),
          ),
          SizedBox(
            height: 136,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: templates.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) =>
                  _TemplateCard(template: templates[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final FormTemplate template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _createFromTemplate(context, template),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                template.imagePath,
                width: 120,
                height: 96,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  width: 120,
                  height: 96,
                  color: const Color(0xFFF3F0FA),
                  child: const Icon(Icons.description_outlined,
                      color: _purple, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              template.title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: Colors.black87,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
          title: template.title, items: template.items, enableQuiz: template.quizMode);
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
