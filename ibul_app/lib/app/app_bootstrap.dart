import 'dart:ui' show PlatformDispatcher;

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
import '../core/providers/cart_provider.dart';
import '../core/providers/connectivity_provider.dart';
import '../core/review_state.dart';
import '../screens/home_screen.dart';

Future<void> initializeAppSupabase() async {
  final rawUrl = AppRuntimeConfig.rawSupabaseUrl.trim();
  final rawAnonKey = AppRuntimeConfig.rawSupabaseAnonKey.trim();

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
  } catch (error, stackTrace) {
    debugPrint('Supabase bootstrap failed before runApp: $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
}

void configureAppDiagnostics({
  required String startupMessage,
  bool includeErrorStackTrace = false,
}) {
  debugPrint(startupMessage);

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    debugPrint('Unhandled Flutter error: ${details.exception}');
    if (includeErrorStackTrace && details.stack != null) {
      debugPrintStack(stackTrace: details.stack);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
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

List<SingleChildWidget> buildAppProviders() {
  return [
    ChangeNotifierProvider.value(value: CartState()),
    ChangeNotifierProvider.value(value: FavoriteState()),
    ChangeNotifierProvider.value(value: ReviewState()),
    ChangeNotifierProvider(create: (_) => AppState()),
    ChangeNotifierProvider(create: (_) => CartProvider()),
    ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
  ];
}

/// Minimal provider set for the /qr fast-path.
///
/// Only includes what the QR ordering flow actually requires:
/// - [CartState] and [CartProvider]: cart management during ordering.
/// - [ConnectivityProvider]: offline banner in [OfflineListener].
///
/// [AppState], [FavoriteState], and [ReviewState] are singletons accessed
/// directly by [BusinessDetailPage] — they still work without being in the
/// provider tree. Excluding them from the tree avoids their eager construction
/// cost (auth init, shared-prefs load, Supabase hydration) during QR cold-start.
List<SingleChildWidget> buildQrProviders() {
  return [
    ChangeNotifierProvider.value(value: CartState()),
    ChangeNotifierProvider(create: (_) => CartProvider()),
    ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
  ];
}

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
  );
}

MapRouteArguments parseMapRouteArguments(dynamic args) {
  String? targetStoreName;
  String? initialStoreProductQuery;

  if (args is Map && args['targetStoreName'] != null) {
    targetStoreName = args['targetStoreName'].toString();
  }

  if (args is Map && args['initialStoreProductQuery'] != null) {
    initialStoreProductQuery = args['initialStoreProductQuery'].toString();
  }

  return MapRouteArguments(
    targetStoreName: targetStoreName,
    initialStoreProductQuery: initialStoreProductQuery,
  );
}

class MapRouteArguments {
  const MapRouteArguments({
    this.targetStoreName,
    this.initialStoreProductQuery,
  });

  final String? targetStoreName;
  final String? initialStoreProductQuery;
}

class HomeWrapper extends StatefulWidget {
  const HomeWrapper({super.key});

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
    return const HomeScreen();
  }
}
