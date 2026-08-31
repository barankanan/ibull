import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../investor_event_service.dart';
import '../investor_inquiry_service.dart';
import '../investor_widgets.dart';

class InvestorContactSection extends StatefulWidget {
  const InvestorContactSection({
    super.key,
    required this.formKey,
    required this.dataRoomKey,
    required this.onExplore,
  });

  final GlobalKey formKey;
  final GlobalKey dataRoomKey;
  final VoidCallback onExplore;

  @override
  State<InvestorContactSection> createState() => _InvestorContactSectionState();
}

class _InvestorContactSectionState extends State<InvestorContactSection> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();
  String? _investorType;
  String? _interest;
  bool _submitting = false;
  bool _started = false;
  bool _success = false;

  static const _types = [
    'Melek yatırımcı',
    'Girişim sermayesi',
    'Stratejik yatırımcı',
    'Teknoloji ortağı',
    'Lojistik ortağı',
    'İşletme / perakende ortağı',
    'Diğer',
  ];

  static const _interests = [
    'Pazaryeri',
    'İHIZ / teslimat',
    'Restoran dikeyi',
    'Emlak / ilan',
    'İBUL Reklam',
    'Veri zekâsı',
    'Lokasyon / gayrimenkul',
    'Stratejik ortaklık',
  ];

  static const _roomItems = [
    'Yatırımcı sunumu',
    'Finansal model',
    'Performans panosu',
    'Ürün yol haritası',
    'Pazar analizi',
    'Ortaklık yapısı',
    'Hukuki belgeler',
  ];

  @override
  void dispose() {
    _name.dispose();
    _company.dispose();
    _email.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  void _markStart() {
    if (_started) return;
    _started = true;
    InvestorEventService.instance.track('investor_form_start');
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await InvestorInquiryService.instance.submit(
        fullName: _name.text,
        company: _company.text,
        email: _email.text,
        phone: _phone.text,
        investorType: _investorType,
        interestArea: _interest,
        message: _message.text,
      );
      InvestorEventService.instance.track('investor_form_submit');
      if (!mounted) return;
      setState(() {
        _success = true;
        _submitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = InvestorTokens.isMobile(MediaQuery.sizeOf(context).width);
    return InvestorSection(
      revealId: 'investor-contact',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(
            key: widget.dataRoomKey,
            child: const InvestorHeader(
              eyebrow: '18  ·  BİLGİ ODASI',
              title: 'Yatırımcı bilgi talebi',
              subtitle: 'İndirme yok. Uygun belgeler talep sonrası paylaşılır.',
            ),
          ),
          const SizedBox(height: 16),
          InvestorCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in _roomItems)
                  Chip(
                    label: Text(item),
                    backgroundColor: AppColors.softPurple,
                    side: BorderSide.none,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: InvestorTokens.ink,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'İndirme butonu yok. Belgeler hazır olunca paylaşılır.',
            style: TextStyle(
              color: InvestorTokens.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          KeyedSubtree(
            key: widget.formKey,
            child: InvestorHeader(
              title: 'Yatırımcılarla iletişime geçin',
              subtitle: _success
                  ? 'Talebiniz başarıyla alındı.'
                  : 'Form, mevcut backend deseniyle kayıt altına alınır.',
            ),
          ),
          const SizedBox(height: 16),
          InvestorCard(
            child: _success
                ? const Text(
                    'Talebiniz başarıyla alındı. Ekibimiz uygun olduğunda sizinle iletişime geçer.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                      color: InvestorTokens.ink,
                    ),
                  )
                : Form(
                    key: _form,
                    child: Column(
                      children: [
                        _field(_name, 'Ad Soyad', requiredField: true),
                        const SizedBox(height: 12),
                        _field(_company, 'Şirket'),
                        const SizedBox(height: 12),
                        _field(
                          _email,
                          'E-mail',
                          requiredField: true,
                          keyboard: TextInputType.emailAddress,
                          email: true,
                        ),
                        const SizedBox(height: 12),
                        _field(_phone, 'Telefon', keyboard: TextInputType.phone),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: _investorType,
                          isExpanded: true,
                          decoration: _decoration('Yatırımcı tipi'),
                          items: [
                            for (final type in _types)
                              DropdownMenuItem(value: type, child: Text(type)),
                          ],
                          onChanged: (value) {
                            _markStart();
                            setState(() => _investorType = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          // ignore: deprecated_member_use
                          value: _interest,
                          isExpanded: true,
                          decoration: _decoration('İlgi alanı'),
                          items: [
                            for (final item in _interests)
                              DropdownMenuItem(value: item, child: Text(item)),
                          ],
                          onChanged: (value) {
                            _markStart();
                            setState(() => _interest = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        _field(_message, 'Mesaj', maxLines: 5),
                        const SizedBox(height: 16),
                        InvestorPrimaryButton(
                          label: _submitting
                              ? 'Gönderiliyor…'
                              : 'Yatırımcı Bilgi Talebi',
                          icon: Icons.send_outlined,
                          expanded: mobile,
                          onPressed: _submitting ? null : _submit,
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 48),
          InvestorCard(
            padding: EdgeInsets.fromLTRB(
              mobile ? 20 : 36,
              mobile ? 28 : 40,
              mobile ? 20 : 36,
              mobile ? 28 : 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const InvestorHeader(
                  title: 'Birlikte inşa edelim.',
                  subtitle: 'Sonraki büyüme aşamasında yer almak ister misiniz?',
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    InvestorPrimaryButton(
                      label: 'Görüşelim',
                      icon: Icons.mail_outline_rounded,
                      expanded: mobile,
                      onPressed: () {
                        InvestorEventService.instance.track(
                          'investor_contact_click',
                        );
                        final ctx = widget.formKey.currentContext;
                        if (ctx == null) return;
                        Scrollable.ensureVisible(
                          ctx,
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutCubic,
                          alignment: 0.08,
                        );
                      },
                    ),
                    InvestorSecondaryButton(
                      label: 'İBUL’u keşfet',
                      icon: Icons.storefront_outlined,
                      expanded: mobile,
                      onPressed: widget.onExplore,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool requiredField = false,
    bool email = false,
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      onTap: _markStart,
      onChanged: (_) => _markStart(),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (requiredField && text.isEmpty) return 'Bu alan gerekli';
        if (email &&
            text.isNotEmpty &&
            !RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(text)) {
          return 'Geçerli bir e-posta girin';
        }
        return null;
      },
      decoration: _decoration(label),
    );
  }
}
