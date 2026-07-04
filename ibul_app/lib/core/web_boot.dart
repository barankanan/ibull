import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/ibul_app_mode.dart';
import 'web_page_reload.dart';

/// Web boot tracing. Uses [print] on web so release Chrome console shows logs.
class WebBootLogger {
  WebBootLogger._();

  static void log(String stage, {String? detail}) {
    final suffix = detail == null || detail.isEmpty ? '' : ' $detail';
    final message = '[WebBoot][$stage]$suffix';
    if (kIsWeb) {
      // ignore: avoid_print
      print(message);
      return;
    }
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static void supabaseConfig({required bool hasUrl, required bool hasAnonKey}) {
    log(
      'supabase_config',
      detail: 'hasUrl=$hasUrl hasAnonKey=$hasAnonKey',
    );
  }
}

/// Shown when fatal boot errors prevent the normal app shell from starting.
class WebBootFatalScreen extends StatelessWidget {
  const WebBootFatalScreen({
    super.key,
    required this.message,
    this.technicalDetail,
    this.stage,
    this.entrypoint,
    this.stackSummary,
    this.missingDefine,
  });

  final String message;
  final String? technicalDetail;
  final String? stage;
  final String? entrypoint;
  final String? stackSummary;
  final String? missingDefine;

  @override
  Widget build(BuildContext context) {
    final showDevDetails = kDebugMode || kProfileMode;
    final devLines = <String>[
      if (stage != null && stage!.isNotEmpty) 'stage: $stage',
      if (entrypoint != null && entrypoint!.isNotEmpty)
        'entrypoint: $entrypoint',
      if (missingDefine != null && missingDefine!.isNotEmpty)
        'missing dart-define: $missingDefine',
      if (technicalDetail != null && technicalDetail!.trim().isNotEmpty)
        'error: $technicalDetail',
      if (stackSummary != null && stackSummary!.trim().isNotEmpty)
        'stack: $stackSummary',
    ];

    if (showDevDetails && devLines.isNotEmpty) {
      // ignore: avoid_print
      print('[WebBootFatal] ${devLines.join(' | ')}');
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFF7B2FBE),
                    size: 56,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Uygulama başlatılamadı',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  if (showDevDetails && devLines.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      devLines.join('\n'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: reloadWebPage,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7B2FBE),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Sayfayı Yenile'),
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

String webBootUserMessage(Object error) {
  final text = error.toString();
  if (text.contains('IBUL_SUPABASE_URL') ||
      text.contains('IBUL_SUPABASE_ANON_KEY') ||
      text.contains('dart-define')) {
    return 'Sunucu yapılandırması eksik. Lütfen sayfayı yenileyin veya destek ile iletişime geçin.';
  }
  return 'Bir yükleme hatası oluştu. Sayfayı yenileyin veya destek ile iletişime geçin.';
}

String? webBootMissingDefine(Object error) {
  final text = error.toString();
  if (text.contains('IBUL_SUPABASE_URL')) return 'IBUL_SUPABASE_URL';
  if (text.contains('IBUL_SUPABASE_ANON_KEY')) return 'IBUL_SUPABASE_ANON_KEY';
  if (text.contains('IBUL_GOOGLE_CLIENT_ID')) return 'IBUL_GOOGLE_CLIENT_ID';
  return null;
}

WebBootFatalScreen buildWebBootFatalScreen(
  Object error, {
  StackTrace? stackTrace,
  String stage = 'fatal_error',
}) {
  final stack = stackTrace?.toString() ?? '';
  final stackSummary = stack.isEmpty
      ? null
      : stack.split('\n').take(4).join('\n');
  return WebBootFatalScreen(
    message: webBootUserMessage(error),
    technicalDetail: error.toString(),
    stage: stage,
    entrypoint: ibulEntrypointLabel(IbulAppModeRegistry.current),
    stackSummary: stackSummary,
    missingDefine: webBootMissingDefine(error),
  );
}
