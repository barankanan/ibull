import 'package:flutter/material.dart';

import '../../../../core/constants.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      padding: const EdgeInsets.all(24),
                      child: content,
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
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.store,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      storeLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      sellerIdLabel,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.expand_more, size: 20, color: Colors.grey.shade600),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: onNotificationsTap,
            icon: const Icon(Icons.notifications_outlined, size: 22),
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
        width: 260,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SellerPanelBrandHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: items
                    .map((item) => SellerPanelSidebarItem(item: item))
                    .toList(growable: false),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: item.isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: item.onTap,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: item.isActive ? AppColors.primary : Colors.white70,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      color: item.isActive ? AppColors.primary : Colors.white70,
                      fontSize: 13,
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      endDrawer: drawer,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              storeLabel,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: content,
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
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: items
                      .map((item) => SellerPanelSidebarItem(item: item))
                      .toList(growable: false),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
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
    this.padding = const EdgeInsets.all(20),
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.store_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Satıcı Paneli',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
