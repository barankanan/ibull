import 'package:flutter/material.dart';

import '../core/app_motion.dart';
import 'ibul_router.dart';
import 'marketplace_paths.dart';

/// Account sidebar sections. Route path is the source of truth on web.
enum AccountSection {
  overview,
  ai,
  orders,
  rentals,
  favorites,
  coupons,
  following,
  addresses,
  cards,
  reviews,
  support,
  settings,
}

abstract final class AccountSections {
  static const _byPath = <String, AccountSection>{
    MarketplacePaths.account: AccountSection.overview,
    MarketplacePaths.ai: AccountSection.ai,
    MarketplacePaths.orders: AccountSection.orders,
    MarketplacePaths.rentals: AccountSection.rentals,
    MarketplacePaths.favorites: AccountSection.favorites,
    MarketplacePaths.coupons: AccountSection.coupons,
    MarketplacePaths.following: AccountSection.following,
    MarketplacePaths.addresses: AccountSection.addresses,
    MarketplacePaths.cards: AccountSection.cards,
    MarketplacePaths.reviews: AccountSection.reviews,
    MarketplacePaths.support: AccountSection.support,
    MarketplacePaths.settings: AccountSection.settings,
  };

  static AccountSection? fromPath(String path) {
    final normalized = path.split('?').first;
    return _byPath[normalized];
  }

  static String pathOf(AccountSection section) {
    switch (section) {
      case AccountSection.overview:
        return MarketplacePaths.account;
      case AccountSection.ai:
        return MarketplacePaths.ai;
      case AccountSection.orders:
        return MarketplacePaths.orders;
      case AccountSection.rentals:
        return MarketplacePaths.rentals;
      case AccountSection.favorites:
        return MarketplacePaths.favorites;
      case AccountSection.coupons:
        return MarketplacePaths.coupons;
      case AccountSection.following:
        return MarketplacePaths.following;
      case AccountSection.addresses:
        return MarketplacePaths.addresses;
      case AccountSection.cards:
        return MarketplacePaths.cards;
      case AccountSection.reviews:
        return MarketplacePaths.reviews;
      case AccountSection.support:
        return MarketplacePaths.support;
      case AccountSection.settings:
        return MarketplacePaths.settings;
    }
  }

  static String labelOf(AccountSection section) {
    switch (section) {
      case AccountSection.overview:
        return 'Hesap Özeti';
      case AccountSection.ai:
        return 'Yapay Zekaya Danış';
      case AccountSection.orders:
        return 'Siparişlerim';
      case AccountSection.rentals:
        return 'Kiralamalarım';
      case AccountSection.favorites:
        return 'Favorilerim';
      case AccountSection.coupons:
        return 'Kuponlarım';
      case AccountSection.following:
        return 'Takip Ettiklerim';
      case AccountSection.addresses:
        return 'Adreslerim';
      case AccountSection.cards:
        return 'Kayıtlı Kartlarım';
      case AccountSection.reviews:
        return 'Değerlendirmelerim';
      case AccountSection.support:
        return 'Müşteri Hizmetleri';
      case AccountSection.settings:
        return 'Ayarlar';
    }
  }

  static String documentTitleOf(AccountSection section) {
    if (section == AccountSection.overview) return 'Hesabım | İBUL';
    return '${labelOf(section)} | İBUL';
  }

  /// Web: [IbulRouter.push] so browser history records each section.
  /// Native: keeps the existing Navigator stack behavior.
  static Future<void> open(
    BuildContext context,
    AccountSection section, {
    required Widget nativePage,
    bool replaceNative = true,
  }) {
    if (IbulRouter.usesRootRouter) {
      final path = pathOf(section);
      if (IbulRouter.currentPath(context) == path) {
        return Future<void>.value();
      }
      return IbulRouter.push(context, path);
    }
    if (replaceNative) {
      return Navigator.pushReplacement<void, void>(
        context,
        buildAppPageRoute<void>(builder: (_) => nativePage),
      );
    }
    return Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => nativePage),
    );
  }
}
