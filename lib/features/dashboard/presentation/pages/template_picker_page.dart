import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/error_modal.dart';
import '../../../editor/presentation/pages/editor_page.dart';
import '../cubit/dashboard_cubit.dart';
import 'template_data.dart';
import '../../../../core/theme/app_colors.dart';

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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: AppColors.purple),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: const Text(
            'Create Form',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: _TemplatePickerBody(
          selectedCategory: _selectedCategory,
          onCategorySelected: (cat) =>
              setState(() => _selectedCategory = cat),
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
      if (context.mounted) cubit.loadForms();
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

// ── Body ──────────────────────────────────────────────────────────────────────

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
      return switch (c.state) {
        DashboardLoaded(:final isCreating) => isCreating,
        DashboardError(:final isCreating) => isCreating,
        _ => false,
      };
    });

    final visibleCategories = selectedCategory == 'All'
        ? kTemplateCategories
        : kTemplateCategories
            .where((c) => c == selectedCategory)
            .toList();

    return AbsorbPointer(
      absorbing: isCreating,
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Blank cards ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionLabel('START FROM SCRATCH'),
                      const SizedBox(height: 12),
                      const _BlankCardsRow(),
                    ],
                  ),
                ),
              ),

              // ── Template gallery header ──────────────────────────────────
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 28, 16, 12),
                  child: _SectionLabel('TEMPLATE GALLERY'),
                ),
              ),

              // ── Category tabs ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _CategoryTabBar(
                  selected: selectedCategory,
                  onSelected: onCategorySelected,
                ),
              ),

              // ── Template sections ────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.only(top: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final category = visibleCategories[index];
                      final templates = kFormTemplates
                          .where((t) => t.category == category)
                          .toList();
                      return _CategorySection(
                        category: category,
                        templates: templates,
                      );
                    },
                    childCount: visibleCategories.length,
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
            ],
          ),

          // ── Creating overlay ─────────────────────────────────────────────
          if (isCreating)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(
                  child: CupertinoActivityIndicator(
                      radius: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
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
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.6,
      ),
    );
  }
}

// ── Category tab bar ──────────────────────────────────────────────────────────

const _kTabDefs = [
  ('All',       null),
  ('Work',      CupertinoIcons.briefcase),
  ('Personal',  CupertinoIcons.person),
  ('Education', CupertinoIcons.book),
];

class _CategoryTabBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _CategoryTabBar(
      {required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final (label, icon) in _kTabDefs)
              _TabChip(
                label: label,
                icon: icon,
                selected: selected == label,
                onTap: () => onSelected(label),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.purple : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Form name dialog ──────────────────────────────────────────────────────────

Future<String?> _showFormNameDialog(
  BuildContext context, {
  String prefill = '',
}) {
  final controller = TextEditingController(text: prefill);
  if (prefill.isNotEmpty) {
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: prefill.length,
    );
  }

  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    CupertinoIcons.doc_text,
                    color: AppColors.purple,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Form Name',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: AppColors.groupedBackground),
            const SizedBox(height: 12),
            const Text(
              'Give your form a name to get started.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6E6E73)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
              cursorColor: AppColors.purple,
              decoration: InputDecoration(
                hintText: 'e.g. Customer Feedback',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.groupedBackground,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.purple, width: 1.5),
                ),
              ),
              onSubmitted: (v) {
                final name = v.trim();
                if (name.isNotEmpty) Navigator.of(ctx).pop(name);
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: AppColors.groupedBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatefulBuilder(
                    builder: (ctx2, setLocal) {
                      controller.addListener(() => setLocal(() {}));
                      final canCreate = controller.text.trim().isNotEmpty;
                      return GestureDetector(
                        onTap: canCreate
                            ? () => Navigator.of(ctx)
                                .pop(controller.text.trim())
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: canCreate
                                ? AppColors.purple
                                : AppColors.purple.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: canCreate
                                ? [
                                    BoxShadow(
                                      color: AppColors.purple.withValues(alpha: 0.30),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [],
                          ),
                          child: const Center(
                            child: Text(
                              'Create',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Blank cards row ───────────────────────────────────────────────────────────

class _BlankCardsRow extends StatelessWidget {
  const _BlankCardsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BlankCard(
            icon: CupertinoIcons.add,
            title: 'Blank Form',
            onCreate: (ctx) => _create(ctx, quiz: false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BlankCard(
            icon: CupertinoIcons.question,
            title: 'Blank Quiz',
            onCreate: (ctx) => _create(ctx, quiz: true),
          ),
        ),
      ],
    );
  }

  void _create(BuildContext context, {required bool quiz}) async {
    final defaultName = quiz ? 'Untitled quiz' : 'Untitled form';
    final name = await _showFormNameDialog(context, prefill: defaultName);
    if (name == null || !context.mounted) return;

    final cubit = context.read<DashboardCubit>();
    try {
      if (quiz) {
        await cubit.createForm(
          title: name,
          items: kBlankQuizTemplate.items,
          enableQuiz: true,
        );
      } else {
        await cubit.createForm(title: name);
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.separator),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => onCreate(context),
        borderRadius: BorderRadius.circular(14),
        splashColor: AppColors.purple.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.purple, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Category section ──────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String category;
  final List<FormTemplate> templates;

  const _CategorySection(
      {required this.category, required this.templates});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _categoryIcon(category),
                      color: AppColors.purple,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    category,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(
                  height: 1, thickness: 1, color: AppColors.groupedBackground),
              const SizedBox(height: 14),
              // Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: templates.length,
                padding: EdgeInsets.zero,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
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

  IconData _categoryIcon(String category) => switch (category) {
        'Work'      => CupertinoIcons.briefcase,
        'Personal'  => CupertinoIcons.person,
        'Education' => CupertinoIcons.book,
        _           => CupertinoIcons.doc_text,
      };
}

// ── Template card ─────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final FormTemplate template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: InkWell(
        onTap: () => _createFromTemplate(context, template),
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.purple.withValues(alpha: 0.06),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
                child: Image.asset(
                  template.imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) => Container(
                    color: AppColors.purple.withValues(alpha: 0.06),
                    child: const Center(
                      child: Icon(
                        CupertinoIcons.doc_text,
                        color: AppColors.purple,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Text(
                template.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createFromTemplate(
      BuildContext context, FormTemplate template) async {
    final name =
        await _showFormNameDialog(context, prefill: template.title);
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
