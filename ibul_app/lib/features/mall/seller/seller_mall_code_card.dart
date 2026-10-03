import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants.dart';
import 'seller_mall_apply_dialog.dart';
import 'seller_mall_link_repository.dart';

/// Opens the application dialog and confirms with the AVM name. True when sent.
Future<bool> openSellerMallApplication(
  BuildContext context, {
  SellerMallLinkRepository? repository,
  SellerMallFilePicker? pickFile,
}) async {
  final mallName = await showSellerMallApplyDialog(context, repository: repository, pickFile: pickFile);
  if (mallName == null || !context.mounted) return false;
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(SnackBar(content: Text('Başvurunuz $mallName yönetimine gönderildi.')));
  return true;
}

/// Public branch code an AVM uses to find this store, plus the store's own
/// AVM application. The code is not the store id and not a secret.
class SellerMallCodeCard extends StatefulWidget {
  const SellerMallCodeCard({super.key, this.gap = 0, this.repository, this.pickFile});

  final double gap;
  final SellerMallLinkRepository? repository;
  final SellerMallFilePicker? pickFile;

  @override
  State<SellerMallCodeCard> createState() => _SellerMallCodeCardState();
}

class _SellerMallCodeCardState extends State<SellerMallCodeCard> {
  late final Future<String?> _code = (widget.repository ?? SellerMallLinkRepository()).myBranchCode();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _code,
      builder: (context, snapshot) {
        final code = snapshot.data;
        if (code == null || code.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(bottom: widget.gap),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8E6EF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.apartment_outlined, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('AVM / İşletme Bağlantısı',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ]),
                const SizedBox(height: 12),
                const Text('Bağlantı kodu', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EEFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        code,
                        key: const ValueKey('seller-mall-code'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                      if (!context.mounted) return;
                      ScaffoldMessenger.maybeOf(context)
                          ?.showSnackBar(const SnackBar(content: Text('Kod kopyalandı.')));
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Kopyala'),
                  ),
                ]),
                const SizedBox(height: 10),
                const Text(
                  'AVM yönetimleri mağazanızı İBUL\'da bulmak için bu kodu kullanabilir. '
                  'Fiziksel mağazanız bir AVM\'deyse siz de başvurabilirsiniz.',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('seller-mall-apply'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () =>
                        openSellerMallApplication(context, repository: widget.repository, pickFile: widget.pickFile),
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: const Text('AVM\'ye Başvur', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
