import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/web_boot_trace.dart';

/// Small on-screen boot trace for web release diagnostics (hidden when home loads).
class WebBootDebugPanel extends StatelessWidget {
  const WebBootDebugPanel({
    super.key,
    required this.snapshot,
    this.visible = true,
  });

  final WebBootTraceSnapshot snapshot;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !visible) return const SizedBox.shrink();
    if (snapshot.stage == WebBootTraceStage.completed) {
      return const SizedBox.shrink();
    }

    final errorLine = snapshot.lastError == null || snapshot.lastError!.isEmpty
        ? 'last error: —'
        : 'last error: ${snapshot.lastError}';

    return Positioned(
      left: 8,
      bottom: 8,
      right: 8,
      child: IgnorePointer(
        child: Material(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontFamily: 'monospace',
                height: 1.35,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('module: ${snapshot.module}'),
                  Text('stage: ${snapshot.stage}'),
                  Text('elapsed: ${snapshot.elapsedSeconds}s'),
                  Text('retry: ${snapshot.retryCount}'),
                  Text(errorLine, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
