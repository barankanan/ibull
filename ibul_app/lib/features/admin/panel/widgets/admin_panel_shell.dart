import 'package:flutter/material.dart';

import 'admin_sidebar.dart';
import 'admin_topbar.dart';

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
          AdminSidebar(
            panelTitle: panelTitle,
            menuSections: menuSections,
            operationSelector: operationSelector,
            adminName: adminName,
            adminEmail: adminEmail,
            onLogoutTap: onLogoutTap,
          ),
          Expanded(
            child: Column(
              children: [
                AdminTopbar(
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
