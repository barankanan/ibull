import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/search_telemetry_service.dart';
import '../../services/store_service.dart';

class MapAdminPage extends StatefulWidget {
  const MapAdminPage({super.key});

  @override
  State<MapAdminPage> createState() => _MapAdminPageState();
}

class _MapAdminPageState extends State<MapAdminPage> {
  final StoreService _storeService = StoreService();
  Future<_MapAdminDataset>? _datasetFuture;

  @override
  void initState() {
    super.initState();
    _datasetFuture = _loadDataset();
  }

  Future<_MapAdminDataset> _loadDataset() async {
    final stores = await _storeService.getStoresForMap();
    List<SearchTelemetryEvent> searches = const [];
    String? searchError;
    try {
      searches = await SearchTelemetryService.instance.getRecentSearches();
    } catch (error) {
      searchError = error.toString().replaceFirst('Exception: ', '');
    }
    return _MapAdminDataset(
      stores: stores,
      searches: searches,
      searchError: searchError,
    );
  }

  void _refresh() {
    setState(() {
      _datasetFuture = _loadDataset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_MapAdminDataset>(
      future: _datasetFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Harita verileri yuklenemedi: ${snapshot.error}',
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          );
        }

        final dataset =
            snapshot.data ??
            const _MapAdminDataset(stores: [], searches: [], searchError: null);
        final stores = _mapStores(dataset.stores);
        final hotspots = _buildRegionHotspots(stores, dataset.searches);
        final queryLocations = _buildQueryLocationPoints(
          hotspots,
          dataset.searches,
        );
        final visibleQueryLocations = queryLocations.take(60).toList();
        final center = _resolveCenter(stores, hotspots);
        final dailyTrend = _buildDailyTrend(dataset.searches);
        final themeBreakdown = _buildThemeBreakdown(dataset.searches);
        final topRegions = hotspots.take(6).toList();
        final topQueryLocations = queryLocations.take(8).toList();
        final recentSearches = dataset.searches.take(10).toList();
        final topQueries = _buildTopQueries(dataset.searches);
        final registeredCount = dataset.searches
            .where((event) => event.isRegistered)
            .length;
        final guestCount = dataset.searches.length - registeredCount;
        final anonymousRate = dataset.searches.isEmpty
            ? 0
            : ((guestCount / dataset.searches.length) * 100).round();
        final uniqueViewers = _countUniqueViewers(dataset.searches);
        final uniqueGuestViewers = _countUniqueViewers(
          dataset.searches.where((event) => !event.isRegistered),
        );
        final uniqueRegisteredViewers = _countUniqueViewers(
          dataset.searches.where((event) => event.isRegistered),
        );

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildHero(
              totalStores: stores.length,
              totalSearches: dataset.searches.length,
              hotspotCount: hotspots.length,
              totalSearchers: uniqueViewers,
              onRefresh: _refresh,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _metricCard(
                    title: 'Kayitli Magaza',
                    value: '${stores.length}',
                    subtitle: 'Haritada pinlenen aktif konum',
                    icon: Icons.storefront_rounded,
                    accent: const Color(0xFF6C63FF),
                    tint: const Color(0xFFEEF2FF),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _metricCard(
                    title: '30 Gun Arama',
                    value: '${dataset.searches.length}',
                    subtitle: 'Tum arama olaylari',
                    icon: Icons.travel_explore_rounded,
                    accent: const Color(0xFF06B6D4),
                    tint: const Color(0xFFECFEFF),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _metricCard(
                    title: 'Arayan Kisi',
                    value: '$uniqueViewers',
                    subtitle:
                        '$uniqueRegisteredViewers uyeli • $uniqueGuestViewers anonim',
                    icon: Icons.groups_2_rounded,
                    accent: const Color(0xFFF97316),
                    tint: const Color(0xFFFFF7ED),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _metricCard(
                    title: 'Aktif Bolge',
                    value: '${hotspots.length}',
                    subtitle: 'Arama gelen il/ilce noktasi',
                    icon: Icons.public_rounded,
                    accent: const Color(0xFF10B981),
                    tint: const Color(0xFFECFDF5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSearcherInsightBanner(
              totalSearches: dataset.searches.length,
              anonymousRate: anonymousRate,
              mappedQueryCount: queryLocations
                  .where((entry) => entry.point != null)
                  .length,
              unmappedQueryCount: queryLocations
                  .where((entry) => entry.point == null)
                  .length,
            ),
            if (dataset.searchError != null) ...[
              const SizedBox(height: 16),
              _warningBanner(dataset.searchError!),
            ],
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 8,
                  child: _buildMapPanel(
                    center: center,
                    stores: stores,
                    hotspots: hotspots,
                    queryLocations: visibleQueryLocations,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(flex: 4, child: _buildRegionPanel(topRegions)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: _buildTrendPanel(dailyTrend)),
                const SizedBox(width: 20),
                Expanded(flex: 5, child: _buildThemePanel(themeBreakdown)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: _buildRecentSearchPanel(recentSearches),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 5,
                  child: _buildStoreCoveragePanel(stores, hotspots),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: _buildQueryLocationPanel(topQueryLocations),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 6,
                  child: _buildRegionQueryMatrixPanel(topRegions),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTopQueriesPanel(topQueries),
            const SizedBox(height: 20),
            _buildExplanationPanel(
              topRegions: topRegions,
              totalSearches: dataset.searches.length,
              registeredCount: registeredCount,
            ),
          ],
        );
      },
    );
  }

  Widget _buildHero({
    required int totalStores,
    required int totalSearches,
    required int hotspotCount,
    required int totalSearchers,
    required VoidCallback onRefresh,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Magaza yogunlugu ve kullanici arama akislarini tek haritada izleyin.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Bolgesel Harita & Arama Kontrolu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$totalStores magaza pinden, $totalSearches arama olayindan, $totalSearchers farkli arayandan ve $hotspotCount hotspot bolgeden olusan canli yonetim gorunumu.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton.icon(
            onPressed: onRefresh,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'Veriyi Yenile',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _warningBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$message SQL kurulum dosyasi: SUPABASE_SEARCH_TELEMETRY.sql',
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPanel({
    required LatLng center,
    required List<_StoreMapPoint> stores,
    required List<_RegionHotspot> hotspots,
    required List<_QueryLocationPoint> queryLocations,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Magaza Haritasi & Arama Hotspotlari',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Mor pinler magazalari, turuncu halkalar bolgesel yogunlugu, mavi etiketler ise kullanicilarin nerede ne arattigini ve kac kisi oldugunu gosterir.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 520,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 6.5,
                  minZoom: 4,
                  maxZoom: 18,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.ibul.app',
                  ),
                  MarkerLayer(
                    markers: [
                      ...stores.map(
                        (store) => Marker(
                          width: 130,
                          height: 72,
                          point: store.location,
                          child: Tooltip(
                            message:
                                '${store.name}\n${store.city ?? 'Sehir yok'} • ${store.category ?? 'Kategori yok'}',
                            child: _storeMarker(store),
                          ),
                        ),
                      ),
                      ...hotspots
                          .where((hotspot) => hotspot.center != null)
                          .map(
                            (hotspot) => Marker(
                              width: 120,
                              height: 120,
                              point: hotspot.center!,
                              child: Tooltip(
                                message:
                                    '${hotspot.label}\n${hotspot.totalSearches} arama\n${hotspot.topQuery}',
                                child: _hotspotMarker(hotspot),
                              ),
                            ),
                          ),
                      ...queryLocations
                          .where((entry) => entry.point != null)
                          .map(
                            (entry) => Marker(
                              width: 164,
                              height: 92,
                              point: entry.point!,
                              child: Tooltip(
                                message:
                                    '${entry.query}\n${entry.regionLabel}\n${entry.uniqueViewers} kisi • ${entry.totalSearches} arama',
                                child: _queryLocationMarker(entry),
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _storeMarker(_StoreMapPoint store) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF),
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x336C63FF),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            store.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF6C63FF), width: 4),
          ),
        ),
      ],
    );
  }

  Widget _hotspotMarker(_RegionHotspot hotspot) {
    final scale = hotspot.totalSearches >= 20
        ? 1.0
        : hotspot.totalSearches >= 10
        ? 0.8
        : 0.6;
    final size = 92.0 * scale;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF97316).withValues(alpha: 0.16),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFF97316).withValues(alpha: 0.45),
            width: 2,
          ),
        ),
        child: Center(
          child: Container(
            width: size * 0.58,
            height: size * 0.58,
            decoration: const BoxDecoration(
              color: Color(0xFFF97316),
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${hotspot.totalSearches}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const Text(
                  'arama',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _queryLocationMarker(_QueryLocationPoint entry) {
    final intensity = entry.totalSearches >= 10
        ? const Color(0xFF1D4ED8)
        : const Color(0xFF2563EB);
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: intensity.withValues(alpha: 0.22)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: intensity,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '${entry.uniqueViewers}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 104,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.regionLabel} • ${entry.totalSearches} arama',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearcherInsightBanner({
    required int totalSearches,
    required int anonymousRate,
    required int mappedQueryCount,
    required int unmappedQueryCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _insightChip(
            icon: Icons.pin_drop_outlined,
            label: '$mappedQueryCount sorgu konumu haritada isaretli',
            accent: const Color(0xFF2563EB),
          ),
          _insightChip(
            icon: Icons.person_search_rounded,
            label: '$totalSearches aramanin %$anonymousRate kadari anonim',
            accent: const Color(0xFFF97316),
          ),
          _insightChip(
            icon: Icons.location_off_outlined,
            label: unmappedQueryCount == 0
                ? 'Tum sorgular eslesen bolgeye yerlestirildi'
                : '$unmappedQueryCount sorgu grubu adres yetersiz oldugu icin haritada yok',
            accent: const Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  Widget _insightChip({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionPanel(List<_RegionHotspot> hotspots) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bolgesel Arama Yogunlugu',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hangi bolgede ne araniyor sorusunun ozet cevabi',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 18),
          if (hotspots.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Henüz bolgesel arama telemetrisi yok.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            ...hotspots.map(
              (hotspot) => Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hotspot.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Text(
                          '${hotspot.totalSearches}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'En cok aranan: ${hotspot.topQuery}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: hotspot.topQueryCounts
                          .map(
                            (queryCount) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                '${queryCount.query} • ${queryCount.count}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrendPanel(List<_SearchTrendPoint> trend) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gunluk Arama Grafigi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Son 7 gunde uygulama icindeki arama hacmi',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _SearchTrendPainter(trend),
              child: Container(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: trend
                .map(
                  (point) => Expanded(
                    child: Text(
                      point.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePanel(List<_ThemeCount> themes) {
    final maxValue = themes.isEmpty
        ? 1
        : themes.map((theme) => theme.count).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bolgelere Akan Niyetler',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Arama kelimelerinden cikarilan tematik dagilim',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 18),
          if (themes.isEmpty)
            const Text(
              'Tema verisi bulunmuyor.',
              style: TextStyle(color: Color(0xFF6B7280)),
            )
          else
            ...themes.map(
              (theme) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            theme.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Text(
                          '${theme.count}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 9,
                        value: theme.count / maxValue,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation<Color>(theme.color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecentSearchPanel(List<SearchTelemetryEvent> events) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Son Arama Akisi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Kayitli ve kayitsiz kullanicilarin son arama davranislari',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 18),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Text(
                'Henüz arama telemetrisi toplanmadi.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            ...events.map(
              (event) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: event.isRegistered
                            ? const Color(0xFFEEF2FF)
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        event.isRegistered
                            ? Icons.person_outline_rounded
                            : Icons.person_off_outlined,
                        color: event.isRegistered
                            ? const Color(0xFF6C63FF)
                            : const Color(0xFFF97316),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.query,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_eventRegionLabel(event)} • ${event.resultCount ?? 0} sonuc',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatRelative(event.createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQueryLocationPanel(List<_QueryLocationPoint> entries) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nerede Ne Aratiliyor?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Arama kelimesi, bolge ve kisi sayisini ayni listede takip edin',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Haritada gosterilecek sorgu noktasi birikmedi.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            ...entries.map(
              (entry) => Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${entry.uniqueViewers}',
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.query,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.regionLabel,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _tagPill('${entry.totalSearches} arama'),
                              _tagPill('${entry.uniqueViewers} kisi'),
                              _tagPill(
                                entry.point == null
                                    ? 'Konum eslesmedi'
                                    : 'Haritada isaretli',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopQueriesPanel(List<_QueryCount> topQueries) {
    final maxValue = topQueries.isEmpty
        ? 1
        : topQueries
              .map((query) => query.count)
              .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'En Cok Aratilanlar',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Uygulama genelinde hangi kelime ne kadar aratildi',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 18),
          if (topQueries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Henüz arama birikmedi.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            ...topQueries.asMap().entries.map((entry) {
              final index = entry.key;
              final query = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            query.query,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Text(
                          '${query.count} kez',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF6C63FF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: query.count / maxValue,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6C63FF),
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

  Widget _buildRegionQueryMatrixPanel(List<_RegionHotspot> hotspots) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bolgede Ne Aratiliyor?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Her bolge icin en cok aratilan kelimeler ve hacimleri',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 18),
          if (hotspots.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Bolgesel arama matrisi icin veri bekleniyor.',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else
            ...hotspots.map((hotspot) {
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hotspot.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Text(
                          '${hotspot.totalSearches} arama',
                          style: const TextStyle(
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...hotspot.topQueryCounts.map((queryCount) {
                      final ratio = hotspot.totalSearches == 0
                          ? 0.0
                          : queryCount.count / hotspot.totalSearches;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    queryCount.query,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${queryCount.count} kez',
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 7,
                                backgroundColor: const Color(0xFFE5E7EB),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFF97316),
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
            }),
        ],
      ),
    );
  }

  Widget _buildStoreCoveragePanel(
    List<_StoreMapPoint> stores,
    List<_RegionHotspot> hotspots,
  ) {
    final byCity = <String, int>{};
    for (final store in stores) {
      final city = (store.city ?? 'Bilinmeyen').trim();
      byCity[city] = (byCity[city] ?? 0) + 1;
    }
    final topCities = byCity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Magaza Kapsam Analizi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${hotspots.where((hotspot) => hotspot.center == null).length} bolgede arama var ama esitlenen magaza koordinati bulunamadi.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 18),
          ...topCities
              .take(6)
              .map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_city_rounded,
                          color: Color(0xFF6C63FF),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value} magaza',
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _tagPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildExplanationPanel({
    required List<_RegionHotspot> topRegions,
    required int totalSearches,
    required int registeredCount,
  }) {
    final registeredRate = totalSearches == 0
        ? 0
        : ((registeredCount / totalSearches) * 100).round();
    final strongestRegion = topRegions.isEmpty ? null : topRegions.first;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grafikleri Nasil Okumalisiniz?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            strongestRegion == null
                ? 'Arama telemetrisi geldikce burada hangi bolgede hangi niyetlerin one ciktigini yorumlayacagim.'
                : '${strongestRegion.label} su anda en guclu arama havzasi. Bu bolgede kullanicilar en cok "${strongestRegion.topQuery}" aratiyor.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Toplam aramalarin %$registeredRate kadari kayitli kullanicilardan geliyor. Bu oran dusukse kampanya ve giris tesvikleri ile anonim talebi uye donusumune cevirebilirsiniz.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Haritadaki turuncu halkalar arama yogunlugunu, mavi etiketler ise tam olarak hangi sorgunun hangi bolgede ve kac kisi tarafindan aratildigini gosterir. Magaza pini olmayan ama arama gelen sehirlerde yeni satici kazanimi veya bolgesel reklam deneyebilirsiniz.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A111827),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
    );
  }

  List<_StoreMapPoint> _mapStores(List<Map<String, dynamic>> stores) {
    return stores
        .map((store) {
          return _StoreMapPoint(
            sellerId: store['seller_id']?.toString() ?? '',
            name: store['business_name']?.toString() ?? 'Magaza',
            category: store['category']?.toString(),
            city: store['city']?.toString(),
            address: store['address']?.toString(),
            location: LatLng(
              _asDouble(store['store_lat']) ?? 39.0,
              _asDouble(store['store_lng']) ?? 35.0,
            ),
          );
        })
        .where(
          (store) =>
              store.location.latitude != 39.0 ||
              store.location.longitude != 35.0,
        )
        .toList();
  }

  List<_RegionHotspot> _buildRegionHotspots(
    List<_StoreMapPoint> stores,
    List<SearchTelemetryEvent> events,
  ) {
    final groups = <String, List<SearchTelemetryEvent>>{};
    for (final event in events) {
      final key = _regionKey(event.city, event.district);
      groups.putIfAbsent(key, () => <SearchTelemetryEvent>[]).add(event);
    }

    final hotspots = groups.entries.map((entry) {
      final eventsInRegion = entry.value;
      final city = eventsInRegion.first.city?.trim();
      final district = eventsInRegion.first.district?.trim();
      final matchingStores = stores.where((store) {
        final sameCity =
            city != null &&
            city.isNotEmpty &&
            (store.city ?? '').trim().toLowerCase() == city.toLowerCase();
        return sameCity;
      }).toList();
      LatLng? center;
      if (matchingStores.isNotEmpty) {
        final lat =
            matchingStores
                .map((store) => store.location.latitude)
                .reduce((a, b) => a + b) /
            matchingStores.length;
        final lng =
            matchingStores
                .map((store) => store.location.longitude)
                .reduce((a, b) => a + b) /
            matchingStores.length;
        center = LatLng(lat, lng);
      }

      final queries = <String, int>{};
      for (final event in eventsInRegion) {
        queries[event.query] = (queries[event.query] ?? 0) + 1;
      }
      final sortedQueries = queries.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return _RegionHotspot(
        regionKey: entry.key,
        label: _regionLabel(city: city, district: district),
        topQuery: sortedQueries.isEmpty ? '-' : sortedQueries.first.key,
        topQueryCounts: sortedQueries
            .take(5)
            .map((entry) => _QueryCount(query: entry.key, count: entry.value))
            .toList(),
        totalSearches: eventsInRegion.length,
        center: center,
      );
    }).toList()..sort((a, b) => b.totalSearches.compareTo(a.totalSearches));

    return hotspots;
  }

  List<_QueryLocationPoint> _buildQueryLocationPoints(
    List<_RegionHotspot> hotspots,
    List<SearchTelemetryEvent> events,
  ) {
    final hotspotByKey = {
      for (final hotspot in hotspots) hotspot.regionKey: hotspot,
    };
    final groupedByRegion = <String, Map<String, List<SearchTelemetryEvent>>>{};

    for (final event in events) {
      final regionKey = _regionKey(event.city, event.district);
      final normalizedQuery = event.normalizedQuery.trim().isNotEmpty
          ? event.normalizedQuery.trim().toLowerCase()
          : event.query.trim().toLowerCase();
      if (normalizedQuery.isEmpty) {
        continue;
      }
      groupedByRegion
          .putIfAbsent(regionKey, () => <String, List<SearchTelemetryEvent>>{})
          .putIfAbsent(normalizedQuery, () => <SearchTelemetryEvent>[])
          .add(event);
    }

    final points = <_QueryLocationPoint>[];
    for (final entry in groupedByRegion.entries) {
      final hotspot = hotspotByKey[entry.key];
      final queryGroups = entry.value.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
      final mappableCount = hotspot?.center == null ? 0 : queryGroups.length;

      for (var i = 0; i < queryGroups.length; i++) {
        final eventsInGroup = queryGroups[i].value;
        final first = eventsInGroup.first;
        final queryCounts = <String, int>{};
        for (final event in eventsInGroup) {
          final candidate = event.query.trim();
          if (candidate.isEmpty) continue;
          queryCounts[candidate] = (queryCounts[candidate] ?? 0) + 1;
        }
        final sortedDisplayQueries = queryCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final uniqueViewerIds = eventsInGroup
            .map(_viewerIdentity)
            .where((identity) => identity.isNotEmpty)
            .toSet();
        points.add(
          _QueryLocationPoint(
            query: sortedDisplayQueries.isEmpty
                ? first.query
                : sortedDisplayQueries.first.key,
            regionLabel: _regionLabel(
              city: first.city,
              district: first.district,
            ),
            totalSearches: eventsInGroup.length,
            uniqueViewers: uniqueViewerIds.length,
            point: hotspot?.center == null
                ? null
                : _spreadPoint(hotspot!.center!, i, mappableCount),
            latestAt: eventsInGroup
                .map((event) => event.createdAt)
                .reduce((a, b) => a.isAfter(b) ? a : b),
          ),
        );
      }
    }

    points.sort((a, b) {
      final byPeople = b.uniqueViewers.compareTo(a.uniqueViewers);
      if (byPeople != 0) return byPeople;
      final bySearches = b.totalSearches.compareTo(a.totalSearches);
      if (bySearches != 0) return bySearches;
      return b.latestAt.compareTo(a.latestAt);
    });
    return points;
  }

  LatLng _resolveCenter(
    List<_StoreMapPoint> stores,
    List<_RegionHotspot> hotspots,
  ) {
    final points = <LatLng>[
      ...stores.map((store) => store.location),
      ...hotspots
          .where((hotspot) => hotspot.center != null)
          .map((hotspot) => hotspot.center!),
    ];
    if (points.isEmpty) return const LatLng(39.0, 35.0);
    final avgLat =
        points.map((point) => point.latitude).reduce((a, b) => a + b) /
        points.length;
    final avgLng =
        points.map((point) => point.longitude).reduce((a, b) => a + b) /
        points.length;
    return LatLng(avgLat, avgLng);
  }

  List<_SearchTrendPoint> _buildDailyTrend(List<SearchTelemetryEvent> events) {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final day = DateTime(now.year, now.month, now.day - (6 - index));
      final nextDay = day.add(const Duration(days: 1));
      final count = events.where((event) {
        return !event.createdAt.isBefore(day) &&
            event.createdAt.isBefore(nextDay);
      }).length;
      return _SearchTrendPoint(label: _weekdayShort(day.weekday), count: count);
    });
  }

  List<_ThemeCount> _buildThemeBreakdown(List<SearchTelemetryEvent> events) {
    final buckets = <String, int>{};
    for (final event in events) {
      final theme = _classifyQueryTheme(
        event.normalizedQuery.isNotEmpty ? event.normalizedQuery : event.query,
      );
      buckets[theme] = (buckets[theme] ?? 0) + 1;
    }
    final palette = <String, Color>{
      'Elektronik': const Color(0xFF6C63FF),
      'Yemek': const Color(0xFFEF4444),
      'Market': const Color(0xFF10B981),
      'Moda': const Color(0xFFEC4899),
      'Ev & Yasam': const Color(0xFFF59E0B),
      'Kozmetik': const Color(0xFF8B5CF6),
      'Diger': const Color(0xFF64748B),
    };
    final items =
        buckets.entries
            .map(
              (entry) => _ThemeCount(
                label: entry.key,
                count: entry.value,
                color: palette[entry.key] ?? const Color(0xFF64748B),
              ),
            )
            .toList()
          ..sort((a, b) => b.count.compareTo(a.count));
    return items.take(6).toList();
  }

  String _classifyQueryTheme(String query) {
    final q = query.toLowerCase();
    if (_containsAny(q, [
      'iphone',
      'telefon',
      'laptop',
      'kulaklik',
      'tablet',
      'tv',
      'kamera',
    ])) {
      return 'Elektronik';
    }
    if (_containsAny(q, [
      'doner',
      'pizza',
      'burger',
      'kahve',
      'tavuk',
      'yemek',
    ])) {
      return 'Yemek';
    }
    if (_containsAny(q, ['market', 'sut', 'su', 'ekmek', 'meyve', 'sebze'])) {
      return 'Market';
    }
    if (_containsAny(q, [
      'elbise',
      'ayakkabi',
      'pantolon',
      'ceket',
      'cantа',
      'giyim',
    ])) {
      return 'Moda';
    }
    if (_containsAny(q, [
      'sandalye',
      'masa',
      'nevresim',
      'hali',
      'perde',
      'lamba',
    ])) {
      return 'Ev & Yasam';
    }
    if (_containsAny(q, [
      'parfum',
      'cilt',
      'makyaj',
      'ruj',
      'krem',
      'sampuan',
    ])) {
      return 'Kozmetik';
    }
    return 'Diger';
  }

  bool _containsAny(String source, List<String> tokens) {
    return tokens.any(source.contains);
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _weekdayShort(int weekday) {
    const labels = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];
    return labels[weekday - 1];
  }

  String _formatRelative(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    return '${diff.inDays} gun';
  }

  String _regionLabel({String? city, String? district}) {
    final parts = [
      if (district != null && district.isNotEmpty) district,
      if (city != null && city.isNotEmpty) city,
    ];
    if (parts.isEmpty) {
      return 'Adres secilmedi';
    }
    return parts.join(' / ');
  }

  String _eventRegionLabel(SearchTelemetryEvent event) {
    return _regionLabel(
      city: event.city?.trim(),
      district: event.district?.trim(),
    );
  }

  String _regionKey(String? city, String? district) {
    final normalizedCity = (city ?? '').trim().toLowerCase();
    final normalizedDistrict = (district ?? '').trim().toLowerCase();
    return '$normalizedDistrict|$normalizedCity';
  }

  int _countUniqueViewers(Iterable<SearchTelemetryEvent> events) {
    return events
        .map(_viewerIdentity)
        .where((identity) => identity.isNotEmpty)
        .toSet()
        .length;
  }

  String _viewerIdentity(SearchTelemetryEvent event) {
    final userId = event.userId?.trim();
    if (userId != null && userId.isNotEmpty) {
      return 'user:$userId';
    }
    final viewerKey = event.viewerKey?.trim();
    if (viewerKey != null && viewerKey.isNotEmpty) {
      return viewerKey;
    }
    return 'anon:${event.id}';
  }

  LatLng _spreadPoint(LatLng center, int index, int total) {
    if (total <= 1) return center;
    final ringIndex = index + 1;
    final angle = (2 * math.pi * index / total) - (math.pi / 2);
    final latRadius = 0.14 + ((ringIndex - 1) ~/ 6) * 0.05;
    final lngFactor = math.max(
      0.35,
      math.cos(center.latitude * math.pi / 180).abs(),
    );
    final lngRadius = latRadius / lngFactor;
    return LatLng(
      center.latitude + math.sin(angle) * latRadius,
      center.longitude + math.cos(angle) * lngRadius,
    );
  }

  List<_QueryCount> _buildTopQueries(List<SearchTelemetryEvent> events) {
    final queryMap = <String, int>{};
    for (final event in events) {
      final query = event.query.trim();
      if (query.isEmpty) continue;
      queryMap[query] = (queryMap[query] ?? 0) + 1;
    }
    final sorted = queryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted
        .take(10)
        .map((entry) => _QueryCount(query: entry.key, count: entry.value))
        .toList();
  }
}

class _MapAdminDataset {
  const _MapAdminDataset({
    required this.stores,
    required this.searches,
    required this.searchError,
  });

  final List<Map<String, dynamic>> stores;
  final List<SearchTelemetryEvent> searches;
  final String? searchError;
}

class _StoreMapPoint {
  const _StoreMapPoint({
    required this.sellerId,
    required this.name,
    required this.location,
    this.category,
    this.city,
    this.address,
  });

  final String sellerId;
  final String name;
  final String? category;
  final String? city;
  final String? address;
  final LatLng location;
}

class _RegionHotspot {
  const _RegionHotspot({
    required this.regionKey,
    required this.label,
    required this.topQuery,
    required this.topQueryCounts,
    required this.totalSearches,
    required this.center,
  });

  final String regionKey;
  final String label;
  final String topQuery;
  final List<_QueryCount> topQueryCounts;
  final int totalSearches;
  final LatLng? center;
}

class _QueryLocationPoint {
  const _QueryLocationPoint({
    required this.query,
    required this.regionLabel,
    required this.totalSearches,
    required this.uniqueViewers,
    required this.latestAt,
    required this.point,
  });

  final String query;
  final String regionLabel;
  final int totalSearches;
  final int uniqueViewers;
  final DateTime latestAt;
  final LatLng? point;
}

class _QueryCount {
  const _QueryCount({required this.query, required this.count});

  final String query;
  final int count;
}

class _SearchTrendPoint {
  const _SearchTrendPoint({required this.label, required this.count});

  final String label;
  final int count;
}

class _ThemeCount {
  const _ThemeCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;
}

class _SearchTrendPainter extends CustomPainter {
  const _SearchTrendPainter(this.points);

  final List<_SearchTrendPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 12.0;
    const rightPadding = 12.0;
    const topPadding = 8.0;
    const bottomPadding = 18.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    final maxCount = points.isEmpty
        ? 1
        : points
              .map((point) => point.count)
              .reduce((a, b) => a > b ? a : b)
              .clamp(1, 9999);

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = topPadding + (chartHeight / 3) * i;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    if (points.isEmpty) return;

    final step = points.length == 1 ? 0.0 : chartWidth / (points.length - 1);
    final linePath = ui.Path();
    final fillPath = ui.Path();

    Offset offsetFor(int index, int count) {
      final x = leftPadding + step * index;
      final y = topPadding + chartHeight - ((count / maxCount) * chartHeight);
      return Offset(x, y);
    }

    for (var i = 0; i < points.length; i++) {
      final point = offsetFor(i, points[i].count);
      if (i == 0) {
        linePath.moveTo(point.dx, point.dy);
        fillPath.moveTo(point.dx, topPadding + chartHeight);
        fillPath.lineTo(point.dx, point.dy);
      } else {
        linePath.lineTo(point.dx, point.dy);
        fillPath.lineTo(point.dx, point.dy);
      }
    }

    final lastPoint = offsetFor(points.length - 1, points.last.count);
    fillPath.lineTo(lastPoint.dx, topPadding + chartHeight);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x446C63FF), Color(0x106C63FF)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFF6C63FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);

    final dotPaint = Paint()..color = const Color(0xFF6C63FF);
    for (var i = 0; i < points.length; i++) {
      final point = offsetFor(i, points[i].count);
      canvas.drawCircle(point, 4.5, dotPaint);
      canvas.drawCircle(point, 8, Paint()..color = const Color(0x226C63FF));
    }
  }

  @override
  bool shouldRepaint(covariant _SearchTrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
