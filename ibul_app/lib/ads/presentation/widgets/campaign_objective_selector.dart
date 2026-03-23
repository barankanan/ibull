import 'package:flutter/material.dart';

class CampaignObjectiveOption {
  const CampaignObjectiveOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
}

class CampaignObjectiveSelector extends StatelessWidget {
  const CampaignObjectiveSelector({
    required this.options,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<CampaignObjectiveOption> options;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1160
            ? 3
            : constraints.maxWidth > 720
            ? 2
            : 1;
        final cardRatio = switch (crossAxisCount) {
          3 => 2.5,
          2 => 2.2,
          _ => 1.95,
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
            final isSelected = option.id == selectedId;
            return _SelectionCard(
              title: option.title,
              description: option.description,
              icon: option.icon,
              selected: isSelected,
              onTap: () => onSelected(option.id),
            );
          },
        );
      },
    );
  }
}

class _SelectionCard extends StatefulWidget {
  const _SelectionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SelectionCard> createState() => _SelectionCardState();
}

class _SelectionCardState extends State<_SelectionCard> {
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
          padding: const EdgeInsets.all(12),
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
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.16)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  size: 18,
                  color: isSelected ? Colors.white : const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isSelected ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  widget.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11.8,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.88)
                        : const Color(0xFF64748B),
                    height: 1.32,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
