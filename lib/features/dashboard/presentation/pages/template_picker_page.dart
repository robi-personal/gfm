import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/error_modal.dart';
import '../../../editor/presentation/pages/editor_page.dart';
import '../cubit/dashboard_cubit.dart';
import 'template_data.dart';

const _purple = Color(0xFF772FC0);
const _bgGray = Color(0xFFF5F5F5);

class TemplatePickerPage extends StatefulWidget {
  const TemplatePickerPage({super.key});

  @override
  State<TemplatePickerPage> createState() => _TemplatePickerPageState();
}

class _TemplatePickerPageState extends State<TemplatePickerPage> {
  String _selectedCategory = 'All';

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
            'Create Form',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ),
        body: _TemplatePickerBody(
          selectedCategory: _selectedCategory,
          onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, CreateNavigation nav) {
    final cubit = context.read<DashboardCubit>();
    cubit.clearNavigation();

    void goToEditor() async {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              EditorPage(formId: nav.formId, formName: nav.formName),
        ),
      );
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
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const _TemplatePickerBody({
    required this.selectedCategory,
    required this.onCategorySelected,
  });

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

    final visibleCategories = selectedCategory == 'All'
        ? kTemplateCategories
        : kTemplateCategories.where((c) => c == selectedCategory).toList();

    return AbsorbPointer(
      absorbing: isCreating,
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── header ───────────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 28, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start From Scratch or Select From Gallery',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverToBoxAdapter(child: _BlankCardsRow()),
              ),
              // ── Template Gallery header ───────────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 28, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Template Gallery',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              // ── Category tab bar ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: _CategoryTabBar(
                  selected: selectedCategory,
                  onSelected: onCategorySelected,
                ),
              ),
              // ── Category sections ─────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.only(top: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final category = visibleCategories[index];
                    final templates = kFormTemplates
                        .where((t) => t.category == category)
                        .toList();
                    return _CategorySection(
                      category: category,
                      templates: templates,
                    );
                  }, childCount: visibleCategories.length),
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

// ── Category tab bar ──────────────────────────────────────────────────────────

const _kTabDefs = [
  ('All', null),
  ('Work', Icons.work_outline),
  ('Personal', Icons.person_outline),
  ('Education', Icons.school_outlined),
];

class _CategoryTabBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryTabBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        itemCount: _kTabDefs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, icon) = _kTabDefs[index];
          final isSelected = selected == label;
          return GestureDetector(
            onTap: () => onSelected(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _purple : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _purple : const Color(0xFFDDDDDD),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 15,
                      color: isSelected ? Colors.white : Colors.black54,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Blank cards ───────────────────────────────────────────────────────────────

class _BlankCardsRow extends StatelessWidget {
  const _BlankCardsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BlankCard(
            icon: Icons.add,
            title: 'Blank form',
            onCreate: (context) => _create(context, quiz: false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BlankCard(
            icon: Icons.question_mark,
            title: 'Blank quiz',
            onCreate: (context) => _create(context, quiz: true),
          ),
        ),
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
    return Card(
      color: Colors.white,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => onCreate(context),
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  decoration: BoxDecoration(
                    color: Color(0xFFEDE7F6).withValues(alpha: .7),
                  ),
                  height: 112,
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
                fontSize: 11,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Category section ──────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String category;
  final List<FormTemplate> templates;

  const _CategorySection({required this.category, required this.templates});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Card(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _categoryEmoji(category),
                  const SizedBox(width: 8),
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFD1C4E9), height: 2),
              const SizedBox(height: 12),
              // Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: templates.length,
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (context, index) =>
                    _TemplateCard(template: templates[index]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryEmoji(String category) {
    final IconData icon = switch (category) {
      'Work' => (Icons.work_outline),
      'Personal' => (Icons.school_outlined),
      'Education' => (Icons.school),
      _ => (Icons.disabled_by_default),
    };
    return Container(
      width: 24,
      height: 24,
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(shape: BoxShape.circle, color: _purple),
      child: Center(child: Icon(icon, color: Colors.white, size: 14)),
    );
  }
}

// ── Template card ─────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final FormTemplate template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () => _createFromTemplate(context, template),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Image.asset(
                  template.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    color: const Color(0xFFF3F0FA),
                    child: const Center(
                      child: Icon(
                        Icons.description_outlined,
                        color: _purple,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Text(
                  template.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _createFromTemplate(BuildContext context, FormTemplate template) async {
    final cubit = context.read<DashboardCubit>();
    try {
      await cubit.createForm(
        title: template.title,
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
