import 'package:flutter/material.dart';

import '../../core/constants.dart';
import 'coming_soon_catalog.dart';

/// Single marketplace “Yakında” shelf — not mixed into live shortcuts.
class ComingSoonShelfPage extends StatelessWidget {
  const ComingSoonShelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Yakında',
          style: TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Bu özellikler henüz satışta veya randevuda değil. '
              'Canlı kısayollar ana menüde duruyor.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ),
          for (final item in ComingSoonCatalog.marketplaceShelf)
            ListTile(
              leading: Icon(item.icon, color: AppColors.primary),
              title: Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: const Text(
                'Yakında aktif olacak',
                style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.iconMuted,
              ),
              onTap: () => ComingSoonCatalog.open(context, item),
            ),
        ],
      ),
    );
  }
}
