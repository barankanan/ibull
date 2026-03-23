import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../services/admin_service.dart';

class IhizAdminPage extends StatefulWidget {
  const IhizAdminPage({super.key});

  @override
  State<IhizAdminPage> createState() => _IhizAdminPageState();
}

class _IhizAdminPageState extends State<IhizAdminPage> {
  final AdminService _adminService = AdminService();
  late Future<AdminIhizSnapshot> _snapshotFuture;
  String _selectedStatus = 'Tum';
  String _trackingSearch = '';
  String? _selectedShipmentId;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _adminService.getIhizOperationsSnapshot();
  }

  void _refresh() {
    setState(() {
      _snapshotFuture = _adminService.getIhizOperationsSnapshot();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: FutureBuilder<AdminIhizSnapshot>(
            future: _snapshotFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _buildError(snapshot.error);
              }
              final data = snapshot.data;
              if (data == null) {
                return _buildError('IHIZ snapshot bos dondu.');
              }
              return _buildContent(data);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'IHIZ Operasyon Merkezi',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Kurye havuzu, dagitim, teslim ve takip kalitesini tek panelden izleyin.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Yenile'),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/ihiz'),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Kurye Ekrani'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          elevation: 0,
          color: const Color(0xFFFEF2F2),
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'IHIZ verisi yuklenemedi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7F1D1D),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AdminIhizSnapshot data) {
    final availableStatuses = <String>{
      'Tum',
      ...data.statusBreakdown.map((item) => item.label),
    }.toList();
    final effectiveStatus = availableStatuses.contains(_selectedStatus)
        ? _selectedStatus
        : 'Tum';
    final visibleItems = effectiveStatus == 'Tum'
        ? data.recentShipments
        : data.recentShipments
              .where((item) => item.statusLabel == effectiveStatus)
              .toList(growable: false);
    final searchedItems = _trackingSearch.trim().isEmpty
        ? visibleItems
        : visibleItems
              .where((item) {
                final query = _trackingSearch.toLowerCase();
                return item.trackingNumber.toLowerCase().contains(query) ||
                    item.storeName.toLowerCase().contains(query) ||
                    item.productName.toLowerCase().contains(query) ||
                    item.id.toLowerCase().contains(query);
              })
              .toList(growable: false);
    final selectedShipment = _resolveSelectedShipment(
      searchedItems,
      fallback: data.recentShipments,
    );
    final activeCouriers = _buildActiveCouriers(
      data: data,
      visibleItems: searchedItems,
      selectedShipment: selectedShipment,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLiveOperationsBoard(
            data: data,
            visibleItems: searchedItems,
            selectedShipment: selectedShipment,
            activeCouriers: activeCouriers,
          ),
          const SizedBox(height: 18),
          _buildHero(data),
          const SizedBox(height: 18),
          _buildMetricGrid(data),
          const SizedBox(height: 18),
          _buildStatusFilter(availableStatuses),
          const SizedBox(height: 18),
          _buildRecentList(searchedItems),
        ],
      ),
    );
  }

  Widget _buildHero(AdminIhizSnapshot data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Anlik IHIZ Ozet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${data.windowLabel} icin ${_compact(data.totalIhizShipments)} kurye akisi izlendi. '
            'Tum gonderilerde IHIZ payi: ${_percent(data.ihizShareRatio)}',
            style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(AdminIhizSnapshot data) {
    final metrics = [
      _MetricItem(
        title: 'Havuz Bekleyen',
        value: _compact(data.readyPoolCount),
        subtitle: 'Paket alinmayi bekliyor',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF0369A1),
      ),
      _MetricItem(
        title: 'Yolda / Dagitim',
        value: _compact(data.inTransitCount),
        subtitle: 'Aktif teslimat akisinda',
        icon: Icons.delivery_dining_outlined,
        color: const Color(0xFF7C3AED),
      ),
      _MetricItem(
        title: '24 Saat Teslim',
        value: _compact(data.delivered24hCount),
        subtitle: 'Son 24 saatte kapanan',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF059669),
      ),
      _MetricItem(
        title: 'Sorunlu',
        value: _compact(data.problemCount),
        subtitle: 'Iade / iptal riski olan',
        icon: Icons.error_outline_rounded,
        color: const Color(0xFFDC2626),
      ),
      _MetricItem(
        title: '48 Saat Ustunde',
        value: _compact(data.delayedOpenCount),
        subtitle: 'Acik ama geciken gonderi',
        icon: Icons.timer_outlined,
        color: const Color(0xFFB45309),
      ),
      _MetricItem(
        title: 'Takip Kapsamasi',
        value: _percent(data.trackingCoverage),
        subtitle: 'Takip no bulunan IHIZ gonderi',
        icon: Icons.route_outlined,
        color: const Color(0xFF1D4ED8),
      ),
      _MetricItem(
        title: 'Sube Transferi',
        value: _compact(data.branchTransferCount),
        subtitle: 'Sube odakli operasyon',
        icon: Icons.store_mall_directory_outlined,
        color: const Color(0xFF0F766E),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth > 1300
            ? (constraints.maxWidth - 24) / 4
            : constraints.maxWidth > 900
            ? (constraints.maxWidth - 16) / 3
            : constraints.maxWidth > 600
            ? (constraints.maxWidth - 8) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: metrics
              .map((metric) {
                return SizedBox(
                  width: tileWidth,
                  child: _buildMetricTile(metric),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildMetricTile(_MetricItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 18, color: item.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: item.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilter(List<String> statuses) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: statuses
          .map((status) {
            final selected = status == _selectedStatus;
            return ChoiceChip(
              label: Text(status),
              selected: selected,
              onSelected: (_) => setState(() => _selectedStatus = status),
              selectedColor: const Color(0xFFDBEAFE),
              side: BorderSide(
                color: selected
                    ? const Color(0xFF3B82F6)
                    : const Color(0xFFE5E7EB),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildRecentList(List<AdminIhizShipment> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Son IHIZ Gonderileri',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Secili filtrede kayit yok.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            ...items.map((item) {
              final statusColor = _statusColor(item.statusLabel);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusIcon(item.statusLabel),
                      color: statusColor,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.storeName} - ${item.productName}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${item.cargoCompany} | ${_formatDate(item.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: item.hasTracking
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.hasTracking ? 'Takip var' : 'Takip yok',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLiveOperationsBoard({
    required AdminIhizSnapshot data,
    required List<AdminIhizShipment> visibleItems,
    required AdminIhizShipment? selectedShipment,
    required List<_CourierLivePoint> activeCouriers,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1180;
        final queuePanel = _buildShipmentQueuePanel(
          items: visibleItems,
          selectedShipment: selectedShipment,
        );
        final liveMapPanel = _buildLiveMapPanel(
          data: data,
          selectedShipment: selectedShipment,
          activeCouriers: activeCouriers,
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 340, child: queuePanel),
              const SizedBox(width: 12),
              Expanded(child: liveMapPanel),
            ],
          );
        }

        return Column(
          children: [liveMapPanel, const SizedBox(height: 12), queuePanel],
        );
      },
    );
  }

  Widget _buildShipmentQueuePanel({
    required List<AdminIhizShipment> items,
    required AdminIhizShipment? selectedShipment,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Canli Takip Havuzu',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFEFF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${items.length} kayit',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0E7490),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => setState(() => _trackingSearch = value),
              decoration: InputDecoration(
                hintText: 'Takip no veya magazada ara',
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Arama/filtreye uygun gonderi yok.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              )
            else
              ...items.take(6).map((item) {
                final isSelected = selectedShipment?.id == item.id;
                return _buildShipmentQueueCard(item, isSelected: isSelected);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentQueueCard(
    AdminIhizShipment item, {
    required bool isSelected,
  }) {
    final color = _statusColor(item.statusLabel);
    return InkWell(
      onTap: () => setState(() => _selectedShipmentId = item.id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _trackingLabel(item),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.statusLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.storeName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.productName,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  item.hasTracking ? Icons.route_rounded : Icons.route_outlined,
                  size: 15,
                  color: item.hasTracking
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Text(
                  item.hasTracking ? 'Takip aktif' : 'Takip bekleniyor',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(item.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveMapPanel({
    required AdminIhizSnapshot data,
    required AdminIhizShipment? selectedShipment,
    required List<_CourierLivePoint> activeCouriers,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Canli Kurye Haritasi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${activeCouriers.length} aktif kurye',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Harita anlik operasyon durumunu sabit gorunumde gosterir.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500),
            ),
            const SizedBox(height: 12),
            _buildMapView(activeCouriers: activeCouriers),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildShipmentInfoCard(
                          data: data,
                          selectedShipment: selectedShipment,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildRouteTimelineCard(
                          selectedShipment: selectedShipment,
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildShipmentInfoCard(
                      data: data,
                      selectedShipment: selectedShipment,
                    ),
                    const SizedBox(height: 12),
                    _buildRouteTimelineCard(selectedShipment: selectedShipment),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView({required List<_CourierLivePoint> activeCouriers}) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CourierMapPainter(couriers: activeCouriers),
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                children: const [
                  _MapControlButton(icon: Icons.add_rounded),
                  SizedBox(height: 8),
                  _MapControlButton(icon: Icons.remove_rounded),
                  SizedBox(height: 8),
                  _MapControlButton(icon: Icons.my_location_rounded),
                ],
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: activeCouriers
                    .take(4)
                    .map((courier) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFD1D5DB)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: courier.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              courier.label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentInfoCard({
    required AdminIhizSnapshot data,
    required AdminIhizShipment? selectedShipment,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sevkiyat Bilgisi',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Takip No', _trackingLabel(selectedShipment)),
          _buildInfoRow(
            'Kurye',
            selectedShipment?.cargoCompany ?? 'IHIZ Kuryesi',
          ),
          _buildInfoRow('Durum', selectedShipment?.statusLabel ?? 'Beklemede'),
          _buildInfoRow(
            'Teslim Adimi',
            selectedShipment?.shipmentStep.isNotEmpty == true
                ? selectedShipment!.shipmentStep
                : 'Dagitim',
          ),
          _buildInfoRow('Aktif Dagitim', _compact(data.inTransitCount)),
          _buildInfoRow('Takip Kapsamasi', _percent(data.trackingCoverage)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 115,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTimelineCard({
    required AdminIhizShipment? selectedShipment,
  }) {
    final created = selectedShipment?.createdAt?.toLocal() ?? DateTime.now();
    final timeline = [
      ('Havuzda', created.subtract(const Duration(hours: 2))),
      ('Kurye Alimi', created.subtract(const Duration(hours: 1))),
      (
        selectedShipment?.statusLabel.isNotEmpty == true
            ? selectedShipment!.statusLabel
            : 'Dagitimda',
        created,
      ),
      ('Teslimat Hedefi', created.add(const Duration(hours: 1))),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rota Detayi',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...timeline.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == timeline.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Column(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: index <= 2
                              ? const Color(0xFFFACC15)
                              : const Color(0xFFD1D5DB),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 24,
                          color: const Color(0xFFE2E8F0),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 0.5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _formatDate(item.$2),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  AdminIhizShipment? _resolveSelectedShipment(
    List<AdminIhizShipment> items, {
    required List<AdminIhizShipment> fallback,
  }) {
    if (items.isNotEmpty) {
      if (_selectedShipmentId != null) {
        for (final item in items) {
          if (item.id == _selectedShipmentId) return item;
        }
      }
      return items.first;
    }
    if (fallback.isEmpty) return null;
    if (_selectedShipmentId != null) {
      for (final item in fallback) {
        if (item.id == _selectedShipmentId) return item;
      }
    }
    return fallback.first;
  }

  List<_CourierLivePoint> _buildActiveCouriers({
    required AdminIhizSnapshot data,
    required List<AdminIhizShipment> visibleItems,
    required AdminIhizShipment? selectedShipment,
  }) {
    final transitItems = visibleItems
        .where((item) => _isTransitLike(item.statusLabel, item.shipmentStep))
        .toList(growable: false);
    final source = transitItems.isNotEmpty
        ? transitItems
        : [
            ...?(selectedShipment == null ? null : [selectedShipment]),
            ...data.recentShipments.where(
              (item) => _isTransitLike(item.statusLabel, item.shipmentStep),
            ),
          ];
    final base = source.isNotEmpty ? source : data.recentShipments;
    final count = math.max(
      1,
      math.min(
        6,
        math.max(data.inTransitCount, base.isEmpty ? 1 : base.length),
      ),
    );
    const palette = [
      Color(0xFFFACC15),
      Color(0xFF22C55E),
      Color(0xFF38BDF8),
      Color(0xFFFB7185),
      Color(0xFFA78BFA),
      Color(0xFF60A5FA),
    ];

    return List.generate(count, (index) {
      final shipment = base.isNotEmpty ? base[index % base.length] : null;
      return _CourierLivePoint(
        id: 'courier_$index',
        label: 'Kurye ${index + 1}',
        phase: ((index + 1) * 0.17) % 1,
        color: palette[index % palette.length],
        shipment: shipment,
      );
    });
  }

  bool _isTransitLike(String status, String step) {
    final normalized = '$status $step'.toLowerCase();
    return normalized.contains('yolda') ||
        normalized.contains('dagitim') ||
        normalized.contains('transit') ||
        normalized.contains('kurye');
  }

  String _trackingLabel(AdminIhizShipment? shipment) {
    if (shipment == null) return '#-';
    final tracking = shipment.trackingNumber.trim();
    if (tracking.isNotEmpty) return tracking;
    final fallback = shipment.id.trim();
    if (fallback.length >= 6) return '#${fallback.substring(0, 6)}';
    return '#$fallback';
  }

  String _compact(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }

  String _percent(double ratio) => '%${(ratio * 100).toStringAsFixed(1)}';

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Teslim edildi':
        return const Color(0xFF16A34A);
      case 'Dagitimda':
      case 'Yolda':
        return const Color(0xFF2563EB);
      case 'Hazirlandi':
      case 'Hazirlaniyor':
        return const Color(0xFFB45309);
      case 'Sorunlu / Iade':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Teslim edildi':
        return Icons.check_circle_outline_rounded;
      case 'Dagitimda':
      case 'Yolda':
        return Icons.local_shipping_outlined;
      case 'Hazirlandi':
      case 'Hazirlaniyor':
        return Icons.inventory_2_outlined;
      case 'Sorunlu / Iade':
        return Icons.warning_amber_rounded;
      default:
        return Icons.tune_rounded;
    }
  }
}

class _MetricItem {
  const _MetricItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _CourierLivePoint {
  const _CourierLivePoint({
    required this.id,
    required this.label,
    required this.phase,
    required this.color,
    required this.shipment,
  });

  final String id;
  final String label;
  final double phase;
  final Color color;
  final AdminIhizShipment? shipment;
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Icon(icon, color: const Color(0xFF334155), size: 18),
    );
  }
}

class _CourierMapPainter extends CustomPainter {
  _CourierMapPainter({required this.couriers});

  final List<_CourierLivePoint> couriers;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFE2E8F0);
    canvas.drawRect(Offset.zero & size, background);

    _drawParks(canvas, size);
    _drawRiver(canvas, size);
    _drawRoads(canvas, size);

    final routePoints = [
      Offset(size.width * 0.2, size.height * 0.2),
      Offset(size.width * 0.32, size.height * 0.35),
      Offset(size.width * 0.44, size.height * 0.31),
      Offset(size.width * 0.54, size.height * 0.47),
      Offset(size.width * 0.69, size.height * 0.42),
      Offset(size.width * 0.8, size.height * 0.58),
    ];

    final routePath = Path()
      ..moveTo(routePoints.first.dx, routePoints.first.dy);
    for (var i = 1; i < routePoints.length; i++) {
      routePath.lineTo(routePoints[i].dx, routePoints[i].dy);
    }

    _drawDashedPath(
      canvas,
      routePath,
      color: const Color(0xFF111827).withValues(alpha: 0.55),
      strokeWidth: 3,
      dashLength: 9,
      gapLength: 6,
    );

    final highlightProgress = couriers.isEmpty ? 0.35 : couriers.first.phase;
    final highlightPath = _subPathUntil(routePath, highlightProgress);
    canvas.drawPath(
      highlightPath,
      Paint()
        ..color = const Color(0xFF1E293B)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    _drawRouteEndpoint(
      canvas,
      routePoints.first,
      fill: const Color(0xFF0EA5E9),
      stroke: Colors.white,
    );
    _drawRouteEndpoint(
      canvas,
      routePoints.last,
      fill: const Color(0xFF334155),
      stroke: Colors.white,
    );

    for (final courier in couriers) {
      final point = _pointOnPath(routePath, courier.phase);
      canvas.drawCircle(
        point,
        22,
        Paint()..color = courier.color.withValues(alpha: 0.15),
      );
      canvas.drawCircle(point, 15, Paint()..color = courier.color);
      canvas.drawCircle(point, 6, Paint()..color = const Color(0xFF0F172A));
      canvas.drawCircle(
        point,
        15,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawParks(Canvas canvas, Size size) {
    final parkPaint = Paint()
      ..color = const Color(0xFF86EFAC).withValues(alpha: 0.55);
    final parks = [
      Rect.fromLTWH(size.width * 0.1, size.height * 0.18, 60, 30),
      Rect.fromLTWH(size.width * 0.3, size.height * 0.1, 70, 34),
      Rect.fromLTWH(size.width * 0.6, size.height * 0.26, 52, 32),
      Rect.fromLTWH(size.width * 0.78, size.height * 0.18, 58, 30),
      Rect.fromLTWH(size.width * 0.2, size.height * 0.64, 75, 34),
      Rect.fromLTWH(size.width * 0.52, size.height * 0.72, 62, 32),
      Rect.fromLTWH(size.width * 0.78, size.height * 0.65, 72, 36),
    ];
    for (final park in parks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(park, const Radius.circular(6)),
        parkPaint,
      );
    }
  }

  void _drawRiver(Canvas canvas, Size size) {
    final riverPath = Path()
      ..moveTo(-20, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.25,
        size.width * 0.52,
        size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.66,
        size.width + 20,
        size.height * 0.42,
      )
      ..lineTo(size.width + 20, size.height * 0.66)
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.9,
        size.width * 0.5,
        size.height * 0.65,
      )
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.42,
        -20,
        size.height * 0.72,
      )
      ..close();

    canvas.drawPath(
      riverPath,
      Paint()..color = const Color(0xFF93C5FD).withValues(alpha: 0.85),
    );
  }

  void _drawRoads(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.84)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 10; i++) {
      final y = size.height * (0.08 + (i * 0.085));
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y - (i % 2 == 0 ? 8 : -6)),
        roadPaint,
      );
    }
    for (var i = 0; i < 12; i++) {
      final x = size.width * (0.05 + (i * 0.08));
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + (i % 2 == 0 ? 8 : -8), size.height),
        roadPaint,
      );
    }
  }

  void _drawRouteEndpoint(
    Canvas canvas,
    Offset point, {
    required Color fill,
    required Color stroke,
  }) {
    canvas.drawCircle(point, 9, Paint()..color = fill);
    canvas.drawCircle(
      point,
      9,
      Paint()
        ..color = stroke
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawDashedPath(
    Canvas canvas,
    Path source, {
    required Color color,
    required double strokeWidth,
    required double dashLength,
    required double gapLength,
  }) {
    final dashPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(metric.length, distance + dashLength);
        canvas.drawPath(metric.extractPath(distance, next), dashPaint);
        distance = next + gapLength;
      }
    }
  }

  Path _subPathUntil(Path source, double progress) {
    final metric = source.computeMetrics().first;
    final length = metric.length * progress.clamp(0.0, 1.0);
    return metric.extractPath(0, length);
  }

  Offset _pointOnPath(Path source, double progress) {
    final metric = source.computeMetrics().first;
    final tangent = metric.getTangentForOffset(
      metric.length * progress.clamp(0.0, 1.0),
    );
    return tangent?.position ?? Offset.zero;
  }

  @override
  bool shouldRepaint(covariant _CourierMapPainter oldDelegate) {
    if (oldDelegate.couriers.length != couriers.length) return true;
    for (var i = 0; i < couriers.length; i++) {
      if (couriers[i].phase != oldDelegate.couriers[i].phase) return true;
      if (couriers[i].id != oldDelegate.couriers[i].id) return true;
    }
    return false;
  }
}
