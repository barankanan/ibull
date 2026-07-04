import 'package:flutter/material.dart';

import '../widgets/skeleton_loading.dart';

typedef HomeDeferredTabLoader = Future<Widget> Function();

/// Lazy-mounts a bottom-nav tab only after first visit (deferred library load).
class HomeDeferredTab extends StatefulWidget {
  const HomeDeferredTab({
    super.key,
    required this.load,
    this.placeholder,
  });

  final HomeDeferredTabLoader load;
  final Widget? placeholder;

  @override
  State<HomeDeferredTab> createState() => _HomeDeferredTabState();
}

class _HomeDeferredTabState extends State<HomeDeferredTab> {
  Widget? _child;
  Object? _error;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  Future<void> _ensureLoaded() async {
    if (_requested || _child != null) return;
    _requested = true;
    if (!mounted) return;
    try {
      final page = await widget.load();
      if (!mounted) return;
      setState(() {
        _child = page;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_child != null) return _child!;
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: Colors.red),
              const SizedBox(height: 12),
              Text('Sayfa yüklenemedi: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _requested = false;
                  });
                  _ensureLoaded();
                },
                child: const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      );
    }
    return widget.placeholder ??
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: SkeletonLoading(width: double.infinity, height: 200),
          ),
        );
  }
}
