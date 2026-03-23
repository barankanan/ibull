import 'package:flutter/material.dart';

import '../widgets/ihiz_marketing_chrome.dart';

class IhizLoginMarketingSection extends StatelessWidget {
  const IhizLoginMarketingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF163B73), Color(0xFF2C6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IhizHeroChip('Sadece onaylı kuryeler'),
          SizedBox(height: 18),
          Text(
            'İhız kurye paneline giriş',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Giriş sonrası sipariş havuzu, canlı rota, mağaza adresi ve müşteri teslim ekranları açılır.',
            style: TextStyle(color: Colors.white70, height: 1.6, fontSize: 15),
          ),
          SizedBox(height: 20),
          IhizLoginPoint('Sipariş havuzundan görev seç'),
          SizedBox(height: 10),
          IhizLoginPoint('Mağazadan teslim al'),
          SizedBox(height: 10),
          IhizLoginPoint('Müşteriye bırak ve görevi kapat'),
        ],
      ),
    );
  }
}
