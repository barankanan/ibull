import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';

import 'app_bootstrap.dart';
import 'ibul_go_router.dart';

/// Shared [MaterialApp.router] chrome for CustomerApp, FullApp, and root MyApp.
class IbulMaterialApp extends StatefulWidget {
  const IbulMaterialApp({
    super.key,
    required this.navigatorKey,
    required this.includeAuthRoutes,
    this.navigatorObservers = const <NavigatorObserver>[],
    this.builder,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final bool includeAuthRoutes;
  final List<NavigatorObserver> navigatorObservers;
  final TransitionBuilder? builder;

  @override
  State<IbulMaterialApp> createState() => _IbulMaterialAppState();
}

class _IbulMaterialAppState extends State<IbulMaterialApp> {
  late final GoRouter _router = createIbulGoRouter(
    navigatorKey: widget.navigatorKey,
    includeAuthRoutes: widget.includeAuthRoutes,
    observers: widget.navigatorObservers,
  );

  @override
  void dispose() {
    if (IbulGoRouterBinding.instance == _router) {
      IbulGoRouterBinding.instance = null;
    }
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'IBUL App',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: kIbulLocale,
      supportedLocales: kIbulSupportedLocales,
      theme: buildAppTheme(),
      routerConfig: _router,
      builder: widget.builder,
    );
  }
}
