import 'package:flutter/material.dart';

import 'admin_panel_state_widgets.dart';

class AdminLoginRequiredState extends StatelessWidget {
  const AdminLoginRequiredState({super.key, required this.onLoginTap});

  final VoidCallback onLoginTap;

  @override
  Widget build(BuildContext context) {
    return AdminPanelStatusScaffold(
      maxWidth: 420,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            size: 56,
            color: Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 16),
          const Text(
            'Admin girisi gerekli',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bu ekran sadece admin rolleriyle acilir. Normal kullanici veya satici oturumuyla acildiginda admin modulleri kullanilamaz.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onLoginTap,
            child: const Text('Admin Olarak Giris Yap'),
          ),
        ],
      ),
    );
  }
}
