import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../screens/become_seller_page.dart';
import '../screens/seller_login_page.dart';
import '../utils/external_navigation.dart';

class WebFooter extends StatelessWidget {
  const WebFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 920;

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            isCompact ? 20 : 40,
            isCompact ? 22 : 36,
            isCompact ? 20 : 40,
            18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact) ...[
                _buildBrandColumn(),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 20,
                  runSpacing: 18,
                  children: [
                    SizedBox(
                      width: 180,
                      child: _buildFooterColumn(context, 'Kurumsal', [
                        'Hakkımızda',
                        'Kariyer',
                        'İletişim',
                        'Basın Odası',
                        'Yatırımcı İlişkileri',
                      ]),
                    ),
                    SizedBox(
                      width: 180,
                      child: _buildFooterColumn(context, 'Müşteri Hizmetleri', [
                        'Sıkça Sorulan Sorular',
                        'Canlı Destek',
                        'İade ve Değişim',
                        'Kargo Takibi',
                        'Güvenli Alışveriş',
                      ]),
                    ),
                    SizedBox(
                      width: 180,
                      child: _buildFooterColumn(context, 'İş Ortaklığı', [
                        'Satıcı Ol',
                        'İhız',
                        'Reklam Ver',
                        'API Entegrasyonu',
                        'İş Birlikleri',
                      ]),
                    ),
                  ],
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildBrandColumn()),
                    Expanded(
                      child: _buildFooterColumn(context, 'Kurumsal', [
                        'Hakkımızda',
                        'Kariyer',
                        'İletişim',
                        'Basın Odası',
                        'Yatırımcı İlişkileri',
                      ]),
                    ),
                    Expanded(
                      child: _buildFooterColumn(context, 'Müşteri Hizmetleri', [
                        'Sıkça Sorulan Sorular',
                        'Canlı Destek',
                        'İade ve Değişim',
                        'Kargo Takibi',
                        'Güvenli Alışveriş',
                      ]),
                    ),
                    Expanded(
                      child: _buildFooterColumn(context, 'İş Ortaklığı', [
                        'Satıcı Ol',
                        'İhız',
                        'Reklam Ver',
                        'API Entegrasyonu',
                        'İş Birlikleri',
                      ]),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              Divider(color: Colors.grey[700], height: 1),
              const SizedBox(height: 16),
              if (isCompact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '© 2026 iBul E-Ticaret A.Ş. Tüm hakları saklıdır.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 18,
                      runSpacing: 10,
                      children: [
                        _buildFooterLink('Gizlilik Politikası'),
                        _buildFooterLink('Kullanım Koşulları'),
                        _buildFooterLink('KVKK Aydınlatma Metni'),
                        _buildActionLink(
                          label: 'İhız',
                          color: const Color(0xFF7FE3C4),
                          onTap: () {
                            _openIhiz(context);
                          },
                        ),
                        _buildActionLink(
                          label: 'Admin Paneli',
                          color: Colors.grey[600]!,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const SellerLoginPage(adminMode: true),
                              ),
                            );
                          },
                        ),
                        _buildActionLink(
                          label: 'Satıcı Girişi',
                          color: AppColors.primary,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SellerLoginPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '© 2026 iBul E-Ticaret A.Ş. Tüm hakları saklıdır.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 20,
                        runSpacing: 8,
                        children: [
                          _buildFooterLink('Gizlilik Politikası'),
                          _buildFooterLink('Kullanım Koşulları'),
                          _buildFooterLink('KVKK Aydınlatma Metni'),
                          _buildActionLink(
                            label: 'İhız',
                            color: const Color(0xFF7FE3C4),
                            onTap: () {
                              _openIhiz(context);
                            },
                          ),
                          _buildActionLink(
                            label: 'Admin Paneli',
                            color: Colors.grey[600]!,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const SellerLoginPage(adminMode: true),
                                ),
                              );
                            },
                          ),
                          _buildActionLink(
                            label: 'Satıcı Girişi',
                            color: AppColors.primary,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SellerLoginPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBrandColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'iBul',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Türkiye\'nin akıllı e-ticaret platformu.\nYakın lokasyon siparişleri, mağaza teslim alma\nve hızlı kurye operasyonları tek ekosistemde.',
          style: TextStyle(color: Colors.grey[400], height: 1.55, fontSize: 13),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildSocialIcon(Icons.facebook),
            const SizedBox(width: 12),
            _buildSocialIcon(Icons.camera_alt_outlined),
            const SizedBox(width: 12),
            _buildSocialIcon(Icons.alternate_email),
            const SizedBox(width: 12),
            _buildSocialIcon(Icons.play_arrow_outlined),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[700]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.grey[400], size: 18),
    );
  }

  Widget _buildFooterColumn(
    BuildContext context,
    String title,
    List<String> links,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...links.map(
          (link) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () {
                if (link == 'Satıcı Ol') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BecomeSellerPage()),
                  );
                } else if (link == 'Satıcı Girişi') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SellerLoginPage()),
                  );
                } else if (link == 'İhız') {
                  _openIhiz(context);
                }
              },
              child: MouseRegion(
                cursor: _isClickable(link)
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: Text(
                  link,
                  style: TextStyle(
                    color: link == 'İhız'
                        ? const Color(0xFF7FE3C4)
                        : Colors.grey[400],
                    fontSize: 13,
                    fontWeight: link == 'İhız'
                        ? FontWeight.w700
                        : FontWeight.w400,
                    decoration: _isClickable(link)
                        ? TextDecoration.underline
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _isClickable(String link) {
    return link == 'Satıcı Ol' || link == 'Satıcı Girişi' || link == 'İhız';
  }

  Widget _buildFooterLink(String text) {
    return Text(text, style: TextStyle(color: Colors.grey[500], fontSize: 12));
  }

  Widget _buildActionLink({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  void _openIhiz(BuildContext context) {
    final openedExternally = ExternalNavigation.openIhizSite();
    if (openedExternally) return;

    Navigator.of(context, rootNavigator: true).pushNamed('/ihiz');
  }
}
