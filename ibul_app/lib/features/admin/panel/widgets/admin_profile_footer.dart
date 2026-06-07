import 'package:flutter/material.dart';

import '../../../../widgets/premium_interactions.dart';

class AdminProfileFooter extends StatelessWidget {
  const AdminProfileFooter({
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adminName,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  adminEmail,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Spacer(),
          PremiumPressable(
            pressedScale: 0.92,
            hoverScale: 1.04,
            hoverLift: 0.5,
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white54, size: 20),
              onPressed: onLogoutTap,
            ),
          ),
        ],
      ),
    );
  }
}
