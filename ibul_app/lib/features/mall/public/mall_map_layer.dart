import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/ibul_router.dart';
import '../../../app/marketplace_paths.dart';
import '../../../core/constants.dart';
import '../../../utils/text_normalizer.dart';
import 'mall_public_repository.dart';

/// Open state for free-text hours such as `08:00 - 22:00` (overnight ranges
/// wrap). null when the text has no single time range.
bool? mallOpenAt(String? hours, DateTime now) {
  final match = RegExp(r'(\d{1,2})[:.](\d{2})\s*[-–]\s*(\d{1,2})[:.](\d{2})').firstMatch(hours ?? '');
  if (match == null) return null;
  final open = int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  final close = int.parse(match.group(3)!) * 60 + int.parse(match.group(4)!);
  final minute = now.hour * 60 + now.minute;
  if (open == close) return true;
  return open < close ? minute >= open && minute < close : minute >= open || minute < close;
}

/// Last customer-map camera / filters so a deep-link back to `/map` does not
/// reset to the country view. A push from the mall card keeps the live page.
class MapViewportMemory {
  static LatLng? center;
  static double? zoom;
  static String search = '';
  static double distance = 10;
  static List<String> categories = const [];
  static bool openNow = false;

  static bool get hasCamera => center != null && zoom != null;

  static void remember({
    LatLng? camera,
    double? cameraZoom,
    String? query,
    double? filterDistance,
    List<String>? filterCategories,
    bool? filterOpenNow,
  }) {
    if (camera != null) center = camera;
    if (cameraZoom != null) zoom = cameraZoom;
    if (query != null) search = query;
    if (filterDistance != null) distance = filterDistance;
    if (filterCategories != null) categories = List<String>.from(filterCategories);
    if (filterOpenNow != null) openNow = filterOpenNow;
  }
}

/// Active malls for the customer map. Owned by the map page; loaded once.
class MallMapPins extends ChangeNotifier {
  MallMapPins({MallPublicRepository? repository}) : _repository = repository ?? MallPublicRepository();

  final MallPublicRepository _repository;
  List<MallMapPin> _pins = const [];
  List<MallStoreSearchHit> _stores = const [];
  Set<String> _hiddenStoreIds = const {};
  var _disposed = false;

  List<MallMapPin> get pins => _pins;
  List<MallStoreSearchHit> get stores => _stores;
  Set<String> get hiddenStoreIds => _hiddenStoreIds;

  Future<void> load() async {
    try {
      final pins = await _repository.activePins();
      final stores = await _repository.storeDirectory();
      final hidden = await _repository.hiddenStoreIds();
      if (_disposed) return;
      _pins = pins;
      _stores = stores;
      _hiddenStoreIds = hidden;
      notifyListeners();
    } catch (error) {
      debugPrint('[MALL][MAP] pins failed: $error');
    }
  }

  MallMapPin? match(String query) {
    final needle = TextNormalizer.normalize(query);
    if (needle.length < 2) return null;
    for (final pin in _pins) {
      if (TextNormalizer.normalize(pin.name).contains(needle)) return pin;
    }
    return null;
  }

  MallStoreSearchHit? matchStore(String query) {
    final needle = TextNormalizer.normalize(query);
    if (needle.length < 2) return null;
    for (final store in _stores) {
      if (TextNormalizer.normalize(store.storeName).contains(needle)) return store;
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class MallMapLayer extends StatelessWidget {
  const MallMapLayer({super.key, required this.pins, required this.onTap});

  final MallMapPins pins;
  final ValueChanged<MallMapPin> onTap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: pins,
      builder: (context, _) => MarkerLayer(
        markers: [
          for (final pin in pins.pins)
            Marker(
              point: LatLng(pin.latitude, pin.longitude),
              width: 120,
              height: 72,
              child: GestureDetector(
                key: ValueKey('mall-map-pin-${pin.id}'),
                onTap: () => onTap(pin),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                    ),
                    child: const Icon(Icons.location_city, color: Colors.white, size: 20),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Text(pin.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

Future<void> showMallMapCard(BuildContext context, MallMapPin pin) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          key: const ValueKey('mall-map-card'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFEEF2FF),
                child: Icon(Icons.location_city, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pin.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(['AVM', if (pin.locationLabel.isNotEmpty) pin.locationLabel].join(' • '),
                      style: const TextStyle(color: Colors.black54)),
                  if (pin.storeCount != null)
                    Text('${pin.storeCount} mağaza',
                        key: const ValueKey('mall-map-store-count'),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  if (pin.openingHours != null)
                    Row(children: [
                      if (mallOpenAt(pin.openingHours, DateTime.now()) case final open?) ...[
                        Text(
                          open ? 'Açık' : 'Kapalı',
                          key: const ValueKey('mall-map-open-state'),
                          style: TextStyle(
                            color: open ? AppColors.success : AppColors.danger,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const Text(' • ', style: TextStyle(color: Colors.black54, fontSize: 13)),
                      ],
                      Flexible(
                        child: Text(pin.openingHours!, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                      ),
                    ]),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('mall-map-open'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                Navigator.pop(sheetContext);
                IbulRouter.push(context, MarketplacePaths.mallProfile(pin.id));
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('AVM\'yi Gör'),
            ),
          ],
        ),
      ),
    ),
  );
}
