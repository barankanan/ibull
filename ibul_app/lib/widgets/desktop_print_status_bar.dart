import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/desktop_print_hub.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DesktopPrintStatusBar
// ─────────────────────────────────────────────────────────────────────────────

/// Floating status chip shown in the bottom-right corner of the seller
/// desktop app when the print hub is running.
///
/// Injected via `MaterialApp.builder` in `main_seller.dart` so it overlays
/// ALL routes without touching seller_panel_page.dart.
///
/// Tap → navigates to `/printer-setup`.
class DesktopPrintStatusBar extends StatelessWidget {
  const DesktopPrintStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DesktopPrintHub>(
      builder: (ctx, hub, _) {
        if (!hub.isRunning) return const SizedBox.shrink();
        return _PrintChip(hub: hub);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal chip widget
// ─────────────────────────────────────────────────────────────────────────────

class _PrintChip extends StatelessWidget {
  const _PrintChip({required this.hub});

  final DesktopPrintHub hub;

  @override
  Widget build(BuildContext context) {
    final (dotColor, statusLabel) = _statusInfo(hub.bridgeStatus);
    final hasError = hub.lastJobError != null;
    final hasCount = hub.dispatchedCount > 0;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).pushNamed('/printer-setup'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFFCA5A5)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bridge status indicator
              if (hub.bridgeStatus == BridgeStatus.checking)
                const SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Color(0xFFF59E0B),
                  ),
                )
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                statusLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
              // Listener active badge
              if (hub.listenerActive) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF8B5CF6),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              // Dispatch count badge
              if (hasCount) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${hub.dispatchedCount}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                ),
              ],
              // Error dot
              if (hasError) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              const Icon(
                Icons.print_outlined,
                size: 13,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static (Color, String) _statusInfo(BridgeStatus status) {
    return switch (status) {
      BridgeStatus.online => (const Color(0xFF10B981), 'Yazıcı Hazır'),
      BridgeStatus.offline => (const Color(0xFFEF4444), 'Yazıcı Kapalı'),
      BridgeStatus.error => (const Color(0xFFF97316), 'Yazıcı Hata'),
      BridgeStatus.checking => (const Color(0xFFF59E0B), 'Kontrol…'),
      BridgeStatus.unknown => (const Color(0xFF9CA3AF), 'Yazıcı'),
    };
  }
}
