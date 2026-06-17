import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants.dart';
import '../models/saved_payment_card_models.dart';
import '../services/saved_payment_cards_service.dart';

class AddSavedCardSheet extends StatefulWidget {
  const AddSavedCardSheet({super.key});

  @override
  State<AddSavedCardSheet> createState() => _AddSavedCardSheetState();
}

class _AddSavedCardSheetState extends State<AddSavedCardSheet> {
  final _holderController = TextEditingController();
  final _numberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _aliasController = TextEditingController();
  bool _makeDefault = false;
  bool _submitting = false;

  @override
  void dispose() {
    _holderController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  RawCardInput _buildInput() => RawCardInput(
        cardNumber: _numberController.text,
        expiry: _expiryController.text,
        cvv: _cvvController.text,
        holderName: _holderController.text,
        alias: _aliasController.text,
      );

  Future<void> _submit() async {
    final input = _buildInput();
    if (!input.isComplete) {
      _showSnack('Lütfen tüm kart bilgilerini doldurun.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final token = await SavedPaymentCardsService.instance.tokenizeCard(input);
      if (token == null) {
        _showSnack(
          'Kart kaydetme ödeme altyapısı aktif edildiğinde kullanılabilir.',
        );
        return;
      }
      await SavedPaymentCardsService.instance.addSavedCardFromProviderToken(
        token,
        makeDefault: _makeDefault,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on CardTokenizationUnavailable catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Kart Ekle',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                'Kart kaydetme ödeme altyapısı bağlanınca aktif olacak. '
                'Ham kart bilgileri sunucuya kaydedilmez.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            _field('Kart üzerindeki isim', _holderController),
            const SizedBox(height: 12),
            _field(
              'Kart numarası',
              _numberController,
              keyboardType: TextInputType.number,
              maxLength: 19,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _field(
                    'Son kullanma (AA/YY)',
                    _expiryController,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    'CVV',
                    _cvvController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscure: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field('Kart adı', _aliasController, hint: 'Kişisel Kartım'),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _makeDefault,
              onChanged: (v) => setState(() => _makeDefault = v ?? false),
              contentPadding: EdgeInsets.zero,
              title: const Text('Varsayılan kart yap'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Kartı Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

Future<bool?> showAddSavedCardSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const AddSavedCardSheet(),
  );
}
