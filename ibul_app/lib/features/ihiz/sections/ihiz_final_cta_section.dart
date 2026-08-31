import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';

class IhizFinalCtaSection extends StatelessWidget {
  const IhizFinalCtaSection({
    super.key,
    required this.onCourierApply,
    required this.onBusinessJoin,
  });

  final VoidCallback onCourierApply;
  final VoidCallback onBusinessJoin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = IhizBrand.isMobile(constraints.maxWidth);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            mobile ? 20 : 40,
            mobile ? 28 : 40,
            mobile ? 20 : 40,
            mobile ? 28 : 40,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: IhizBrand.heroGradient,
            boxShadow: [
              BoxShadow(
                color: IhizBrand.navy.withValues(alpha: 0.24),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Teslimatın geleceğine hazır mısın?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: mobile ? 26 : 34,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'İhız ile daha hızlı teslim et, daha kolay yönet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w600,
                  fontSize: mobile ? 15 : 17,
                  height: 1.45,
                ),
              ),
              SizedBox(height: mobile ? 22 : 28),
              if (mobile)
                Column(
                  children: [
                    IhizPrimaryButton(
                      label: 'Kurye Ol',
                      icon: Icons.two_wheeler_rounded,
                      onPressed: onCourierApply,
                      expanded: true,
                    ),
                    const SizedBox(height: 12),
                    IhizSecondaryButton(
                      label: 'İşletme Olarak Başla',
                      icon: Icons.storefront_rounded,
                      onPressed: onBusinessJoin,
                      expanded: true,
                      onDark: true,
                    ),
                  ],
                )
              else
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    IhizPrimaryButton(
                      label: 'Kurye Ol',
                      icon: Icons.two_wheeler_rounded,
                      onPressed: onCourierApply,
                    ),
                    IhizSecondaryButton(
                      label: 'İşletme Olarak Başla',
                      icon: Icons.storefront_rounded,
                      onPressed: onBusinessJoin,
                      onDark: true,
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
