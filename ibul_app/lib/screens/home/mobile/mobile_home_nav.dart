import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/constants.dart';
import '../../../l10n/arb/app_localizations.dart';
import 'mobile_home_chrome.dart';

/// Mobile shell tabs. Stack indexes stay 0 home, 1 categories, 2 map, 3 cart, 4 account.
/// Favorites stay on Hesabım → Favorilerim and are not a bottom-nav tab.
class MobileHomeBottomNav extends StatelessWidget {
  const MobileHomeBottomNav({
    super.key,
    required this.stackIndex,
    required this.onStack,
  });

  final int stackIndex;
  final ValueChanged<int> onStack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: context.read<AppState>().cartCountNotifier,
      builder: (context, cartCount, _) {
        final items = <_NavSpec>[
          _NavSpec(
            'mobile-nav-home',
            0,
            l10n?.home ?? 'Ana Sayfa',
            Icons.home_outlined,
            Icons.home,
          ),
          const _NavSpec(
            'mobile-nav-categories',
            1,
            'Kategoriler',
            Icons.grid_view_outlined,
            Icons.grid_view_rounded,
          ),
          const _NavSpec(
            'mobile-nav-map',
            2,
            'Harita',
            Icons.map_outlined,
            Icons.map,
          ),
          _NavSpec(
            'mobile-nav-cart',
            3,
            'Sepetim',
            Icons.shopping_cart_outlined,
            Icons.shopping_cart,
            badge: cartCount,
          ),
          const _NavSpec(
            'mobile-nav-account',
            4,
            'Hesabım',
            Icons.person_outline,
            Icons.person,
          ),
        ];
        final compact = MediaQuery.sizeOf(context).width < 400;
        return Material(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  for (final item in items)
                    Expanded(
                      child: InkWell(
                        key: ValueKey(
                          item.selected(stackIndex)
                              ? '${item.key}-active'
                              : item.key,
                        ),
                        onTap: () => onStack(item.stackIndex),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Badge(
                                isLabelVisible: item.badge > 0,
                                label: Text(
                                  item.badge > 9 ? '9+' : '${item.badge}',
                                ),
                                child: Icon(
                                  item.selected(stackIndex)
                                      ? item.active
                                      : item.icon,
                                  size: compact ? 22 : 23,
                                  color: item.selected(stackIndex)
                                      ? AppColors.primary
                                      : mobileHomeMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              SizedBox(
                                height: 14,
                                width: double.infinity,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: compact ? 11 : 12,
                                      fontWeight: FontWeight.w600,
                                      color: item.selected(stackIndex)
                                          ? AppColors.primary
                                          : mobileHomeMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavSpec {
  const _NavSpec(
    this.key,
    this.stackIndex,
    this.label,
    this.icon,
    this.active, {
    this.badge = 0,
  });

  final String key;
  final int stackIndex;
  final String label;
  final IconData icon;
  final IconData active;
  final int badge;

  bool selected(int current) => stackIndex >= 0 && current == stackIndex;
}
