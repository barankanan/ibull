import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../models/db_category.dart';
import '../../../services/supabase_service.dart';

/// Both rows use the same active category tree and retain the parent selection.
class HomeCategoryNavigation extends StatefulWidget {
  const HomeCategoryNavigation({
    super.key,
    required this.selectedCategory,
    required this.selectedSubCategory,
    required this.onSelected,
    this.onOpenSubCategory,
    this.loadCategories,
  });

  final String selectedCategory;
  final String? selectedSubCategory;
  final void Function(String category, String? subCategory) onSelected;
  final void Function(DBCategory mainCategory, DBCategory subCategory)?
  onOpenSubCategory;
  final Future<List<CategoryWithSubcategories>> Function()? loadCategories;

  @override
  State<HomeCategoryNavigation> createState() => _HomeCategoryNavigationState();
}

class _HomeCategoryNavigationState extends State<HomeCategoryNavigation> {
  late Future<List<CategoryWithSubcategories>> _categories = _load();
  Timer? _closeTimer;
  MenuController? _activeMenuController;
  final Map<int, ScrollController> _menuScrollControllers = {};

  Future<List<CategoryWithSubcategories>> _load() =>
      (widget.loadCategories ??
      SupabaseService.instance.getCategoriesWithSubsStrict)();

  @override
  void dispose() {
    _closeTimer?.cancel();
    for (final controller in _menuScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _cancelClose() => _closeTimer?.cancel();

  void _scheduleClose(MenuController controller) {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 180), controller.close);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CategoryWithSubcategories>>(
      future: _categories,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 52,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Kategoriler yükleniyor…'),
            ),
          );
        }
        if (snapshot.hasError) {
          return Row(
            children: [
              const Expanded(child: Text('Kategoriler yüklenemedi.')),
              TextButton(
                onPressed: () => setState(() => _categories = _load()),
                child: const Text('Tekrar dene'),
              ),
            ],
          );
        }
        final categories =
            (snapshot.data ?? const <CategoryWithSubcategories>[])
                .where((node) => node.mainCategory.isActive)
                .toList(growable: false);
        return SizedBox(
          height: 52,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) =>
                  _categoryMenu(context, categories[index]),
            ),
          ),
        );
      },
    );
  }

  Widget _categoryMenu(
    BuildContext context,
    CategoryWithSubcategories node,
  ) {
    final main = node.mainCategory;
    final subs = node.subCategories
        .where((sub) => sub.isActive && sub.parentId == main.id)
        .toList(growable: false);
    if (subs.isEmpty) {
      return TextButton(onPressed: null, child: Text(main.name));
    }

    final hoverEnabled = MediaQuery.sizeOf(context).width >= 1200;
    final screen = MediaQuery.sizeOf(context);
    final menuWidth = math.min(920.0, screen.width - 32).clamp(280.0, 920.0);
    final columns = menuWidth >= 740 ? 4 : menuWidth >= 520 ? 3 : 2;
    final rows = (subs.length / columns).ceil();
    final menuHeight = math.min(
      560.0,
      math.min(screen.height * .7, rows * 48.0 + 32),
    );
    final scrollController = _menuScrollControllers.putIfAbsent(
      main.id ?? main.name.hashCode,
      ScrollController.new,
    );

    return MenuAnchor(
      consumeOutsideTap: true,
      menuChildren: [
        MouseRegion(
          onEnter: (_) => _cancelClose(),
          onExit: (_) {
            final controller = _activeMenuController;
            if (controller != null) _scheduleClose(controller);
          },
          child: SizedBox(
            width: menuWidth,
            height: menuHeight,
            child: GridView.builder(
              controller: scrollController,
              primary: false,
              padding: const EdgeInsets.all(16),
              itemCount: subs.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 8,
                mainAxisSpacing: 4,
                childAspectRatio: 4.8,
              ),
              itemBuilder: (context, index) {
                final sub = subs[index];
                return TextButton(
                  key: ValueKey('home-subcategory-${sub.id}'),
                  onPressed: () {
                    _activeMenuController?.close();
                    final open = widget.onOpenSubCategory;
                    if (open != null) {
                      open(main, sub);
                    } else {
                      widget.onSelected(main.name, sub.name);
                    }
                  },
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    sub.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        _activeMenuController = controller;
        return MouseRegion(
          onEnter: (_) {
            _cancelClose();
            if (hoverEnabled && !controller.isOpen) controller.open();
          },
          onExit: (_) {
            if (hoverEnabled) _scheduleClose(controller);
          },
          child: TextButton(
            key: ValueKey('home-main-category-${main.id}'),
            onPressed: () {
              _cancelClose();
              controller.isOpen ? controller.close() : controller.open();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(main.name),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

}