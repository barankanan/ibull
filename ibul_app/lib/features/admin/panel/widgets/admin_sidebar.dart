import 'package:flutter/material.dart';

import '../../../../widgets/premium_interactions.dart';
import 'admin_panel_section_label.dart';
import 'admin_profile_footer.dart';

class AdminPanelMenuEntry {
  const AdminPanelMenuEntry({
    required this.icon,
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback onTap;
}

class AdminPanelMenuSectionEntry {
  const AdminPanelMenuSectionEntry({
    required this.label,
    required this.icon,
    required this.items,
  });

  final String label;
  final IconData icon;
  final List<AdminPanelMenuEntry> items;
}

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.panelTitle,
    required this.menuSections,
    required this.operationSelector,
    required this.adminName,
    required this.adminEmail,
    required this.onLogoutTap,
  });

  final String panelTitle;
  final List<AdminPanelMenuSectionEntry> menuSections;
  final Widget operationSelector;
  final String adminName;
  final String adminEmail;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          AdminProfileFooter(
            adminName: adminName,
            adminEmail: adminEmail,
            onLogoutTap: onLogoutTap,
          ),
        ],
      ),
    );
  }
}

class AdminSidebarHeader extends StatelessWidget {
  const AdminSidebarHeader({super.key, required this.panelTitle});

  final String panelTitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.shopping_bag,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              panelTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSidebarFooter extends StatelessWidget {
  const AdminSidebarFooter({
    super.key,
    required this.adminName,
    required this.adminEmail,
    required this.onLogoutTap,
  });

  final String adminName;
  final String adminEmail;
  final VoidCallback onLogoutTap;

  @override
  Widget build(BuildContext context) {
    return AdminProfileFooter(
      adminName: adminName,
      adminEmail: adminEmail,
      onLogoutTap: onLogoutTap,
    );
  }
}

class AdminSidebarMenuItem extends StatelessWidget {
  const AdminSidebarMenuItem({super.key, required this.entry});

  final AdminPanelMenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return PremiumPressable(
      hoverLift: 1,
      hoverScale: 1.008,
      child: InkWell(
        onTap: entry.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: entry.isActive
                ? const Color(0xFF8B5CF6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                entry.icon,
                color: entry.isActive ? Colors.white : Colors.grey.shade400,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.title,
                  style: TextStyle(
                    color: entry.isActive ? Colors.white : Colors.grey.shade400,
                    fontSize: 14,
                    fontWeight: entry.isActive
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
