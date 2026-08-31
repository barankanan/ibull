import 'package:flutter/material.dart';

import '../../../app/ibul_router.dart';
import '../../../services/ihiz_delivery_service.dart';
import '../delivery/ihiz_route_paths.dart';
import '../send/ihiz_package_send_validator.dart';
import '../shell/ihiz_footer.dart';
import '../shell/ihiz_header.dart';
import '../shell/ihiz_subpage_scaffold.dart';
import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';

class IhizPackageSendPage extends StatefulWidget {
  const IhizPackageSendPage({super.key, this.service});

  final IhizDeliveryService? service;

  @override
  State<IhizPackageSendPage> createState() => _IhizPackageSendPageState();
}

class _IhizPackageSendPageState extends State<IhizPackageSendPage> {
  late final IhizDeliveryService _service =
      widget.service ?? IhizDeliveryService.instance;

  final _pickupName = TextEditingController();
  final _pickupPhone = TextEditingController();
  final _pickupAddress = TextEditingController();
  final _pickupCity = TextEditingController();
  final _pickupDistrict = TextEditingController();
  final _dropoffName = TextEditingController();
  final _dropoffPhone = TextEditingController();
  final _dropoffAddress = TextEditingController();
  final _dropoffCity = TextEditingController();
  final _dropoffDistrict = TextEditingController();
  final _weight = TextEditingController();
  final _notes = TextEditingController();
  String _size = 'medium';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _pickupName.dispose();
    _pickupPhone.dispose();
    _pickupAddress.dispose();
    _pickupCity.dispose();
    _pickupDistrict.dispose();
    _dropoffName.dispose();
    _dropoffPhone.dispose();
    _dropoffAddress.dispose();
    _dropoffCity.dispose();
    _dropoffDistrict.dispose();
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _goLanding() {
    IbulRouter.go(context, IhizRoutePaths.landing);
  }

  Future<void> _submit() async {
    final weightRaw = _weight.text.trim().replaceAll(',', '.');
    final weight = weightRaw.isEmpty ? null : double.tryParse(weightRaw);
    final input = IhizPackageSendInput(
      pickupName: _pickupName.text,
      pickupPhone: _pickupPhone.text,
      pickupAddress: _pickupAddress.text,
      pickupCity: _pickupCity.text,
      pickupDistrict: _pickupDistrict.text,
      dropoffName: _dropoffName.text,
      dropoffPhone: _dropoffPhone.text,
      dropoffAddress: _dropoffAddress.text,
      dropoffCity: _dropoffCity.text,
      dropoffDistrict: _dropoffDistrict.text,
      packageSize: _size,
      packageWeight: weight,
      notes: _notes.text,
    );
    final invalid = IhizPackageSendValidator.validate(input);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _service.createPackageDelivery(input);
      if (!mounted) return;
      final code = result['tracking_code']?.toString() ?? '';
      IbulRouter.replace(context, IhizRoutePaths.track(code));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = IhizBrand.isMobile(MediaQuery.sizeOf(context).width);
    return IhizSubpageScaffold(
      header: IhizHeader(
        onHome: _goLanding,
        onHowItWorks: _goLanding,
        onTracking: _goLanding,
        onBusinessJoin: _goLanding,
        onLogin: _goLanding,
        onCourierApply: _goLanding,
      ),
      body: IhizSectionPadding(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const IhizSectionHeader(
                  eyebrow: 'PAKET GÖNDER',
                  title: 'Evden teslim al',
                  subtitle:
                      'Kurye çağırın; teslimat görevi İHIZ havuzuna düşer. Otomatik atama yapılmaz.',
                ),
                const SizedBox(height: 20),
                _Field(controller: _pickupName, label: 'Gönderici adı'),
                _Field(controller: _pickupPhone, label: 'Gönderici telefon'),
                _Field(
                  controller: _pickupAddress,
                  label: 'Alınacak adres',
                  maxLines: 2,
                ),
                _Field(controller: _pickupCity, label: 'Alınacak şehir'),
                _Field(controller: _pickupDistrict, label: 'Alınacak ilçe'),
                const SizedBox(height: 12),
                _Field(controller: _dropoffName, label: 'Alıcı adı'),
                _Field(controller: _dropoffPhone, label: 'Alıcı telefon'),
                _Field(
                  controller: _dropoffAddress,
                  label: 'Teslim edilecek adres',
                  maxLines: 2,
                ),
                _Field(controller: _dropoffCity, label: 'Teslim şehir'),
                _Field(controller: _dropoffDistrict, label: 'Teslim ilçe'),
                const SizedBox(height: 12),
                Text(
                  'Paket boyutu',
                  style: TextStyle(
                    color: IhizBrand.inkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final size in IhizPackageSendValidator.packageSizes)
                      ChoiceChip(
                        label: Text(
                          IhizPackageSendValidator.packageSizeLabel(size),
                        ),
                        selected: _size == size,
                        onSelected: (_) => setState(() => _size = size),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _weight,
                  label: 'Ağırlık (kg, opsiyonel)',
                  keyboard: TextInputType.number,
                ),
                _Field(
                  controller: _notes,
                  label: 'Teslimat notu',
                  maxLines: 3,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                IhizPrimaryButton(
                  label: _busy ? 'Gönderiliyor...' : 'Kurye Çağır',
                  icon: Icons.two_wheeler_rounded,
                  onPressed: _busy ? () {} : _submit,
                  expanded: compact,
                ),
              ],
            ),
          ),
        ),
      ),
      footer: IhizFooter(
        onHome: _goLanding,
        onHowItWorks: _goLanding,
        onCourierApply: _goLanding,
        onBusinessJoin: _goLanding,
        onTracking: _goLanding,
        onReturnToIbul: () {
          IbulRouter.go(context, '/home');
        },
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboard,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
