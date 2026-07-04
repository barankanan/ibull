import 'package:flutter/material.dart';

import '../core/config/runtime_config.dart';
import '../core/web_boot.dart';

/// Minimal web-safe shell — no providers, Supabase, or HomeScreen.
class IbulSafeBootApp extends StatelessWidget {
  const IbulSafeBootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'İBUL Safe Boot',
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B2FBE), Color(0xFF5B1FBF)],
                      ),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'İBUL Safe Boot',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Uygulama güvenli modda açıldı.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bu ekran görünüyorsa Flutter web mount başarılı.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Colors.grey.shade600,
                    ),
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

/// Immediate safe-boot entry — no async init, no provider tree.
void runIbulSafeBootApp() {
  WebBootLogger.log('main', detail: 'entered');
  WebBootLogger.log('safe_boot', detail: 'enabled=true');
  runApp(const IbulSafeBootApp());
  WebBootLogger.log('safe_boot', detail: 'runApp called');
}

/// Returns false when safe boot should bypass full bootstrap.
bool shouldRunFullAppBootstrap({bool? safeBootMode}) {
  return !(safeBootMode ?? AppRuntimeConfig.safeBootMode);
}
