import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/marketplace_paths.dart';
import '../core/constants.dart';
import '../models/db_category.dart';
import '../services/supabase_service.dart';
import 'marketplace_content_frame.dart';
import '../core/ibul_chrome.dart';

class WebCategoryBar extends StatefulWidget {
  final String? selectedCategory;
  final ValueChanged<String>? onCategorySelected;

  const WebCategoryBar({
    super.key,
    this.selectedCategory,
    this.onCategorySelected,
  });

  @override
  State<WebCategoryBar> createState() => _WebCategoryBarState();
}

class _WebCategoryBarState extends State<WebCategoryBar> {
  late Future<List<CategoryWithSubcategories>> _categoriesFuture;
  final ScrollController _scrollController = ScrollController();
  
  MenuController? _activeMenuController;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = SupabaseService.instance.getCategoriesWithSubsStrict();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _closeTimer?.cancel();
    super.dispose();
  }

  void _cancelClose() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _scheduleClose(MenuController controller) {
    _cancelClose();
    _closeTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted && controller.isOpen) {
        controller.close();
      }
    });
  }
  
  void _openCategoryPage(DBCategory mainCat, [DBCategory? subCat]) {
    _activeMenuController?.close();
    if (subCat == null) {
      if (widget.onCategorySelected != null) {
        widget.onCategorySelected!(mainCat.name);
      } else {
        // Fallback for pages that don't pass onCategorySelected
        final route = MarketplacePaths.home + '?category=${Uri.encodeComponent(mainCat.name)}';
        GoRouter.maybeOf(context)?.go(route);
      }
    } else {
      if (mainCat.name == "Yakın Lokasyon") {
        final route = MarketplacePaths.home + '?category=${Uri.encodeComponent(mainCat.name)}&subcategory=${Uri.encodeComponent(subCat.name)}';
        GoRouter.maybeOf(context)?.go(route);
      } else {
        final route = MarketplacePaths.category(
          mainCat.id?.toString() ?? mainCat.name, 
          subCat.id?.toString() ?? subCat.name, 
          slug: '${mainCat.name}-${subCat.name}'
        );
        GoRouter.maybeOf(context)?.push(route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: IbulChrome.categoryBarDecoration,
      child: MarketplaceContentFrame(
        child: SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              FutureBuilder<List<CategoryWithSubcategories>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  final categories = (snapshot.data ?? [])
                      .where((c) => c.mainCategory.isActive)
                      .toList(growable: false);

                  return ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                      },
                    ),
                    child: ListView.separated(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 44),
                      itemCount: categories.length,
                      shrinkWrap: true,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return _buildCategoryItem(categories[index]);
                      },
                    ),
                  );
                },
              ),
              Positioned(
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.white,
                        Colors.white.withOpacity(0.0),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 20),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Daha fazla kategori',
                      icon: const Icon(
                        Icons.chevron_right,
                        color: AppColors.primary,
                      ),
                      onPressed: () {
                        _scrollController.animateTo(
                          _scrollController.offset + 200,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(CategoryWithSubcategories node) {
    final main = node.mainCategory;
    final subs = node.subCategories
        .where((s) => s.isActive && s.parentId == main.id)
        .toList(growable: false);

    final isSelected = widget.selectedCategory == main.name;

    Widget mainButton(MenuController controller) {
      return InkWell(
        onTap: () {
          _cancelClose();
          if (subs.isNotEmpty) {
            if (controller.isOpen) {
              controller.close();
            } else {
              _activeMenuController?.close();
              _activeMenuController = controller;
              controller.open();
            }
          } else {
            _openCategoryPage(main);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          decoration: BoxDecoration(
            border: isSelected
                ? const Border(bottom: BorderSide(color: AppColors.primary, width: 2))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                main.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.primary : Colors.grey[800],
                ),
              ),
              if (subs.isNotEmpty) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: isSelected ? AppColors.primary : Colors.grey[600],
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (subs.isEmpty) {
      return Center(
        child: mainButton(MenuController()), // Dummy controller
      );
    }

    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        backgroundColor: WidgetStateProperty.all(Colors.white),
        elevation: WidgetStateProperty.all(4),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        padding: WidgetStateProperty.all(EdgeInsets.zero),
      ),
      menuChildren: [
        MouseRegion(
          onEnter: (_) => _cancelClose(),
          onExit: (_) {
            if (_activeMenuController != null) {
              _scheduleClose(_activeMenuController!);
            }
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 180,
              maxWidth: 320,
              maxHeight: 400,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // All products link
                    InkWell(
                      onTap: () => _openCategoryPage(main),
                      hoverColor: AppColors.primary.withOpacity(0.05),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text(
                          'Tüm ${main.name} ürünleri',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey.shade200),
                    ...subs.map((sub) {
                      return InkWell(
                        onTap: () => _openCategoryPage(main, sub),
                        hoverColor: AppColors.primary.withOpacity(0.05),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Text(
                            sub.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        return MouseRegion(
          onEnter: (_) {
            _cancelClose();
            if (!controller.isOpen) {
              _activeMenuController?.close();
              _activeMenuController = controller;
              controller.open();
            }
          },
          onExit: (_) {
            _scheduleClose(controller);
          },
          child: Center(child: mainButton(controller)),
        );
      },
    );
  }
}
