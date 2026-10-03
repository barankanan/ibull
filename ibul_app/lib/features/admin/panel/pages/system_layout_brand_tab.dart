import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../widgets/system_layout_section.dart';

/// Genel görünüm ve logolar. Uygulama/site logosu için canlı bir ayar kaydı
/// yoktur; logo uygulama paketine gömülüdür. Bu bölüm gerçek kaynağı gösterir.
class SystemLayoutBrandTab extends StatelessWidget {
  const SystemLayoutBrandTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SystemLayoutColors.background,
      child: Column(
        children: [
          const SystemLayoutSectionHeader(
            title: 'Genel Görünüm ve Logolar',
            subtitle:
                'Uygulama ve site logosunun kaynağı, satıcı logolarının yönetim yeri',
            liveNote:
                'Bu bölümde canlıya kaydedilen bir ayar yoktur; logo değişikliği yeni uygulama sürümüyle yayına girer.',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                _InfoCard(
                  icon: Icons.verified_outlined,
                  title: 'İBUL uygulama ve site logosu',
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      AppAssets.ibulLogo,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  lines: const [
                    'Kaynak: ${AppAssets.ibulLogo} (uygulama paketi)',
                    'Web sekme ve ana ekran simgeleri: web/icons ve web/favicon.png',
                    'Veritabanında logo ayarı bulunmadığından buradan değiştirilemez.',
                  ],
                ),
                const SizedBox(height: 12),
                const _InfoCard(
                  icon: Icons.storefront_outlined,
                  title: 'Satıcı ve mağaza logoları',
                  lines: [
                    'Kaynak: stores.logo_url — mağazanın sahibi satıcıdır.',
                    'Logolar mağaza başvurusu ve Mağaza Yönetimi akışlarında, mevcut admin yetkileriyle yönetilir.',
                    'Sistem Düzeni satıcı logolarının sahipliğini veya kaynağını değiştirmez.',
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.lines,
    this.leading,
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SystemLayoutColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SystemLayoutColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading ??
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: SystemLayoutColors.accentSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: SystemLayoutColors.accent, size: 30),
              ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SystemLayoutColors.title,
                  ),
                ),
                const SizedBox(height: 8),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: SystemLayoutColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
