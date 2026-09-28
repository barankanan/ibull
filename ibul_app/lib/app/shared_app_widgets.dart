import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/home_navigation.dart';
import '../core/providers/connectivity_provider.dart';
import '../core/qr_initial_params.dart';
import '../core/web_seo.dart';
import '../features/investor/investor_route_paths.dart';
import '../screens/qr_entry_screen.dart' deferred as qr_entry;
import '../widgets/deferred_module_screen.dart';
import 'app_bootstrap.dart';
import 'seller_routes.dart';

class OfflineListener extends StatelessWidget {
  const OfflineListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        Consumer<ConnectivityProvider>(
          builder: (context, provider, _) {
            if (!provider.isOnline) {
              return Container(
                width: double.infinity,
                color: Colors.red,
                padding: const EdgeInsets.all(8),
                child: const Text(
                  'İnternet bağlantısı yok',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

class OfflineWrapper extends StatelessWidget {
  const OfflineWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

Widget buildSafeHome({
  required String source,
  Object? arguments,
  int initialIndex = 0,
  String? initialCategory,
  String? initialSearchQuery,
}) {
  final homeArgs = HomeRouteArgs.from(arguments);
  debugPrint(
    '[Routing] home route opened — source=$source tab=${homeArgs.initialIndex} '
    '${QrInitialParams.debugState}',
  );
  return OfflineWrapper(
    child: HomeWrapper(
      initialIndex: homeArgs.initialIndex != 0
          ? homeArgs.initialIndex
          : initialIndex,
      initialCategory: homeArgs.initialCategory ?? initialCategory,
      initialSearchQuery: homeArgs.initialSearchQuery ?? initialSearchQuery,
    ),
  );
}

Widget buildQrEntry({required String source}) {
  debugPrint(
    '[Routing] QR route opened — source=$source ${QrInitialParams.debugState}',
  );
  return DeferredModuleScreen(
    moduleName: 'qr_entry',
    loadLibrary: qr_entry.loadLibrary,
    builder: () => qr_entry.QrEntryScreen(),
  );
}

/// Initial [MaterialApp.home] for all three shells.
Widget buildLaunchHome() {
  final launchQrHome = kIsWeb &&
      QrInitialParams.isQrPath &&
      !QrInitialParams.wasResetAfterQrExit;
  if (launchQrHome) {
    return buildQrEntry(source: 'MaterialApp.home');
  }
  if (kIsWeb && InvestorRoutePaths.isLaunchPath()) {
    return SellerRoutes.buildInvestorPage();
  }
  return buildSafeHome(source: 'MaterialApp.home');
}

class SeoRouteObserver extends NavigatorObserver {
  SeoRouteObserver({this.includeSellerRoutes = true});

  final bool includeSellerRoutes;

  static const List<String> _defaultKeywords = [
    'ibul',
    'online alışveriş',
    'e-ticaret',
    'hızlı teslimat',
    'ihız',
    'satıcı paneli',
  ];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _apply(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _apply(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _apply(previousRoute);
  }

  void _apply(Route<dynamic>? route) {
    final config = _seoForRoute(route?.settings.name);
    setSeoMeta(
      title: config.title,
      description: config.description,
      keywords: _defaultKeywords,
      canonicalPath: config.path,
    );
  }

  _SeoRouteConfig _seoForRoute(String? routeName) {
    final path = (routeName ?? '').split('?').first;
    if (path.startsWith('/urun/')) {
      return _SeoRouteConfig(
        title: 'Ürün | İBUL',
        description: 'İBUL ürün detayı.',
        path: path,
      );
    }
    if (path.startsWith('/arac/')) {
      return _SeoRouteConfig(
        title: 'Araç | İBUL',
        description: 'İBUL araç ilanı.',
        path: path,
      );
    }
    if (path.startsWith('/magaza/')) {
      return _SeoRouteConfig(
        title: 'Mağaza | İBUL',
        description: 'İBUL mağaza sayfası.',
        path: path,
      );
    }
    if (path == '/hesabim' || path.startsWith('/hesabim/')) {
      return _SeoRouteConfig(
        title: path.contains('kiralama')
            ? 'Kiralamalarım | İBUL'
            : path.contains('siparis')
            ? 'Siparişlerim | İBUL'
            : 'Hesabım | İBUL',
        description: 'İBUL hesap yönetimi.',
        path: path,
      );
    }
    if (path.startsWith('/ihiz/track/')) {
      return const _SeoRouteConfig(
        title: 'İHIZ Teslimat Takibi',
        description: 'Teslimat kodunuzla İHIZ gönderinizi takip edin.',
        path: '/ihiz',
      );
    }
    switch (routeName) {
      case '/map':
        return const _SeoRouteConfig(
          title: 'İbul Harita | Yakındaki Mağazalar',
          description:
              'İbul harita sayfasında yakındaki mağazaları keşfedin, mağaza konumlarını ve detaylarını inceleyin.',
          path: '/map',
        );
      case '/become-seller':
        return const _SeoRouteConfig(
          title: 'İbul Satıcı Başvurusu',
          description:
              'İbul satıcı başvuru formunu doldurarak mağazanızı platforma taşıyın.',
          path: '/become-seller',
        );
      case '/yatirimci':
        return const _SeoRouteConfig(
          title: 'İBUL Yatırımcı İlişkileri | Yerel Ticaretin Dijital Altyapısı',
          description:
              'İBUL’un ürün ekosistemini, gelir modellerini, büyüme stratejisini, İHIZ teslimat altyapısını ve uzun vadeli vizyonunu keşfedin.',
          path: '/yatirimci',
        );
      case '/ihiz':
        if (!includeSellerRoutes) break;
        return const _SeoRouteConfig(
          title: 'İHIZ | Hızlı Teslimat Platformu',
          description:
              'Mağazalardan müşterilere hızlı, güvenli ve takip edilebilir teslimat.',
          path: '/ihiz',
        );
      case '/admin':
        if (!includeSellerRoutes) break;
        return const _SeoRouteConfig(
          title: 'İbul Admin Paneli',
          description:
              'İbul yönetim paneli üzerinden operasyon, mağaza ve sistem yönetimini takip edin.',
          path: '/admin',
        );
      case '/seller':
        if (!includeSellerRoutes) break;
        return const _SeoRouteConfig(
          title: 'İbul Satıcı Paneli | Mağaza Yönetimi',
          description:
              'Satıcı paneli üzerinden mağazanızı, ürünlerinizi, siparişlerinizi ve kampanyalarınızı yönetin.',
          path: '/seller',
        );
      case '/':
      default:
        return const _SeoRouteConfig(
          title: 'İbul | Online Alışveriş ve Hızlı Teslimat',
          description:
              'İbul ile teknoloji, market ve daha birçok kategoride online alışveriş yapın; hızlı teslimat avantajını yakalayın.',
          path: '/',
        );
    }
    return const _SeoRouteConfig(
      title: 'İbul | Online Alışveriş ve Hızlı Teslimat',
      description:
          'İbul ile teknoloji, market ve daha birçok kategoride online alışveriş yapın; hızlı teslimat avantajını yakalayın.',
      path: '/',
    );
  }
}

class _SeoRouteConfig {
  const _SeoRouteConfig({
    required this.title,
    required this.description,
    required this.path,
  });

  final String title;
  final String description;
  final String path;
}
