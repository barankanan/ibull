import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';

/// Corporate İHIZ footer: four link columns, a bottom legal bar with social
/// icons, and the Admin Girişi entry point.
///
/// Informational links are placeholders for pages that do not exist yet; only
/// the flows that are actually wired ([onApply], [onAdminLogin]) navigate.
class IhizSiteFooter extends StatelessWidget {
  const IhizSiteFooter({
    super.key,
    required this.onApply,
    required this.onAdminLogin,
  });

  final VoidCallback onApply;
  final VoidCallback onAdminLogin;

  @override
  Widget build(BuildContext context) {
    final columns = <_FooterColumn>[
      const _FooterColumn(
        title: 'KURUMSAL',
        links: [
          _FooterLinkData('Hakkımızda'),
          _FooterLinkData('Kariyer'),
          _FooterLinkData('Basın'),
          _FooterLinkData('Yatırımcı İlişkileri'),
        ],
      ),
      const _FooterColumn(
        title: 'BİLGİ',
        links: [
          _FooterLinkData('Teslimat Politikası'),
          _FooterLinkData('İade Süreci'),
          _FooterLinkData('Kullanım Koşulları'),
          _FooterLinkData('Gizlilik Politikası'),
          _FooterLinkData('KVKK'),
        ],
      ),
      _FooterColumn(
        title: 'DESTEK',
        links: [
          const _FooterLinkData('Yardım Merkezi'),
          const _FooterLinkData('Canlı Destek'),
          const _FooterLinkData('Sık Sorulan Sorular'),
          _FooterLinkData('Kurye Destek', onTap: onApply),
          const _FooterLinkData('Satıcı Destek'),
        ],
      ),
      const _FooterColumn(
        title: 'HABERLER',
        links: [
          _FooterLinkData('Blog'),
          _FooterLinkData('Duyurular'),
          _FooterLinkData('Sistem Güncellemeleri'),
          _FooterLinkData('Yeni Bölgeler'),
        ],
      ),
    ];

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: IhizBrand.footerGradient),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: IhizBrand.contentMaxWidth,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 32 : 22,
                  wide ? 46 : 34,
                  wide ? 32 : 22,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const IhizLogoLockup(size: 30),
                        OutlinedButton.icon(
                          onPressed: onAdminLogin,
                          icon: const Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 18,
                          ),
                          label: const Text('Admin Girişi'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: wide ? 34 : 26),
                    Wrap(
                      spacing: 40,
                      runSpacing: 30,
                      children: [
                        for (final column in columns)
                          SizedBox(
                            width: wide ? 210 : constraints.maxWidth - 44,
                            child: column,
                          ),
                      ],
                    ),
                    SizedBox(height: wide ? 40 : 30),
                    Divider(color: Colors.white.withValues(alpha: 0.14)),
                    const SizedBox(height: 14),
                    _BottomBar(wide: wide),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final legal = Text(
      '© 2026 İHIZ Kurye Teknolojileri A.Ş. Tüm hakları saklıdır.',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontWeight: FontWeight.w600,
        fontSize: 12.5,
      ),
    );
    const social = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SocialIcon(icon: Icons.camera_alt_outlined, label: 'Instagram'),
        _SocialIcon(icon: Icons.close_rounded, label: 'X'),
        _SocialIcon(icon: Icons.business_center_outlined, label: 'LinkedIn'),
        _SocialIcon(icon: Icons.play_circle_outline_rounded, label: 'YouTube'),
      ],
    );

    if (wide) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Flexible(child: legal), social],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [legal, const SizedBox(height: 14), social],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: label,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Icon(
            icon,
            size: 18,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}

class _FooterColumn extends StatelessWidget {
  const _FooterColumn({required this.title, required this.links});

  final String title;
  final List<_FooterLinkData> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 14),
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: _FooterLink(data: link),
          ),
      ],
    );
  }
}

class _FooterLinkData {
  const _FooterLinkData(this.label, {this.onTap});

  final String label;
  final VoidCallback? onTap;
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.data});

  final _FooterLinkData data;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      data.label,
      style: TextStyle(
        color: Colors.white.withValues(alpha: data.onTap != null ? 0.96 : 0.82),
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
    if (data.onTap == null) {
      return Align(alignment: Alignment.centerLeft, child: text);
    }
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(6),
      child: Align(alignment: Alignment.centerLeft, child: text),
    );
  }
}
