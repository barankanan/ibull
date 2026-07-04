import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/product_load_trace.dart';

/// On-screen product fetch diagnostics (web).
class ProductLoadDebugPanel extends StatelessWidget {
  const ProductLoadDebugPanel({
    super.key,
    required this.snapshot,
    this.visible = true,
  });

  final ProductLoadTraceSnapshot snapshot;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !visible) return const SizedBox.shrink();
    if (snapshot.stage == ProductLoadTraceStage.renderCompleted &&
        snapshot.error == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      right: 8,
      bottom: 8,
      child: IgnorePointer(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Material(
            color: Colors.deepPurple.withValues(alpha: 0.82),
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
                  children: <Widget>[
                    const Text('product load trace'),
                    Text('stage: ${snapshot.stage}'),
                    if (snapshot.table != null) Text('table: ${snapshot.table}'),
                    if (snapshot.rawCount != null)
                      Text(
                        'raw: ${snapshot.rawCount} → filtered: ${snapshot.filteredCount ?? 0}',
                      ),
                    if (snapshot.error != null && snapshot.error!.isNotEmpty)
                      Text(
                        'error: ${snapshot.error}',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (snapshot.detail != null && snapshot.detail!.isNotEmpty)
                      Text(
                        snapshot.detail!,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
