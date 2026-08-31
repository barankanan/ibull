import 'package:flutter/material.dart';

import '../../../app/ibul_router.dart';
import '../../../services/ihiz_business_account_service.dart';
import '../delivery/ihiz_route_paths.dart';
import '../shell/ihiz_footer.dart';
import '../shell/ihiz_header.dart';
import '../shell/ihiz_subpage_scaffold.dart';
import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';
import 'ihiz_business_admin_page.dart';
import 'ihiz_business_couriers_page.dart';

class IhizBusinessApplyPage extends StatefulWidget {
  const IhizBusinessApplyPage({super.key, this.service});

  final IhizBusinessAccountService? service;

  @override
  State<IhizBusinessApplyPage> createState() => _IhizBusinessApplyPageState();
}

class _IhizBusinessApplyPageState extends State<IhizBusinessApplyPage> {
  late final IhizBusinessAccountService _service =
      widget.service ?? IhizBusinessAccountService.instance;

  final _contactName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _region = TextEditingController();
  final _notes = TextEditingController();
  final _courierCount = TextEditingController();

  List<Map<String, dynamic>> _stores = const [];
  Map<String, dynamic>? _account;
  String? _storeId;
  bool _hasOwnCouriers = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  @override
  void dispose() {
    _contactName.dispose();
    _phone.dispose();
    _email.dispose();
    _region.dispose();
    _notes.dispose();
    _courierCount.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    final stores = await _service.ownedStores();
    final account = await _service.currentAccount();
    if (!mounted) return;
    setState(() {
      _stores = stores;
      _account = account;
      _storeId = account?['store_id']?.toString() ??
          (stores.isNotEmpty ? stores.first['seller_id']?.toString() : null);
      _loading = false;
    });
  }

  void _goLanding() {
    IbulRouter.go(context, IhizRoutePaths.landing);
  }

  String _storeName(Map<String, dynamic> store) {
    return (store['business_name'] ?? 'Mağaza').toString();
  }

  Future<void> _apply() async {
    final storeId = (_storeId ?? '').trim();
    if (storeId.isEmpty) {
      setState(() => _error = 'Bağlanacak İBUL mağazasını seçin.');
      return;
    }
    final selected = _stores.cast<Map<String, dynamic>?>().firstWhere(
      (store) => store?['seller_id']?.toString() == storeId,
      orElse: () => null,
    );
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.apply(
        storeId: storeId,
        businessName: _storeName(selected ?? {'business_name': ''}),
        contactName: _contactName.text,
        contactPhone: _phone.text,
        contactEmail: _email.text,
        hasOwnCouriers: _hasOwnCouriers,
        courierCount: int.tryParse(_courierCount.text.trim()),
        deliveryRegion: _region.text,
        notes: _notes.text,
      );
      await _hydrate();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate() async {
    final storeId = (_storeId ?? '').trim();
    if (storeId.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _service.activate(storeId);
      await _hydrate();
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
    final status = (_account?['status'] ?? '').toString();
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const IhizSectionHeader(
                        eyebrow: 'İŞLETME OLARAK KULLAN',
                        title: 'İBUL mağazanızı İHIZ’e bağlayın',
                        subtitle:
                            'Ödeme alınmaz. Başvuru sonrası hesabınızı etkinleştirip kurye havuzunu seçersiniz.',
                      ),
                      const SizedBox(height: 18),
                      if (_stores.isEmpty)
                        const Text(
                          'Bu hesapla yetkili olduğunuz bir İBUL mağazası bulunamadı.',
                          style: TextStyle(
                            color: IhizBrand.inkSoft,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else ...[
                        const Text(
                          'İBUL Mağazamı Bağla',
                          style: TextStyle(
                            color: IhizBrand.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final store in _stores)
                          RadioListTile<String>(
                            value: store['seller_id'].toString(),
                            groupValue: _storeId,
                            onChanged: (value) =>
                                setState(() => _storeId = value),
                            title: Text(_storeName(store)),
                          ),
                        _field(_contactName, 'İletişim adı'),
                        _field(_phone, 'Telefon'),
                        _field(_email, 'E-posta'),
                        _field(_region, 'Teslimat bölgesi'),
                        SwitchListTile(
                          value: _hasOwnCouriers,
                          onChanged: (value) =>
                              setState(() => _hasOwnCouriers = value),
                          title: const Text('Mevcut kurye sistemimiz var'),
                        ),
                        if (_hasOwnCouriers)
                          _field(_courierCount, 'Kurye sayısı', numeric: true),
                        _field(_notes, 'Not', maxLines: 3),
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFFB42318),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 12),
                        IhizPrimaryButton(
                          label: _busy ? 'Kaydediliyor...' : 'Başvur',
                          icon: Icons.storefront_rounded,
                          onPressed: _busy ? () {} : _apply,
                          expanded: compact,
                        ),
                        if (status.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Durum: $status',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: IhizBrand.ink,
                            ),
                          ),
                        ],
                        if (status == 'pending') ...[
                          const SizedBox(height: 12),
                          IhizSecondaryButton(
                            label: 'Hesabı etkinleştir',
                            onPressed: _busy ? () {} : _activate,
                            expanded: compact,
                          ),
                        ],
                        if (status == 'active') ...[
                          const SizedBox(height: 12),
                          IhizPrimaryButton(
                            label: 'İHIZ Yönetim',
                            icon: Icons.admin_panel_settings_outlined,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => IhizBusinessAdminPage(
                                    storeId: _storeId!,
                                  ),
                                ),
                              );
                            },
                            expanded: compact,
                          ),
                          const SizedBox(height: 12),
                          IhizSecondaryButton(
                            label: 'Kurye Yönetimi',
                            icon: Icons.groups_rounded,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => IhizBusinessCouriersPage(
                                    storeId: _storeId!,
                                  ),
                                ),
                              );
                            },
                            expanded: compact,
                          ),
                        ],
                      ],
                    ],
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

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool numeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
