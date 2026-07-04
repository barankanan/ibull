import 'package:flutter/material.dart';

import '../core/ibul_boot_stage.dart';
import '../core/web_boot.dart';
import 'ibul_boot_controller.dart';

/// Visible loading shell — no providers, Supabase, or HomeScreen.
class IbulBootShellScreen extends StatelessWidget {
  const IbulBootShellScreen({
    super.key,
    this.currentStep = 'starting',
  });

  final String currentStep;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
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
                  'İBUL yükleniyor',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Başlatılıyor…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text(
                  currentStep,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Diagnostic shell — boot stage `shell`.
class IbulBootDiagnosticShellPage extends StatelessWidget {
  const IbulBootDiagnosticShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('İBUL Boot Shell')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Boot stage: shell\nMaterialApp + router mount OK.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Diagnostic page — boot stage `providers`.
class IbulBootDiagnosticProvidersPage extends StatelessWidget {
  const IbulBootDiagnosticProvidersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('İBUL Providers Diagnostic')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Boot stage: providers\nProvider tree mounted; HomeScreen skipped.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Wraps boot shell → real app transition.
class IbulProgressiveBootApp extends StatelessWidget {
  const IbulProgressiveBootApp({
    super.key,
    required this.controller,
    required this.readyBuilder,
    this.bootStage = IbulBootStage.normal,
  });

  final IbulBootController controller;
  final Widget Function(BuildContext context) readyBuilder;
  final IbulBootStage bootStage;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        switch (controller.status) {
          case IbulBootStatus.loading:
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              home: IbulBootShellScreen(currentStep: controller.currentStep),
            );
          case IbulBootStatus.error:
            return WebBootFatalScreen(
              message: webBootUserMessage(controller.errorMessage ?? 'error'),
              technicalDetail: controller.errorMessage,
            );
          case IbulBootStatus.ready:
            if (bootStage == IbulBootStage.shell) {
              return const MaterialApp(
                debugShowCheckedModeBanner: false,
                home: IbulBootDiagnosticShellPage(),
              );
            }
            return readyBuilder(context);
        }
      },
    );
  }
}
