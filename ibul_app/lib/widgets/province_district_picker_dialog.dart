import 'package:flutter/material.dart';

import '../core/turkiye_location_data.dart';

class ProvinceDistrictSelection {
  const ProvinceDistrictSelection({
    required this.province,
    required this.district,
  });

  final String province;
  final String district;
}

Future<ProvinceDistrictSelection?> showProvinceDistrictPickerDialog({
  required BuildContext context,
  String? initialProvince,
  String? initialDistrict,
  String title = 'İl / İlçe seç',
}) {
  return showDialog<ProvinceDistrictSelection>(
    context: context,
    builder: (dialogContext) {
      var provinceQuery = '';
      var districtQuery = '';
      var selectedProvince =
          TurkiyeLocationData.provinces.contains(initialProvince)
          ? initialProvince!
          : TurkiyeLocationData.provinces.first;
      var selectedDistrict =
          TurkiyeLocationData.districtsForProvince(
            selectedProvince,
          ).contains(initialDistrict)
          ? initialDistrict!
          : TurkiyeLocationData.defaultDistrictForProvince(selectedProvince);

      List<String> filteredProvinces() {
        if (provinceQuery.trim().isEmpty) return TurkiyeLocationData.provinces;
        return TurkiyeLocationData.provinces
            .where(
              (item) => item.toLowerCase().contains(
                provinceQuery.trim().toLowerCase(),
              ),
            )
            .toList(growable: false);
      }

      List<String> filteredDistricts() {
        final all = TurkiyeLocationData.districtsForProvince(selectedProvince);
        if (districtQuery.trim().isEmpty) return all;
        return all
            .where(
              (item) => item.toLowerCase().contains(
                districtQuery.trim().toLowerCase(),
              ),
            )
            .toList(growable: false);
      }

      return StatefulBuilder(
        builder: (context, setState) {
          final provinces = filteredProvinces();
          final districts = filteredDistricts();
          if (!districts.contains(selectedDistrict)) {
            selectedDistrict = districts.isNotEmpty
                ? districts.first
                : TurkiyeLocationData.defaultDistrictForProvince(
                    selectedProvince,
                  );
          }

          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 760,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'İl ara',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() {
                              provinceQuery = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'İlçe ara',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (value) {
                            setState(() {
                              districtQuery = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 360,
                    child: Row(
                      children: [
                        Expanded(
                          child: _PickerPane(
                            title: 'İl',
                            items: provinces,
                            selectedValue: selectedProvince,
                            onSelected: (value) {
                              setState(() {
                                selectedProvince = value;
                                final nextDistricts =
                                    TurkiyeLocationData.districtsForProvince(
                                      value,
                                    );
                                selectedDistrict = nextDistricts.first;
                                districtQuery = '';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _PickerPane(
                            title: 'İlçe',
                            items: districts,
                            selectedValue: selectedDistrict,
                            onSelected: (value) {
                              setState(() {
                                selectedDistrict = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(
                    ProvinceDistrictSelection(
                      province: selectedProvince,
                      district: selectedDistrict,
                    ),
                  );
                },
                child: const Text('Seç'),
              ),
            ],
          );
        },
      );
    },
  );
}

class _PickerPane extends StatelessWidget {
  const _PickerPane({
    required this.title,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
  });

  final String title;
  final List<String> items;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  '${items.length} kayıt',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Kayıt bulunamadı'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final selected = item == selectedValue;
                      return InkWell(
                        onTap: () => onSelected(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFEDE9FE)
                                : Colors.white,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? const Color(0xFF6D28D9)
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (selected)
                                const Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: Color(0xFF6D28D9),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
