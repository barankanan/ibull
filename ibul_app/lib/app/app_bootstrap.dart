import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_state.dart';
import '../core/app_motion.dart';
import '../core/cart_state.dart';
import '../core/config/runtime_config.dart';
import '../core/constants.dart';
import '../core/favorite_state.dart';
import '../core/ibul_app_mode.dart';
import '../core/providers/connectivity_provider.dart';
import '../core/review_state.dart';
import '../core/web_boot_error_store.dart';
import '../core/web_boot.dart';
import '../core/commerce_image_cache.dart';
import '../screens/home_screen_gate.dart';
import 'app_providers.dart';

export 'route_args.dart';

Future<void> initializeAppSupabase() async {
  final rawUrl = AppRuntimeConfig.rawSupabaseUrl.trim();
  final rawAnonKey = AppRuntimeConfig.rawSupabaseAnonKey.trim();

  WebBootLogger.supabaseConfig(
    hasUrl: rawUrl.isNotEmpty,
    hasAnonKey: rawAnonKey.isNotEmpty,
  );
  WebBootLogger.log('auth_init_start');

  debugPrint('IBUL_SUPABASE_URL=${rawUrl.isEmpty ? 'EMPTY' : rawUrl}');
  debugPrint(
    'IBUL_SUPABASE_ANON_KEY=${rawAnonKey.isEmpty ? 'EMPTY' : 'SET(len=${rawAnonKey.length})'}',
  );

  try {
    debugPrint('Supabase bootstrap: validating runtime config.');
    await Supabase.initialize(
      url: AppRuntimeConfig.supabaseUrl,
      anonKey: AppRuntimeConfig.supabaseAnonKey,
    );
    debugPrint('Supabase bootstrap: initialize completed.');
    WebBootLogger.log('auth_init_success');
  } catch (error, stackTrace) {
    WebBootLogger.log('auth_init_error', detail: error.toString());
    debugPrint('Supabase bootstrap failed before runApp: $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
}

void configureAppDiagnostics({
  required String startupMessage,
  bool includeErrorStackTrace = false,
}) {
  CommerceImageCache.configure();
  debugPrint(startupMessage);

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    debugPrint('Unhandled Flutter error: ${details.exception}');
    if (includeErrorStackTrace && details.stack != null) {
      debugPrintStack(stackTrace: details.stack);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    saveWebBootError(
      module: 'platform_dispatcher',
      message: error.toString(),
      detail: stackTrace.toString(),
    );
    debugPrint('Unhandled platform error: $error');
    if (includeErrorStackTrace) {
      debugPrintStack(stackTrace: stackTrace);
    }
    return false;
  };

  assert(() {
    debugPrint(
      'App is running in DEBUG mode. Start with ./scripts/run.sh or flutter run -d <deviceId>, then press "r" (hot reload) or "R" (hot restart) in this terminal.',
    );
    return true;
  }());
}

List<SingleChildWidget> buildAppProviders() =>
    buildProvidersForMode(IbulAppModeRegistry.current);

/// Minimal provider set for the /qr fast-path.
///
/// Only includes what the QR ordering flow actually requires:
/// - [CartState]: cart management during ordering.
/// - [ConnectivityProvider]: offline banner in [OfflineListener].
///
/// [AppState], [FavoriteState], and [ReviewState] are singletons accessed
/// directly by [BusinessDetailPage] — they still work without being in the
/// provider tree. Excluding them from the tree avoids their eager construction
/// cost (auth init, shared-prefs load, Supabase hydration) during QR cold-start.
List<SingleChildWidget> buildQrProviders() {
  return [
    ChangeNotifierProvider.value(value: CartState()),
    ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
  ];
}

const Locale kIbulLocale = Locale('tr');
const List<Locale> kIbulSupportedLocales = <Locale>[kIbulLocale];

ThemeData buildAppTheme() {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
      ).copyWith(
        secondaryContainer: AppColors.softPurple,
        tertiaryContainer: AppColors.softPurple,
        surfaceTint: AppColors.popupLavenderStrong,
      );

  return ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.primary,
    colorScheme: colorScheme,
    pageTransitionsTheme: AppMotion.pageTransitionsTheme(),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: AppColors.popupLavender,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: AppColors.popupLavender,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: AppColors.popupLavender,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    scaffoldBackgroundColor: AppColors.background,
    extensions: const <ThemeExtension<dynamic>>[IbulColorTokens()],
  );
}

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key, this.initialIndex = 0, this.initialCategory});

  final int initialIndex;
  final String? initialCategory;

  @override
  State<HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  @override
  void reassemble() {
    super.reassemble();
    debugPrint(
      'Hot reload / reassemble at ${DateTime.now().toIso8601String()}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreenGate(
      initialIndex: widget.initialIndex,
      initialCategory: widget.initialCategory,
    );
  }
}
