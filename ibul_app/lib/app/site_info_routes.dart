import 'package:flutter/material.dart';

import '../features/customer_support/screens/customer_support_page.dart'
    deferred as customer_support;
import '../screens/feature_coming_soon_page.dart';
import '../widgets/deferred_module_screen.dart';
import '../screens/legal/legal_document.dart';
import '../screens/legal/legal_document_page.dart';
import '../screens/legal/public_tracking_lookup_page.dart';

/// Public marketing / legal paths shared by CustomerApp and FullApp.
abstract final class SiteInfoRoutes {
  static const privacy = '/gizlilik';
  static const terms = '/kullanim';
  static const kvkk = '/kvkk';
  static const about = '/hakkimizda';
  static const contact = '/iletisim';
  static const faq = '/sss';
  static const returns = '/iade';
  static const safeShopping = '/guvenli-alisveris';
  static const career = '/kariyer';
  static const press = '/basin';
  static const advertise = '/reklam-ver';
  static const api = '/api-entegrasyonu';
  static const partnerships = '/is-birlikleri';
  static const support = '/destek';
  static const shipmentLookup = '/kargo-takibi';

  static const List<String> paths = [
    privacy,
    terms,
    kvkk,
    about,
    contact,
    faq,
    returns,
    safeShopping,
    career,
    press,
    advertise,
    api,
    partnerships,
    support,
    shipmentLookup,
  ];

  static const Map<String, String> footerLabelToPath = {
    'Hakkımızda': about,
    'Kariyer': career,
    'İletişim': contact,
    'Basın Odası': press,
    'Sıkça Sorulan Sorular': faq,
    'Canlı Destek': support,
    'İade ve Değişim': returns,
    'Kargo Takibi': shipmentLookup,
    'Güvenli Alışveriş': safeShopping,
    'Reklam Ver': advertise,
    'API Entegrasyonu': api,
    'İş Birlikleri': partnerships,
    'Gizlilik Politikası': privacy,
    'Kullanım Koşulları': terms,
    'KVKK Aydınlatma Metni': kvkk,
  };

  static Widget? pageForPath(String path) {
    switch (path) {
      case privacy:
        return const LegalDocumentPage(documentId: LegalDocumentId.privacy);
      case terms:
        return const LegalDocumentPage(documentId: LegalDocumentId.terms);
      case kvkk:
        return const LegalDocumentPage(documentId: LegalDocumentId.kvkk);
      case about:
        return const LegalDocumentPage(documentId: LegalDocumentId.about);
      case contact:
        return const LegalDocumentPage(documentId: LegalDocumentId.contact);
      case faq:
        return const LegalDocumentPage(documentId: LegalDocumentId.faq);
      case returns:
        return const LegalDocumentPage(documentId: LegalDocumentId.returns);
      case safeShopping:
        return const LegalDocumentPage(documentId: LegalDocumentId.safeShopping);
      case support:
        return DeferredModuleScreen(
          moduleName: 'customer_support_page',
          loadLibrary: customer_support.loadLibrary,
          loading: const Scaffold(
            backgroundColor: Color(0xFFF9FAFB),
            body: Center(child: CircularProgressIndicator()),
          ),
          builder: () => customer_support.CustomerSupportPage(),
        );
      case shipmentLookup:
        return const PublicTrackingLookupPage();
      case career:
        return const FeatureComingSoonPage(
          title: 'Kariyer',
          description:
              'Açık pozisyon listesi henüz yayımlanmadı. İletişim sayfasından ulaşabilirsiniz.',
          icon: Icons.work_outline_rounded,
        );
      case press:
        return const FeatureComingSoonPage(
          title: 'Basın Odası',
          description:
              'Basın kiti ve bülten arşivi hazırlanıyor. Kurumsal talepler için iletişim kanalını kullanın.',
          icon: Icons.newspaper_outlined,
        );
      case advertise:
        return const FeatureComingSoonPage(
          title: 'Reklam Ver',
          description:
              'Satıcı reklam paneli mevcut; self-servis marka reklam vitrini yakında açılacak.',
          icon: Icons.campaign_outlined,
        );
      case api:
        return const FeatureComingSoonPage(
          title: 'API Entegrasyonu',
          description:
              'Dış geliştirici API’si henüz herkese açık değil. İş birliği taleplerini iletişimden iletin.',
          icon: Icons.hub_outlined,
        );
      case partnerships:
        return const FeatureComingSoonPage(
          title: 'İş Birlikleri',
          description:
              'Lojistik ve marka ortaklıkları için yatırımcı veya iletişim formunu kullanın.',
          icon: Icons.handshake_outlined,
        );
      default:
        return null;
    }
  }

  static bool handles(String path) => pageForPath(path) != null;

  static void openFooterLabel(BuildContext context, String label) {
    final path = footerLabelToPath[label];
    if (path == null) return;
    final page = pageForPath(path);
    if (page == null) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: path),
        builder: (_) => page,
      ),
    );
  }
}
