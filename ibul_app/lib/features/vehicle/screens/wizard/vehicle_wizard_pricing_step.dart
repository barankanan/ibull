import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/vehicle_enums.dart';
import '../../models/vehicle_listing.dart';
import '../../models/vehicle_wizard_draft.dart';
import '../../widgets/vehicle_wizard_chrome.dart';

class VehicleWizardPricingStep extends StatelessWidget {
  const VehicleWizardPricingStep({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final VehicleWizardDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (draft.listingType.allowsSale)
          VehicleWizardSection(
            title: 'Satış fiyatı',
            subtitle: 'Alıcının göreceği ana fiyat.',
            child: Column(
              children: [
                VehicleMoneyField(
                  label: 'Satış fiyatı',
                  value: draft.salePrice,
                  onChanged: (v) {
                    draft.salePrice = v;
                    onChanged();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pazarlık yapılır'),
                  value: draft.negotiable,
                  onChanged: (v) {
                    draft.negotiable = v;
                    onChanged();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Krediye uygun'),
                  value: draft.creditEligible,
                  onChanged: (v) {
                    draft.creditEligible = v;
                    onChanged();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Takas'),
                  value: draft.tradeIn,
                  onChanged: (v) {
                    draft.tradeIn = v;
                    onChanged();
                  },
                ),
                VehicleOptionChips<String>(
                  values: const ['included', 'excluded', 'unspecified'],
                  selected: draft.vatStatus,
                  labelOf: (v) => switch (v) {
                    'included' => 'KDV dahil',
                    'excluded' => 'KDV hariç',
                    _ => 'Belirtilmemiş',
                  },
                  onSelected: (v) {
                    draft.vatStatus = v;
                    draft.vatIncluded = v == 'included';
                    onChanged();
                  },
                ),
              ],
            ),
          ),
        if (!draft.listingType.allowsRental)
          VehicleWizardSection(
            title: 'Kiralama Ayarları',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kiralama aktif'),
              value: false,
              onChanged: (v) {
                if (!v) return;
                draft.listingType = draft.listingType.allowsSale
                    ? VehicleListingType.both
                    : VehicleListingType.rental;
                draft.rental ??= const VehicleRentalSettings(dailyPrice: 0);
                onChanged();
              },
            ),
          ),
          VehicleWizardSection(
            title: 'Kiralama Ayarları',
            subtitle: 'Kiralama aktif olduğunda müşteri Kirala butonunu görür.',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kiralama aktif'),
                  value: draft.listingType.allowsRental,
                  onChanged: (v) {
                    draft.listingType = v
                        ? (draft.listingType.allowsSale
                              ? VehicleListingType.both
                              : VehicleListingType.rental)
                        : VehicleListingType.sale;
                    onChanged();
                  },
                ),
                VehicleMoneyField(
                  label: 'Günlük fiyat',
                  value: draft.rental?.dailyPrice,
                  onChanged: (v) => _patchRental(daily: v),
                ),
                VehicleMoneyField(
                  label: 'Haftalık fiyat',
                  value: draft.rental?.weeklyPrice,
                  onChanged: (v) => _patchRental(weekly: v),
                ),
                VehicleMoneyField(
                  label: 'Aylık fiyat',
                  value: draft.rental?.monthlyPrice,
                  onChanged: (v) => _patchRental(monthly: v),
                ),
                VehicleMoneyField(
                  label: 'Depozito',
                  value: draft.rental?.deposit,
                  onChanged: (v) => _patchRental(deposit: v),
                ),
                _intField('Min. kiralama (gün)', draft.rental?.minDays, (v) {
                  _patchRental(minDays: v);
                }),
                _intField('Maks. kiralama (gün)', draft.rental?.maxDays, (v) {
                  _patchRental(maxDays: v);
                }),
                _intField('Minimum yaş', draft.minDriverAge, (v) {
                  draft.minDriverAge = v;
                  _patchRental(minAge: v);
                  onChanged();
                }),
                _intField('Minimum ehliyet süresi (yıl)', draft.minLicenseYears, (
                  v,
                ) {
                  draft.minLicenseYears = v;
                  _patchRental(minLicense: v);
                  onChanged();
                }),
                _intField('Günlük KM', draft.rental?.kmLimitPerDay, (v) {
                  _patchRental(kmLimit: v);
                }),
                VehicleMoneyField(
                  label: 'Ek KM (TL/km)',
                  value: draft.rental?.extraKmPrice,
                  onChanged: (v) => _patchRental(extraKm: v),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Galeriden teslim'),
                  value: draft.rental?.galleryPickup ?? true,
                  onChanged: (v) => _patchRental(gallery: v),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Adrese teslim'),
                  value: draft.rental?.homeDelivery ?? false,
                  onChanged: (v) => _patchRental(home: v),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Farklı teslim noktası'),
                  value: draft.rental?.mapPointDelivery ?? false,
                  onChanged: (v) => _patchRental(mapPoint: v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Rezervasyon öncesi satıcı onayı'),
                  value: draft.rental?.requiresApproval ?? true,
                  onChanged: (v) => _patchRental(approval: v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Anında rezervasyon'),
                  value: draft.rental?.instantBooking ?? false,
                  onChanged: (v) => _patchRental(instant: v),
                ),
              ],
            ),
          ),
        VehicleWizardSection(
          title: 'Konum',
          child: _twoCol(wide, [
            _textField('İl', draft.city ?? '', (v) {
              draft.city = v;
              onChanged();
            }),
            _textField('İlçe', draft.district ?? '', (v) {
              draft.district = v;
              onChanged();
            }),
          ]),
        ),
      ],
    );
  }

  void _patchRental({
    double? daily,
    double? weekly,
    double? monthly,
    double? deposit,
    int? minDays,
    int? maxDays,
    int? kmLimit,
    double? extraKm,
    bool? gallery,
    bool? home,
    bool? mapPoint,
    bool? approval,
    bool? instant,
    int? minAge,
    int? minLicense,
  }) {
    final current = draft.rental ?? const VehicleRentalSettings(dailyPrice: 0);
    draft.rental = current.copyWith(
      dailyPrice: daily ?? current.dailyPrice,
      weeklyPrice: weekly ?? current.weeklyPrice,
      monthlyPrice: monthly ?? current.monthlyPrice,
      deposit: deposit ?? current.deposit,
      minDays: minDays ?? current.minDays,
      maxDays: maxDays ?? current.maxDays,
      kmLimitPerDay: kmLimit ?? current.kmLimitPerDay,
      extraKmPrice: extraKm ?? current.extraKmPrice,
      galleryPickup: gallery ?? current.galleryPickup,
      mapPointDelivery: mapPoint ?? current.mapPointDelivery,
      homeDelivery: home ?? current.homeDelivery,
      requiresApproval: approval ?? current.requiresApproval,
      instantBooking: instant ?? current.instantBooking,
      minDriverAge: minAge ?? current.minDriverAge,
      minLicenseYears: minLicense ?? current.minLicenseYears,
    );
    onChanged();
  }

  Widget _twoCol(bool wide, List<Widget> children) {
    if (!wide) return Column(children: children);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: children[0]),
        const SizedBox(width: 10),
        Expanded(child: children.length > 1 ? children[1] : const SizedBox()),
      ],
    );
  }

  Widget _intField(String label, int? value, ValueChanged<int?> onSave) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value?.toString() ?? '',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: vehicleWizardInputDecoration(label),
        onChanged: (raw) {
          onSave(raw.trim().isEmpty ? null : int.tryParse(raw));
          onChanged();
        },
      ),
    );
  }

  Widget _textField(String label, String value, ValueChanged<String> onSave) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value,
        decoration: vehicleWizardInputDecoration(label),
        onChanged: onSave,
      ),
    );
  }
}
