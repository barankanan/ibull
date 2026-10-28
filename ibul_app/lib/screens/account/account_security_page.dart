import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/auth/user_identity.dart';
import '../../core/constants.dart';
import '../../core/home_navigation.dart';
import '../change_password_page.dart';

class AccountSecurityPage extends StatelessWidget {
  const AccountSecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select<AppState, Map<String, dynamic>?>(
      (state) => state.currentUser,
    );
    final hasPassword = context.select<AppState, bool>(
      (state) => state.hasEmailPasswordProvider,
    );
    final email = UserIdentity.resolveEmail(currentUser: user);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF111827),
        centerTitle: true,
        title: const Text(
          'Güvenlik',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _SecurityCard(
            children: [
              _SecurityTile(
                icon: Icons.lock_outline,
                title: 'Şifre Değiştir',
                subtitle: hasPassword
                    ? 'Mevcut şifreni doğrulayarak güncelle'
                    : 'E-posta ile şifre sıfırlama bağlantısı gönderilir',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ChangePasswordPage(),
                    ),
                  );
                },
              ),
              _SecurityInfo(
                icon: Icons.mail_outline,
                title: 'Giriş e-postası',
                subtitle: email.isEmpty
                    ? 'Bu oturumda e-posta görünmüyor'
                    : email,
              ),
              _SecurityInfo(
                icon: Icons.verified_user_outlined,
                title: 'Hesap güvenliği',
                subtitle: hasPassword
                    ? 'E-posta ve şifre ile giriş açık'
                    : 'Bu hesap e-posta şifresi kullanmıyor',
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SecurityCard(
            children: [
              _SecurityInfo(
                icon: Icons.devices_outlined,
                title: 'Cihaz bilgisi',
                subtitle:
                    'Açık oturumlar için ayrı bir cihaz listesi tutulmuyor.',
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SecurityCard(
            children: [
              _SecurityTile(
                icon: Icons.logout,
                title: 'Oturumdan çıkış',
                subtitle: 'Bu cihazdaki müşteri oturumunu kapat',
                danger: true,
                showDivider: false,
                onTap: () => _signOut(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final appState = context.read<AppState>();
    try {
      await appState.logout();
      if (!context.mounted) return;
      HomeNavigation.openHome(context, initialIndex: 4);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cikis yapilamadi: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E7EE)),
      ),
      child: Column(children: children),
    );
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFB91C1C) : const Color(0xFF111827);
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Icon(icon, color: danger ? color : AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 48, color: Color(0xFFE6E7EE)),
      ],
    );
  }
}

class _SecurityInfo extends StatelessWidget {
  const _SecurityInfo({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 48, color: Color(0xFFE6E7EE)),
      ],
    );
  }
}
