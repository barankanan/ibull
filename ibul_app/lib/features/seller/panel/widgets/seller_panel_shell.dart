import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../theme/seller_panel_theme.dart';

class SellerPanelMenuEntry {
  const SellerPanelMenuEntry({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
}

class SellerPanelShell extends StatelessWidget {
  const SellerPanelShell({
    super.key,
    required this.topBar,
    required this.sidebar,
    required this.content,
  });

  final Widget topBar;
  final Widget sidebar;
  final Widget content;

  static const double sidebarWidth = 224;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildSellerPanelTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        body: SafeArea(
          child: Column(
            children: [
              topBar,
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sidebar,
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: content,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SellerPanelTopBar extends StatelessWidget {
  const SellerPanelTopBar({
    super.key,
    required this.title,
    required this.storeLabel,
    required this.sellerIdLabel,
    this.onNotificationsTap,
  });

  final String title;
  final String storeLabel;
  final String sellerIdLabel;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: const Color(0xFF111827),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.store,
                    color: AppColors.primary,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      storeLabel,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      sellerIdLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 16, color: Colors.grey.shade600),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: onNotificationsTap,
            icon: const Icon(Icons.notifications_outlined, size: 18),
          ),
        ],
      ),
    );
  }
}

class SellerPanelSidebar extends StatelessWidget {
  const SellerPanelSidebar({
    super.key,
    required this.items,
    required this.onLogoutTap,
  });

  final List<SellerPanelMenuEntry> items;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF111827),
      child: SizedBox(
        width: SellerPanelShell.sidebarWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SellerPanelBrandHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                children: items
                    .map((item) => SellerPanelSidebarItem(item: item))
                    .toList(growable: false),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: SellerPanelSidebarItem(
                item: SellerPanelMenuEntry(
                  icon: Icons.logout,
                  label: 'Çıkış Yap',
                  isActive: false,
                  onTap: onLogoutTap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SellerPanelSidebarItem extends StatelessWidget {
  const SellerPanelSidebarItem({super.key, required this.item});

  final SellerPanelMenuEntry item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: item.isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: item.onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 17,
                  color: item.isActive ? AppColors.primary : Colors.white70,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: item.isActive ? AppColors.primary : Colors.white70,
                      fontWeight: item.isActive
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
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

class SellerPanelMobileShell extends StatelessWidget {
  const SellerPanelMobileShell({
    super.key,
    required this.title,
    required this.storeLabel,
    required this.drawer,
    required this.content,
    required this.onRefresh,
  });

  final String title;
  final String storeLabel;
  final Widget drawer;
  final Widget content;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final panelTheme = buildSellerPanelTheme(Theme.of(context));
    return Theme(
      data: panelTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        endDrawer: drawer,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: const Color(0xFF111827),
          toolbarHeight: 52,
          titleSpacing: 14,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: panelTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                storeLabel,
                style: panelTheme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF6B7280),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Yenile',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Menü',
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: content,
          ),
        ),
      ),
    );
  }
}

class SellerPanelMobileDrawer extends StatelessWidget {
  const SellerPanelMobileDrawer({
    super.key,
    required this.items,
    required this.onLogoutTap,
  });

  final List<SellerPanelMenuEntry> items;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Material(
        color: const Color(0xFF111827),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SellerPanelBrandHeader(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  children: items
                      .map((item) => SellerPanelSidebarItem(item: item))
                      .toList(growable: false),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: SellerPanelSidebarItem(
                  item: SellerPanelMenuEntry(
                    icon: Icons.logout,
                    label: 'Çıkış Yap',
                    isActive: false,
                    onTap: onLogoutTap,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SellerPanelBrandHeader extends StatelessWidget {
  const _SellerPanelBrandHeader({this.padding = const EdgeInsets.all(18)});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.store_outlined,
              color: Colors.white,
              size: 15,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'Satıcı Paneli',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
