import 'package:flutter/material.dart';

import '../services/restaurant_offline/restaurant_lan_host.dart';

/// Shown on the restaurant's computer when a waiter device asks to connect.
/// The operator compares the six digits with the phone and approves; the
/// staff member is then checked with the cloud before anything is granted.
Future<void> showLanPairingApprovalDialog(
  BuildContext context,
  LanPairingRequest request,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _LanPairingApprovalDialog(request: request),
  );
}

class _LanPairingApprovalDialog extends StatefulWidget {
  const _LanPairingApprovalDialog({required this.request});

  final LanPairingRequest request;

  @override
  State<_LanPairingApprovalDialog> createState() =>
      _LanPairingApprovalDialogState();
}

class _LanPairingApprovalDialogState extends State<_LanPairingApprovalDialog> {
  static const _purple = Color(0xFF7C3AED);
  bool _busy = false;
  String? _error;
  bool _done = false;

  Future<void> _approve() async {
    final host = RestaurantLanHostRegistry.current;
    if (host == null || !host.listening) {
      setState(() => _error = 'Yazıcı merkezi kapalı. Eşleştirme yapılamadı.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await host.approvePairingRequest(widget.request.id);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Garson cihazı bağlandı.')),
      );
      return;
    }
    setState(() {
      _busy = false;
      _done = true;
      _error = error;
    });
  }

  void _deny() {
    RestaurantLanHostRegistry.current?.denyPairingRequest(widget.request.id);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final code = request.matchCode;
    final shown = code.length == 6
        ? '${code.substring(0, 3)} ${code.substring(3)}'
        : code;
    final who = request.staffName.isEmpty ? 'Bir personel' : request.staffName;
    final device = request.deviceName.isEmpty ? 'cihaz' : request.deviceName;
    return AlertDialog(
      title: const Text('Garson cihazı bağlanmak istiyor'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$who · $device'),
            const SizedBox(height: 12),
            Center(
              child: Text(
                shown,
                key: const Key('lan_pairing_code'),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: _purple,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Telefonda aynı kod görünüyorsa onaylayın. Kod farklıysa veya '
              'bu cihazı tanımıyorsanız reddedin.',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: _done
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kapat'),
              ),
            ]
          : [
              TextButton(
                onPressed: _busy ? null : _deny,
                child: const Text('Reddet'),
              ),
              FilledButton(
                key: const Key('lan_pairing_approve'),
                onPressed: _busy ? null : _approve,
                style: FilledButton.styleFrom(backgroundColor: _purple),
                child: Text(_busy ? 'Doğrulanıyor…' : 'Onayla'),
              ),
            ],
    );
  }
}
