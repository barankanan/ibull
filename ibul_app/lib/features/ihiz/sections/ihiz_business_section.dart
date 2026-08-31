import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';
import '../delivery/ihiz_business_serial.dart';

class IhizBusinessSection extends StatefulWidget {
  const IhizBusinessSection({
    super.key,
    required this.onJoin,
    required this.onBindSerial,
  });

  final VoidCallback onJoin;
  final ValueChanged<String> onBindSerial;

  @override
  State<IhizBusinessSection> createState() => _IhizBusinessSectionState();
}

class _IhizBusinessSectionState extends State<IhizBusinessSection> {
  final _serial = TextEditingController();
  String? _error;

  static const _features = [
    (
      Icons.speed_rounded,
      'Daha hızlı teslimat',
      'Siparişleri yerel kurye ağıyla dakikalar içinde ulaştırın.',
    ),
    (
      Icons.settings_suggest_rounded,
      'Daha az operasyon',
      'Rota, eşleşme ve takip İhız tarafından yönetilir.',
    ),
    (
      Icons.sentiment_satisfied_alt_rounded,
      'Daha iyi müşteri deneyimi',
      'Canlı takip ve güvenli teslimat ile memnuniyeti artırın.',
    ),
  ];

  @override
  void dispose() {
    _serial.dispose();
    super.dispose();
  }

  void _bind() {
    final code = IhizBusinessSerial.normalize(_serial.text);
    if (!IhizBusinessSerial.isValid(code)) {
      setState(() => _error = 'Geçerli bir işletme seri no girin (ISL-XXXXXX).');
      return;
    }
    setState(() => _error = null);
    widget.onBindSerial(code);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = !IhizBrand.useMediumGrid(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const IhizSectionHeader(
              eyebrow: 'İŞLETME',
              title: 'Mağazanız için hızlı teslimat altyapısı.',
              subtitle:
                  'İBUL işletme profilindeki seri no ile mağazanızı bağlayın.',
            ),
            SizedBox(height: compact ? 18 : 24),
            IhizResponsiveCardGrid(
              children: [
                for (final f in _features)
                  IhizFeatureCard(
                    icon: f.$1,
                    title: f.$2,
                    body: f.$3,
                    compact: compact,
                  ),
              ],
            ),
            SizedBox(height: compact ? 18 : 24),
            _BindCard(
              controller: _serial,
              error: _error,
              compact: compact,
              onBind: _bind,
              onJoin: widget.onJoin,
            ),
          ],
        );
      },
    );
  }
}

class _BindCard extends StatelessWidget {
  const _BindCard({
    required this.controller,
    required this.error,
    required this.compact,
    required this.onBind,
    required this.onJoin,
  });

  final TextEditingController controller;
  final String? error;
  final bool compact;
  final VoidCallback onBind;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
        LengthLimitingTextInputFormatter(10),
      ],
      onSubmitted: (_) => onBind(),
      decoration: InputDecoration(
        labelText: 'İşletme bağla',
        hintText: 'ISL-XXXXXX',
        filled: true,
        fillColor: Colors.white,
        errorText: error,
        prefixIcon: const Icon(Icons.qr_code_2_rounded),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: IhizBrand.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: IhizBrand.line),
        ),
      ),
    );
    final findButton = IhizPrimaryButton(
      label: 'İşletmeyi Bul',
      icon: Icons.search_rounded,
      onPressed: onBind,
      expanded: compact,
    );
    final joinButton = IhizSecondaryButton(
      label: 'İşletme Olarak Kullan',
      icon: Icons.storefront_rounded,
      onPressed: onJoin,
      expanded: compact,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: IhizBrand.line),
        boxShadow: IhizBrand.cardShadow,
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'İşletme bağla',
              style: TextStyle(
                color: IhizBrand.ink,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'İBUL mağaza profilindeki işletme seri numarasını girin.',
              style: TextStyle(
                color: IhizBrand.inkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (compact) ...[
              field,
              const SizedBox(height: 12),
              findButton,
              const SizedBox(height: 10),
              joinButton,
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: field),
                  const SizedBox(width: 12),
                  findButton,
                ],
              ),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: joinButton),
            ],
          ],
        ),
      ),
    );
  }
}
