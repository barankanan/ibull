import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:ibul_app/app/app_bootstrap.dart';
import 'package:ibul_app/app/ibul_app_boot.dart';
import 'package:ibul_app/app/ibul_boot_controller.dart';
import 'package:ibul_app/app/ibul_boot_shell_app.dart';
import 'package:ibul_app/app/ibul_safe_boot_app.dart';
import 'package:ibul_app/core/config/runtime_config.dart';
import 'package:ibul_app/core/ibul_boot_stage.dart';
import 'package:ibul_app/core/web_boot.dart';
import 'package:ibul_app/core/web_boot_step_profiler.dart';
import 'package:ibul_app/core/route_observer.dart';
import 'package:ibul_app/core/qr_initial_params.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';
import 'package:ibul_app/screens/qr_entry_screen.dart';

// ── Deferred imports — excluded from the main bundle, downloaded on-demand ──
// This reduces the main JS bundle for cold-start users (including /qr).
import 'package:ibul_app/screens/ihiz_courier_page.dart' deferred as ihiz_courier;
import 'package:ibul_app/screens/map_page.dart' deferred as map_page;
import 'package:ibul_app/screens/seller/admin_panel_page.dart' deferred as admin_panel;
import 'package:ibul_app/screens/seller_panel_page.dart';
import 'package:ibul_app/screens/become_seller_page.dart' deferred as become_seller;

/// Root-level navigator key — gives push-notification service and any
/// background code a handle to the root navigator without importing the
/// ibul_app package’s standalone main.dart.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WebBootLogger.log('main', detail: 'entered');
  WebBootStepProfiler.done('widgets_binding');

  if (AppRuntimeConfig.safeBootMode) {
    runIbulSafeBootApp();
    return;
  }

  WebBootLogger.log('safe_boot', detail: 'enabled=false');

  if (kIsWeb) {
    _runWebProgressiveBoot();
    return;
  }

  final bootWatch = Stopwatch()..start();
  await runIbulAppBootstrap(
    bootWatch: bootWatch,
    initServicesBackground: initIbulServicesBackground,
    runAppWidget: () {
      WebBootStepProfiler.start('provider_tree');
      runApp(_buildReadyAppTree());
      WebBootStepProfiler.done('provider_tree');
    },
  );
}

void _runWebProgressiveBoot() {
  QrInitialParams.captureFromUri();
  configureAppDiagnostics(
    startupMessage: 'Starting IBUL App on Web (root entry)',
    includeErrorStackTrace: true,
  );

  final bootWatch = Stopwatch()..start();
  final controller = IbulBootController();

  WebBootStepProfiler.start('runApp_normal_shell');
  runApp(
    IbulProgressiveBootApp(
      controller: controller,
      bootStage: AppRuntimeConfig.bootStage,
      readyBuilder: (_) => _buildReadyAppTree(),
    ),
  );
  WebBootStepProfiler.done('runApp_normal_shell');

  unawaited(controller.initialize(bootWatch: bootWatch));
}

Widget _buildReadyAppTree() {
  WebBootStepProfiler.start('provider_tree');
  final stage = AppRuntimeConfig.bootStage;
  if (stage == IbulBootStage.providers) {
    final tree = MultiProvider(
      providers: buildAppProviders(),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: IbulBootDiagnosticProvidersPage(),
      ),
    );
    WebBootStepProfiler.done('provider_tree', detail: 'diagnostic');
    return tree;
  }

  final tree = MultiProvider(
    providers: buildAppProviders(),
    child: const MyApp(),
  );
  WebBootStepProfiler.done('provider_tree');
  return tree;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'IBUL App',
      theme: buildAppTheme(),
      navigatorObservers: [routeObserver],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr'), Locale('en')],
      // On QR URLs, go directly to QrEntryScreen — no home-screen overhead.
      home: (kIsWeb && QrInitialParams.isQrPath)
          ? const QrEntryScreen()
          : const HomeWrapper(),
      // Use onGenerateRoute only — avoids duplicating route builders.
      onGenerateRoute: (RouteSettings settings) {
        final rawName = settings.name ?? '/';
        final normalizedPath = Uri.tryParse(rawName)?.path.takeIf((p) => p.isNotEmpty) ?? rawName.split('?').first;

        switch (normalizedPath) {
          case '/qr':
            return MaterialPageRoute(builder: (_) => const QrEntryScreen());
          case '/map':
            final args = parseMapRouteArguments(settings.arguments);
            return MaterialPageRoute(
              builder: (_) => _DeferredScreen(
                debugLabel: '/map',
                loadLibrary: map_page.loadLibrary,
                builder: () => map_page.MapPage(
                  targetStoreName: args.targetStoreName,
                  initialStoreProductQuery: args.initialStoreProductQuery,
                ),
              ),
            );
          case '/ihiz':
            return MaterialPageRoute(
              builder: (_) => _DeferredScreen(
                debugLabel: '/ihiz',
                loadLibrary: ihiz_courier.loadLibrary,
                builder: () => ihiz_courier.IhizCourierPage(),
              ),
            );
          case '/admin':
            return MaterialPageRoute(
              builder: (_) => _DeferredScreen(
                debugLabel: '/admin',
                loadLibrary: admin_panel.loadLibrary,
                builder: () => admin_panel.AdminPanelPage(),
              ),
            );
          case '/seller':
            final entryRole = parseSellerPanelEntryRole(settings.arguments);
            debugPrint(
              '[Routing] route=/seller mode=eager entryRole=${entryRole.name}',
            );
            return MaterialPageRoute(
              builder: (_) => SellerPanelPage(entryRole: entryRole),
            );
          case '/become-seller':
            return MaterialPageRoute(
              builder: (_) => _DeferredScreen(
                debugLabel: '/become-seller',
                loadLibrary: become_seller.loadLibrary,
                builder: () => become_seller.BecomeSellerPage(),
              ),
            );
          case '/':
            return MaterialPageRoute(builder: (_) => const HomeWrapper());
          default:
            return null;
        }
      },
      onUnknownRoute: (settings) =>
          MaterialPageRoute(builder: (_) => const HomeWrapper()),
    );
  }
}

/// Shows a loading spinner while a deferred library chunk is downloading,
/// then builds the actual screen once the chunk is available.
class _DeferredScreen extends StatefulWidget {
  final String debugLabel;
  final Future<void> Function() loadLibrary;
  final Widget Function() builder;

  const _DeferredScreen({
    required this.debugLabel,
    required this.loadLibrary,
    required this.builder,
  });

  @override
  State<_DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<_DeferredScreen> {
  bool _didLogErrorScreen = false;
  late final Future<void> _loadFuture = _loadLibraryWithDiagnostics();

  Future<void> _loadLibraryWithDiagnostics() async {
    debugPrint('[DeferredRoute] start route=${widget.debugLabel}');
    try {
      await widget.loadLibrary();
      debugPrint('[DeferredRoute] ready route=${widget.debugLabel}');
    } catch (error, stackTrace) {
      debugPrint(
        '[DeferredRoute] failed route=${widget.debugLabel} error=$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (!_didLogErrorScreen) {
            _didLogErrorScreen = true;
            debugPrint(
              '[DeferredRoute] error_screen route=${widget.debugLabel} '
              'error=${snapshot.error}',
            );
          }
          return const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Sayfa yüklenemedi. Lütfen tekrar deneyin.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return widget.builder();
      },
    );
  }
}

extension _StringTakeIf on String {
  String? takeIf(bool Function(String) predicate) =>
      predicate(this) ? this : null;
}
