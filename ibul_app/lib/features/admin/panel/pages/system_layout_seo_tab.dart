import 'package:flutter/material.dart';

import '../../../../core/public_seo.dart';
import '../widgets/system_layout_section.dart';

/// SEO controls for Sistem Düzeni.
///
/// Live titles, canonical URLs and JSON-LD are generated in `public_seo.dart`
/// from real content. Global overrides need `seo_site_settings`, which is
/// proposed and not applied. This tab does not accept raw JSON-LD.
class SystemLayoutSeoTab extends StatelessWidget {
  const SystemLayoutSeoTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        const SystemLayoutSectionHeader(
          title: 'SEO',
          subtitle:
              'Başlık, açıklama ve yapılandırılmış veri gerçek içerikten üretilir. Kalıcı admin override şeması önerildi, bu görevde uygulanmadı.',
        ),
        const SizedBox(height: 16),
        const _SeoCard(
          title: 'Genel',
          rows: [
            ('Site başlığı', kHomeTitle),
            ('Meta açıklama', kHomeDescription),
            ('Site adı', kPublicSiteName),
            ('Kanonik taban', kPublicSiteOrigin),
            ('Varsayılan dizin', 'index, follow'),
            ('Kuruluş', kPublicSiteName),
            ('Sosyal görsel', 'Ürün veya yazı görseli; yoksa logo'),
            ('Search Console', 'Doğrulama anahtarı kaynak koda yazılmadı'),
            ('Analytics / GTM', 'Ayrı ölçüm sistemi kurulmadı'),
            ('robots.txt', 'Açık; hesap, sepet, admin ve giriş kapalı'),
            ('sitemap.xml', 'Açık; her web derlemesinde gerçek veriyle yenilenir'),
          ],
        ),
        const SizedBox(height: 12),
        _SeoCard(
          title: 'İçerik türleri',
          rows: [
            ('Ürün', productSeoTitle('Ürün adı')),
            ('Kategori', categorySeoTitle('Kategori')),
            ('Mağaza', storeSeoTitle('Mağaza')),
            ('AVM', mallSeoTitle('AVM')),
            ('Blog', blogSeoTitle('Yazı başlığı')),
          ],
          note:
              'Ürün, kategori, mağaza ve AVM başlıkları kayıttaki addan üretilir. Blog yazılarında mevcut seo_title ve meta_description override olarak kullanılır. Ürün/mağaza/AVM kolonları önerilen şemadadır; JSON-LD alanı yoktur.',
        ),
      ],
    );
  }
}

class _SeoCard extends StatelessWidget {
  const _SeoCard({required this.title, required this.rows, this.note});

  final String title;
  final List<(String, String)> rows;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SystemLayoutColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SystemLayoutColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SystemLayoutColors.title,
            ),
          ),
          const SizedBox(height: 12),
          for (final row in rows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 160,
                  child: Text(
                    row.$1,
                    style: const TextStyle(
                      fontSize: 13,
                      color: SystemLayoutColors.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.$2,
                    style: const TextStyle(fontSize: 13, color: SystemLayoutColors.title),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: SystemLayoutColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
