import 'dart:async';

/// Completer resolved once Supabase + core locale services finish initializing.
///
/// On the QR web fast-path [runApp] is called BEFORE services are ready so
/// that the QR loading screen becomes visible immediately. [QrEntryScreen]
/// awaits [appServicesReady] before making any Supabase API calls, guaranteeing
/// Supabase.instance is available by the time any RPC is triggered.
///
/// On native and the normal web path the completer is resolved synchronously
/// inside [main] before [runApp] is called, so the await is a no-op.
final Completer<void> appServicesReadyCompleter = Completer<void>();

/// Future that resolves once Supabase and core services are initialized.
Future<void> get appServicesReady => appServicesReadyCompleter.future;
