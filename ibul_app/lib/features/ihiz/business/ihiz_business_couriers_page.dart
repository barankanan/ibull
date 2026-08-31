import 'package:flutter/material.dart';

import '../../../app/ibul_router.dart';
import '../../../services/ihiz_business_account_service.dart';
import '../delivery/ihiz_route_paths.dart';
import '../shell/ihiz_footer.dart';
import '../shell/ihiz_header.dart';
import '../shell/ihiz_subpage_scaffold.dart';
import '../widgets/ihiz_landing_widgets.dart';

class IhizBusinessCouriersPage extends StatefulWidget {
  const IhizBusinessCouriersPage({
    super.key,
    required this.storeId,
    this.service,
  });

  final String storeId;
  final IhizBusinessAccountService? service;

  @override
  State<IhizBusinessCouriersPage> createState() =>
      _IhizBusinessCouriersPageState();
}

class _IhizBusinessCouriersPageState extends State<IhizBusinessCouriersPage> {
  late final IhizBusinessAccountService _service =
      widget.service ?? IhizBusinessAccountService.instance;

  List<Map<String, dynamic>> _directory = const [];
  final Set<String> _selected = <String>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final directory = await _service.approvedCouriers();
    final assigned = await _service.storeCouriers(widget.storeId);
    if (!mounted) return;
    setState(() {
      _directory = directory;
      _selected
        ..clear()
        ..addAll(
          assigned
              .where((row) => row['is_selected'] == true)
              .map((row) => row['courier_user_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty),
        );
      _loading = false;
    });
  }

  void _goLanding() {
    IbulRouter.go(context, IhizRoutePaths.landing);
  }

  Future<void> _toggle(String courierId, bool selected) async {
    await _service.setStoreCourier(
      storeId: widget.storeId,
      courierUserId: courierId,
      selected: selected,
    );
    if (!mounted) return;
    setState(() {
      if (selected) {
        _selected.add(courierId);
      } else {
        _selected.remove(courierId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  eyebrow: 'KURYE YÖNETİMİ',
                  title: 'Bu mağazanın teslimatlarında kullanılacak kuryeler',
                  subtitle:
                      'Yalnızca onaylı İHIZ kuryeleri listelenir. Seçilen kuryeler işletme havuzunu oluşturur.',
                ),
                const SizedBox(height: 16),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_directory.isEmpty)
                  const Text(
                    'Seçilebilir onaylı kurye bulunamadı.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  )
                else
                  for (final courier in _directory)
                    CheckboxListTile(
                      value: _selected.contains(
                        courier['user_id']?.toString() ?? '',
                      ),
                      onChanged: (value) {
                        final id = courier['user_id']?.toString() ?? '';
                        if (id.isEmpty) return;
                        _toggle(id, value == true);
                      },
                      title: Text(
                        (courier['full_name'] ?? 'Kurye').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        [
                          courier['city'],
                          courier['district'],
                        ].where((part) => (part ?? '').toString().trim().isNotEmpty).join(' / '),
                      ),
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
