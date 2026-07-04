import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/perf_debug_config.dart';
import '../core/product_load_trace.dart';
import '../core/web_boot_trace.dart';
import '../core/web_perf_trace.dart';

/// Combined boot + product perf panel (web only, debug or `?perf=1`).
class WebPerfDebugPanel extends StatelessWidget {
  const WebPerfDebugPanel({
    super.key,
    this.bootSnapshot,
    this.productSnapshot,
    this.visible = true,
  });

  final WebBootTraceSnapshot? bootSnapshot;
  final ProductLoadTraceSnapshot? productSnapshot;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !visible || !perfDebugPanelEnabled) {
      return const SizedBox.shrink();
    }

    final perf = WebPerfTrace.instance.snapshot;
    final boot = bootSnapshot;
    final product = productSnapshot;
    final stage = perf.stage;
    final showBoot = boot != null &&
        boot.stage != WebBootTraceStage.completed &&
        boot.stage != WebBootTraceStage.homescreenFirstFrameRendered;

    if (!showBoot &&
        product?.stage == ProductLoadTraceStage.renderCompleted &&
        perf.stage == WebPerfTraceStage.bootComplete &&
        perf.lastError == null) {
      return const SizedBox.shrink();
    }

    final mainJsKb = perf.mainJsBytes != null
        ? '${(perf.mainJsBytes! / 1024).toStringAsFixed(0)} KB'
        : '—';

    return Positioned(
      left: 8,
      bottom: 8,
      child: IgnorePointer(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            color: Colors.black.withValues(alpha: 0.78),
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
                    const Text('ibul web perf trace'),
                    Text('stage: $stage'),
                    Text('elapsed: ${perf.elapsedMs} ms'),
                    Text('main.js: $mainJsKb'),
                    if (perf.productRawCount != null ||
                        perf.productFilteredCount != null ||
                        perf.productRenderCount != null)
                      Text(
                        'products raw=${perf.productRawCount ?? '—'} '
                        'filtered=${perf.productFilteredCount ?? '—'} '
                        'render=${perf.productRenderCount ?? '—'}',
                      ),
                    if (perf.firstProductRenderMs != null)
                      Text('first card: ${perf.firstProductRenderMs} ms'),
                    if (boot != null && showBoot) ...[
                      Text('boot: ${boot.stage} (${boot.elapsedSeconds}s)'),
                    ],
                    if (product != null &&
                        product.stage != ProductLoadTraceStage.renderCompleted)
                      Text('product: ${product.stage}'),
                    if (perf.lastError != null && perf.lastError!.isNotEmpty)
                      Text(
                        'error: ${perf.lastError}',
                        maxLines: 3,
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
