import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/vehicle_catalog.dart';
import '../../models/vehicle_wizard_draft.dart';
import '../../widgets/vehicle_wizard_chrome.dart';

class VehicleWizardDetailsStep extends StatelessWidget {
  const VehicleWizardDetailsStep({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final VehicleWizardDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final schema = VehicleTypeCatalog.of(draft.vehicleClass);
    final fields = <Widget>[
      if (schema.shows('mileageKm'))
        _intField('Kilometre', draft.mileageKm, (v) {
          draft.mileageKm = v;
          draft.applySuggestedTitleIfNeeded();
        }, suffix: 'km'),
      if (schema.shows('hoursOperated'))
        _intField('Çalışma saati', draft.hoursOperated, (v) {
          draft.hoursOperated = v;
        }),
      if (schema.shows('fuel'))
        VehicleDropdownField(
          label: 'Yakıt',
          value: draft.fuel,
          items: VehicleCatalog.fuels,
          onChanged: (v) {
            draft.fuel = v;
            onChanged();
          },
        ),
      if (schema.shows('transmission'))
        VehicleDropdownField(
          label: 'Vites',
          value: draft.transmission,
          items: VehicleCatalog.transmissions,
          onChanged: (v) {
            draft.transmission = v;
            draft.applySuggestedTitleIfNeeded();
            onChanged();
          },
        ),
      if (schema.shows('bodyType'))
        VehicleDropdownField(
          label: 'Kasa tipi',
          value: draft.bodyType,
          items: VehicleCatalog.bodyTypes,
          onChanged: (v) {
            draft.bodyType = v;
            onChanged();
          },
        ),
      if (schema.shows('hullType'))
        _textField('Gövde tipi', draft.hullType ?? '', (v) {
          draft.hullType = v;
          onChanged();
        }),
      if (schema.shows('drive'))
        VehicleDropdownField(
          label: 'Çekiş',
          value: draft.drive,
          items: VehicleCatalog.drives,
          onChanged: (v) {
            draft.drive = v;
            onChanged();
          },
        ),
      if (schema.shows('color'))
        VehicleDropdownField(
          label: 'Renk',
          value: draft.color,
          items: VehicleCatalog.colors,
          onChanged: (v) {
            draft.color = v;
            onChanged();
          },
        ),
      if (schema.shows('engineCc'))
        _intField('Motor hacmi (cc)', draft.engineCc, (v) {
          draft.engineCc = v;
        }),
      if (schema.shows('powerHp'))
        _intField('Motor gücü (HP)', draft.powerHp, (v) {
          draft.powerHp = v;
        }),
      if (schema.shows('cylinders'))
        _intField('Silindir', draft.cylinders, (v) {
          draft.cylinders = v;
        }),
      if (schema.shows('torqueNm'))
        _intField('Tork (Nm)', draft.torqueNm, (v) {
          draft.torqueNm = v;
        }),
      if (schema.shows('zeroToHundred'))
        _textField('0-100 (sn)', draft.zeroToHundred ?? '', (v) {
          draft.zeroToHundred = v;
        }),
      if (schema.shows('topSpeedKmh'))
        _textField('Azami hız (km/s)', draft.topSpeedKmh ?? '', (v) {
          draft.topSpeedKmh = v;
        }),
      if (schema.shows('cooling'))
        _textField('Soğutma', draft.cooling ?? '', (v) {
          draft.cooling = v;
          onChanged();
        }),
      if (schema.shows('axles'))
        _intField('Dingil', draft.axles, (v) {
          draft.axles = v;
        }),
      if (schema.shows('payloadKg'))
        _intField('Taşıma kapasitesi (kg)', draft.payloadKg, (v) {
          draft.payloadKg = v;
        }),
      if (schema.shows('passengerCapacity'))
        _intField('Kişi kapasitesi', draft.passengerCapacity, (v) {
          draft.passengerCapacity = v;
        }),
      if (schema.shows('berths'))
        _intField('Yatak kapasitesi', draft.berths, (v) {
          draft.berths = v;
        }),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        VehicleWizardSection(
          title: 'Temel bilgiler',
          child: _twoCol(wide, fields),
        ),
        if (schema.shows('kitchen') ||
            schema.shows('shower') ||
            schema.shows('wc') ||
            schema.shows('solar'))
          VehicleWizardSection(
            title: 'Karavan donanımı',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mutfak'),
                  value: draft.kitchen,
                  onChanged: (v) {
                    draft.kitchen = v;
                    onChanged();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Duş'),
                  value: draft.shower,
                  onChanged: (v) {
                    draft.shower = v;
                    onChanged();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('WC'),
                  value: draft.wc,
                  onChanged: (v) {
                    draft.wc = v;
                    onChanged();
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Güneş paneli'),
                  value: draft.solar,
                  onChanged: (v) {
                    draft.solar = v;
                    onChanged();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _twoCol(bool wide, List<Widget> children) {
    if (!wide) return Column(children: children);
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 10),
            Expanded(
              child: i + 1 < children.length
                  ? children[i + 1]
                  : const SizedBox(),
            ),
          ],
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _intField(
    String label,
    int? value,
    ValueChanged<int?> onSave, {
    String? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value?.toString() ?? '',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: vehicleWizardInputDecoration(
          label,
        ).copyWith(suffixText: suffix),
        onChanged: (raw) {
          onSave(raw.trim().isEmpty ? null : int.tryParse(raw));
          onChanged();
        },
      ),
    );
  }

  Widget _textField(
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
