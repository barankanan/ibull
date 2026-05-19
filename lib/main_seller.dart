// İbul Satıcı — Desktop seller panel entry point.
//
// Run with:
//   ./scripts/run_seller_desktop.sh
// or manually:
//   flutter run -d macos --target lib/main_seller.dart \
//     --dart-define=IBUL_SUPABASE_URL=... \
//     --dart-define=IBUL_SUPABASE_ANON_KEY=...
//
// This entry point is intentionally lean:
// • No Firebase / push notifications (Phase 2)
// • No QR fast-path (web-only feature)
// • No deferred loading (not needed on native/desktop)
// • Session restore: if a valid seller session exists the panel opens immediately
// • Logout navigates back to the login screen
// • Missing config shows a clear error screen before any network call
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ibul_app/app/app_bootstrap.dart';
import 'package:ibul_app/core/config/runtime_config.dart';
import 'package:ibul_app/l10n/arb/app_localizations.dart';
import 'package:ibul_app/screens/seller/desktop_printer_setup_page.dart';
import 'package:ibul_app/screens/seller_login_page.dart';
import 'package:ibul_app/screens/seller_panel_page.dart';
import 'package:ibul_app/services/auth_service.dart';
import 'package:ibul_app/services/bridge_manager.dart';
import 'package:ibul_app/services/desktop_print_hub.dart';
import 'package:ibul_app/utils/desktop_printer_status_policy.dart';
import 'package:ibul_app/widgets/desktop_print_status_bar.dart';

final GlobalKey<NavigatorState> sellerNavigatorKey =
    GlobalKey<NavigatorState>();

// ─────────────────────────────────────────────────────────────────────────────
// Config validation — checked once at boot, before any network call.
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a human-readable description of any missing required config keys,
/// or `null` if everything looks good.
String? _validateConfig() {
  final missing = <String>[];
  if (AppRuntimeConfig.rawSupabaseUrl.trim().isEmpty) {
    missing.add('IBUL_SUPABASE_URL');
  }
  if (AppRuntimeConfig.rawSupabaseAnonKey.trim().isEmpty) {
    missing.add('IBUL_SUPABASE_ANON_KEY');
  }
  if (missing.isEmpty) return null;
  return missing.join(', ');
}

String _resolveDesktopRestaurantId(LoginRouteResolution resolution) {
  final candidates = <String?>[
    resolution.storeProfile?['seller_id']?.toString(),
    resolution.storeProfile?['store_id']?.toString(),
    resolution.storeProfile?['restaurant_id']?.toString(),
    resolution.profile?['seller_id']?.toString(),
    resolution.profile?['store_id']?.toString(),
    resolution.profile?['restaurant_id']?.toString(),
    resolution.profile?['assigned_seller_id']?.toString(),
    resolution.profile?['parent_seller_id']?.toString(),
    resolution.userId,
  ];
  for (final candidate in candidates) {
    final trimmed = candidate?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

void main() async {
  final sw = Stopwatch()..start();
  WidgetsFlutterBinding.ensureInitialized();

  configureAppDiagnostics(
    startupMessage: 'İbul Satıcı — desktop startup',
    includeErrorStackTrace: true,
  );

  // ── 1. Config check — fail fast with a clear UI if secrets are missing ──
  final missingConfig = _validateConfig();
  if (missingConfig != null) {
    debugPrint('[Config] HATA: Eksik dart-define değerleri: $missingConfig');
    debugPrint(
      '[Config] .env dosyasını oluşturun ve run_seller_desktop.sh ile başlatın.',
    );
    runApp(_ConfigErrorApp(missingKeys: missingConfig));
    return;
  }

  // ── 2. Normal boot ───────────────────────────────────────────────────────
  Intl.defaultLocale = 'tr_TR';
  await initializeDateFormatting('tr_TR');
  debugPrint('[Boot] ${sw.elapsedMilliseconds}ms — locale ready');

  try {
    await initializeAppSupabase();
    debugPrint('[Boot] ${sw.elapsedMilliseconds}ms — Supabase ready');
  } catch (e, st) {
    debugPrint('[Boot] Supabase başlatma hatası: $e');
    debugPrintStack(stackTrace: st);
    runApp(_ConfigErrorApp(missingKeys: null, bootError: e.toString()));
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ...buildAppProviders(),
        ChangeNotifierProvider<DesktopPrintHub>(
          create: (_) => DesktopPrintHub(),
        ),
      ],
      child: const SellerDesktopApp(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// App shell
// ─────────────────────────────────────────────────────────────────────────────

class SellerDesktopApp extends StatelessWidget {
  const SellerDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: sellerNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'İbul Satıcı',
      theme: buildAppTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr'), Locale('en')],
      // ── Home: session restore gate ──────────────────────────────────────
      home: const _SellerSessionGate(),
      // ── Named routes ────────────────────────────────────────────────────
      routes: {
        '/seller-login': (ctx) => const SellerLoginPage(),
        '/seller': (ctx) => _DesktopSellerRouteShell(
          entryRole: parseSellerPanelEntryRole(
            ModalRoute.of(ctx)?.settings.arguments,
          ),
        ),
        '/printer-setup': (ctx) => const DesktopPrinterSetupPage(),
      },
      // ── Print status bar overlay (bottom-right, desktop only) ───────────
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            const Positioned(
              right: 12,
              bottom: 12,
              child: DesktopPrintStatusBar(),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session gate — checks existing Supabase session; shows loading then routes.
// ─────────────────────────────────────────────────────────────────────────────

class _SellerSessionGate extends StatefulWidget {
  const _SellerSessionGate();

  @override
  State<_SellerSessionGate> createState() => _SellerSessionGateState();
}

class _SellerSessionGateState extends State<_SellerSessionGate> {
  /// `null`  = still checking
  /// `true`  = valid seller session found → will push /seller
  /// `false` = no session → show login page
  bool? _hasSession;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (mounted) {
        Provider.of<DesktopPrintHub>(context, listen: false).stop();
        setState(() => _hasSession = false);
      }
      return;
    }

    try {
      final resolution = await AuthService().resolveLoginRoute(
        diagnosticContext: 'desktop_session_restore',
        includeStoreProfile: true,
      );

      if (!mounted) return;

      if (resolution.resolvedRole == LoginResolvedRole.seller &&
          resolution.isSellerApproved) {
        setState(() => _hasSession = true);
        sellerNavigatorKey.currentState?.pushReplacementNamed('/seller');
        return;
      }

      if (resolution.resolvedRole == LoginResolvedRole.waiter) {
        setState(() => _hasSession = true);
        sellerNavigatorKey.currentState?.pushReplacementNamed(
          '/seller',
          arguments: SellerPanelEntryRole.waiter,
        );
        return;
      }
    } catch (e) {
      debugPrint('[SessionGate] restore error: $e');
    }

    if (mounted) {
      Provider.of<DesktopPrintHub>(context, listen: false).stop();
      setState(() => _hasSession = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Still checking — show a neutral loading screen.
    if (_hasSession == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
              SizedBox(height: 16),
              Text(
                'İbul Satıcı',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // No valid session → show login.
    return const SellerLoginPage();
  }
}

class _DesktopSellerRouteShell extends StatefulWidget {
  const _DesktopSellerRouteShell({required this.entryRole});

  final SellerPanelEntryRole entryRole;

  @override
  State<_DesktopSellerRouteShell> createState() =>
      _DesktopSellerRouteShellState();
}

class _DesktopSellerRouteShellState extends State<_DesktopSellerRouteShell> {
  bool _bootstrapped = false;
  String? _bootError;

  bool _isBridgeReady(DesktopPrintHub hub) =>
      isDesktopPrinterBridgeReady(hub.bridgeStatus);

  void _syncBootErrorWithHub(DesktopPrintHub hub) {
    if (_isBridgeReady(hub)) {
      if (_bootError != null) {
        setState(() => _bootError = null);
      }
      return;
    }
    if (!_bootstrapped || _bootError != null) return;
    setState(() {
      _bootError = switch (hub.bridgeStatus) {
        BridgeStatus.offline =>
          'Yazıcı bağlantısı kurulamadı. Yazıcı ayarlarından servisi başlatın veya onarın.',
        BridgeStatus.error => 'Yazıcı servisinde hata oluştu.',
        _ => 'Yazıcı servisi hazırlanıyor...',
      };
    });
  }

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapDesktopPrinting());
  }

  Future<void> _bootstrapDesktopPrinting() async {
    try {
      final resolution = await AuthService().resolveLoginRoute(
        diagnosticContext: 'desktop_route_bootstrap',
        includeStoreProfile: true,
      );
      if (!mounted) return;
      final restaurantId = _resolveDesktopRestaurantId(resolution);
      final hub = Provider.of<DesktopPrintHub>(context, listen: false);
      final bridge = await BridgeManager.ensureReady();
      if (!mounted) return;
      if (restaurantId.isNotEmpty) {
        await hub.start(restaurantId);
      } else {
        await hub.checkBridge();
      }
      if (!mounted) return;
      setState(() {
        _bootstrapped = true;
        if (!bridge.ok && !_isBridgeReady(hub)) {
          _bootError = kDebugMode
              ? bridge.message
              : 'Yazıcı bağlantısı kurulamadı. Yazıcı ayarlarından servisi başlatın veya onarın.';
        } else {
          _bootError = null;
        }
      });
    } catch (error, stackTrace) {
      debugPrint('[DesktopSeller] bootstrap failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      final hub = Provider.of<DesktopPrintHub>(context, listen: false);
      setState(() {
        _bootstrapped = true;
        _bootError = _isBridgeReady(hub)
            ? null
            : (kDebugMode
                  ? error.toString()
                  : 'Yazıcı servisi hazırlanırken bir sorun oluştu.');
      });
    }
  }

  @override
  void dispose() {
    Provider.of<DesktopPrintHub>(context, listen: false).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final panel = SellerPanelPage(entryRole: widget.entryRole);
    return Consumer<DesktopPrintHub>(
      builder: (context, hub, _) {
        if (_bootstrapped) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _syncBootErrorWithHub(hub);
          });
        }
        final showBootBanner = shouldShowDesktopPrinterBootBanner(
          bridgeStatus: hub.bridgeStatus,
          bootstrapped: _bootstrapped,
          bootError: _bootError,
        );
        if (!showBootBanner) return panel;
        return Stack(
          fit: StackFit.expand,
          children: [
            panel,
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 340),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.print_disabled_outlined,
                        size: 18,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _bootstrapped
                              ? 'Yazıcı servisi hazır değil: ${_bootError ?? hub.bridgeStatus.name}'
                              : 'Yazıcı servisi hazırlanıyor...',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Config error screen — shown before any Supabase call when dart-defines are
// missing.  Displayed instead of letting the app crash with a cryptic error.
// ─────────────────────────────────────────────────────────────────────────────

class _ConfigErrorApp extends StatelessWidget {
  const _ConfigErrorApp({this.missingKeys, this.bootError});

  /// Comma-separated list of missing env key names, or null if the error is
  /// something other than missing keys (see [bootError]).
  final String? missingKeys;

  /// Set when Supabase initialisation itself threw (i.e., keys were present but
  /// invalid).
  final String? bootError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'İbul Satıcı — Kurulum Gerekli',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF8B5CF6)),
      home: _ConfigErrorScreen(missingKeys: missingKeys, bootError: bootError),
    );
  }
}

class _ConfigErrorScreen extends StatelessWidget {
  const _ConfigErrorScreen({this.missingKeys, this.bootError});

  final String? missingKeys;
  final String? bootError;

  @override
  Widget build(BuildContext context) {
    final title = missingKeys != null
        ? 'Yapılandırma Eksik'
        : 'Başlatma Hatası';

    final body = missingKeys != null
        ? 'Aşağıdaki dart-define değerleri ayarlanmamış:\n\n'
              '  $missingKeys\n\n'
              'Çözüm:\n'
              '  1. Proje kök dizininde .env dosyası oluşturun:\n'
              '       cp .env.example .env\n'
              '  2. .env içine gerçek Supabase URL ve Anon Key değerlerini girin.\n'
              '  3. Uygulamayı run_seller_desktop.sh ile başlatın:\n'
              '       ./scripts/run_seller_desktop.sh'
        : 'Supabase başlatılırken hata oluştu:\n\n$bootError\n\n'
              '.env dosyasındaki IBUL_SUPABASE_URL ve IBUL_SUPABASE_ANON_KEY\n'
              'değerlerinin doğru olduğunu kontrol edin.';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFF8B5CF6),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4C1D95),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SelectableText(
                    body,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      fontFamily: 'monospace',
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'İbul Satıcı — Masaüstü',
                    style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
