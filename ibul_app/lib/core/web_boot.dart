import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/ibul_app_mode.dart';
import 'config/runtime_config.dart';
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
    this.debugInfoLines,
  });

  final String message;
  final String? technicalDetail;
  final String? stage;
  final String? entrypoint;
  final String? stackSummary;
  final String? missingDefine;

  /// GEÇİCİ teşhis build'i: release'te de gösterilen güvenli debug satırları.
  /// İçerik [AppRuntimeConfig.safeDiagnostics] + maskelenmiş hata metnidir;
  /// anon key değeri asla içermez (sadece uzunluk). Teşhis bitince
  /// [buildWebBootFatalScreen] içindeki üretim kaldırılarak kapatılır.
  final List<String>? debugInfoLines;

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

    // UI tasarımı değişmez (dev detayları ekranda sadece debug/profile'da),
    // ama gerçek sebep release dahil HER modda console'a yazılır ki
    // "Sunucu yapılandırması eksik" görüldüğünde missing=<define> izlenebilsin.
    if (devLines.isNotEmpty) {
      debugPrint('[WebBootFatal] ${devLines.join(' | ')}');
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
                  if (debugInfoLines != null && debugInfoLines!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SelectableText(
                        debugInfoLines!.join('\n'),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                          fontFamily: 'monospace',
                          height: 1.4,
                        ),
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

/// GEÇİCİ teşhis build'i: [AppRuntimeConfig.safeDiagnostics] + maskelenmiş
/// hata bilgisinden küçük, kopyalanabilir bir debug satır listesi üretir.
/// Anon key değeri asla içermez (sadece uzunluk); [AppRuntimeConfig.maskSecrets]
/// hata metnindeki olası JWT/secret kalıntılarını da maskeler.
List<String> _buildSafeDebugInfoLines(Object error) {
  final diag = AppRuntimeConfig.safeDiagnostics();
  final maskedError = AppRuntimeConfig.maskSecrets(error.toString());
  return <String>[
    'DEBUG BUILD:',
    'marker=${diag['buildMarker']}',
    'urlPresent=${diag['supabaseUrlPresent']}',
    'keyPresent=${diag['supabaseAnonKeyPresent']}',
    'source=${diag['configSource']}',
    'host=${diag['supabaseUrlHost']}',
    'keyLength=${diag['anonKeyLength']}',
    'missing=${diag['missingKey']}',
    'firebaseApiKeyPresent=${diag['firebaseAndroidApiKeyPresent']}',
    'firebaseAppIdPresent=${diag['firebaseAndroidAppIdPresent']}',
    'firebaseProjectId=${diag['firebaseProjectId']}',
    'firebaseSource=${diag['firebaseSource']}',
    'firebaseMissing=${diag['firebaseMissingKey']}',
    'errorType=${error.runtimeType}',
    'errorMessage=$maskedError',
  ];
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
    debugInfoLines: _buildSafeDebugInfoLines(error),
  );
}
