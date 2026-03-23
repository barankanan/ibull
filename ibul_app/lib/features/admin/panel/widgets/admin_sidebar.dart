import 'package:flutter/material.dart';

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
          Text(
            panelTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF8B5CF6),
            radius: 16,
            child: Text(
              'BK',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                adminName,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                adminEmail,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
            onPressed: onLogoutTap,
          ),
        ],
      ),
    );
  }
}

class AdminSidebarMenuItem extends StatelessWidget {
  const AdminSidebarMenuItem({super.key, required this.entry});

  final AdminPanelMenuEntry entry;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: entry.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: entry.isActive ? const Color(0xFF8B5CF6) : Colors.transparent,
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
            Text(
              entry.title,
              style: TextStyle(
                color: entry.isActive ? Colors.white : Colors.grey.shade400,
                fontSize: 14,
                fontWeight: entry.isActive
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
