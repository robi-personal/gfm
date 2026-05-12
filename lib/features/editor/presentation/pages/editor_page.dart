import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/drive_client.dart';
import '../../../../core/api/forms_client.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/form_doc.dart';
import '../../../../core/models/form_response.dart';
import '../../../../core/models/form_settings.dart';
import '../../../../core/models/item.dart';
import '../../../../core/models/item_content.dart';
import '../../../../core/widgets/skeleton_bone.dart';
import '../widgets/question_edit_sheet.dart';
import '../widgets/image_url_dialog.dart';
import '../widgets/video_search_dialog.dart';
import '../../../../core/widgets/error_modal.dart';
import '../../../paywall/data/services/subscription_service.dart';
import '../../../paywall/presentation/pages/paywall_page.dart';
import '../../../preview/preview_screen.dart';
import '../../../responses/presentation/pages/responses_page.dart';
import '../cubit/editor_cubit.dart';
import '../widgets/form_header_card.dart';
import '../widgets/question_card.dart';
import '../widgets/section_card.dart' show SectionCard, TextBlockCard, TextBlockEditSheet;

const _purple = Color(0xFF772FC0);
const _iosBg = Colors.white;
const _separator = Color(0xFFE8E8E8);
const _primaryText = Color(0xFF1C1C1E);
const _secondaryText = Color(0xFF8E8E93);

class EditorPage extends StatelessWidget {
  final String formId;
  final String formName;

  const EditorPage({
    super.key,
    required this.formId,
    required this.formName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<EditorCubit>()..loadForm(formId),
      child: _EditorView(formId: formId, initialName: formName),
    );
  }
}

// ── Main view (stateful for TabController) ────────────────────────────────────

class _EditorView extends StatefulWidget {
  final String formId;
  final String initialName;

  const _EditorView({required this.formId, required this.initialName});

  @override
  State<_EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<_EditorView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, animationDuration: Duration.zero);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) AnalyticsService.logResponsesViewed();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EditorCubit, EditorState>(
      listener: _onStateChange,
      listenWhen: (prev, curr) {
        if (prev.runtimeType != curr.runtimeType) return true;
        if (curr is EditorLoaded) {
          final p = prev is EditorLoaded ? prev : null;
          if (curr.conflictPending && !(p?.conflictPending ?? false)) return true;
          if (curr.saveFailed && !(p?.saveFailed ?? false)) return true;
          if (curr.pendingEditItemId != null &&
              curr.pendingEditItemId != (p?.pendingEditItemId)) {
            return true;
          }
        }
        return curr is EditorError;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: _buildAppBar(context),
        body: Column(
          children: [
            // Tab bar
            _SegmentedTabBar(controller: _tabController),
            // Tab content + floating bottom bar
            Expanded(
              child: Stack(
                children: [
                  SizedBox.expand(
                   child: ColoredBox(
                    color: const Color(0xFFF2F2F7),
                    child: BlocBuilder<EditorCubit, EditorState>(
                      buildWhen: (prev, curr) {
                        if (prev.runtimeType != curr.runtimeType) return true;
                        if (prev is EditorLoaded && curr is EditorLoaded) {
                          return prev.isSaving != curr.isSaving;
                        }
                        return false;
                      },
                      builder: (context, state) => switch (state) {
                        EditorLoading() => const _EditorSkeleton(),
                        EditorLoaded(:final isSaving) when isSaving =>
                          const _EditorSkeleton(),
                        EditorError(:final kind, :final message)
                            when kind == EditorErrorKind.network =>
                          _FullScreenError(
                            message: message,
                            onRetry: () =>
                                context.read<EditorCubit>().loadForm(widget.formId),
                          ),
                        EditorError() => const SizedBox.shrink(),
                        EditorLoaded(:final form) => TabBarView(
                            controller: _tabController,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              const _EditorBody(),
                              ResponsesScreen(
                                formId: widget.formId,
                                items: form.items,
                              ),
                              _SettingsTabPage(formId: widget.formId),
                            ],
                          ),
                      },
                    ),
                  )),
                  // Floating bottom toolbar — only on Questions tab
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        if (_tabController.index != 0) return const SizedBox.shrink();
                        return BlocSelector<EditorCubit, EditorState, bool>(
                          selector: (state) =>
                              state is EditorLoaded && !state.isSaving,
                          builder: (context, enabled) =>
                              _BottomBar(enabled: enabled, formId: widget.formId),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: _purple, size: 18),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.initialName,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: _primaryText,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        // Save button
        BlocSelector<EditorCubit, EditorState,
            ({bool isLoaded, bool isDirty, bool isSaving})>(
          selector: (state) => state is EditorLoaded
              ? (
                  isLoaded: true,
                  isDirty: state.isDirty,
                  isSaving: state.isSaving
                )
              : (isLoaded: false, isDirty: false, isSaving: false),
          builder: (context, data) {
            final active = data.isLoaded && data.isDirty;
            return GestureDetector(
              onTap: active && !data.isSaving
                  ? () => context.read<EditorCubit>().save()
                  : null,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? _purple
                      : _purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data.isSaving)
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CupertinoActivityIndicator(
                          radius: 6,
                          color: active ? Colors.white : _secondaryText,
                        ),
                      )
                    else
                      Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        size: 13,
                        color: active ? Colors.white : _secondaryText,
                      ),
                    const SizedBox(width: 4),
                    Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : _secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Options button
        BlocSelector<EditorCubit, EditorState,
            ({bool isLoaded, String responderUri, String title})>(
          selector: (state) => state is EditorLoaded
              ? (
                  isLoaded: true,
                  responderUri: state.form.responderUri,
                  title: state.form.info.title
                )
              : (isLoaded: false, responderUri: '', title: ''),
          builder: (context, data) {
            return IconButton(
              icon: Icon(CupertinoIcons.ellipsis_vertical, color: _purple, size: 22),
              onPressed: data.isLoaded
                  ? () => _showOptionsSheet(
                      context, data.responderUri, data.title)
                  : null,
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _showOptionsSheet(
      BuildContext context, String responderUri, String title) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _OptionsSheet(
        responderUri: responderUri,
        title: title,
      ),
    );
  }

  void _onStateChange(BuildContext context, EditorState state) {
    // Auto-open edit sheet for newly added items
    if (state case EditorLoaded(:final pendingEditItemId?)) {
      final cubit = context.read<EditorCubit>();
      cubit.clearPendingEdit();
      final loaded = state;
      final item = loaded.form.items
          .where((i) => i.itemId == pendingEditItemId)
          .firstOrNull;
      if (item != null) {
        if (item.content is TextItemContent) {
          TextBlockEditSheet.show(context, item);
        } else {
          final sections = loaded.form.items
              .where((i) => i.content is PageBreakItemContent)
              .toList();
          QuestionEditSheet.show(
            context, item, sections,
            isQuiz: loaded.form.settings.quizSettings.isQuiz,
          );
        }
      }
      return;
    }

    if (state case EditorLoaded(conflictPending: true)) {
      context.read<EditorCubit>().clearConflict();
      ErrorModal.show(
        context,
        title: 'This form was edited somewhere else.',
        body: 'Keep your version or load the latest?',
        primaryLabel: 'Keep mine',
        onPrimary: () =>
            context.read<EditorCubit>().resolveConflictKeepMine(),
        secondaryLabel: 'Load latest',
        onSecondary: () =>
            context.read<EditorCubit>().resolveConflictLoadLatest(),
      );
    }

    if (state case EditorLoaded(saveFailed: true)) {
      context.read<EditorCubit>().clearSaveFailed();
      ErrorModal.show(
        context,
        title: "Couldn't save your changes.",
        body: 'Check your connection and try again.',
        primaryLabel: 'OK',
        onPrimary: () {},
      );
    }

    if (state case EditorError(:final kind)) {
      switch (kind) {
        case EditorErrorKind.notFound:
          ErrorModal.show(
            context,
            title: 'This form was deleted.',
            body: "It's no longer available in your Drive.",
            primaryLabel: 'OK',
            onPrimary: () => Navigator.of(context).pop(),
          );
        case EditorErrorKind.permissionDenied:
          ErrorModal.show(
            context,
            title: "You don't have access to this form.",
            body: 'The owner may have revoked your access.',
            primaryLabel: 'OK',
            onPrimary: () => Navigator.of(context).pop(),
          );
        case EditorErrorKind.network:
          break;
      }
    }
  }
}

// ── Options bottom sheet ──────────────────────────────────────────────────────

class _OptionsSheet extends StatelessWidget {
  final String responderUri;
  final String title;

  const _OptionsSheet({required this.responderUri, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 12,
        left: 12,
        right: 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main actions card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _OptionTile(
                  icon: CupertinoIcons.eye_fill,
                  label: 'Preview',
                  subtitle: 'See how the form looks to respondents',
                  color: _purple,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => PreviewScreen(
                        responderUri: responderUri,
                        formTitle: title,
                      ),
                    ));
                  },
                ),
                const Divider(height: 1, indent: 60, color: Color(0xFFEEEEEE)),
                _OptionTile(
                  icon: CupertinoIcons.share_solid,
                  label: 'Share',
                  subtitle: 'Send the form link to respondents',
                  color: _purple,
                  onTap: () {
                    Navigator.of(context).pop();
                    Share.share(responderUri, subject: title);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Cancel button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _purple,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _primaryText,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(CupertinoIcons.chevron_right,
                size: 14, color: _secondaryText),
          ],
        ),
      ),
    );
  }
}

// ── Segmented tab bar ─────────────────────────────────────────────────────────

class _SegmentedTabBar extends StatefulWidget {
  final TabController controller;
  const _SegmentedTabBar({required this.controller});

  @override
  State<_SegmentedTabBar> createState() => _SegmentedTabBarState();
}

class _SegmentedTabBarState extends State<_SegmentedTabBar> {
  static const _tabs = [
    (icon: CupertinoIcons.list_bullet, label: 'Questions'),
    (icon: CupertinoIcons.chart_bar_alt_fill, label: 'Responses'),
    (icon: CupertinoIcons.settings_solid, label: 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final selected = widget.controller.index;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF3B1278).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final isSelected = i == selected;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.controller.index = i,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IntrinsicWidth(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _tabs[i].icon,
                                    size: isSelected ? 16 : 15,
                                    color: Colors.white.withValues(
                                        alpha: 1.0),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    _tabs[i].label,
                                    style: TextStyle(
                                      fontSize: isSelected ? 14 : 12,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: Colors.white.withValues(
                                          alpha: 1.0),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: isSelected ? 2.5 : 0,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Value objects for BlocSelectors ──────────────────────────────────────────

class _BodyData {
  final List<String> itemIds;
  final String title;
  final String description;

  const _BodyData({
    required this.itemIds,
    required this.title,
    required this.description,
  });

  static const empty = _BodyData(itemIds: [], title: '', description: '');

  @override
  bool operator ==(Object other) =>
      other is _BodyData &&
      other.title == title &&
      other.description == description &&
      listEquals(other.itemIds, itemIds);

  @override
  int get hashCode =>
      Object.hash(title, description, Object.hashAll(itemIds));
}

class _ItemData {
  final Item? item;
  final List<Item> sections;
  final bool isQuiz;

  const _ItemData({required this.item, required this.sections, this.isQuiz = false});

  @override
  bool operator ==(Object other) =>
      other is _ItemData &&
      other.item == item &&
      other.isQuiz == isQuiz &&
      listEquals(other.sections, sections);

  @override
  int get hashCode => Object.hash(item, isQuiz, Object.hashAll(sections));
}

// ── Editor body (Questions tab) ───────────────────────────────────────────────

class _EditorBody extends StatefulWidget {
  const _EditorBody();

  @override
  State<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends State<_EditorBody> {
  final _scrollController = ScrollController();
  int _prevItemCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EditorCubit, EditorState>(
      listenWhen: (prev, curr) {
        if (curr is! EditorLoaded) return false;
        final prevCount =
            prev is EditorLoaded ? prev.form.items.length : _prevItemCount;
        return curr.form.items.length > prevCount;
      },
      listener: (context, state) {
        if (state is EditorLoaded) {
          _prevItemCount = state.form.items.length;
          _scrollToBottom();
        }
      },
      child: BlocSelector<EditorCubit, EditorState, _BodyData>(
        selector: (state) {
          if (state is! EditorLoaded) return _BodyData.empty;
          final form = state.form;
          return _BodyData(
            itemIds: form.items.map((i) => i.itemId).toList(),
            title: form.info.title,
            description: form.info.description,
          );
        },
        builder: (context, data) {
          final header = FormHeaderCard(
            key: const ValueKey('__header__'),
            initialTitle: data.title,
            initialDescription: data.description,
          );

          const physics = BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          );

          if (data.itemIds.isEmpty) {
            return CustomScrollView(
              controller: _scrollController,
              physics: physics,
              slivers: [
                SliverToBoxAdapter(child: header),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.question_circle,
                            size: 56,
                            color: Color(0xFFD1D1D6),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No questions yet.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3C3C43),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Tap + below to add your first question.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: _secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return CustomScrollView(
            controller: _scrollController,
            physics: physics,
            cacheExtent: 600,
            slivers: [
              SliverToBoxAdapter(child: header),
              SliverPadding(
                padding: const EdgeInsets.only(top: 4, bottom: 100),
                sliver: SliverReorderableList(
                  itemCount: data.itemIds.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    if (oldIndex == newIndex) return;
                    context.read<EditorCubit>().moveItem(oldIndex, newIndex);
                  },
                  itemBuilder: (context, i) {
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(data.itemIds[i]),
                      index: i,
                      child: BlocProvider.value(
                        value: context.read<EditorCubit>(),
                        child: _ItemRow(itemId: data.itemIds[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Per-item row ──────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final String itemId;

  const _ItemRow({required this.itemId});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<EditorCubit, EditorState, _ItemData>(
      selector: (state) {
        if (state is! EditorLoaded) {
          return const _ItemData(item: null, sections: []);
        }
        final items = state.form.items;
        final idx = items.indexWhere((i) => i.itemId == itemId);
        final item = idx == -1 ? null : items[idx];
        final sections = items
            .where((i) => i.content is PageBreakItemContent)
            .toList(growable: false);
        return _ItemData(
          item: item,
          sections: sections,
          isQuiz: state.form.settings.quizSettings.isQuiz,
        );
      },
      builder: (context, data) {
        final item = data.item;
        if (item == null) return const SizedBox.shrink();
        return switch (item.content) {
          QuestionItemContent() || QuestionGroupItemContent() =>
            QuestionCard(item: item, sections: data.sections, isQuiz: data.isQuiz),
          PageBreakItemContent() => SectionCard(item: item),
          TextItemContent() => TextBlockCard(item: item),
          ImageItemContent() => _ImageCard(item: item),
          VideoItemContent() => _VideoCard(item: item),
        };
      },
    );
  }
}

// ── Settings tab page (inline) ────────────────────────────────────────────────

class _SettingsTabPage extends StatelessWidget {
  final String formId;

  const _SettingsTabPage({required this.formId});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<EditorCubit, EditorState,
        ({FormSettings? settings, String? linkedSheetId})>(
      selector: (state) => (
        settings: state is EditorLoaded ? state.form.settings : null,
        linkedSheetId: state is EditorLoaded ? state.form.linkedSheetId : null,
      ),
      builder: (context, data) {
        if (data.settings == null) {
          return const Center(child: CupertinoActivityIndicator());
        }
        return _SettingsContent(
          initialSettings: data.settings!,
          formId: formId,
          linkedSheetId: data.linkedSheetId,
        );
      },
    );
  }
}

class _SettingsContent extends StatefulWidget {
  final FormSettings initialSettings;
  final String formId;
  final String? linkedSheetId;

  const _SettingsContent({
    required this.initialSettings,
    required this.formId,
    this.linkedSheetId,
  });

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  late EmailCollectionType _emailType;
  late bool _isQuiz;
  bool _isSaving = false;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _emailType = widget.initialSettings.emailCollectionType;
    _isQuiz = widget.initialSettings.quizSettings.isQuiz;
  }

  Future<void> _exportCsv() async {
    if (_isExporting) return;
    final isPremium = await getIt<SubscriptionService>().isPremium();
    if (!mounted) return;
    if (!isPremium) {
      await PaywallPage.show(context);
      return;
    }
    setState(() => _isExporting = true);
    try {
      final editorState = context.read<EditorCubit>().state;
      if (editorState is! EditorLoaded) return;
      final form = editorState.form;

      // Load all responses
      final client = getIt<FormsClient>();
      final responses = <FormResponse>[];
      String? pageToken;
      do {
        final result = await client.api.forms.responses.list(
          widget.formId,
          pageSize: 100,
          pageToken: pageToken,
        );
        responses.addAll((result.responses ?? []).map(FormResponse.fromApi));
        pageToken = result.nextPageToken;
      } while (pageToken != null);
      responses.sort((a, b) => a.createTime.compareTo(b.createTime));

      final csv = _buildCsv(form, responses);

      final dir = await getTemporaryDirectory();
      final title = form.info.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final file = File('${dir.path}/${title}_responses.csv');
      await file.writeAsString(csv);

      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: '${form.info.title} — Responses',
      );
      AnalyticsService.logCsvExported();
    } catch (e) {
      if (!mounted) return;
      ErrorModal.show(
        context,
        title: "Export failed.",
        body: 'Check your connection and try again.',
        primaryLabel: 'OK',
        onPrimary: () {},
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _buildCsv(FormDoc form, List<FormResponse> responses) {
    // Build ordered question index
    final cols = <({String title, String questionId})>[];
    for (final item in form.items) {
      final itemTitle =
          item.title?.isNotEmpty == true ? item.title! : 'Untitled';
      switch (item.content) {
        case QuestionItemContent(:final question):
          cols.add((title: itemTitle, questionId: question.questionId));
        case QuestionGroupItemContent(:final questions):
          for (final q in questions) {
            cols.add((title: itemTitle, questionId: q.questionId));
          }
        default:
          break;
      }
    }
    final questions = cols;

    String escape(String v) {
      if (v.contains(',') || v.contains('"') || v.contains('\n')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }

    final buffer = StringBuffer();
    // Header row
    buffer.write('Timestamp,Email');
    for (final q in questions) { buffer.write(',${escape(q.title)}'); }
    buffer.writeln();

    // Data rows
    for (final r in responses) {
      buffer.write(escape(r.createTime.toIso8601String()));
      buffer.write(',${escape(r.respondentEmail ?? '')}');
      for (final q in questions) {
        final vals = r.answers[q.questionId] ?? [];
        buffer.write(',${escape(vals.join('; '))}');
      }
      buffer.writeln();
    }
    return buffer.toString();
  }

  Future<void> _save({required EmailCollectionType emailType, required bool isQuiz}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await context.read<EditorCubit>().updateSettings(
          FormSettings(
            quizSettings: QuizSettings(isQuiz: isQuiz),
            emailCollectionType: emailType,
          ),
        );
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _onQuizToggle(bool value) async {
    if (!value) {
      bool? confirmed;
      await ErrorModal.show(
        context,
        title: 'Turn off quiz mode?',
        body: 'All answer keys and point values will be permanently removed.',
        primaryLabel: 'Turn off',
        onPrimary: () => confirmed = true,
        secondaryLabel: 'Cancel',
        onSecondary: () => confirmed = false,
      );
      if (confirmed != true) return;
    }
    setState(() => _isQuiz = value);
    await _save(emailType: _emailType, isQuiz: value);
  }

  Future<void> _onEmailTypeChange(EmailCollectionType value) async {
    setState(() => _emailType = value);
    await _save(emailType: value, isQuiz: _isQuiz);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16, 20, 16, MediaQuery.viewPaddingOf(context).bottom + 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Email collection ───────────────────────────────────────────────
          _IosGroupLabel(
            label: 'COLLECT EMAIL ADDRESSES',
            trailing: _isSaving
                ? const CupertinoActivityIndicator(radius: 7)
                : null,
          ),
          _IosCard(children: [
            _IosRadioTile(
              label: "Don't collect",
              selected: _emailType == EmailCollectionType.doNotCollect,
              onTap: _isSaving
                  ? null
                  : () => _onEmailTypeChange(EmailCollectionType.doNotCollect),
            ),
            _IosRadioTile(
              label: 'Verified (Workspace accounts only)',
              selected: _emailType == EmailCollectionType.verified,
              onTap: _isSaving
                  ? null
                  : () => _onEmailTypeChange(EmailCollectionType.verified),
            ),
            _IosRadioTile(
              label: 'Ask respondents',
              selected: _emailType == EmailCollectionType.responderInput,
              isLast: true,
              onTap: _isSaving
                  ? null
                  : () =>
                      _onEmailTypeChange(EmailCollectionType.responderInput),
            ),
          ]),
          const SizedBox(height: 28),

          // ── Quiz mode ──────────────────────────────────────────────────────
          const _IosGroupLabel(label: 'QUIZ'),
          _IosCard(children: [
            _IosSwitchTile(
              label: 'Quiz mode',
              subtitle: 'Assign point values and set correct answers',
              value: _isQuiz,
              isLast: true,
              onChanged: _isSaving ? null : _onQuizToggle,
            ),
          ]),
          const SizedBox(height: 28),

          // ── Data ───────────────────────────────────────────────────────────
          const _IosGroupLabel(label: 'DATA'),
          _IosCard(children: [
            _IosActionTile(
              icon: _isExporting
                  ? null
                  : CupertinoIcons.arrow_down_circle,
              leadingWidget: _isExporting
                  ? const CupertinoActivityIndicator(radius: 10)
                  : null,
              label: 'Export responses as CSV',
              isLast: widget.linkedSheetId == null,
              onTap: _isExporting ? null : _exportCsv,
            ),
            if (widget.linkedSheetId != null)
              _IosActionTile(
                icon: CupertinoIcons.table,
                label: 'Open linked Google Sheet',
                trailing: const Icon(
                  CupertinoIcons.arrow_up_right_square,
                  size: 16,
                  color: _secondaryText,
                ),
                isLast: true,
                onTap: () => launchUrl(
                  Uri.parse(
                    'https://docs.google.com/spreadsheets/d/${widget.linkedSheetId}',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
              ),
          ]),
        ],
      ),
    );
  }
}

// ── iOS settings helpers ──────────────────────────────────────────────────────

class _IosGroupLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;

  const _IosGroupLabel({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _secondaryText,
              letterSpacing: 0.4,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _IosCard extends StatelessWidget {
  final List<Widget> children;

  const _IosCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _iosBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _IosRadioTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isLast;
  final VoidCallback? onTap;

  const _IosRadioTile({
    required this.label,
    required this.selected,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 15, color: _primaryText),
                  ),
                ),
                if (selected)
                  const Icon(CupertinoIcons.checkmark, size: 18, color: _purple),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Divider(height: 1, color: _separator),
          ),
      ],
    );
  }
}

class _IosSwitchTile extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final bool isLast;
  final ValueChanged<bool>? onChanged;

  const _IosSwitchTile({
    required this.label,
    required this.value,
    this.subtitle,
    this.isLast = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 15, color: _primaryText),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              CupertinoSwitch(
                value: value,
                activeTrackColor: _purple,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Divider(height: 1, color: _separator),
          ),
      ],
    );
  }
}

class _IosActionTile extends StatelessWidget {
  final IconData? icon;
  final Widget? leadingWidget;
  final String label;
  final Widget? trailing;
  final bool isLast;
  final VoidCallback? onTap;

  const _IosActionTile({
    this.icon,
    this.leadingWidget,
    required this.label,
    this.trailing,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final leading = leadingWidget ??
        (icon != null
            ? Icon(icon, size: 20, color: _purple)
            : const SizedBox(width: 20));

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 15, color: _primaryText),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(left: 48),
            child: Divider(height: 1, color: _separator),
          ),
      ],
    );
  }
}

// ── Bottom bar (5 buttons) ────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final bool enabled;
  final String formId;

  const _BottomBar({required this.enabled, required this.formId});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EditorCubit>();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF3B1278).withValues(alpha: 0.60),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B1278).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BarButton(
                icon: CupertinoIcons.add_circled_solid,
                label: 'Question',
                enabled: enabled,
                onTap: () => cubit.addQuestion(),
              ),
              _BarButton(
                icon: CupertinoIcons.photo_fill,
                label: 'Image',
                enabled: enabled,
                onTap: () async {
                  final driveClient = getIt<DriveClient>();
                  final url = await showImageUrlDialog(
                    context,
                    onGalleryUpload: (bytes, mimeType) =>
                        driveClient.uploadImage(bytes, mimeType),
                  );
                  if (url != null && context.mounted) {
                    cubit.addImageItem(url);
                  }
                },
              ),
              _BarButton(
                icon: CupertinoIcons.textformat_alt,
                label: 'Text',
                enabled: enabled,
                onTap: () => cubit.addTextBlock(),
              ),
              _BarButton(
                icon: CupertinoIcons.play_circle_fill,
                label: 'Video',
                enabled: enabled,
                onTap: () async {
                  final video = await showVideoSearchDialog(context);
                  if (video != null && context.mounted) {
                    cubit.addVideoItem(video.videoId, video.title);
                  }
                },
              ),
              _BarButton(
                icon: CupertinoIcons.rectangle_stack_fill,
                label: 'Section',
                enabled: enabled,
                onTap: () => cubit.addSection(),
              ),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _BarButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled
        ? Colors.white
        : Colors.white.withValues(alpha: 0.35);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: enabled
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _EditorSkeleton extends StatelessWidget {
  const _EditorSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE5E5EA),
      highlightColor: const Color(0xFFF2F2F7),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          _SkeletonHeaderCard(),
          SizedBox(height: 8),
          _SkeletonQuestionCard(),
          _SkeletonQuestionCard(),
          _SkeletonQuestionCard(),
        ],
      ),
    );
  }
}

class _SkeletonHeaderCard extends StatelessWidget {
  const _SkeletonHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(16),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBone(width: 200, height: 20, radius: 4),
            SizedBox(height: 10),
            SkeletonBone(width: double.infinity, height: 13, radius: 4),
          ],
        ),
      ),
    );
  }
}

class _SkeletonQuestionCard extends StatelessWidget {
  const _SkeletonQuestionCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBone(width: 180, height: 14, radius: 4),
            SizedBox(height: 10),
            SkeletonBone(width: 72, height: 22, radius: 12),
            SizedBox(height: 12),
            SkeletonBone(width: double.infinity, height: 11, radius: 4),
            SizedBox(height: 6),
            SkeletonBone(width: 160, height: 11, radius: 4),
          ],
        ),
      ),
    );
  }
}

// ── Media placeholders ────────────────────────────────────────────────────────

class _ImageCard extends StatelessWidget {
  final Item item;

  const _ImageCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final content = item.content as ImageItemContent;
    final imageUrl =
        content.image.sourceUri ?? content.image.contentUri;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _iosBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(
                height: 180,
                child: Center(
                  child: Icon(CupertinoIcons.photo,
                      size: 40, color: Color(0xFFD1D1D6)),
                ),
              ),
            )
          else
            const SizedBox(
              height: 180,
              child: Center(
                child: Icon(CupertinoIcons.photo,
                    size: 40, color: Color(0xFFD1D1D6)),
              ),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _editImage(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(CupertinoIcons.pencil,
                        color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () =>
                      context.read<EditorCubit>().deleteItem(item.itemId),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(CupertinoIcons.xmark,
                        color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editImage(BuildContext context) async {
    final cubit = context.read<EditorCubit>();
    final driveClient = getIt<DriveClient>();
    final url = await showImageUrlDialog(
      context,
      onGalleryUpload: (bytes, mimeType) =>
          driveClient.uploadImage(bytes, mimeType),
    );
    if (url != null && context.mounted) {
      final content = item.content as ImageItemContent;
      cubit.updateItemFull(
        item.copyWith(
          content: content.copyWith(
            image: content.image.copyWith(sourceUri: url),
          ),
        ),
      );
    }
  }
}

class _VideoCard extends StatelessWidget {
  final Item item;

  const _VideoCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final content = item.content as VideoItemContent;
    final videoId =
        Uri.tryParse(content.video.youtubeUri)?.queryParameters['v'];
    final thumbnailUrl = videoId != null
        ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg'
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _iosBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (thumbnailUrl != null)
                Image.network(
                  thumbnailUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 160,
                    color: const Color(0xFFF2F2F7),
                    child: const Icon(CupertinoIcons.play_circle,
                        size: 48, color: Color(0xFFD1D1D6)),
                  ),
                )
              else
                Container(
                  height: 160,
                  color: const Color(0xFFF2F2F7),
                  child: const Icon(CupertinoIcons.play_circle,
                      size: 48, color: Color(0xFFD1D1D6)),
                ),
              Container(
                width: 52,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(CupertinoIcons.play_arrow_solid,
                    color: Colors.white, size: 22),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () =>
                      context.read<EditorCubit>().deleteItem(item.itemId),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(CupertinoIcons.xmark,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Text(
              item.title ?? content.caption ?? 'Video',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: _primaryText),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full screen error ────────────────────────────────────────────────────────

class _FullScreenError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _FullScreenError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: _primaryText),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _purple),
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
