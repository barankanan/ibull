import 'package:flutter/material.dart';

import '../../core/constants.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  static const options = <_NoticeOption>[
    _NoticeOption(
      icon: Icons.shopping_bag_outlined,
      title: 'Sipariş bildirimleri',
      detail: 'Sipariş durumu bildirimleri mevcut sipariş akışından gelir.',
    ),
    _NoticeOption(
      icon: Icons.local_offer_outlined,
      title: 'Kampanya ve fırsatlar',
      detail: 'Ayrı bir kampanya tercih kaydı bulunmuyor.',
    ),
    _NoticeOption(
      icon: Icons.chat_bubble_outline,
      title: 'Mesajlar / satıcı cevapları',
      detail: 'Satıcı cevapları bildirim kutusunda görünür.',
    ),
    _NoticeOption(
      icon: Icons.local_shipping_outlined,
      title: 'Teslimat / kurye durumları',
      detail: 'Teslimat durumu sipariş kaydından okunur.',
    ),
    _NoticeOption(
      icon: Icons.favorite_border,
      title: 'Favori / fiyat değişiklikleri',
      detail: 'Favori fiyat uyarısı için kayıtlı bir tercih alanı yok.',
    ),
    _NoticeOption(
      icon: Icons.mail_outline,
      title: 'E-posta bildirimleri',
      detail: 'E-posta bildirimi bu hesapta ayrı kaydedilmiyor.',
    ),
    _NoticeOption(
      icon: Icons.sms_outlined,
      title: 'SMS bildirimleri',
      detail: 'SMS bildirimi bu hesapta ayrı kaydedilmiyor.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF111827),
        centerTitle: true,
        title: const Text(
          'Bildirim Ayarları',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE6E7EE)),
            ),
            child: const Text(
              'Bu seçenekler için hesapta kayıtlı bir bildirim tercihi yok. Aşağıdaki satırlar bilgi amaçlıdır; anahtar kaydı oluşturulmaz.',
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE6E7EE)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < options.length; i++)
                  _NoticeRow(
                    option: options[i],
                    showDivider: i != options.length - 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeOption {
  const _NoticeOption({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.option, required this.showDivider});

  final _NoticeOption option;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(option.icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.detail,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 48, color: Color(0xFFE6E7EE)),
      ],
    );
  }
}
