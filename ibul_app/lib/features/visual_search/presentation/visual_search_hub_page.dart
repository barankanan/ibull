import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_state.dart';
import '../../../core/constants.dart';
import '../../../core/home_navigation.dart';
import '../../../screens/cart_page.dart';
import '../../../screens/categories_page.dart';
import '../../../screens/map_page.dart';
import '../application/visual_search_controller.dart';
import '../domain/visual_search_models.dart';
import 'visual_search_capture_page.dart';
import 'visual_search_chrome.dart';
import 'visual_search_history_page.dart';
import 'widgets/visual_search_cards.dart';

class VisualSearchHubPage extends StatefulWidget {
  const VisualSearchHubPage({super.key, this.controller});

  final VisualSearchController? controller;

  @override
  State<VisualSearchHubPage> createState() => _VisualSearchHubPageState();
}

class _VisualSearchHubPageState extends State<VisualSearchHubPage> {
  late final VisualSearchController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? VisualSearchController.shared();
  }

  Future<void> _start(ImageSource source) async {
    final type = await showModalBottomSheet<VisualSearchJobType>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _ModeSheet(),
    );
    if (!mounted || type == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisualSearchCapturePage(
          jobType: type,
          autoPick: source,
          controller: _controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compactNav = MediaQuery.sizeOf(context).width < 800;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: visualSearchAppBar(context, 'Kamera ile Keşfet'),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              const Text(
                'Fotoğrafla keşfet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              VisualSearchUploadArea(
                compact: true,
                onCamera: () => _start(ImageSource.camera),
                onGallery: () => _start(ImageSource.gallery),
              ),
              const SizedBox(height: 12),
              VisualSearchModuleCard(
                title: 'Görsel Zeka',
                icon: Icons.psychology_outlined,
                onTap: () => _openCapture(VisualSearchJobType.combined),
              ),
              const SizedBox(height: 8),
              VisualSearchModuleCard(
                title: 'Ürünü Arat',
                icon: Icons.search,
                onTap: () => _openCapture(VisualSearchJobType.visualSearch),
              ),
              const SizedBox(height: 8),
              VisualSearchModuleCard(
                title: 'Geçmiş',
                icon: Icons.history,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          VisualSearchHistoryPage(controller: _controller),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: compactNav ? _bottomBar(context) : null,
    );
  }

  Future<void> _openCapture(VisualSearchJobType type) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisualSearchCapturePage(
          jobType: type,
          controller: _controller,
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.black,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        onTap: (index) {
          if (index == 0) {
            HomeNavigation.openHome(context, replaceStack: true);
          } else if (index == 1) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute<void>(builder: (_) => const CategoriesPage()),
              (route) => false,
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const MapPage()),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const CartPage()),
            );
          } else if (index == 4) {
            HomeNavigation.openHome(context, initialIndex: 4, replaceStack: true);
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.segment), label: 'Kategori'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'Harita',
          ),
          BottomNavigationBarItem(
            icon: _cartIcon(false),
            activeIcon: _cartIcon(true),
            label: 'Sepet',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Hesap',
          ),
        ],
      ),
    );
  }

  int _cartCount() {
    try {
      return AppState().cart.length;
    } catch (_) {
      return 0;
    }
  }

  Widget _cartIcon(bool active) {
    final count = _cartCount();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(active ? Icons.shopping_cart : Icons.shopping_cart_outlined),
        if (count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

class _ModeSheet extends StatelessWidget {
  const _ModeSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bu görseli ne için kullanmak istersin?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.psychology_outlined, color: AppColors.primary),
              title: const Text('Görsel Zeka'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.iconMuted),
              onTap: () => Navigator.pop(context, VisualSearchJobType.combined),
            ),
            ListTile(
              leading: const Icon(Icons.search, color: AppColors.primary),
              title: const Text('Ürünü Arat'),
              trailing: const Icon(Icons.chevron_right, color: AppColors.iconMuted),
              onTap: () => Navigator.pop(context, VisualSearchJobType.visualSearch),
            ),
          ],
        ),
      ),
    );
  }
}
