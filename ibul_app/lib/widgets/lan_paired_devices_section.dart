import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/restaurant_offline/restaurant_lan_host.dart';

enum LanDeviceStatus { active, offline, expired, revoked }

/// "Aktif" means seen within [window]; the host moves `lastSeenAt` about once
/// a minute, so the window is a little more than two of those.
LanDeviceStatus lanDeviceStatus(
  LanDeviceInfo device,
  DateTime now, {
  Duration window = const Duration(minutes: 2),
}) {
  if (device.revoked) return LanDeviceStatus.revoked;
  final expires = device.expiresAt;
  if (expires != null && !now.isBefore(expires)) return LanDeviceStatus.expired;
  final seen = device.lastSeenAt;
  if (seen != null && now.difference(seen) <= window) {
    return LanDeviceStatus.active;
  }
  return LanDeviceStatus.offline;
}

/// "Bağlı Cihazlar": the devices paired to this computer, read from the
/// running LAN host. Revoking is offered only when [canManageDevices] is set.
class LanPairedDevicesSection extends StatefulWidget {
  const LanPairedDevicesSection({
    super.key,
    required this.loadDevices,
    this.revoke,
    this.changes,
    this.canManageDevices = false,
    this.staffNames = const <String, String>{},
    this.permissionSummaries = const <String, String>{},
    this.hubAddress,
    this.refreshEvery = const Duration(seconds: 10),
    this.clock,
    this.emptyText = 'Henüz eşleştirilmiş cihaz yok',
  });

  /// Reads the live host. The host is looked up on every read, so a hub that
  /// was reopened on a new address (new instance) is followed.
  static Widget forHost({
    Key? key,
    bool canManageDevices = false,
    Map<String, String> staffNames = const <String, String>{},
  }) {
    final host = RestaurantLanHostRegistry.current;
    if (host == null && !deviceMayRunLocalPrintBridge(defaultTargetPlatform)) {
      return const SizedBox.shrink();
    }
    return LanPairedDevicesSection(
      key: key,
      loadDevices: () =>
          RestaurantLanHostRegistry.current?.deviceInfos ??
          const <LanDeviceInfo>[],
      revoke: (id) async =>
          await RestaurantLanHostRegistry.current?.revokeDevice(id) ?? false,
      changes: host?.devicesRevision,
      canManageDevices: canManageDevices,
      staffNames: staffNames,
      hubAddress: () {
        final h = RestaurantLanHostRegistry.current;
        return h?.listening == true ? '${h!.boundAddress}:${h.port}' : null;
      },
      emptyText: host == null
          ? 'Yerel merkez kapalı. Cihaz listesi merkez açıkken görünür.'
          : 'Henüz eşleştirilmiş cihaz yok',
      refreshEvery: const Duration(seconds: 3),
    );
  }

  final List<LanDeviceInfo> Function() loadDevices;
  final Future<bool> Function(String deviceId)? revoke;
  final Listenable? changes;
  final bool canManageDevices;

  /// staff id -> display name; unknown ids show a short id.
  final Map<String, String> staffNames;

  /// Optional staff id -> one-line permission summary. Omitted when absent.
  final Map<String, String> permissionSummaries;
  final String? Function()? hubAddress;
  final Duration refreshEvery;
  final DateTime Function()? clock;
  final String emptyText;

  @override
  State<LanPairedDevicesSection> createState() =>
      _LanPairedDevicesSectionState();
}

class _LanPairedDevicesSectionState extends State<LanPairedDevicesSection> {
  static const _purple = Color(0xFF7C3AED);
  Timer? _timer;
  String? _notice;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    widget.changes?.addListener(_refresh);
    _timer = Timer.periodic(widget.refreshEvery, (_) => _refresh());
  }

  @override
  void didUpdateWidget(LanPairedDevicesSection old) {
    super.didUpdateWidget(old);
    if (!identical(old.changes, widget.changes)) {
      old.changes?.removeListener(_refresh);
      widget.changes?.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.changes?.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  static String short(String value) =>
      value.length > 8 ? value.substring(0, 8) : value;

  static String formatTime(DateTime? time) {
    if (time == null) return 'Henüz yok';
    final t = time.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  Future<void> _confirmRevoke(LanDeviceInfo device) async {
    final name = (device.deviceName ?? '').isEmpty
        ? 'Bu cihaz'
        : device.deviceName!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bağlantı iptal edilsin mi?'),
        content: Text(
          '$name artık bu merkeze erişemez. Yeniden bağlanmak için '
          'cihazın tekrar eşleştirilmesi gerekir.',
        ),
        actions: [
          TextButton(
            key: const Key('lan_device_revoke_cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            key: const Key('lan_device_revoke_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Bağlantıyı iptal et'),
          ),
        ],
      ),
    );
    final revoke = widget.revoke;
    if (ok != true || revoke == null || !mounted) return;
    bool done;
    try {
      done = await revoke(device.deviceId);
    } catch (_) {
      done = false;
    }
    if (!mounted) return;
    setState(() => _notice = done ? 'Bağlantı iptal edildi.' : 'Bağlantı iptal edilemedi.');
  }

  ({IconData icon, String label}) _platform(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'ios':
        return (icon: Icons.phone_iphone, label: 'iPhone');
      case 'android':
        return (icon: Icons.android, label: 'Android');
      case 'macos':
        return (icon: Icons.laptop_mac, label: 'Mac');
      case '':
        return (icon: Icons.devices_other, label: 'Bilinmiyor');
      default:
        return (icon: Icons.devices_other, label: raw!);
    }
  }

  Widget _chip(LanDeviceStatus status) {
    final (label, color) = switch (status) {
      LanDeviceStatus.active => ('Aktif', const Color(0xFF16A34A)),
      LanDeviceStatus.offline => ('Bağlantı yok', const Color(0xFF6B7280)),
      LanDeviceStatus.expired => ('Yetki süresi dolmuş', const Color(0xFFD97706)),
      LanDeviceStatus.revoked => ('İptal edildi', const Color(0xFFDC2626)),
    };
    return Container(
      key: const Key('lan_device_status'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _field(String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _card(LanDeviceInfo device, String? hub, double maxWidth) {
    final status = lanDeviceStatus(device, _now());
    final platform = _platform(device.platform);
    final wide = maxWidth >= 640;
    final fieldWidth = wide ? (maxWidth - 24 - 16 * 2) / 3 : maxWidth - 24;
    final staff = widget.staffNames[device.staffId]?.trim();
    final branch = (device.branchId ?? '').trim();
    final permissions = widget.permissionSummaries[device.staffId]?.trim() ?? '';
    return Container(
      key: Key('lan_device_${device.deviceId}'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE9D5FF)),
        color: const Color(0xFFFAF5FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(platform.icon, color: _purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (device.deviceName ?? '').isEmpty ? 'Adsız cihaz' : device.deviceName!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: _chip(status)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _field('Platform', platform.label, fieldWidth),
              _field(
                'Bağlı personel',
                (staff != null && staff.isNotEmpty) ? staff : short(device.staffId),
                fieldWidth,
              ),
              _field(
                'İşletme / Şube',
                branch.isEmpty ? 'Tüm şubeler' : 'Şube ${short(branch)}',
                fieldWidth,
              ),
              _field('Cihaz no', short(device.deviceId), fieldWidth),
              _field('Son bağlantı', formatTime(device.lastSeenAt), fieldWidth),
              _field('İlk eşleştirme', formatTime(device.pairedAt), fieldWidth),
              _field('LAN merkezi', hub ?? 'Merkez kapalı', fieldWidth),
              if (permissions.isNotEmpty) _field('Yetkiler', permissions, fieldWidth),
            ],
          ),
          if (status != LanDeviceStatus.revoked && widget.canManageDevices)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('lan_device_revoke_${device.deviceId}'),
                onPressed: () => _confirmRevoke(device),
                icon: const Icon(Icons.link_off, size: 18),
                label: const Text('Bağlantıyı iptal et'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devices = List<LanDeviceInfo>.of(widget.loadDevices())
      ..sort((a, b) {
        if (a.revoked != b.revoked) return a.revoked ? 1 : -1;
        final x = a.lastSeenAt ?? a.pairedAt;
        final y = b.lastSeenAt ?? b.pairedAt;
        return y.compareTo(x);
      });
    final hub = widget.hubAddress?.call();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bağlı Cihazlar',
              style: TextStyle(color: _purple, fontWeight: FontWeight.w700),
            ),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_notice!, key: const Key('lan_devices_notice')),
              ),
            if (devices.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(widget.emptyText, key: const Key('lan_devices_empty')),
              )
            else
              for (final device in devices) _card(device, hub, box.maxWidth),
            if (!widget.canManageDevices && devices.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Bağlantıyı yalnızca işletme sahibi veya yazıcı ayarı yetkisi '
                  'olan personel iptal edebilir.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
