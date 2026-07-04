import 'package:flutter/material.dart';

import '../../../../ads/helpers/home_feature_ad_helper.dart';
import '../../../../ads/models/ad_campaign.dart';
import '../../../../ads/models/home_card_template.dart';
import '../../../../ads/services/home_card_template_service.dart';
import '../../../../ads/services/home_feature_ad_service.dart';
import '../../../../ads/presentation/widgets/status_chip.dart';

class HomeFeatureSortingPanel extends StatefulWidget {
  const HomeFeatureSortingPanel({super.key});

  @override
  State<HomeFeatureSortingPanel> createState() => _HomeFeatureSortingPanelState();
}

class _HomeFeatureSortingPanelState extends State<HomeFeatureSortingPanel> {
  final _adService = HomeFeatureAdService();
  final _templateService = HomeCardTemplateService();
  List<AdCampaign> _campaigns = [];
  Map<String, HomeCardTemplate> _templates = {};
  bool _loading = true;
  bool _showExpired = false;
  bool _saving = false;
  String? _movingCampaignId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final templates = await _templateService.getAllTemplates();
      final campaigns = await _adService.getApprovedHomeFeatureAds(
        includeExpired: _showExpired,
      );
      if (mounted) {
        setState(() {
          _templates = {for (final t in templates) t.id: t};
          _campaigns = campaigns;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnack('Liste yüklenemedi.', isError: true);
      }
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : null,
      ),
    );
  }

  Map<String, Map<String, List<AdCampaign>>> _grouped() {
    final map = <String, Map<String, List<AdCampaign>>>{};
    for (final c in _campaigns) {
      final templateId = HomeFeatureAdHelper.cardTemplateId(c) ?? 'unknown';
      final template = _templates[templateId];
      final cat =
          template?.categoryName ??
          HomeFeatureAdHelper.categoryName(c) ??
          'Diğer';
      final cardTitle = template?.title ?? c.name;
      map.putIfAbsent(cat, () => {});
      map[cat]!.putIfAbsent(cardTitle, () => []).add(c);
    }
    for (final cat in map.values) {
      for (final list in cat.values) {
        list.sort(
          (a, b) => HomeFeatureAdHelper.sortOrder(a)
              .compareTo(HomeFeatureAdHelper.sortOrder(b)),
        );
      }
    }
    return map;
  }

  Future<void> _move(AdCampaign campaign, int delta, List<AdCampaign> list) async {
    if (_saving) return;
    final idx = list.indexOf(campaign);
    if (idx < 0) return;
    final newIdx = idx + delta;
    if (newIdx < 0 || newIdx >= list.length) return;

    final reordered = List<AdCampaign>.from(list);
    final item = reordered.removeAt(idx);
    reordered.insert(newIdx, item);

    setState(() {
      _saving = true;
      _movingCampaignId = campaign.id;
    });

    try {
      for (var i = 0; i < reordered.length; i++) {
        await _adService.updateSortOrder(reordered[i].id, i);
      }
      if (!mounted) return;
      _showSnack('Sıralama güncellendi.');
      await _load();
    } catch (_) {
      if (mounted) {
        _showSnack('Sıralama kaydedilemedi.', isError: true);
        await _load();
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _movingCampaignId = null;
        });
      }
    }
  }

  String _formatDateRange(AdCampaign campaign) {
    final start = campaign.startsAt;
    final end = campaign.endsAt;
    return '${start.day.toString().padLeft(2, '0')}.${start.month.toString().padLeft(2, '0')}'
        ' – ${end.day.toString().padLeft(2, '0')}.${end.month.toString().padLeft(2, '0')}.${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final grouped = _grouped();
    if (grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.view_carousel_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'Onaylı ana sayfa reklamı yok.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _expiredToggle(compact: true),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(child: _expiredToggle(compact: false)),
                if (_saving)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((catEntry) {
              return _CategorySection(
                categoryName: catEntry.key,
                cardGroups: catEntry.value,
                movingCampaignId: _movingCampaignId,
                onMove: _move,
                formatDateRange: _formatDateRange,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _expiredToggle({required bool compact}) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        compact ? 'Süresi bitenleri göster' : 'Süresi biten reklamları göster',
        style: TextStyle(
          fontSize: compact ? 14 : 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: compact
          ? null
          : const Text(
              'Geçmiş reklamlar sıralama dışında kalır.',
              style: TextStyle(fontSize: 11),
            ),
      value: _showExpired,
      onChanged: _saving
          ? null
          : (v) {
              setState(() => _showExpired = v);
              _load();
            },
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categoryName,
    required this.cardGroups,
    required this.movingCampaignId,
    required this.onMove,
    required this.formatDateRange,
  });

  final String categoryName;
  final Map<String, List<AdCampaign>> cardGroups;
  final String? movingCampaignId;
  final Future<void> Function(AdCampaign, int, List<AdCampaign>) onMove;
  final String Function(AdCampaign) formatDateRange;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Row(
              children: [
                const Icon(Icons.category_outlined, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    categoryName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Text(
                  '${cardGroups.length} kart',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...cardGroups.entries.map((cardEntry) {
            final list = cardEntry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Text(
                    cardEntry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                ),
                ...list.asMap().entries.map((e) {
                  final campaign = e.value;
                  final storeName =
                      campaign.metadata['store_name']?.toString() ??
                      campaign.name;
                  final expired = campaign.endsAt.isBefore(DateTime.now());
                  final bannerCount =
                      HomeFeatureAdHelper.bannerImages(campaign).length;
                  final productCount =
                      HomeFeatureAdHelper.selectedProductIds(campaign).length;
                  final isMoving = movingCampaignId == campaign.id;

                  return Container(
                    margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${e.key + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Color(0xFF4338CA),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFFE2E8F0),
                          child: Text(
                            storeName.isNotEmpty
                                ? storeName.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                storeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                campaign.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${formatDateRange(campaign)} • $bannerCount banner • $productCount ürün',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip.fromStatus(
                          expired
                              ? 'expired'
                              : campaign.status.dbValue,
                        ),
                        const SizedBox(width: 4),
                        if (isMoving)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else ...[
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: const Icon(Icons.keyboard_arrow_up_rounded),
                            onPressed: e.key > 0
                                ? () => onMove(campaign, -1, list)
                                : null,
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            onPressed: e.key < list.length - 1
                                ? () => onMove(campaign, 1, list)
                                : null,
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }
}
