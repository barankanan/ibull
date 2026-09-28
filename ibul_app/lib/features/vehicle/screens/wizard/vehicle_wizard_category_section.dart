import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../domain/vehicle_catalog.dart';
import '../../models/vehicle_wizard_draft.dart';
import '../../widgets/vehicle_wizard_chrome.dart';

class VehicleWizardCategorySection extends StatelessWidget {
  const VehicleWizardCategorySection({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final VehicleWizardDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final schema = VehicleTypeCatalog.of(draft.vehicleClass);
    final selectedGroup = VehicleTypeCatalog.groups.firstWhere(
      (g) => g.id == schema.groupId,
      orElse: () => VehicleTypeCatalog.groups.first,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VehicleWizardSection(
          title: 'Araç Kategorisi',
          subtitle: 'Önce ana kategoriyi seçin, ardından araç türü açılır.',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoCol = constraints.maxWidth < 560;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: twoCol ? 2 : 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: twoCol ? 2.6 : 1.7,
                children: [
                  for (final group in VehicleTypeCatalog.groups)
                    _CategoryCard(
                      group: group,
                      selected: group.id == selectedGroup.id,
                      onTap: () => _selectGroup(group),
                    ),
                ],
              );
            },
          ),
        ),
        VehicleWizardSection(
          title: 'Araç Türü',
          subtitle: '${selectedGroup.label} için uygun tipi seçin.',
          child: VehicleOptionChips<VehicleClass>(
            values: selectedGroup.types,
            selected: selectedGroup.types.cast<VehicleClass?>().firstWhere(
              (c) => c!.id == draft.vehicleClass,
              orElse: () => null,
            ),
            labelOf: (c) => c.label,
            onSelected: (c) {
              draft.vehicleClass = c.id;
              draft.subtype = '';
              onChanged();
            },
          ),
        ),
        if (schema.subtypes.isNotEmpty)
          VehicleWizardSection(
            title: 'Motosiklet tipi',
            child: VehicleOptionChips<VehicleClass>(
              values: schema.subtypes,
              selected: schema.subtypes.cast<VehicleClass?>().firstWhere(
                (c) => c!.id == draft.subtype,
                orElse: () => null,
              ),
              labelOf: (c) => c.label,
              onSelected: (c) {
                draft.subtype = c.id;
                onChanged();
              },
            ),
          ),
      ],
    );
  }

  void _selectGroup(VehicleClassGroup group) {
    final current = VehicleTypeCatalog.of(draft.vehicleClass).groupId;
    if (current == group.id) {
      onChanged();
      return;
    }
    draft.vehicleClass = group.types.first.id;
    draft.subtype = '';
    onChanged();
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  final VehicleClassGroup group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderStrong,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _iconFor(group.id),
                size: 20,
                color: selected ? AppColors.primary : AppColors.ink,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  group.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (selected)
                const Icon(Icons.check, size: 16, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String id) {
    switch (id) {
      case 'land':
        return Icons.directions_car_outlined;
      case 'motorcycle':
        return Icons.two_wheeler_outlined;
      case 'marine':
        return Icons.sailing_outlined;
      default:
        return Icons.category_outlined;
    }
  }
}
