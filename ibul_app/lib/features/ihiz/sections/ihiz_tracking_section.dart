import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';
import '../delivery/ihiz_route_paths.dart';

class IhizTrackingSection extends StatefulWidget {
  const IhizTrackingSection({super.key, required this.onSubmit});

  final ValueChanged<String> onSubmit;

  @override
  State<IhizTrackingSection> createState() => _IhizTrackingSectionState();
}

class _IhizTrackingSectionState extends State<IhizTrackingSection> {
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
      setState(() => _error = 'Geçerli bir teslimat kodu girin (IHZ-XXXXXX).');
      return;
    }
    setState(() => _error = null);
    widget.onSubmit(code);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = IhizBrand.isMobile(constraints.maxWidth);
        final form = _TrackingForm(
          controller: _controller,
          error: _error,
          expanded: mobile,
          onSubmit: _submit,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const IhizSectionHeader(
              eyebrow: 'TESLİMAT TAKİBİ',
              title: 'Teslimat kodunuzu girin',
              subtitle:
                  'Gerçek teslimat kodunuzla paketinizin güncel durumunu görün.',
            ),
            SizedBox(height: mobile ? 18 : 24),
            form,
          ],
        );
      },
    );
  }
}

class _TrackingForm extends StatelessWidget {
  const _TrackingForm({
    required this.controller,
    required this.error,
    required this.expanded,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String? error;
  final bool expanded;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
        LengthLimitingTextInputFormatter(10),
      ],
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: 'IHZ-XXXXXX',
        filled: true,
        fillColor: Colors.white,
        errorText: error,
        prefixIcon: const Icon(Icons.local_shipping_outlined),
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

    final button = IhizPrimaryButton(
      label: 'Teslimatı Takip Et',
      icon: Icons.search_rounded,
      onPressed: onSubmit,
      expanded: expanded,
    );

    if (expanded) {
      return Column(
        children: [
          field,
          const SizedBox(height: 12),
          button,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: field),
        const SizedBox(width: 12),
        button,
      ],
    );
  }
}
