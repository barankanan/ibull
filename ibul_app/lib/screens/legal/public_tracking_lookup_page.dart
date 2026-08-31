import 'package:flutter/material.dart';

import '../../app/ibul_router.dart';
import '../../core/constants.dart';
import '../../features/ihiz/delivery/ihiz_route_paths.dart';

class PublicTrackingLookupPage extends StatefulWidget {
  const PublicTrackingLookupPage({super.key});

  @override
  State<PublicTrackingLookupPage> createState() =>
      _PublicTrackingLookupPageState();
}

class _PublicTrackingLookupPageState extends State<PublicTrackingLookupPage> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = IhizRoutePaths.normalizeTrackingCode(_controller.text);
    if (!IhizRoutePaths.isValidTrackingCode(code)) {
      setState(() {
        _error = 'Geçerli bir İHIZ kodu girin (ör. IHZ-AB12CD).';
      });
      return;
    }
    setState(() => _error = null);
    IbulRouter.push(context, IhizRoutePaths.track(code));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black87,
        title: const Text(
          'Kargo Takibi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gönderi kodu ile takip',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'İHIZ teslimat kodunuzu girin. Pazaryeri siparişleriniz Hesabım > Siparişlerim altındadır.',
                  style: TextStyle(color: Colors.grey[700], height: 1.5),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Takip kodu',
                    hintText: 'IHZ-AB12CD',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Takip et'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    IbulRouter.push(context, '/ihiz');
                  },
                  child: const Text('İHIZ ana sayfası'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
