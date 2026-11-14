import 'dart:async';

import 'package:flutter/material.dart';

/// Lost response or a failed history check must not paint Boş Masa.
/// The close RPC is not sent again from this decision.
bool garsonCloseFailureShowsEmpty({
  required bool ordersConfirmedClosed,
  required bool historyVerified,
}) {
  return ordersConfirmedClosed && historyVerified;
}

/// Closing text only while the table still has an order.
/// An empty card is "Boş Masa" and must not keep the closing label.
String garsonTableCardStatusLabel({
  required bool closing,
  required bool hasOrder,
  required String activeLabel,
}) {
  if (!hasOrder) return 'Boş Masa';
  if (closing) return 'Masa kapatılıyor...';
  return activeLabel;
}

/// Isolated close stages. [historyFallback] may insert the archive row, so the
/// empty card waits for it. Duplicate-row deletes are not this step.
Future<({int rpcUs, int historyUs, int uiUs})> measureGarsonCloseStages({
  required Future<void> Function() rpc,
  required Future<void> Function() historyFallback,
  required void Function() applyUi,
}) async {
  final rpcWatch = Stopwatch()..start();
  await rpc();
  rpcWatch.stop();
  final historyWatch = Stopwatch()..start();
  await historyFallback();
  historyWatch.stop();
  final uiWatch = Stopwatch()..start();
  applyUi();
  uiWatch.stop();
  return (
    rpcUs: rpcWatch.elapsedMicroseconds,
    historyUs: historyWatch.elapsedMicroseconds,
    uiUs: uiWatch.elapsedMicroseconds,
  );
}

/// Small in-card status. It does not cover the rest of the board.
class GarsonOperationFeedback extends StatelessWidget {
  const GarsonOperationFeedback({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF5B21B6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered operation mark. It does not replace the page underneath.
class GarsonCenterBusy extends StatelessWidget {
  const GarsonCenterBusy({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Material(
          color: Colors.white,
          elevation: 0,
          shadowColor: const Color(0x335B21B6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F5B21B6),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Color(0xFF7B2FBE),
                    backgroundColor: Color(0xFFE9D5FF),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5B21B6),
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
