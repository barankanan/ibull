import 'package:flutter/material.dart';

/// Loads a deferred library then builds [builder]. Shows a lightweight shell while waiting.
class DeferredScreen extends StatefulWidget {
  const DeferredScreen({
    super.key,
    required this.loadLibrary,
    required this.builder,
    this.loading,
  });

  final Future<void> Function() loadLibrary;
  final Widget Function() builder;
  final Widget? loading;

  @override
  State<DeferredScreen> createState() => _DeferredScreenState();
}

class _DeferredScreenState extends State<DeferredScreen> {
  late final Future<void> _loadFuture = widget.loadLibrary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Sayfa yüklenemedi. Lütfen tekrar deneyin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loading ??
              const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
        }

        return widget.builder();
      },
    );
  }
}
