import 'package:flutter/material.dart';

import '../../../../core/constants.dart';
import '../../domain/vehicle_catalog.dart';
import '../../models/vehicle_enums.dart';
import '../../models/vehicle_wizard_draft.dart';
import '../../widgets/vehicle_wizard_chrome.dart';
import 'vehicle_wizard_category_section.dart';

class VehicleWizardListingStep extends StatelessWidget {
  const VehicleWizardListingStep({
    super.key,
    required this.draft,
    required this.titleController,
    required this.descriptionController,
    required this.onChanged,
  });

  final VehicleWizardDraft draft;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        VehicleWizardSection(
          title: 'İlan Bilgileri',
          subtitle: 'Alıcının ilk gördüğü başlık ve açıklamayı buradan yazın.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'İlan Başlığı *',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: titleController,
                maxLength: VehicleCatalog.titleMax,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
                decoration:
                    vehicleWizardInputDecoration(
                      '',
                      hint: '2026 Toyota Corolla 1.5 Dream Manuel Düşük KM',
                    ).copyWith(
                      labelText: null,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                    ),
                onChanged: (v) {
                  draft.title = v;
                  draft.titleManual = true;
                  onChanged();
                },
              ),
              Text(
                '${titleController.text.length} / ${VehicleCatalog.titleMax}',
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              const SizedBox(height: 6),
              const Text(
                'Yıl + marka + model + paket + ayırt edici özelliği kullanın.',
                style: TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    draft.titleManual = false;
                    draft.applySuggestedTitleIfNeeded();
                    titleController.text = draft.title;
                    onChanged();
                  },
                  child: const Text('Otomatik başlığı kullan'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Açıklama *',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descriptionController,
                maxLines: 8,
                maxLength: VehicleCatalog.descriptionMax,
                decoration:
                    vehicleWizardInputDecoration(
                      '',
                      hint:
                          'Aracın genel durumu, bakım geçmişi, hasar/boya bilgileri, garanti, donanım ve alıcının bilmesi gereken diğer detayları yazın.',
                    ).copyWith(
                      labelText: null,
                      counterText: '',
                      alignLabelWithHint: true,
                    ),
                onChanged: (v) {
                  draft.description = v;
                  onChanged();
                },
              ),
              Text(
                '${descriptionController.text.length} / ${VehicleCatalog.descriptionMax}',
                style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
              ),
            ],
          ),
        ),
        VehicleWizardSection(
          title: 'İlan Tipi',
          subtitle:
              'İlanın satış, kiralama veya her ikisini kapsayıp kapsamadığını seçin.',
          child: VehicleOptionChips<VehicleListingType>(
            expanded: true,
            values: VehicleListingType.values,
            selected: draft.listingType,
            labelOf: (v) {
              switch (v) {
                case VehicleListingType.sale:
                  return 'Satılık';
                case VehicleListingType.rental:
                  return 'Kiralık';
                case VehicleListingType.both:
                  return 'Satılık + Kiralık';
              }
            },
            onSelected: (v) {
              draft.listingType = v;
              onChanged();
            },
          ),
        ),
        VehicleWizardCategorySection(draft: draft, onChanged: onChanged),
      ],
    );
  }
}
