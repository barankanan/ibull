import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';

/// İHIZ marketing footer — İBUL WebFooter kullanmaz.
class IhizFooter extends StatelessWidget {
  static const returnToIbulKey = ValueKey<String>('ihiz-return-to-ibul');

  const IhizFooter({
    super.key,
    required this.onHome,
    required this.onHowItWorks,
    required this.onCourierApply,
    required this.onBusinessJoin,
    required this.onTracking,
    required this.onReturnToIbul,
  });

  final VoidCallback onHome;
  final VoidCallback onHowItWorks;
  final VoidCallback onCourierApply;
  final VoidCallback onBusinessJoin;
  final VoidCallback onTracking;
  final VoidCallback onReturnToIbul;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: IhizBrand.footerGradient),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: IhizBrand.contentMaxWidth,
            ),
            child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              final columnWidth = wide ? 210.0 : constraints.maxWidth - 44;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 32 : 22,
                  wide ? 44 : 32,
                  wide ? 32 : 22,
                  22,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 40,
                      runSpacing: 28,
                      children: [
                        SizedBox(
                          width: wide ? 280 : columnWidth,
                          child: const _IhizFooterBrand(),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: _IhizFooterColumn(
                            title: 'HIZLI LİNKLER',
                            links: [
                              _IhizFooterLink('Ana Sayfa', onHome),
                              _IhizFooterLink('Nasıl Çalışır?', onHowItWorks),
                              _IhizFooterLink('Kurye Ol', onCourierApply),
                              _IhizFooterLink('İşletmeler', onBusinessJoin),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: _IhizFooterColumn(
                            title: 'TESLİMAT',
                            links: [
                              _IhizFooterLink(
                                'Teslimat Takibi',
                                onTracking,
                              ),
                              _IhizFooterLink('Kurye Destek', onCourierApply),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: columnWidth,
                          child: _IhizFooterColumn(
                            title: 'İBUL',
                            links: [
                              _IhizFooterLink(
                                'İBUL\'a Dön',
                                onReturnToIbul,
                                key: returnToIbulKey,
                              ),
                              _IhizFooterLink(
                                'İBUL Marketplace',
                                onReturnToIbul,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: wide ? 36 : 26),
                    Divider(color: Colors.white.withValues(alpha: 0.14)),
                    const SizedBox(height: 14),
                    Text(
                      '© 2026 İHIZ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        ),
      ),
    );
  }
}

class _IhizFooterBrand extends StatelessWidget {
  const _IhizFooterBrand();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IhizLogoLockup(size: 28, color: Colors.white, onDark: true),
        SizedBox(height: 14),
        Text(
          'Teslimatın yeni hızı.',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Mağazalar ve müşteriler için hızlı, güvenli ve takip edilebilir teslimat.',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _IhizFooterColumn extends StatelessWidget {
  const _IhizFooterColumn({required this.title, required this.links});

  final String title;
  final List<_IhizFooterLink> links;

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
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 14),
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: InkWell(
              key: link.key,
              onTap: link.onTap,
              borderRadius: BorderRadius.circular(6),
              child: Text(
                link.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _IhizFooterLink {
  const _IhizFooterLink(this.label, this.onTap, {this.key});

  final String label;
  final VoidCallback onTap;
  final Key? key;
}
