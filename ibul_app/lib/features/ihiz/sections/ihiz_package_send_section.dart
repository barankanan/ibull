import 'package:flutter/material.dart';

import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';

class IhizPackageSendSection extends StatelessWidget {
  const IhizPackageSendSection({super.key, required this.onSend});

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = IhizBrand.isMobile(constraints.maxWidth);
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 20 : 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: IhizBrand.line),
            boxShadow: IhizBrand.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IhizSectionHeader(
                eyebrow: 'PAKET GÖNDER',
                title: 'Paketinizi evinizden veya işletmenizden alalım.',
                subtitle:
                    'Adresleri girin, kurye çağırın; teslimat kodunuz anında oluşur.',
              ),
              SizedBox(height: compact ? 16 : 20),
              IhizPrimaryButton(
                label: 'Paketi Gönder',
                icon: Icons.inventory_2_outlined,
                onPressed: onSend,
                expanded: compact,
              ),
            ],
          ),
        );
      },
    );
  }
}
