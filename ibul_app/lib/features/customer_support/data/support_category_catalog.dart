import 'package:flutter/material.dart';

class SupportCategoryOption {
  const SupportCategoryOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.subcategories,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<String> subcategories;
}

const List<SupportCategoryOption> supportCategoryCatalog = [
  SupportCategoryOption(
    id: 'order_issue',
    title: 'Sipariş Sorunu',
    description: 'Teslimat, eksik veya yanlış ürün',
    icon: Icons.shopping_bag_outlined,
    subcategories: [
      'Siparişim gelmedi',
      'Yanlış ürün geldi',
      'Eksik ürün geldi',
      'Siparişim iptal edildi',
      'Sipariş durumu güncellenmiyor',
    ],
  ),
  SupportCategoryOption(
    id: 'return_exchange',
    title: 'İade / Değişim',
    description: 'İade ve değişim talepleri',
    icon: Icons.assignment_return_outlined,
    subcategories: [
      'İade talebi oluşturmak istiyorum',
      'Değişim yapmak istiyorum',
      'İade ücretim yatmadı',
      'Satıcı iade talebime dönmedi',
    ],
  ),
  SupportCategoryOption(
    id: 'payment_issue',
    title: 'Ödeme Sorunu',
    description: 'Ödeme, fatura ve indirim',
    icon: Icons.payments_outlined,
    subcategories: [
      'Ödeme alındı ama sipariş oluşmadı',
      'Kartımdan fazla ücret çekildi',
      'Kupon/indirim uygulanmadı',
      'Fatura / ödeme belgesi istiyorum',
    ],
  ),
  SupportCategoryOption(
    id: 'store_complaint',
    title: 'Mağaza / Satıcı Şikayeti',
    description: 'Satıcı davranışı ve bilgi',
    icon: Icons.storefront_outlined,
    subcategories: [
      'Satıcı cevap vermiyor',
      'Ürün açıklaması hatalı',
      'Mağaza yanlış bilgi verdi',
      'Satıcı davranışıyla ilgili şikayetim var',
    ],
  ),
  SupportCategoryOption(
    id: 'technical_issue',
    title: 'Teknik Sorun',
    description: 'Uygulama ve teknik aksaklıklar',
    icon: Icons.bug_report_outlined,
    subcategories: [
      'Uygulama açılmıyor',
      'Sayfa yüklenmiyor',
      'Harita / konum çalışmıyor',
      'Bildirim sorunu yaşıyorum',
      'Hesabıma giriş yapamıyorum',
    ],
  ),
  SupportCategoryOption(
    id: 'account_security',
    title: 'Hesap ve Güvenlik',
    description: 'Hesap, giriş ve güvenlik',
    icon: Icons.shield_outlined,
    subcategories: [
      'Telefon/e-posta değiştirmek istiyorum',
      'Hesabımda şüpheli işlem var',
      'Şifremi/giriş bilgilerimi güncellemek istiyorum',
      'Hesabımı silmek istiyorum',
    ],
  ),
  SupportCategoryOption(
    id: 'suggestion',
    title: 'Öneri / İstek',
    description: 'Geri bildirim ve öneriler',
    icon: Icons.lightbulb_outline,
    subcategories: [
      'Yeni özellik önerisi',
      'Mağaza önerisi',
      'Ürün/kategori önerisi',
      'Genel geri bildirim',
    ],
  ),
  SupportCategoryOption(
    id: 'other',
    title: 'Diğer',
    description: 'Farklı konularda destek',
    icon: Icons.more_horiz,
    subcategories: [
      'Konum bu başlıklara uymuyor',
      'Farklı bir konuda destek almak istiyorum',
    ],
  ),
];

SupportCategoryOption? findSupportCategory(String? id) {
  if (id == null || id.isEmpty) return null;
  for (final item in supportCategoryCatalog) {
    if (item.id == id) return item;
  }
  return null;
}

String supportCategoryTitle(String? id, {String fallback = 'Diğer'}) {
  return findSupportCategory(id)?.title ?? fallback;
}
