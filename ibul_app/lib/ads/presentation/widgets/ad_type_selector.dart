import 'package:flutter/material.dart';

class AdTypeOption {
  const AdTypeOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.recommended = false,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool recommended;
}

class AdTypeSelector extends StatelessWidget {
  const AdTypeSelector({
    required this.options,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<AdTypeOption> options;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1180
            ? 3
            : constraints.maxWidth > 760
            ? 2
            : 1;
        final cardRatio = switch (crossAxisCount) {
          3 => 3.05,
          2 => 3.05,
          _ => 2.9,
        };
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: options.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: cardRatio,
          ),
          itemBuilder: (context, index) {
            final option = options[index];
            return _AdTypeCard(
              option: option,
              selected: option.id == selectedId,
              onTap: () => onSelected(option.id),
            );
          },
        );
      },
    );
  }
}

class _AdTypeCard extends StatefulWidget {
  const _AdTypeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AdTypeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_AdTypeCard> createState() => _AdTypeCardState();
}

class _AdTypeCardState extends State<_AdTypeCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.selected;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            border: Border.all(
              color: isSelected
                  ? const Color(0x332563EB)
                  : _hovered
                  ? const Color(0xFF93C5FD)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0x332563EB)
                    : const Color(0x080F172A),
                blurRadius: _hovered || isSelected ? 18 : 12,
                offset: Offset(0, _hovered || isSelected ? 10 : 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.16)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.option.icon,
                      size: 17,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF2563EB),
                    ),
                  ),
                  const Spacer(),
                  if (widget.option.recommended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.18)
                            : const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Onerilen',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFF1D4ED8),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.option.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.option.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 11.3,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.88)
                      : const Color(0xFF64748B),
                  height: 1.24,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
