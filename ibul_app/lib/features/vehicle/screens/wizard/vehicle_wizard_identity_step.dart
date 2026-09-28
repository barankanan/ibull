import 'package:flutter/material.dart';

import '../../domain/vehicle_catalog.dart';
import '../../models/vehicle_wizard_draft.dart';
import '../../widgets/vehicle_wizard_chrome.dart';

class VehicleWizardIdentityStep extends StatelessWidget {
  const VehicleWizardIdentityStep({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final VehicleWizardDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        VehicleWizardSection(
          title: 'Marka & Model',
          subtitle: draft.brand.trim().isEmpty
              ? 'Önce marka seçin'
              : draft.model.trim().isEmpty
              ? 'Önce model seçin'
              : null,
          child: Column(
            children: [
              VehicleSearchSelect(
                label: 'Marka',
                value: draft.brand,
                options: VehicleCatalog.brands(),
                hint: 'BMW, Toyota, Togg…',
                onChanged: (brand) {
                  if (brand == draft.brand) return;
                  draft.brand = brand;
                  draft.model = '';
                  draft.version = '';
                  draft.applySuggestedTitleIfNeeded();
                  onChanged();
                },
              ),
              VehicleSearchSelect(
                label: 'Model',
                value: draft.model,
                enabled: draft.brand.trim().isNotEmpty,
                lockMessage: 'Önce marka seçin',
                options: VehicleCatalog.modelsFor(draft.brand),
                onChanged: (model) {
                  if (model == draft.model) return;
                  draft.model = model;
                  draft.version = '';
                  draft.applySuggestedTitleIfNeeded();
                  onChanged();
                },
              ),
              VehicleSearchSelect(
                label: 'Versiyon / paket',
                value: draft.version,
                enabled: draft.model.trim().isNotEmpty,
                lockMessage: 'Önce model seçin',
                hint: VehicleCatalog.trimsFor(draft.brand, draft.model).isEmpty
                    ? 'Manuel olarak girin'
                    : 'Paket seçin veya yazın',
                options: VehicleCatalog.trimsFor(draft.brand, draft.model),
                onChanged: (version) {
                  draft.version = version;
                  draft.applySuggestedTitleIfNeeded();
                  onChanged();
                },
              ),
              DropdownButtonFormField<int>(
                key: ValueKey('year-${draft.year}'),
                initialValue: draft.year,
                decoration: vehicleWizardInputDecoration('Yıl'),
                items: [
                  for (final year in VehicleCatalog.years())
                    DropdownMenuItem(value: year, child: Text('$year')),
                ],
                onChanged: (year) {
                  if (year == null) return;
                  draft.year = year;
                  draft.applySuggestedTitleIfNeeded();
                  onChanged();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
