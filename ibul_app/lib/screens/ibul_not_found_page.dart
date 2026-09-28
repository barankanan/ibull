import 'package:flutter/material.dart';

import '../app/marketplace_paths.dart';
import '../core/constants.dart';
import '../core/home_navigation.dart';
import '../core/web_seo.dart';

class IbulNotFoundPage extends StatelessWidget {
  const IbulNotFoundPage({super.key, this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    setSeoMeta(
      title: 'Sayfa bulunamadı | İBUL',
      description: 'Aradığınız İBUL sayfası bulunamadı.',
      canonicalPath: path ?? MarketplacePaths.home,
    );
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  size: 56,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sayfa bulunamadı',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF3B0764),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bu bağlantı geçersiz veya kaldırılmış olabilir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => HomeNavigation.openHome(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Ana sayfaya dön'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
