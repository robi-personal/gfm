import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design.dart';
import '../../../../core/widgets/error_modal.dart';
import '../../../editor/presentation/pages/editor_page.dart';
import '../cubit/dashboard_cubit.dart';
import '../widgets/template_blank_cards.dart';
import '../widgets/template_category_section.dart';
import '../widgets/template_category_tabs.dart';
import 'template_data.dart';

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
        backgroundColor: AppColors.bg,
        appBar: _buildAppBar(),
        body: _TemplatePickerBody(
          selectedCategory: _selectedCategory,
          onCategorySelected: (cat) =>
              setState(() => _selectedCategory = cat),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 18, color: AppColors.purple600),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text(
        'Create Form',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
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

    return AbsorbPointer(
      absorbing: isCreating,
      child: Stack(
        children: [
          _buildScrollView(context),
          if (isCreating) _buildCreatingOverlay(),
        ],
      ),
    );
  }

  Widget _buildScrollView(BuildContext context) {
    final visibleCategories = selectedCategory == 'All'
        ? kTemplateCategories
        : kTemplateCategories
            .where((c) => c == selectedCategory)
            .toList();

    return CustomScrollView(
      slivers: [
        _buildBlankCardsSliver(),
        _buildGalleryHeaderSliver(),
        _buildCategoryTabsSliver(),
        _buildTemplateSectionsSliver(visibleCategories),
        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  Widget _buildBlankCardsSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('START FROM SCRATCH', style: AppTextStyles.sectionLabel),
            const SizedBox(height: 12),
            const TemplateBlankCardsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryHeaderSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
        child: Text('TEMPLATE GALLERY', style: AppTextStyles.sectionLabel),
      ),
    );
  }

  Widget _buildCategoryTabsSliver() {
    return SliverToBoxAdapter(
      child: TemplateCategoryTabBar(
        selected: selectedCategory,
        onSelected: onCategorySelected,
      ),
    );
  }

  Widget _buildTemplateSectionsSliver(List<String> visibleCategories) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final category = visibleCategories[index];
            final templates =
                kFormTemplates.where((t) => t.category == category).toList();
            return TemplateCategorySection(
              category: category,
              templates: templates,
            );
          },
          childCount: visibleCategories.length,
        ),
      ),
    );
  }

  Widget _buildCreatingOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.25),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 14,
              children: [
                CupertinoActivityIndicator(
                    radius: 12, color: AppColors.purple600),
                Text(
                  'Creating form…',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
