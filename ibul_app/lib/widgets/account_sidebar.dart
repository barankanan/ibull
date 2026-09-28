import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/account_sections.dart';
import '../app/ibul_router.dart';
import '../app/marketplace_paths.dart';
import '../core/constants.dart';
import '../screens/orders_page.dart';
import '../features/vehicle/screens/vehicle_customer_rentals_page.dart';
import '../screens/favorites_page.dart';
import '../screens/coupons_page.dart';
import '../screens/reviews_page.dart';
import '../screens/settings_page.dart';
import '../screens/account_page.dart';
import '../screens/followed_stores_page.dart';
import '../screens/addresses_page.dart';
import '../screens/ai_chat_page.dart';
import '../features/customer_support/screens/customer_support_page.dart';
import '../features/saved_payment_cards/screens/saved_payment_cards_page.dart';
import '../core/app_state.dart';
import '../core/auth/user_identity.dart';

class AccountSidebar extends StatelessWidget {
  final String activePage;

  const AccountSidebar({super.key, required this.activePage});

  void _openSection(
    BuildContext context,
    AccountSection section,
    Widget page,
  ) {
    AccountSections.open(
      context,
      section,
      nativePage: page,
      replaceNative: true,
    );
  }

  bool _isSectionActive(BuildContext context, AccountSection section) {
    if (MarketplacePaths.syncsBrowserUrl()) {
      final path = IbulRouter.currentPath(context);
      if (path != null && MarketplacePaths.isAccountPath(path)) {
        return AccountSections.fromPath(path) == section;
      }
    }
    return activePage == AccountSections.labelOf(section);
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
          IbulRouter.go(context, '/');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.select<AppState, int>((s) => s.accountIdentityStamp);
    final appState = context.read<AppState>();
    final user = appState.currentUser;
    final displayName = UserIdentity.resolveDisplayName(
      currentUser: user,
      fallback: 'Misafir',
    );
    final email = UserIdentity.resolveEmail(currentUser: user);
    final initials = UserIdentity.initialsOf(user);

    return LayoutBuilder(
      builder: (context, constraints) {
        final menuColumn = Column(
          mainAxisSize: MainAxisSize.min,
          children: _buildMenuItems(context),
        );

        final profileHeader = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
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
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        );

        if (!constraints.hasBoundedHeight) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                profileHeader,
                menuColumn,
              ],
            ),
          );
        }

        return Container(
          height: constraints.maxHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              profileHeader,
              Expanded(
                child: SingleChildScrollView(
                  child: menuColumn,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    return [
      _buildWebMenuItem(
        context,
        Icons.dashboard_outlined,
        'Hesap Özeti',
        isActive: _isSectionActive(context, AccountSection.overview),
        onTap: () {
          if (!_isSectionActive(context, AccountSection.overview)) {
            _openSection(context, AccountSection.overview, const AccountPage());
          }
        },
      ),
      _buildWebMenuItem(
        context,
        Icons.lightbulb_outline,
        'Yapay Zekaya Danış',
        isActive: _isSectionActive(context, AccountSection.ai),
        onTap: () {
          if (!_isSectionActive(context, AccountSection.ai)) {
            _openSection(
              context,
              AccountSection.ai,
              const AIChatPage(showAccountSidebar: true),
            );
          }
        },
      ),
      _buildWebMenuItem(
        context,
        Icons.shopping_bag_outlined,
        'Siparişlerim',
        isActive: _isSectionActive(context, AccountSection.orders),
        onTap: () {
          if (!_isSectionActive(context, AccountSection.orders)) {
            _openSection(context, AccountSection.orders, const OrdersPage());
          }
        },
      ),
      _buildWebMenuItem(
        context,
        Icons.directions_car_outlined,
        'Kiralamalarım',
        isActive: _isSectionActive(context, AccountSection.rentals),
        onTap: () {
          if (!_isSectionActive(context, AccountSection.rentals)) {
            _openSection(
              context,
              AccountSection.rentals,
              const VehicleCustomerRentalsPage(),
            );
          }
        },
      ),
      _buildWebMenuItem(
        context,
        Icons.favorite_border,
        'Favorilerim',
        isActive: _isSectionActive(context, AccountSection.favorites),
        onTap: () {
          if (!_isSectionActive(context, AccountSection.favorites)) {
            _openSection(
              context,
              AccountSection.favorites,
              const FavoritesPage(),
            );
          }
        },
      ),
      _buildWebMenuItem(
        context,
        Icons.local_offer_outlined,
        'Kuponlarım',
        isActive: _isSectionActive(context, AccountSection.coupons),
        onTap: () {
          if (!_isSectionActive(context, AccountSection.coupons)) {
            _openSection(context, AccountSection.coupons, const CouponsPage());
          }
        },
      ),
      _buildWebMenuItem(
        context,
        Icons.store_outlined,
        'Takip Ettiklerim',
        isActive: _isSectionActive(context, AccountSection.following),
        onTap: () {
          if (!_isSectionActive(context, AccountSection.following)) {
            _openSection(
              context,
              AccountSection.following,
              const FollowedStoresPage(),
            );
          }
        },
      ),
      _buildWebMenuItem(
        context,
        Icons.location_on_outlined,
        'Adreslerim',
        isActive: _isSectionActive(context, AccountSection.addresses),
        onTap: () {
          if (!_isSectionActive(context, AccountSection.addresses)) {
            _openSection(
              context,
              AccountSection.addresses,
              const AddressesPage(),
            );
          }
        },
      ),
      _buildWebMenuItem(
        context,
        Icons.credit_card_outlined,
        'Kayıtlı Kartlarım',
        isActive: _isSectionActive(context, AccountSection.cards),
        onTap: () {
          if (!_isSectionActive(context, AccountSection.cards)) {
            _openSection(
              context,
              AccountSection.cards,
              const SavedPaymentCardsPage(),
            );
          }
        },
      ),
      _buildWebMenuItem(
        context,
        Icons.reviews_outlined,
        'Değerlendirmelerim',
        isActive: _isSectionActive(context, AccountSection.reviews),
        onTap: () {
          if (!_isSectionActive(context, AccountSection.reviews)) {
            _openSection(context, AccountSection.reviews, const ReviewsPage());
          }
        },
      ),
      _buildWebMenuItem(
        context,
        Icons.support_agent_outlined,
        'Müşteri Hizmetleri',
        subtitle: 'Destek ve talepler',
        isActive: _isSectionActive(context, AccountSection.support),
        onTap: () {
          if (!_isSectionActive(context, AccountSection.support)) {
            _openSection(
              context,
              AccountSection.support,
              const CustomerSupportPage(),
            );
          }
        },
      ),
      _buildWebMenuItem(
        context,
        Icons.settings_outlined,
        'Ayarlar',
        isActive: _isSectionActive(context, AccountSection.settings),
        onTap: () {
          if (!_isSectionActive(context, AccountSection.settings)) {
            _openSection(context, AccountSection.settings, const SettingsPage());
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
    ];
  }

  Widget _buildWebMenuItem(
    BuildContext context,
    IconData icon,
    String title, {
    String? subtitle,
    bool isActive = false,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: isActive
          ? AppColors.primary.withValues(alpha: 0.05)
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
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
