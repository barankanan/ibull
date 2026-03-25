import 'package:flutter/material.dart';

class AdminTopbar extends StatelessWidget {
  const AdminTopbar({
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
