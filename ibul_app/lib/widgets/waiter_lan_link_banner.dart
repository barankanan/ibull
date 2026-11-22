import 'dart:async';

import 'package:flutter/material.dart';

import '../services/restaurant_offline/waiter_lan_link.dart';

/// Short first-connection flow for a waiter's phone. It appears only when
/// the waiter has something to do: a center was found and this device is not
/// approved yet, the approval is pending, or it failed. A connected device
/// and a network without a center show nothing.
class WaiterLanLinkBanner extends StatefulWidget {
  const WaiterLanLinkBanner({super.key, this.link});

  final WaiterLanLink? link;

  @override
  State<WaiterLanLinkBanner> createState() => _WaiterLanLinkBannerState();
}

class _WaiterLanLinkBannerState extends State<WaiterLanLinkBanner> {
  static const _purple = Color(0xFF7C3AED);
  static const _ink = Color(0xFF1F2937);
  static const _muted = Color(0xFF6B7280);

  /// "Sonra": the offer stays away until the app is opened again.
  bool _later = false;

  @override
  Widget build(BuildContext context) {
    final link = widget.link ?? WaiterLanLink.instance;
    return ListenableBuilder(
      listenable: link,
      builder: (context, _) {
        final Widget? body = switch (link.phase) {
          WaiterLanLinkPhase.centerFound => _later ? null : _found(link),
          WaiterLanLinkPhase.noCenter => _later ? null : _notFound(link),
          WaiterLanLinkPhase.waitingApproval => _waiting(link),
          WaiterLanLinkPhase.failed => _failed(link),
          _ => null,
        };
        if (body == null) return const SizedBox.shrink();
        return Material(
          color: Colors.white,
          elevation: 6,
          shadowColor: const Color(0x337C3AED),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: body,
          ),
        );
      },
    );
  }

  Widget _found(WaiterLanLink link) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.wifi_tethering, color: _purple, size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ana bilgisayar bulundu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'İnternet kesilse de sipariş gönderebilmek için bu cihazı bağlayın.',
                    style: TextStyle(fontSize: 12, height: 1.3, color: _muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _later = true),
              child: const Text('Sonra'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              key: const Key('waiter_lan_link_connect'),
              onPressed: () => unawaited(link.requestPairing()),
              style: FilledButton.styleFrom(
                backgroundColor: _purple,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Bu cihazı bağla'),
            ),
          ],
        ),
      ],
    );
  }

  /// Nothing announced on this network: the search may be switched off for
  /// the app, or the center may not announce itself. The link the center
  /// shows on its own screen connects the device without a search.
  Widget _notFound(WaiterLanLink link) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.wifi_find_outlined, color: _muted, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ana bilgisayar bu ağda bulunamadı',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    link.message.isNotEmpty
                        ? link.message
                        : 'Siparişler internet üzerinden gider. Aynı Wi-Fi ağında '
                              'olduğunuzu ve uygulamanın Yerel Ağ izninin açık '
                              'olduğunu kontrol edin ya da ana bilgisayardaki '
                              'bağlantı kodunu kullanın.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: _muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => _later = true),
              child: const Text('Sonra'),
            ),
            const SizedBox(width: 4),
            OutlinedButton(
              key: const Key('waiter_lan_link_code'),
              onPressed: () => unawaited(_askForLink(link)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _purple,
                side: const BorderSide(color: Color(0xFFDDD6FE)),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Kodla bağla'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _askForLink(WaiterLanLink link) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _PairingLinkDialog(),
    );
    if (text == null || text.trim().isEmpty) return;
    await link.pairWithLink(text);
  }

  Widget _waiting(WaiterLanLink link) {
    final code = link.matchCode;
    final shown = code.length == 6
        ? '${code.substring(0, 3)} ${code.substring(3)}'
        : code;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: _purple),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Ana bilgisayarın onayı bekleniyor',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            TextButton(
              onPressed: link.cancelPairing,
              child: const Text('İptal'),
            ),
          ],
        ),
        if (code.isNotEmpty) ...[
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              shown,
              key: const Key('waiter_lan_link_code'),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: _purple,
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          link.message,
          style: const TextStyle(fontSize: 12, height: 1.3, color: _muted),
        ),
      ],
    );
  }

  Widget _failed(WaiterLanLink link) {
    return Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            link.message.isEmpty ? 'Eşleştirme tamamlanamadı.' : link.message,
            style: const TextStyle(fontSize: 13, height: 1.3, color: _ink),
          ),
        ),
        TextButton(
          onPressed: link.cancelPairing,
          child: const Text('Tamam'),
        ),
      ],
    );
  }
}

/// Asks for the link the center shows. The dialog owns its text controller,
/// so it is released only after the dialog has left the screen.
class _PairingLinkDialog extends StatefulWidget {
  const _PairingLinkDialog();

  @override
  State<_PairingLinkDialog> createState() => _PairingLinkDialogState();
}

class _PairingLinkDialogState extends State<_PairingLinkDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ana bilgisayara bağlan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ana bilgisayarda Sistem > Yerel operasyon > "Garson cihazı bağla" '
              'ile gösterilen bağlantı kodunu buraya yapıştırın. Kod iki dakika '
              'geçerlidir ve bir kez kullanılır.',
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('waiter_lan_link_code_field'),
              controller: _controller,
              autocorrect: false,
              enableSuggestions: false,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Bağlantı kodu',
                hintText: 'ibul-lan://pair?…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const Key('waiter_lan_link_code_submit'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
          ),
          child: const Text('Bağlan'),
        ),
      ],
    );
  }
}
