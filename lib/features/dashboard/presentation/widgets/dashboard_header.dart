import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/design.dart';
import '../../../../../core/di/injection.dart';
import '../../../ai_form_builder/data/services/user_status_service.dart';
import '../cubit/dashboard_cubit.dart';

class DashboardHeader extends StatefulWidget implements PreferredSizeWidget {
  final bool isTablet;
  final VoidCallback onShowPaywall;

  const DashboardHeader({
    super.key,
    required this.isTablet,
    required this.onShowPaywall,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends State<DashboardHeader> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocus.requestFocus(),
    );
  }

  void _closeSearch() {
    setState(() => _searchOpen = false);
    _searchController.clear();
    context.read<DashboardCubit>().search('');
  }

  @override
  Widget build(BuildContext context) {
    return _searchOpen ? _searchBar() : _normalBar();
  }

  AppBar _searchBar() {
    return AppBar(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 18, color: AppColors.purple600),
        onPressed: _closeSearch,
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        style: const TextStyle(fontSize: 15, color: AppColors.ink),
        cursorColor: AppColors.purple600,
        decoration: InputDecoration(
          hintText: 'Search forms…',
          hintStyle: const TextStyle(color: AppColors.muted2),
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
            borderSide:
                const BorderSide(color: AppColors.purple600, width: 1.5),
          ),
        ),
        onChanged: (q) => context.read<DashboardCubit>().search(q),
      ),
    );
  }

  AppBar _normalBar() {
    return AppBar(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: widget.isTablet ? null : 4,
      automaticallyImplyLeading: false,
      leading: widget.isTablet
          ? null
          : Builder(
              builder: (ctx) => IconButton(
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                icon: const Icon(Icons.menu_rounded,
                    size: 22, color: AppColors.ink),
              ),
            ),
      title: const Text(
        'GFM',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
          letterSpacing: 0.3,
        ),
      ),
      actions: [
        _SearchButton(onTap: _openSearch),
        ListenableBuilder(
          listenable: getIt<UserStatusService>(),
          builder: (context, _) {
            final isPremium = getIt<UserStatusService>().status?.isPremium;
            if (isPremium != false) return const SizedBox.shrink();
            return GestureDetector(
              onTap: widget.onShowPaywall,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SvgPicture.asset(
                  'assets/dashboard_premium.svg',
                  width: 26,
                  height: 26,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SearchButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
          boxShadow: AppShapes.cardShadow,
        ),
        child: const Icon(Icons.search_rounded, size: 20, color: AppColors.ink),
      ),
    );
  }
}
