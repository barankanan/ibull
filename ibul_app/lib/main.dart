import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app/app_bootstrap.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/review_state.dart';
import 'core/route_observer.dart';
import 'core/web_seo.dart';
import 'screens/map_page.dart';
import 'screens/ihiz_courier_page.dart' deferred as ihiz_courier;
import 'screens/seller/admin_panel_page.dart' deferred as admin_panel;
import 'screens/seller_panel_page.dart';
import 'screens/become_seller_page.dart' deferred as become_seller;
import 'firebase_options.dart';
import 'services/push_notification_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final SeoRouteObserver seoRouteObserver = SeoRouteObserver();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppDiagnostics(
    startupMessage: !kIsWeb
        ? 'Starting IBUL App on Native Platform'
        : 'Starting IBUL App on Web',
    includeErrorStackTrace: true,
  );

  try {
    debugPrint('Bootstrap stage: initializeDateFormatting');
    Intl.defaultLocale = 'tr_TR';
    await initializeDateFormatting('tr_TR');

    debugPrint('Bootstrap stage: initializeAppSupabase');
    await initializeAppSupabase();

    // ReviewState singleton initializes itself in its constructor (_internal calls
    // initialize() which is memoized). Awaiting it here only delays runApp by the
    // SharedPreferences read time (~5-50 ms) without any benefit — the data is
    // only needed after products load (~1-2 s later). Let it run in the background.
    ReviewState().initialize(); // fire-and-forget; memoized, safe to call again

    if (!kIsWeb) {
      debugPrint('Bootstrap stage: Firebase.initializeApp');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    // Render hatalarını ekranda göster
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Bir hata oluştu:',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      );
    };

    debugPrint('Bootstrap stage: runApp');
    runApp(MultiProvider(providers: buildAppProviders(), child: const MyApp()));

    if (!kIsWeb) {
      try {
        await PushNotificationService.instance.initialize(
          navigatorKey: appNavigatorKey,
        );
      } catch (error, stackTrace) {
        debugPrint('PushNotificationService initialize failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  } catch (error, stackTrace) {
    debugPrint('Fatal startup error in ibul_app main(): $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check connectivity and show snackbar/banner if offline
    // We can use a Builder or a wrapping widget for this.
    // Since MaterialApp builds the Navigator, we should place the listener inside it or use a global key.
    // A simple way is to use a builder in MaterialApp.

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'IBUL App',
      navigatorObservers: [routeObserver, seoRouteObserver],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr'), Locale('en')],
      theme: buildAppTheme(),
      home: const OfflineWrapper(child: HomeWrapper()),
      routes: {
        '/map': (context) {
          final args = parseMapRouteArguments(
            ModalRoute.of(context)?.settings.arguments,
          );
          return MapPage(
            targetStoreName: args.targetStoreName,
            initialStoreProductQuery: args.initialStoreProductQuery,
          );
        },
        '/ihiz': (context) => DeferredScreen(
          loadLibrary: ihiz_courier.loadLibrary,
          builder: () => ihiz_courier.IhizCourierPage(),
        ),
        '/admin': (context) => DeferredScreen(
          loadLibrary: admin_panel.loadLibrary,
          builder: () => admin_panel.AdminPanelPage(),
        ),
        '/seller': (context) => const SellerPanelPage(),
        '/become-seller': (context) => DeferredScreen(
          loadLibrary: become_seller.loadLibrary,
          builder: () => become_seller.BecomeSellerPage(),
        ),
      },
      onGenerateRoute: (RouteSettings settings) {
        final rawName = settings.name ?? '/';
        final parsed = Uri.tryParse(rawName);
        final normalizedPath = () {
          if (parsed == null) return rawName.split('?').first;
          final path = parsed.path;
          if (path.isNotEmpty) return path;
          return rawName.split('?').first;
        }();

        switch (normalizedPath) {
          case '/map':
            final args = parseMapRouteArguments(settings.arguments);
            return MaterialPageRoute(
              builder: (_) => MapPage(
                targetStoreName: args.targetStoreName,
                initialStoreProductQuery: args.initialStoreProductQuery,
              ),
            );
          case '/ihiz':
            return MaterialPageRoute(
              builder: (_) => DeferredScreen(
                loadLibrary: ihiz_courier.loadLibrary,
                builder: () => ihiz_courier.IhizCourierPage(),
              ),
            );
          case '/admin':
            return MaterialPageRoute(
              builder: (_) => DeferredScreen(
                loadLibrary: admin_panel.loadLibrary,
                builder: () => admin_panel.AdminPanelPage(),
              ),
            );
          case '/seller':
            return MaterialPageRoute(builder: (_) => const SellerPanelPage());
          case '/become-seller':
            return MaterialPageRoute(
              builder: (_) => DeferredScreen(
                loadLibrary: become_seller.loadLibrary,
                builder: () => become_seller.BecomeSellerPage(),
              ),
            );
          case '/':
            return MaterialPageRoute(
              builder: (_) => const OfflineWrapper(child: HomeWrapper()),
            );
          default:
            return null;
        }
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (_) => const OfflineWrapper(child: HomeWrapper()),
        );
      },
      builder: (context, child) {
        return OfflineListener(child: child ?? const SizedBox());
      },
    );
  }
}

class OfflineListener extends StatelessWidget {
  final Widget child;
  const OfflineListener({super.key, required this.child});

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

class DeferredScreen extends StatefulWidget {
  final Future<void> Function() loadLibrary;
  final Widget Function() builder;

  const DeferredScreen({
    super.key,
    required this.loadLibrary,
    required this.builder,
  });

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late final Future<void> _loadFuture = widget.loadLibrary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Sayfa yüklenemedi. Lütfen tekrar deneyin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return widget.builder();
      },
    );
  }
}

class SeoRouteObserver extends NavigatorObserver {
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
    switch (routeName) {
      case '/map':
        return const _SeoRouteConfig(
          title: 'İbul Harita | Yakındaki Mağazalar',
          description:
              'İbul harita sayfasında yakındaki mağazaları keşfedin, mağaza konumlarını ve detaylarını inceleyin.',
          path: '/map',
        );
      case '/ihiz':
        return const _SeoRouteConfig(
          title: 'İHız Kurye | Hızlı Kurye Teslimatı',
          description:
              'İHız ile bölgesel kurye hizmetlerini ve hızlı teslimat seçeneklerini görüntüleyin.',
          path: '/ihiz',
        );
      case '/admin':
        return const _SeoRouteConfig(
          title: 'İbul Admin Paneli',
          description:
              'İbul yönetim paneli üzerinden operasyon, mağaza ve sistem yönetimini takip edin.',
          path: '/admin',
        );
      case '/seller':
        return const _SeoRouteConfig(
          title: 'İbul Satıcı Paneli | Mağaza Yönetimi',
          description:
              'Satıcı paneli üzerinden mağazanızı, ürünlerinizi, siparişlerinizi ve kampanyalarınızı yönetin.',
          path: '/seller',
        );
      case '/become-seller':
        return const _SeoRouteConfig(
          title: 'İbul Satıcı Başvurusu',
          description:
              'İbul satıcı başvuru formunu doldurarak mağazanızı platforma taşıyın.',
          path: '/become-seller',
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

class OfflineWrapper extends StatelessWidget {
  final Widget child;
  const OfflineWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // This wrapper can be used to block access entirely if needed,
    // but the banner approach in builder is less intrusive.
    return child;
  }
}
