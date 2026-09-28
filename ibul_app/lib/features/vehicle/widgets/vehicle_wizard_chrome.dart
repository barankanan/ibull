import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants.dart';
import '../domain/vehicle_catalog.dart';

class VehicleWizardStepper extends StatelessWidget {
  const VehicleWizardStepper({
    super.key,
    required this.labels,
    required this.index,
    this.onSelect,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int>? onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Container(
                width: 16,
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: AppColors.borderStrong,
              ),
            InkWell(
              onTap: onSelect == null ? null : () => onSelect!(i),
              borderRadius: BorderRadius.circular(20),
              child: _dot(i),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dot(int i) {
    final active = i == index;
    final done = i < index;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.surface,
            border: Border.all(
              color: active
                  ? AppColors.primary
                  : done
                  ? AppColors.ink.withValues(alpha: 0.25)
                  : AppColors.borderStrong,
            ),
            shape: BoxShape.circle,
          ),
          child: done && !active
              ? const Icon(Icons.check, size: 12, color: AppColors.ink)
              : Text(
                  '${i + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : AppColors.textGrey,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(
          labels[i],
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? AppColors.ink : AppColors.textGrey,
          ),
        ),
      ],
    );
  }
}

class VehicleWizardSection extends StatelessWidget {
  const VehicleWizardSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.ink,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

InputDecoration vehicleWizardInputDecoration(String label, {String? hint}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: const BorderSide(color: AppColors.borderStrong),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
  );
}

class VehicleOptionChips<T> extends StatelessWidget {
  const VehicleOptionChips({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.expanded = false,
  });

  final List<T> values;
  final T? selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final value in values)
        VehicleOutlineChip(
          label: labelOf(value),
          selected: selected == value,
          expanded: expanded,
          onTap: () => onSelected(value),
        ),
    ];
    if (expanded) {
      return Row(
        children: [
          for (var i = 0; i < chips.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: chips[i]),
          ],
        ],
      );
    }
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class VehicleOutlineChip extends StatelessWidget {
  const VehicleOutlineChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.expanded = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderStrong,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
              ],
              if (expanded)
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                )
              else
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class VehicleSearchSelect extends StatefulWidget {
  const VehicleSearchSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.hint,
    this.lockMessage,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? hint;
  final String? lockMessage;

  @override
  State<VehicleSearchSelect> createState() => _VehicleSearchSelectState();
}

class _VehicleSearchSelectState extends State<VehicleSearchSelect> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant VehicleSearchSelect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && !_focus.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InputDecorator(
          decoration: vehicleWizardInputDecoration(widget.label),
          child: Text(
            widget.lockMessage ?? 'Önce önceki alanı seçin',
            style: const TextStyle(color: AppColors.textGrey),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RawAutocomplete<String>(
        textEditingController: _controller,
        focusNode: _focus,
        optionsBuilder: (text) {
          final q = text.text;
          final filtered = widget.options
              .where((item) {
                return VehicleCatalog.fold(
                  item,
                ).contains(VehicleCatalog.fold(q));
              })
              .toList(growable: false);
          if (filtered.isEmpty && q.trim().isNotEmpty) {
            return <String>[q.trim()];
          }
          return filtered;
        },
        onSelected: widget.onChanged,
        fieldViewBuilder: (context, controller, focusNode, onSubmit) {
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration:
                vehicleWizardInputDecoration(
                  widget.label,
                  hint: widget.hint ?? 'Yazarak arayın',
                ).copyWith(
                  suffixIcon: const Icon(
                    Icons.search,
                    color: AppColors.iconMuted,
                  ),
                ),
            onSubmitted: (raw) {
              final text = raw.trim();
              if (text.isEmpty) return;
              widget.onChanged(text);
              onSubmit();
            },
          );
        },
        optionsViewBuilder: (context, onSelected, opts) {
          final items = opts.toList(growable: false);
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 240,
                  maxWidth: 420,
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      dense: true,
                      title: Text(item),
                      onTap: () => onSelected(item),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class VehicleMoneyField extends StatelessWidget {
  const VehicleMoneyField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: value == null
            ? ''
            : VehicleMoney.format(value!, withSuffix: false),
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        decoration: vehicleWizardInputDecoration(
          label,
          hint: '1.250.000',
        ).copyWith(suffixText: 'TL'),
        onChanged: (raw) => onChanged(VehicleMoney.parse(raw)),
      ),
    );
  }
}

class VehicleDropdownField extends StatelessWidget {
  const VehicleDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final itemsWithValue = [
      ...items,
      if (value != null && value!.trim().isNotEmpty && !items.contains(value))
        value!,
    ];
    final selected = (value != null && itemsWithValue.contains(value))
        ? value
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$label-$selected'),
        initialValue: selected,
        decoration: vehicleWizardInputDecoration(label),
        items: [
          for (final item in itemsWithValue)
            DropdownMenuItem(value: item, child: Text(item)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
