import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../services/ihiz_business_account_service.dart';
import '../../../ihiz/business/ihiz_business_admin_page.dart';
import 'seller_store_profile_dashboard_widgets.dart';

class IhizStoreProfileCard extends StatefulWidget {
  const IhizStoreProfileCard({
    super.key,
    required this.storeId,
    this.service,
  });

  final String storeId;
  final IhizBusinessAccountService? service;

  @override
  State<IhizStoreProfileCard> createState() => _IhizStoreProfileCardState();
}

class _IhizStoreProfileCardState extends State<IhizStoreProfileCard> {
  late final IhizBusinessAccountService _service =
      widget.service ?? IhizBusinessAccountService.instance;

  String? _serial;
  String? _status;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await _service.ensureSerial(storeId: widget.storeId);
      if (!mounted) return;
      setState(() {
        _serial = row['business_serial_no']?.toString();
        _status = row['ihiz_status']?.toString();
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

  void _openAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IhizBusinessAdminPage(storeId: widget.storeId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreProfileSectionCard(
      title: 'İHIZ işletme',
      subtitle: 'İşletme seri no ile İHIZ bağlama ve teslimat yönetimi',
      icon: Icons.delivery_dining_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            )
          else if (_error != null)
            Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            const Text(
              'İşletme seri no',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    _serial ?? '—',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Kopyala',
                  onPressed: _serial == null
                      ? null
                      : () => Clipboard.setData(ClipboardData(text: _serial!)),
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            if ((_status ?? '').isNotEmpty)
              Text(
                'İHIZ durum: $_status',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _openAdmin,
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('İHIZ Yönetim'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
