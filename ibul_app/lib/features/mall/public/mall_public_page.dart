import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/ibul_router.dart';
import '../../../app/marketplace_paths.dart';
import 'mall_public_chrome.dart';
import 'mall_public_format.dart';
import 'mall_public_repository.dart';
import 'mall_public_store_views.dart';

const _sections = ['Genel', 'Mağazalar', 'Katlar', 'Profil'];

/// Customer mall page. Sections stay on this route: identity and the
/// selected floor's stores, the full store list, floors, then contact.
class MallPublicPage extends StatefulWidget {
  const MallPublicPage({
    super.key,
    required this.mallId,
    this.repository,
    this.floorId,
    this.storeId,
  });

  final String mallId;
  final MallPublicRepository? repository;
  final String? floorId;
  final String? storeId;

  @override
  State<MallPublicPage> createState() => _MallPublicPageState();
}

class _MallPublicPageState extends State<MallPublicPage> {
  late final _repository = widget.repository ?? MallPublicRepository();
  late Future<MallPublicDetail?> _detail = _repository.detail(widget.mallId);
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String? _floorId;
  String? _catalogFloorId;
  String? _category;
  String _section = 'Genel';
  bool _favorite = false;
  bool _showPlan = false;

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    IbulRouter.go(context, '/map');
  }

  Future<void> _open(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openStore(MallPublicStore store) {
    final id = store.storeId;
    if (id == null) return;
    IbulRouter.push(context, MarketplacePaths.store(id));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MallPublicDetail?>(
      future: _detail,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        return Scaffold(
          backgroundColor: mallPublicCanvas,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              key: const ValueKey('mall-public-back'),
              tooltip: 'Geri',
              icon: const Icon(Icons.arrow_back),
              onPressed: _back,
            ),
            title: Text(detail?.name ?? '', overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                key: const ValueKey('mall-public-favorite'),
                tooltip: 'Favori',
                icon: Icon(
                  _favorite ? Icons.favorite : Icons.favorite_border,
                  color: _favorite ? const Color(0xFFE11D48) : null,
                ),
                onPressed: () => setState(() => _favorite = !_favorite),
              ),
              IconButton(
                key: const ValueKey('mall-public-share'),
                tooltip: 'Paylaş',
                icon: const Icon(Icons.ios_share),
                onPressed: detail == null
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(
                          text: '${detail.name}\n${MarketplacePaths.mallProfile(detail.id)}',
                        ));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı kopyalandı')));
                      },
              ),
            ],
          ),
          body: _body(snapshot),
        );
      },
    );
  }

  Widget _body(AsyncSnapshot<MallPublicDetail?> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) return const MallPublicSkeleton();
    if (snapshot.hasError) return _message('AVM bilgileri yüklenemedi.', retry: true);
    final detail = snapshot.data;
    if (detail == null) return _message('AVM bulunamadı veya henüz yayında değil.');
    return _content(detail);
  }

  Widget _message(String text, {bool retry = false}) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.location_city_outlined, size: 48, color: Colors.black38),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center),
        if (retry)
          TextButton(
            onPressed: () => setState(() => _detail = _repository.detail(widget.mallId)),
            child: const Text('Tekrar dene'),
          ),
      ]),
    );
  }

  Widget _content(MallPublicDetail detail) {
    final hours = mallHoursPresentation(detail.openingHours);
    return LayoutBuilder(builder: (context, constraints) {
      final width = math.min(840.0, constraints.maxWidth);
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          height: constraints.maxHeight,
          child: Column(
            key: const ValueKey('mall-public-page'),
            children: [
              if (detail.preview) _preview(),
              MallPublicSectionNav(
                items: _sections,
                selected: _section,
                onSelect: (value) => setState(() => _section = value),
              ),
              Expanded(child: _sectionBody(detail, hours)),
            ],
          ),
        ),
      );
    });
  }

  Widget _preview() {
    return Container(
      key: const ValueKey('mall-public-preview'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(10)),
      child: const Text(
        'Önizleme: Bu AVM henüz yayında değil. Müşteriler bu sayfayı göremez.',
        style: TextStyle(fontSize: 13, height: 1.3, color: Color(0xFF9A3412), fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _sectionBody(MallPublicDetail detail, MallHoursPresentation? hours) {
    return switch (_section) {
      'Mağazalar' => _storesTab(detail),
      'Katlar' => _floorsTab(detail),
      'Profil' => _profileTab(detail, hours),
      _ => _generalTab(detail, hours),
    };
  }

  Widget _generalTab(MallPublicDetail detail, MallHoursPresentation? hours) {
    final floor = _selectedFloor(detail);
    final stores = floor == null ? const <MallPublicStore>[] : detail.storesOn(floor.id);
    final hasPlan = (floor?.planUrl ?? '').isNotEmpty;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        MallPublicIdentityCard(detail: detail, hours: hours),
        if (detail.floors.isNotEmpty) ...[
          const SizedBox(height: 12),
          MallPublicFloorChips(
            floors: detail.floors,
            selectedId: floor?.id,
            storeCount: (id) => detail.storesOn(id).length,
            onSelect: (id) => setState(() {
              _floorId = id;
              _showPlan = false;
            }),
          ),
        ],
        if (hasPlan) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('mall-public-view-plan'),
              onPressed: () => setState(() => _showPlan = !_showPlan),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7A2FF4),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 2),
              ),
              child: Text(_showPlan ? 'Planı gizle' : 'Kat planı'),
            ),
          ),
        ],
        if (_showPlan && hasPlan) ...[
          const SizedBox(height: 4),
          _plan(floor!, stores),
        ],
        SizedBox(height: hasPlan ? 4 : 12),
        if (detail.floors.isEmpty)
          const Text('Mağaza bilgisi yakında eklenecek.', style: TextStyle(color: mallPublicMuted, fontWeight: FontWeight.w600))
        else
          MallPublicStoreList(
            stores: stores,
            highlightedStoreId: widget.storeId,
            emptyText: 'Bu katta henüz mağaza yok.',
            onOpen: _openStore,
          ),
      ],
    );
  }

  Widget _storesTab(MallPublicDetail detail) {
    final categories = {
      for (final store in detail.stores)
        if ((store.category ?? '').trim().isNotEmpty) store.category!.trim(),
    }.toList()
      ..sort();
    final canFilter = detail.stores.length >= 5;
    final filtering = _search.text.trim().isNotEmpty || _category != null || _catalogFloorId != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        if (canFilter) ...[
          MallPublicStoreSearch(controller: _search, focusNode: _searchFocus, onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          if (detail.floors.length > 1) ...[
            MallPublicFloorChips(
              floors: detail.floors,
              selectedId: _catalogFloorId,
              showAll: true,
              storeCount: (id) => detail.storesOn(id).length,
              onSelect: (id) => setState(() => _catalogFloorId = id.isEmpty ? null : id),
            ),
            const SizedBox(height: 10),
          ],
          if (categories.length >= 2) ...[
            MallPublicCategoryChips(
              categories: categories,
              selected: _category,
              onSelect: (value) => setState(() => _category = value),
            ),
            const SizedBox(height: 10),
          ],
        ],
        MallPublicStoreList(
          stores: _catalogStores(detail),
          highlightedStoreId: widget.storeId,
          floorLabel: (store) => _floorName(detail, store.floorId),
          emptyText: detail.stores.isEmpty || !filtering ? 'Mağaza bilgisi yakında eklenecek.' : 'Mağaza bulunamadı.',
          onOpen: _openStore,
        ),
      ],
    );
  }

  Widget _floorsTab(MallPublicDetail detail) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        MallPublicFloorDirectory(
          floors: detail.floors,
          storeCount: (id) => detail.storesOn(id).length,
          onOpen: (id) => setState(() {
            _floorId = id;
            _showPlan = false;
            _section = 'Genel';
          }),
        ),
      ],
    );
  }

  Widget _profileTab(MallPublicDetail detail, MallHoursPresentation? hours) {
    final rows = _profileRows(detail, hours);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (rows.isEmpty)
          const Text('Profil bilgisi henüz eklenmedi.', style: TextStyle(color: mallPublicMuted, fontWeight: FontWeight.w600))
        else
          MallPublicAboutCard(rows: rows),
        if (detail.campaigns.isNotEmpty) ...[
          const SizedBox(height: 16),
          MallPublicCampaignRail(campaigns: detail.campaigns),
        ],
      ],
    );
  }

  List<Widget> _profileRows(MallPublicDetail detail, MallHoursPresentation? hours) {
    final rows = <Widget>[];
    if ((detail.address ?? '').isNotEmpty) {
      rows.add(MallPublicInfoRow(
        icon: Icons.place_outlined,
        label: 'Adres',
        value: detail.address!,
        onTap: () => _directions(detail),
      ));
    }
    if ((detail.phone ?? '').isNotEmpty) {
      rows.add(MallPublicInfoRow(
        icon: Icons.phone_outlined,
        label: 'Telefon',
        value: detail.phone!,
        onTap: () => _open(Uri(scheme: 'tel', path: detail.phone)),
      ));
    }
    if (hours != null) {
      rows.add(MallPublicInfoRow(
        icon: Icons.schedule_outlined,
        label: 'Çalışma saatleri',
        value: hours.range,
        detail: hours.isOpen == true ? 'Açık' : hours.isOpen == false ? 'Kapalı' : null,
      ));
    }
    if ((detail.website ?? '').isNotEmpty) {
      final site = detail.website!;
      rows.add(MallPublicInfoRow(
        icon: Icons.language,
        label: 'Web sitesi',
        value: site,
        onTap: () => _open(Uri.parse(site.startsWith('http') ? site : 'https://$site')),
      ));
    }
    if (_hasDirections(detail)) {
      rows.add(MallPublicInfoRow(
        key: const ValueKey('mall-public-directions'),
        icon: Icons.near_me_outlined,
        label: 'Yol tarifi',
        value: 'Haritada aç',
        onTap: () => _directions(detail),
      ));
    }
    return rows;
  }

  List<MallPublicStore> _catalogStores(MallPublicDetail detail) {
    var list = _catalogFloorId == null ? detail.stores : detail.storesOn(_catalogFloorId!);
    final query = _search.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((store) {
        return store.storeName.toLowerCase().contains(query) ||
            store.unitCode.toLowerCase().contains(query) ||
            (store.category ?? '').toLowerCase().contains(query);
      }).toList();
    }
    if (_category != null) list = list.where((store) => store.category == _category).toList();
    return list;
  }

  MallPublicFloor? _selectedFloor(MallPublicDetail detail) {
    final focused = detail.stores.where((store) => store.storeId == widget.storeId).firstOrNull;
    return detail.floors.where((item) => item.id == (_floorId ?? widget.floorId ?? focused?.floorId)).firstOrNull ??
        detail.floors.where((item) => detail.storesOn(item.id).isNotEmpty).firstOrNull ??
        detail.floors.firstOrNull;
  }

  String? _floorName(MallPublicDetail detail, String floorId) {
    final floor = detail.floors.where((item) => item.id == floorId).firstOrNull;
    return floor == null ? null : mallFloorChipLabel(floor);
  }

  bool _hasDirections(MallPublicDetail detail) =>
      (detail.latitude != null && detail.longitude != null) || (detail.address ?? '').isNotEmpty;

  Widget _plan(MallPublicFloor floor, List<MallPublicStore> stores) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(builder: (context, box) {
        return Stack(children: [
          Image.network(
            floor.planUrl!,
            width: box.maxWidth,
            fit: BoxFit.fitWidth,
            errorBuilder: (_, _, _) => Container(
              height: 120,
              color: const Color(0xFFF3F4F6),
              alignment: Alignment.center,
              child: const Icon(Icons.map_outlined, color: Color(0xFF9CA3AF), size: 36),
            ),
          ),
          for (final store in stores.where((store) => store.isPlaced))
            Positioned.fill(
              child: Align(
                alignment: Alignment(store.mapX! * 2 - 1, store.mapY! * 2 - 1),
                child: Tooltip(
                  message: '${store.storeName} • Mağaza No: ${store.unitCode}',
                  child: const Icon(Icons.location_on, color: Color(0xFF7A2FF4), size: 28),
                ),
              ),
            ),
        ]);
      }),
    );
  }

  Future<void> _directions(MallPublicDetail detail) async {
    if (detail.latitude != null && detail.longitude != null) {
      await _open(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${detail.latitude},${detail.longitude}'));
      return;
    }
    if ((detail.address ?? '').isNotEmpty) {
      await _open(Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(detail.address!)}'));
    }
  }
}
