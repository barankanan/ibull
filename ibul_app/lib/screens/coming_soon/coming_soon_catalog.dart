import 'package:flutter/material.dart';

import 'coming_soon_shelf_page.dart';
import '../feature_coming_soon_page.dart';

class ComingSoonItem {
  const ComingSoonItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
}

/// Marketplace features that are not live. Open via [open] or [openShelf].
abstract final class ComingSoonCatalog {
  static const premium = ComingSoonItem(
    id: 'premium',
    title: 'iBul Premium',
    description:
        'Öncelikli teslimat, özel kampanyalar ve üyelik ayrıcalıkları '
        'henüz satışa açılmadı. Bu bir abonelik sayfası değil.',
    icon: Icons.workspace_premium_rounded,
  );

  static const repair = ComingSoonItem(
    id: 'repair',
    title: 'Garantili Tamir',
    description:
        'Yetkili servis ve yerinde tamir ağı henüz randevu almıyor. '
        'Talep oluştuğunda buradan açılacak.',
    icon: Icons.build_outlined,
  );

  static const assembly = ComingSoonItem(
    id: 'assembly',
    title: 'Montaj Hizmeti',
    description:
        'Mobilya ve cihaz montajı için saha ekibi henüz atanmıyor. '
        'Hizmet bölgesi belirlendiğinde duyurulacak.',
    icon: Icons.format_list_bulleted,
  );

  static const barcode = ComingSoonItem(
    id: 'barcode',
    title: 'Barkod Okut',
    description:
        'Kamera ile barkod okuma henüz bağlı değil. Ürünü arama veya '
        'görsel zeka ile bulabilirsiniz.',
    icon: Icons.qr_code_scanner,
  );

  static const appFeedback = ComingSoonItem(
    id: 'app_feedback',
    title: 'Uygulama Görüşün',
    description:
        'Mağaza puanı henüz bağlı değil. Görüşlerinizi müşteri '
        'hizmetleri formundan iletebilirsiniz.',
    icon: Icons.star_border,
  );

  static const List<ComingSoonItem> marketplaceShelf = [
    premium,
    repair,
    assembly,
    barcode,
    appFeedback,
  ];

  static Future<void> open(BuildContext context, ComingSoonItem item) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FeatureComingSoonPage(
          title: item.title,
          description: item.description,
          icon: item.icon,
        ),
      ),
    );
  }

  static Future<void> openShelf(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ComingSoonShelfPage(),
      ),
    );
  }
}
