import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../theme/seller_panel_theme.dart';

/// Menu item state. Only "open" and "locked because the cloud is down".
/// Pages the user has no permission for are NOT represented here: they are
/// hidden from the menu entirely. Never mix "no permission" with
/// "needs internet".
enum SellerMenuItemState { open, lockedOffline }

class SellerPanelMenuEntry {
  const SellerPanelMenuEntry({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.state = SellerMenuItemState.open,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final SellerMenuItemState state;
}

/// Text on the dark sidebar: white at 0.85 for locked titles (AA >= 4.5:1).
const Color kSellerMenuSidebarColor = Color(0xFF111827);
const Color kSellerMenuLockedTextColor = Color(0xD9FFFFFF);
const Color kSellerMenuLockedIconColor = Color(0xB3FFFFFF);
const String kSellerMenuLockedHint = 'İnternet gerekli';

class SellerPanelShell extends StatelessWidget {
  const SellerPanelShell({
    super.key,
    required this.topBar,
    required this.sidebar,
    required this.content,
    this.contentBanner,
  });

  final Widget topBar;
  final Widget sidebar;
  final Widget content;
  final Widget? contentBanner;

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
                        child: Column(
                          children: [
                            if (contentBanner != null) ...[
                              contentBanner!,
                              const SizedBox(height: 12),
                            ],
                            Expanded(child: content),
                          ],
                        ),
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
    this.onToggleSidebar,
    this.sidebarCollapsed = false,
  });

  final String title;
  final String storeLabel;
  final String sellerIdLabel;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onToggleSidebar;
  final bool sidebarCollapsed;

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
            onPressed: onToggleSidebar,
            tooltip: sidebarCollapsed
                ? 'Kenar çubuğunu genişlet'
                : 'Kenar çubuğunu daralt',
            icon: Icon(
              sidebarCollapsed ? Icons.menu_rounded : Icons.menu_open_rounded,
              size: 18,
            ),
          ),
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
    this.collapsed = false,
    this.roleLabel,
  });

  final List<SellerPanelMenuEntry> items;
  final VoidCallback onLogoutTap;
  final bool collapsed;
  final String? roleLabel;

  static const double _collapsedWidth = 56;

  @override
  Widget build(BuildContext context) {
    final targetWidth = collapsed
        ? _collapsedWidth
        : SellerPanelShell.sidebarWidth;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: targetWidth,
      color: const Color(0xFF111827),
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: 0,
        maxWidth: SellerPanelShell.sidebarWidth,
        child: SizedBox(
          width: targetWidth,
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SellerPanelBrandHeader(
                  collapsed: collapsed,
                  roleLabel: roleLabel,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: collapsed ? 4 : 6,
                    ),
                    children: items
                        .map(
                          (item) => SellerPanelSidebarItem(
                            item: item,
                            collapsed: collapsed,
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
                Padding(
                  padding: collapsed
                      ? const EdgeInsets.fromLTRB(4, 6, 4, 10)
                      : const EdgeInsets.fromLTRB(10, 6, 10, 10),
                  child: SellerPanelSidebarItem(
                    collapsed: collapsed,
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
      ),
    );
  }
}

class SellerPanelSidebarItem extends StatelessWidget {
  const SellerPanelSidebarItem({
    super.key,
    required this.item,
    this.collapsed = false,
  });

  final SellerPanelMenuEntry item;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = item.state == SellerMenuItemState.lockedOffline;
    final selected = item.isActive && !locked;
    final iconColor = selected
        ? AppColors.primary
        : (locked ? kSellerMenuLockedIconColor : Colors.white);
    final textColor = selected
        ? AppColors.primary
        : (locked ? kSellerMenuLockedTextColor : Colors.white);
    final icon = Icon(item.icon, size: 18, color: iconColor);
    final leading = locked && collapsed
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              icon,
              const Positioned(
                right: -5,
                bottom: -4,
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 10,
                  color: kSellerMenuLockedTextColor,
                ),
              ),
            ],
          )
        : icon;
    final Widget content = collapsed
        ? Center(child: leading)
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: textColor,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (locked)
                        const Text(
                          kSellerMenuLockedHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: kSellerMenuLockedTextColor,
                            fontSize: 11.5,
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                ),
                if (locked) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: kSellerMenuLockedTextColor,
                  ),
                ],
              ],
            ),
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: item.onTap,
          mouseCursor: locked ? SystemMouseCursors.basic : null,
          hoverColor: locked ? Colors.transparent : null,
          highlightColor: locked ? Colors.transparent : null,
          splashColor: locked ? Colors.transparent : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: collapsed
                ? Tooltip(
                    message: locked
                        ? '${item.label}: $kSellerMenuLockedHint'
                        : item.label,
                    preferBelow: false,
                    child: SizedBox(height: 44, child: content),
                  )
                : content,
          ),
        ),
      ),
    );
  }
}

/// Tablet shell (800–1199 px).
/// Content occupies full width; sidebar is an overlay left [Drawer].
/// Toggle button in the top-bar opens/closes the drawer.
class SellerPanelTabletShell extends StatelessWidget {
  const SellerPanelTabletShell({
    super.key,
    required this.title,
    required this.storeLabel,
    required this.sellerIdLabel,
    required this.drawerItems,
    required this.onLogoutTap,
    required this.content,
    this.contentBanner,
    this.onNotificationsTap,
  });

  final String title;
  final String storeLabel;
  final String sellerIdLabel;
  final List<SellerPanelMenuEntry> drawerItems;
  final VoidCallback onLogoutTap;
  final Widget content;
  final Widget? contentBanner;
  final VoidCallback? onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    final panelTheme = buildSellerPanelTheme(Theme.of(context));
    return Theme(
      data: panelTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        drawer: SellerPanelMobileDrawer(
          items: drawerItems,
          onLogoutTap: onLogoutTap,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Builder gives a context that is a descendant of the Scaffold,
              // which is required by Scaffold.of() to open the drawer.
              Builder(
                builder: (ctx) => SellerPanelTopBar(
                  title: title,
                  storeLabel: storeLabel,
                  sellerIdLabel: sellerIdLabel,
                  // Always show the "closed" icon since drawer is hidden by default.
                  sidebarCollapsed: true,
                  onToggleSidebar: () => Scaffold.of(ctx).openDrawer(),
                  onNotificationsTap: onNotificationsTap,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      if (contentBanner != null) ...[
                        contentBanner!,
                        const SizedBox(height: 12),
                      ],
                      Expanded(child: content),
                    ],
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

class SellerPanelMobileShell extends StatelessWidget {
  const SellerPanelMobileShell({
    super.key,
    required this.title,
    required this.storeLabel,
    required this.drawer,
    required this.content,
    required this.onRefresh,
    this.contentBanner,
  });

  final String title;
  final String storeLabel;
  final Widget drawer;
  final Widget content;
  final VoidCallback onRefresh;
  final Widget? contentBanner;

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
            child: Column(
              children: [
                if (contentBanner != null) ...[
                  contentBanner!,
                  const SizedBox(height: 10),
                ],
                Expanded(child: content),
              ],
            ),
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
    this.roleLabel,
  });

  final List<SellerPanelMenuEntry> items;
  final VoidCallback onLogoutTap;
  final String? roleLabel;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Material(
        color: const Color(0xFF111827),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SellerPanelBrandHeader(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                roleLabel: roleLabel,
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
  const _SellerPanelBrandHeader({
    this.padding = const EdgeInsets.all(18),
    this.collapsed = false,
    this.roleLabel,
  });

  final EdgeInsetsGeometry padding;
  final bool collapsed;
  final String? roleLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconBox = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.store_outlined, color: Colors.white, size: 15),
    );
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(child: iconBox),
      );
    }
    return Padding(
      padding: padding,
      child: Row(
        children: [
          iconBox,
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Satıcı Paneli',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (roleLabel != null && roleLabel!.trim().isNotEmpty)
                  Text(
                    roleLabel!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFD1D5DB),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
