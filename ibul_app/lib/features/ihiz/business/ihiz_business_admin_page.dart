import 'package:flutter/material.dart';

import '../../../app/ibul_router.dart';
import '../../../services/ihiz_business_account_service.dart';
import '../delivery/ihiz_route_paths.dart';
import '../shell/ihiz_footer.dart';
import '../shell/ihiz_header.dart';
import '../shell/ihiz_subpage_scaffold.dart';
import '../theme/ihiz_brand.dart';
import '../widgets/ihiz_landing_widgets.dart';
import 'ihiz_business_couriers_page.dart';
import 'ihiz_business_ops_panel.dart';

class IhizBusinessAdminPage extends StatefulWidget {
  const IhizBusinessAdminPage({
    super.key,
    this.storeId,
    this.embedded = false,
    this.service,
  });

  final String? storeId;
  final bool embedded;
  final IhizBusinessAccountService? service;

  @override
  State<IhizBusinessAdminPage> createState() => _IhizBusinessAdminPageState();
}

class _IhizBusinessAdminPageState extends State<IhizBusinessAdminPage> {
  late final IhizBusinessAccountService _service =
      widget.service ?? IhizBusinessAccountService.instance;

  List<Map<String, dynamic>> _stores = const [];
  String? _storeId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _storeId = widget.storeId;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await _service.listOps(storeId: widget.storeId);
      if (!mounted) return;
      final stores = (payload['stores'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
      setState(() {
        _stores = stores;
        _storeId ??= stores.isNotEmpty
            ? stores.first['store_id']?.toString()
            : widget.storeId;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = IhizBusinessAccountService.describeError(error);
        _loading = false;
      });
    }
  }

  void _goLanding() {
    IbulRouter.go(context, IhizRoutePaths.landing);
  }

  Map<String, dynamic>? get _selected {
    if (_stores.isEmpty) return null;
    return _stores.cast<Map<String, dynamic>?>().firstWhere(
      (row) => row?['store_id']?.toString() == _storeId,
      orElse: () => _stores.first,
    );
  }

  Widget _body() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Text(
        _error!,
        style: const TextStyle(
          color: Color(0xFFB42318),
          fontWeight: FontWeight.w700,
        ),
      );
    }
    final store = _selected;
    if (store == null) {
      return const Text(
        'Görüntülenecek İHIZ işletme kaydı yok.',
        style: TextStyle(
          color: IhizBrand.inkSoft,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    return IhizBusinessOpsPanel(
      store: store,
      stores: _stores,
      selectedStoreId: _storeId,
      onSelectStore: _stores.length > 1
          ? (value) => setState(() => _storeId = value)
          : null,
      onOpenCouriers: () {
        final id = (store['store_id'] ?? '').toString();
        if (id.isEmpty) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => IhizBusinessCouriersPage(storeId: id),
          ),
        );
      },
      onRefresh: _load,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _body();
    if (widget.embedded) {
      return ColoredBox(
        color: IhizBrand.surface,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const IhizSectionHeader(
              eyebrow: 'İHIZ İŞLETME',
              title: 'İşletme teslimatları',
              subtitle:
                  'Kurye havuzu, çıkan paketler, gönderilen paketler ve aktif teslimatlar.',
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      );
    }
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
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const IhizSectionHeader(
                  eyebrow: 'İHIZ İŞLETME YÖNETİMİ',
                  title: 'İşletme admin',
                  subtitle:
                      'Kuryeler, gelen paketler, çıkan paketler ve gönderilen paketler.',
                ),
                const SizedBox(height: 16),
                content,
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
}
