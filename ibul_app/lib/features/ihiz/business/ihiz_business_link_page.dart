import 'package:flutter/material.dart';

import '../../../app/ibul_router.dart';
import '../../../services/ihiz_business_account_service.dart';
import '../delivery/ihiz_business_serial.dart';
import '../delivery/ihiz_route_paths.dart';
import '../shell/ihiz_footer.dart';
import '../shell/ihiz_header.dart';
import '../shell/ihiz_subpage_scaffold.dart';
import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';
import 'ihiz_business_admin_page.dart';

class IhizBusinessLinkPage extends StatefulWidget {
  const IhizBusinessLinkPage({
    super.key,
    this.initialSerial,
    this.service,
  });

  final String? initialSerial;
  final IhizBusinessAccountService? service;

  @override
  State<IhizBusinessLinkPage> createState() => _IhizBusinessLinkPageState();
}

class _IhizBusinessLinkPageState extends State<IhizBusinessLinkPage> {
  late final IhizBusinessAccountService _service =
      widget.service ?? IhizBusinessAccountService.instance;

  final _serial = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  Map<String, dynamic>? _found;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final seed = IhizBusinessSerial.normalize(widget.initialSerial);
    if (seed.isNotEmpty) _serial.text = seed;
    if (IhizBusinessSerial.isValid(seed)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _find());
    }
  }

  @override
  void dispose() {
    _serial.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _goLanding() {
    IbulRouter.go(context, IhizRoutePaths.landing);
  }

  Future<void> _find() async {
    final code = IhizBusinessSerial.normalize(_serial.text);
    if (!IhizBusinessSerial.isValid(code)) {
      setState(() => _error = 'Geçerli bir işletme seri no girin (ISL-XXXXXX).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _found = null;
    });
    try {
      final result = await _service.lookupBySerial(code);
      if (!mounted) return;
      if (result['found'] != true) {
        setState(() {
          _error = result['error'] == 'rate_limited'
              ? 'Çok fazla deneme. Lütfen sonra tekrar deneyin.'
              : 'Bu seri numarasıyla işletme bulunamadı.';
        });
        return;
      }
      setState(() => _found = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = IhizBusinessAccountService.describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loginAndLink() async {
    final code = IhizBusinessSerial.normalize(_serial.text);
    if (_found == null) {
      setState(() => _error = 'Önce işletmeyi bulun.');
      return;
    }
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'E-posta ve şifre girin.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final linked = await _service.signInAndLink(
        serial: code,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      final storeId = linked['store_id']?.toString() ?? '';
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => IhizBusinessAdminPage(
            storeId: storeId,
            service: _service,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = IhizBusinessAccountService.describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = IhizBrand.isMobile(MediaQuery.sizeOf(context).width);
    final foundName = (_found?['business_name'] ?? '').toString();
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: IhizBrand.line),
    );
    return IhizSubpageScaffold(
      header: IhizHeader(
        onHome: _goLanding,
        onHowItWorks: _goLanding,
        onTracking: _goLanding,
        onBusinessJoin: () {},
        onLogin: _goLanding,
        onCourierApply: _goLanding,
      ),
      body: IhizSectionPadding(
        top: compact ? 24 : 36,
        bottom: compact ? 28 : 48,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: IhizBrand.line),
                boxShadow: IhizBrand.cardShadow,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 20 : 40,
                  compact ? 28 : 40,
                  compact ? 20 : 40,
                  compact ? 24 : 36,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const IhizSectionHeader(
                      eyebrow: 'İŞLETME BAĞLA',
                      title: 'İBUL mağazanızı İHIZ’e bağlayın',
                      subtitle:
                          'İşletme seri numarasını girin, mağazayı bulun, ardından e-posta ve şifre ile bağlayın.',
                    ),
                    SizedBox(height: compact ? 22 : 28),
                    TextField(
                      controller: _serial,
                      textCapitalization: TextCapitalization.characters,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        labelText: 'İşletme seri no',
                        hintText: 'ISL-XXXXXX',
                        filled: true,
                        fillColor: IhizBrand.surface,
                        prefixIcon: const Icon(Icons.qr_code_2_rounded),
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: IhizBrand.blue,
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    IhizPrimaryButton(
                      label: _busy && _found == null
                          ? 'Aranıyor...'
                          : 'İşletmeyi Bul',
                      icon: Icons.search_rounded,
                      onPressed: _busy ? () {} : _find,
                      expanded: true,
                    ),
                    if (foundName.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text(
                        'Bulunan işletme: $foundName',
                        style: const TextStyle(
                          color: IhizBrand.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if ((_found?['city'] ?? '').toString().isNotEmpty)
                        Text(
                          [
                            _found?['city'],
                            _found?['district'],
                          ].where((v) => (v ?? '').toString().isNotEmpty).join(' / '),
                          style: const TextStyle(
                            color: IhizBrand.inkSoft,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: 'E-posta',
                          filled: true,
                          fillColor: IhizBrand.surface,
                          border: fieldBorder,
                          enabledBorder: fieldBorder,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: 'Şifre',
                          filled: true,
                          fillColor: IhizBrand.surface,
                          border: fieldBorder,
                          enabledBorder: fieldBorder,
                        ),
                      ),
                      const SizedBox(height: 14),
                      IhizPrimaryButton(
                        label: _busy ? 'Bağlanıyor...' : 'İşletmeyi Bağla',
                        icon: Icons.link_rounded,
                        onPressed: _busy ? () {} : _loginAndLink,
                        expanded: true,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFB42318),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      footer: IhizFooter(
        onHome: _goLanding,
        onHowItWorks: _goLanding,
        onCourierApply: _goLanding,
        onBusinessJoin: () {},
        onTracking: _goLanding,
        onReturnToIbul: () {
          IbulRouter.go(context, '/home');
        },
      ),
    );
  }
}
