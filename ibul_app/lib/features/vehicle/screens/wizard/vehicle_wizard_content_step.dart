import 'package:flutter/material.dart';

import '../../domain/vehicle_catalog.dart';
import '../../models/vehicle_wizard_draft.dart';
import '../../widgets/vehicle_damage_panel.dart';
import '../../widgets/vehicle_wizard_chrome.dart';

class VehicleWizardContentStep extends StatelessWidget {
  const VehicleWizardContentStep({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final VehicleWizardDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final schema = VehicleTypeCatalog.of(draft.vehicleClass);
    final groups = VehicleCatalog.featureGroupsFor(draft.vehicleClass);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        VehicleWizardSection(
          title: 'Araç durumu',
          subtitle: 'Hukuki / finansal alanlar satıcı beyanıdır.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VehicleOptionChips<bool>(
                values: const [true, false],
                selected: draft.isNew,
                labelOf: (v) => v ? 'Sıfır' : 'İkinci El',
                onSelected: (v) {
                  draft.isNew = v;
                  if (v) draft.mileageKm = 0;
                  onChanged();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hasar kaydı var'),
                value: draft.hasDamage,
                onChanged: (v) {
                  draft.hasDamage = v;
                  onChanged();
                },
              ),
              _text(
                'Tramer / hasar kaydı tutarı',
                draft.tramerAmount == null
                    ? ''
                    : VehicleMoney.format(
                        draft.tramerAmount!,
                        withSuffix: false,
                      ),
                (v) {
                  draft.tramerAmount = VehicleMoney.parse(v);
                  onChanged();
                },
              ),
              _text('Garanti', draft.warranty ?? '', (v) {
                draft.warranty = v;
                onChanged();
              }),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ekspertiz var'),
                value: draft.hasExpertise,
                onChanged: (v) {
                  draft.hasExpertise = v;
                  onChanged();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ağır hasar kaydı'),
                value: draft.heavyDamage,
                onChanged: (v) {
                  draft.heavyDamage = v;
                  onChanged();
                },
              ),
              _text('Servis geçmişi', draft.serviceHistory ?? '', (v) {
                draft.serviceHistory = v;
                onChanged();
              }, maxLines: 3),
              VehicleDropdownField(
                label: 'Plaka durumu',
                value: draft.plateStatus,
                items: VehicleCatalog.plateStatuses,
                onChanged: (v) {
                  draft.plateStatus = v;
                  onChanged();
                },
              ),
              VehicleDropdownField(
                label: 'İthalat durumu',
                value: draft.importStatus,
                items: VehicleCatalog.importStatuses,
                onChanged: (v) {
                  draft.importStatus = v;
                  onChanged();
                },
              ),
              VehicleDropdownField(
                label: 'Rehin / haciz (beyan)',
                value: draft.lienStatus,
                items: VehicleCatalog.lienStatuses,
                onChanged: (v) {
                  draft.lienStatus = v;
                  onChanged();
                },
              ),
            ],
          ),
        ),
        if (schema.hasDamagePanel)
          VehicleWizardSection(
            title: 'Boya / değişen',
            subtitle: 'Parça durumunu seçin. Veri yoksa orijinal bırakın.',
            child: VehicleDamagePanel(
              values: draft.damageParts,
              onChanged: (part, state) {
                draft.damageParts[part] = state;
                onChanged();
              },
            ),
          ),
        for (final group in groups) _featureGroup(group),
      ],
    );
  }

  Widget _featureGroup(VehicleFeatureGroup group) {
    final selected = group.items
        .where((i) => draft.features.contains(i.id))
        .length;
    return VehicleWizardSection(
      title: '${group.label}  ($selected)',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in group.items)
            VehicleOutlineChip(
              label: item.label,
              selected: draft.features.contains(item.id),
              onTap: () {
                if (draft.features.contains(item.id)) {
                  draft.features.remove(item.id);
                } else {
                  draft.features.add(item.id);
                }
                onChanged();
              },
            ),
        ],
      ),
    );
  }

  Widget _text(
    String label,
    String value,
    ValueChanged<String> onSave, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value,
        maxLines: maxLines,
        decoration: vehicleWizardInputDecoration(label),
        onChanged: onSave,
      ),
    );
  }
}
