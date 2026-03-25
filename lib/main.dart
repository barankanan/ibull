import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ibul_app/app/app_bootstrap.dart';
import 'package:ibul_app/screens/ihiz_courier_page.dart';
import 'package:ibul_app/screens/map_page.dart';
import 'package:ibul_app/screens/seller/admin_panel_page.dart';
import 'package:ibul_app/screens/seller_panel_page.dart';
import 'package:ibul_app/screens/become_seller_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureAppDiagnostics(
    startupMessage: 'Starting IBUL App. Platform: ${kIsWeb ? "web" : "native"}',
    includeErrorStackTrace: true,
  );

  try {
    debugPrint('Bootstrap stage: initializeAppSupabase');
    await initializeAppSupabase();
    debugPrint('Bootstrap stage: runApp');

    runApp(MultiProvider(providers: buildAppProviders(), child: const MyApp()));
  } catch (error, stackTrace) {
    debugPrint('Fatal startup error in root main(): $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IBUL App',
      theme: buildAppTheme(),
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/map':
            final args = parseMapRouteArguments(settings.arguments);
            return MaterialPageRoute(
              builder: (_) => MapPage(
                targetStoreName: args.targetStoreName,
                initialStoreProductQuery: args.initialStoreProductQuery,
              ),
            );
          case '/seller':
            return MaterialPageRoute(builder: (_) => const SellerPanelPage());
          case '/admin':
            return MaterialPageRoute(builder: (_) => const AdminPanelPage());
          case '/become-seller':
            return MaterialPageRoute(builder: (_) => const BecomeSellerPage());
          case '/ihiz':
            return MaterialPageRoute(builder: (_) => const IhizCourierPage());
          case '/':
            return MaterialPageRoute(builder: (_) => const HomeWrapper());
          default:
            return null;
        }
      },
      routes: {
        '/ihiz': (context) => const IhizCourierPage(),
        '/map': (context) => const MapPage(),
        '/seller': (context) => const SellerPanelPage(),
        '/admin': (context) => const AdminPanelPage(),
        '/become-seller': (context) => const BecomeSellerPage(),
      },
      // Wrap HomeScreen so we can detect hot reload and show status
      home: const HomeWrapper(),
    );
  }
}
