import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/qr_initial_params.dart';
import '../core/route_observer.dart';
import 'app_bootstrap.dart';
import 'app_navigator.dart';
import 'seller_routes.dart';
import 'shared_app_widgets.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';

final SeoRouteObserver fullSeoRouteObserver = SeoRouteObserver();

/// Full IBUL app — customer routes plus deferred seller/admin/courier modules.
class FullApp extends StatelessWidget {
  const FullApp({super.key});

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
      navigatorObservers: [routeObserver, fullSeoRouteObserver],
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
          return SellerRoutes.buildMapPage(args: args);
        },
        '/ihiz': (context) => SellerRoutes.buildIhizCourier(),
        '/admin': (context) => SellerRoutes.buildAdminPanel(),
        '/seller': (context) => SellerRoutes.buildSellerPanel(
          source: 'routes:/seller',
          arguments: ModalRoute.of(context)?.settings.arguments,
        ),
        '/become-seller': (context) => SellerRoutes.buildBecomeSeller(),
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
              builder: (_) => SellerRoutes.buildMapPage(args: args),
            );
          case '/ihiz':
            return MaterialPageRoute(
              builder: (_) => SellerRoutes.buildIhizCourier(),
            );
          case '/admin':
            return MaterialPageRoute(
              builder: (_) => SellerRoutes.buildAdminPanel(),
            );
          case '/seller':
            return MaterialPageRoute(
              builder: (_) => SellerRoutes.buildSellerPanel(
                source: 'onGenerateRoute:/seller',
                arguments: settings.arguments,
              ),
            );
          case '/become-seller':
            return MaterialPageRoute(
              builder: (_) => SellerRoutes.buildBecomeSeller(),
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
