import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/store_service.dart';

/// Staff confirms they can see the customer at one table, then receives a
/// single-use code. The code does not replace the 100 metre check for anyone
/// who does not show this session to the staff member.
Future<void> showCustomerTablePresenceGrant(
  BuildContext context, {
  required String sellerId,
  required int tableNumber,
}) async {
  final sessionController = TextEditingController();
  var sawCustomer = false;
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final session = sessionController.text.trim();
            final canIssue = sawCustomer && session.length >= 8;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Masa $tableNumber konum onayı',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Kodu yalnız bu masada gördüğünüz müşterinin telefonundaki oturum için üretin. Kod 15 dakika ve tek sipariş için geçerlidir.',
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: sawCustomer,
                    onChanged: (value) {
                      setSheetState(() => sawCustomer = value == true);
                    },
                    title: const Text('Müşteriyi bu masada görüyorum'),
                  ),
                  TextField(
                    controller: sessionController,
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setSheetState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Müşterinin ekranındaki oturum kodu',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: canIssue
                        ? () async {
                            try {
                              final issued = await StoreService()
                                  .issueCustomerProximityGrant(
                                    sellerId: sellerId,
                                    tableNumber: tableNumber,
                                    customerSessionId: session,
                                    staffConfirmed: true,
                                  );
                              if (!sheetContext.mounted) return;
                              final code =
                                  issued['grant_code']?.toString() ?? '';
                              await showDialog<void>(
                                context: sheetContext,
                                builder: (dialogContext) {
                                  return AlertDialog(
                                    title: const Text('Tek kullanımlık kod'),
                                    content: SelectableText(
                                      code.isEmpty
                                          ? 'Kod alınamadı.'
                                          : code,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: code.isEmpty
                                            ? null
                                            : () {
                                                Clipboard.setData(
                                                  ClipboardData(text: code),
                                                );
                                              },
                                        child: const Text('Kopyala'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(
                                          dialogContext,
                                        ),
                                        child: const Text('Kapat'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (sheetContext.mounted) {
                                Navigator.pop(sheetContext);
                              }
                            } catch (error) {
                              if (!sheetContext.mounted) return;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    error
                                        .toString()
                                        .replaceFirst('Bad state: ', '')
                                        .replaceFirst('Exception: ', ''),
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    child: const Text('Onay kodu üret'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  } finally {
    sessionController.dispose();
  }
}
