import 'package:flutter/material.dart';

export 'admin_operation_selector.dart';
export 'admin_sidebar.dart';

import 'admin_panel_section_label.dart';
import 'admin_sidebar.dart';

class AdminPanelShell extends StatelessWidget {
  const AdminPanelShell({
    super.key,
    required this.panelTitle,
    required this.menuSections,
    required this.adminName,
    required this.adminEmail,
    required this.onLogoutTap,
    required this.headerTitle,
    required this.content,
    required this.operationSelector,
    this.showSearch = true,
    this.showOverviewBadge = false,
  });

  final String panelTitle;
  final List<AdminPanelMenuSectionEntry> menuSections;
  final String adminName;
  final String adminEmail;
  final VoidCallback onLogoutTap;
  final String headerTitle;
  final Widget content;
  final Widget operationSelector;
  final bool showSearch;
  final bool showOverviewBadge;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 280,
            color: const Color(0xFF111827),
            child: Column(
              children: [
                AdminSidebarHeader(panelTitle: panelTitle),
                operationSelector,
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: menuSections
                        .expand(
                          (section) => [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                right: 4,
                                bottom: 10,
                                top: 8,
                              ),
                              child: AdminPanelSectionLabel(
                                label: section.label,
                                icon: section.icon,
                                iconColor: Colors.white70,
                                textColor: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                            ...section.items.map(
                              (entry) => AdminSidebarMenuItem(entry: entry),
                            ),
                            const SizedBox(height: 12),
                          ],
                        )
                        .toList(growable: false),
                  ),
                ),
                AdminSidebarFooter(
                  adminName: adminName,
                  adminEmail: adminEmail,
                  onLogoutTap: onLogoutTap,
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                AdminPanelHeader(
                  title: headerTitle,
                  showOverviewBadge: showOverviewBadge,
                  showSearch: showSearch,
                ),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminPanelHeader extends StatelessWidget {
  const AdminPanelHeader({
    super.key,
    required this.title,
    required this.showOverviewBadge,
    required this.showSearch,
  });

  final String title;
  final bool showOverviewBadge;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    final shouldShowSearchChrome = showSearch;
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          if (showOverviewBadge) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield, size: 14, color: Color(0xFF8B5CF6)),
                  SizedBox(width: 6),
                  Text(
                    'Super Admin',
                    style: TextStyle(
                      color: Color(0xFF8B5CF6),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          if (shouldShowSearchChrome) ...[
            Container(
              width: 300,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey.shade400, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Panel içinde ara',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Stack(
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  color: Colors.grey,
                  size: 24,
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
