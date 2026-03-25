import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_motion.dart';
import '../core/constants.dart';
import '../screens/orders_page.dart';
import '../screens/favorites_page.dart';
import '../screens/coupons_page.dart';
import '../screens/reviews_page.dart';
import '../screens/settings_page.dart';
import '../screens/account_page.dart';
import '../screens/followed_stores_page.dart';
import '../screens/addresses_page.dart';
import '../core/app_state.dart';
import '../core/auth/user_identity.dart';

class AccountSidebar extends StatelessWidget {
  final String activePage;

  const AccountSidebar({super.key, required this.activePage});

  void _pushReplacementPage(BuildContext context, Widget page) {
    Navigator.pushReplacement(
      context,
      buildAppPageRoute<void>(builder: (_) => page),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text(
          'Hesabınızdan çıkış yapmak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Çıkış Yap',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (context.mounted) {
        final appState = Provider.of<AppState>(context, listen: false);
        await appState.logout();
        if (context.mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;
    final displayName = UserIdentity.resolveDisplayName(
      currentUser: user,
      fallback: 'Misafir',
    );
    final email = UserIdentity.resolveEmail(currentUser: user);
    final initials = UserIdentity.initialsOf(user);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Summary
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Navigation Items
          _buildWebMenuItem(
            context,
            Icons.dashboard_outlined,
            'Hesap Özeti',
            isActive: activePage == 'Hesap Özeti',
            onTap: () {
              if (activePage != 'Hesap Özeti') {
                _pushReplacementPage(context, const AccountPage());
              }
            },
          ),
          _buildWebMenuItem(
            context,
            Icons.shopping_bag_outlined,
            'Siparişlerim',
            isActive: activePage == 'Siparişlerim',
            onTap: () {
              if (activePage != 'Siparişlerim') {
                _pushReplacementPage(context, const OrdersPage());
              }
            },
          ),
          _buildWebMenuItem(
            context,
            Icons.favorite_border,
            'Favorilerim',
            isActive: activePage == 'Favorilerim',
            onTap: () {
              // Navigation logic here
              if (activePage != 'Favorilerim') {
                _pushReplacementPage(context, const FavoritesPage());
              }
            },
          ),
          _buildWebMenuItem(
            context,
            Icons.local_offer_outlined,
            'Kuponlarım',
            isActive: activePage == 'Kuponlarım',
            onTap: () {
              if (activePage != 'Kuponlarım') {
                _pushReplacementPage(context, const CouponsPage());
              }
            },
          ),
          _buildWebMenuItem(
            context,
            Icons.store_outlined,
            'Takip Ettiklerim',
            isActive: activePage == 'Takip Ettiklerim',
            onTap: () {
              if (activePage != 'Takip Ettiklerim') {
                _pushReplacementPage(context, const FollowedStoresPage());
              }
            },
          ),
          _buildWebMenuItem(
            context,
            Icons.location_on_outlined,
            'Adreslerim',
            isActive: activePage == 'Adreslerim',
            onTap: () {
              if (activePage != 'Adreslerim') {
                _pushReplacementPage(context, const AddressesPage());
              }
            },
          ),
          _buildWebMenuItem(
            context,
            Icons.credit_card_outlined,
            'Kayıtlı Kartlarım',
            isActive: activePage == 'Kayıtlı Kartlarım',
          ),
          _buildWebMenuItem(
            context,
            Icons.reviews_outlined,
            'Değerlendirmelerim',
            isActive: activePage == 'Değerlendirmelerim',
            onTap: () {
              if (activePage != 'Değerlendirmelerim') {
                _pushReplacementPage(context, const ReviewsPage());
              }
            },
          ),
          _buildWebMenuItem(
            context,
            Icons.settings_outlined,
            'Ayarlar',
            isActive: activePage == 'Ayarlar',
            onTap: () {
              if (activePage != 'Ayarlar') {
                _pushReplacementPage(context, const SettingsPage());
              }
            },
          ),
          const Divider(height: 1),
          _buildWebMenuItem(
            context,
            Icons.logout,
            'Çıkış Yap',
            isDestructive: true,
            isActive: false,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildWebMenuItem(
    BuildContext context,
    IconData icon,
    String title, {
    bool isActive = false,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: isActive
          ? AppColors.primary.withOpacity(0.05)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: isActive
                ? const Border(
                    left: BorderSide(color: AppColors.primary, width: 4),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isDestructive
                    ? Colors.red
                    : (isActive ? AppColors.primary : Colors.grey.shade600),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isDestructive
                      ? Colors.red
                      : (isActive
                            ? AppColors.primary
                            : const Color(0xFF4B5563)),
                ),
              ),
              if (isActive) const Spacer(),
              if (isActive)
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
