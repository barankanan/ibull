import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/qr_initial_params.dart';
import '../core/route_observer.dart';
import '../screens/become_seller_page.dart' deferred as become_seller;
import '../widgets/deferred_module_screen.dart';
import 'app_bootstrap.dart';
import 'app_navigator.dart';
import 'customer_routes.dart';
import 'shared_app_widgets.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';

final SeoRouteObserver customerSeoRouteObserver =
    SeoRouteObserver(includeSellerRoutes: false);

/// Lightweight customer MaterialApp — home, map, QR, become-seller only.
class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final launchQrHome =
        kIsWeb &&
        QrInitialParams.isQrPath &&
        !QrInitialParams.wasResetAfterQrExit;

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'IBUL App',
      navigatorObservers: [routeObserver, customerSeoRouteObserver],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr'), Locale('en')],
      theme: buildAppTheme(),
      home: launchQrHome
          ? buildQrEntry(source: 'MaterialApp.home')
          : buildSafeHome(source: 'MaterialApp.home'),
      routes: {
        '/home': (context) => buildSafeHome(
          source: 'routes:/home',
          arguments: ModalRoute.of(context)?.settings.arguments,
        ),
        '/qr': (context) => buildQrEntry(source: 'routes:/qr'),
        '/map': (context) {
          final args = parseMapRouteArguments(
            ModalRoute.of(context)?.settings.arguments,
          );
          return CustomerRoutes.buildMapPage(args: args);
        },
        '/become-seller': (context) => DeferredModuleScreen(
          moduleName: 'become_seller_page',
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
        debugPrint(
          '[Routing] route redirect source=$rawName '
          'normalizedPath=$normalizedPath ${QrInitialParams.debugState}',
        );

        switch (normalizedPath) {
          case '/home':
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => buildSafeHome(
                source: 'onGenerateRoute:/home',
                arguments: settings.arguments,
              ),
            );
          case '/qr':
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => buildQrEntry(source: 'onGenerateRoute:/qr'),
            );
          case '/map':
            final args = parseMapRouteArguments(settings.arguments);
            return MaterialPageRoute(
              builder: (_) => CustomerRoutes.buildMapPage(args: args),
            );
          case '/become-seller':
            return MaterialPageRoute(
              builder: (_) => DeferredModuleScreen(
                moduleName: 'become_seller_page',
                loadLibrary: become_seller.loadLibrary,
                builder: () => become_seller.BecomeSellerPage(),
              ),
            );
          case '/':
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => buildSafeHome(source: 'onGenerateRoute:/'),
            );
          default:
            return null;
        }
      },
      onUnknownRoute: (settings) {
        debugPrint(
          '[Routing] route redirect source=${settings.name ?? 'unknown'} '
          'normalizedPath=unknown fallback=/home ${QrInitialParams.debugState}',
        );
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => buildSafeHome(source: 'onUnknownRoute'),
        );
      },
      builder: (context, child) {
        return OfflineListener(child: child ?? const SizedBox());
      },
    );
  }
}
