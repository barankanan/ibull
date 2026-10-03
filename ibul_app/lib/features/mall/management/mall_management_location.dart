import '../../../app/marketplace_paths.dart';

class MallManagementLocation {
  const MallManagementLocation({
    this.mallId,
    this.section = 'ozet',
    this.floorId,
  });

  final String? mallId;
  final String section;
  final String? floorId;

  static const sections = <String>{
    'ozet',
    'bilgiler',
    'katlar',
    'magazalar',
    'harita',
    'kampanyalar',
    'reklam',
    'istatistikler',
    'yetkililer',
  };

  static const _aliases = <String, String>{
    'yoneticiler': 'yetkililer',
    'birimler': 'katlar',
  };

  bool get isSelector => mallId == null || mallId!.isEmpty;

  static MallManagementLocation? parse(String path) {
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return null;
    final List<String> tail;
    if (parts.first == 'avm-yonetim') {
      tail = parts.sublist(1);
    } else if (parts.length >= 2 && parts[0] == 'avm' && parts[1] == 'yonetim') {
      tail = parts.sublist(2);
    } else {
      return null;
    }
    if (tail.isEmpty) return const MallManagementLocation();
    final mallId = Uri.decodeComponent(tail[0]);
    if (tail.length == 1) return MallManagementLocation(mallId: mallId);
    final section = _aliases[tail[1]] ?? tail[1];
    if (section == 'katlar' && tail.length == 3) {
      return MallManagementLocation(
        mallId: mallId,
        section: 'katlar',
        floorId: Uri.decodeComponent(tail[2]),
      );
    }
    if (tail.length == 2 && sections.contains(section)) {
      return MallManagementLocation(mallId: mallId, section: section);
    }
    return null;
  }

  String get path {
    if (isSelector) return MarketplacePaths.mallManagement;
    final root = MarketplacePaths.mallManagementMall(mallId!);
    if (section == 'ozet') return root;
    if (section == 'katlar' && floorId != null) {
      return MarketplacePaths.mallFloor(mallId!, floorId!);
    }
    return '$root/$section';
  }
}
