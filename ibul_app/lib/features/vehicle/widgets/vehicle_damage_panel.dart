import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../domain/vehicle_catalog.dart';

class VehicleDamagePanel extends StatelessWidget {
  const VehicleDamagePanel({
    super.key,
    required this.values,
    required this.onChanged,
  });

  final Map<String, String> values;
  final void Function(String partId, String state) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final part in VehicleCatalog.damageParts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    part.label,
                    style: const TextStyle(fontSize: 13, color: AppColors.ink),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    children: [
                      for (final state in VehicleCatalog.damageStates)
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            VehicleCatalog.damageStateLabels[state] ?? state,
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: (values[part.id] ?? 'original') == state,
                          selectedColor: state == 'original'
                              ? AppColors.successSoft
                              : state == 'replaced'
                              ? AppColors.dangerSoft
                              : AppColors.warningSoft,
                          onSelected: (_) => onChanged(part.id, state),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
