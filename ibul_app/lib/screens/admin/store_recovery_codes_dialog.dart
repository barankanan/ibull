import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../services/seller_recovery_service.dart';

class StoreRecoveryCodesDialog extends StatefulWidget {
  const StoreRecoveryCodesDialog({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  final String storeId;
  final String storeName;

  @override
  State<StoreRecoveryCodesDialog> createState() =>
      _StoreRecoveryCodesDialogState();
}

class _StoreRecoveryCodesDialogState extends State<StoreRecoveryCodesDialog> {
  final _service = SellerRecoveryService();
  bool _loading = false;
  List<String> _codes = const [];

  Future<void> _issue() async {
    setState(() => _loading = true);
    try {
      final codes = await _service.issueStoreCodes(widget.storeId);
      if (!mounted) return;
      setState(() => _codes = codes);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kodlar üretilemedi: $error')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.storeName} — kurtarma kodları'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Her mağaza için 5 tek kullanımlık kod üretilir. Kodları satıcıya iletin; düz metin yalnızca bu ekranda görünür.',
            ),
            const SizedBox(height: 16),
            if (_codes.isEmpty)
              const Text(
                'Üret’e basınca eski kullanılmamış kodlar geçersiz olur.',
              )
            else
              ..._codes.map(
                (code) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SelectableText(
                    code,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
        if (_codes.isNotEmpty)
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _codes.join('\n')));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kodlar panoya kopyalandı.')),
              );
            },
            child: const Text('Kopyala'),
          ),
        FilledButton(
          onPressed: _loading ? null : _issue,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_codes.isEmpty ? '5 kod üret' : 'Yeniden üret'),
        ),
      ],
    );
  }
}
