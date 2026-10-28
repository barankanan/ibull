import 'package:flutter/material.dart';

import '../../theme/ihiz_brand.dart';

class IhizHomeTask {
  const IhizHomeTask({
    required this.storeName,
    required this.ctaLabel,
    required this.onPressed,
    this.destination = '',
    this.typeLabel = '',
    this.distance,
    this.eta,
    this.earning,
    this.status,
    this.enabled = true,
    this.busy = false,
    this.active = false,
  });

  final String storeName;
  final String destination;
  final String typeLabel;
  final String? distance;
  final String? eta;
  final String? earning;
  final String? status;
  final String ctaLabel;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool busy;
  final bool active;
}

class IhizCourierMobileHome extends StatelessWidget {
  const IhizCourierMobileHome({
    super.key,
    required this.displayName,
    required this.online,
    required this.onToggleOnline,
    required this.loading,
    required this.onRetry,
    required this.tasks,
    this.error,
    this.activeTask,
  });

  final String? displayName;
  final bool online;
  final VoidCallback onToggleOnline;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final IhizHomeTask? activeTask;
  final List<IhizHomeTask> tasks;

  @override
  Widget build(BuildContext context) {
    final name = displayName?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const IhizLogoLockup(size: 20, color: IhizBrand.ink),
            const Spacer(),
            _StatusChip(online: online, onTap: onToggleOnline),
          ],
        ),
        if (name.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Merhaba, $name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w600,
              fontSize: 18,
              height: 1.2,
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (loading)
          const _BlockSkeleton(height: 132)
        else if (error != null)
          _EmptyPanel(
            title: 'Teslimatlar yüklenemedi.',
            body: error!,
            action: 'Tekrar dene',
            onAction: onRetry,
          )
        else ...[
          if (activeTask != null) ...[
            const _SectionLabel('Aktif teslimat'),
            const SizedBox(height: 8),
            _TaskCard(task: activeTask!),
            const SizedBox(height: 18),
          ],
          const _SectionLabel('Uygun teslimatlar'),
          const SizedBox(height: 8),
          if (tasks.isEmpty)
            _EmptyPanel(
              title: activeTask == null
                  ? 'Şu anda uygun teslimat yok.'
                  : 'Başka uygun teslimat yok.',
              body: 'Yeni görevler geldiğinde burada görünecek.',
              action: 'Yenile',
              onAction: onRetry,
            )
          else
            for (var i = 0; i < tasks.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _TaskCard(task: tasks[i]),
            ],
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: IhizBrand.inkSoft,
        fontWeight: FontWeight.w600,
        fontSize: 13,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final IhizHomeTask task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: task.active ? IhizBrand.blue : IhizBrand.line,
          width: task.active ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (task.typeLabel.trim().isNotEmpty)
                _Pill(task.typeLabel, filled: false),
              const Spacer(),
              if ((task.earning ?? '').trim().isNotEmpty)
                _Pill(task.earning!.trim(), filled: true),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            task.storeName.trim().isEmpty ? 'Mağaza' : task.storeName.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          if (task.destination.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              task.destination.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: IhizBrand.inkSoft,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ],
          if ((task.status ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              task.status!.trim(),
              style: const TextStyle(
                color: IhizBrand.blue,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if ((task.distance ?? '').trim().isNotEmpty)
                _Pill(task.distance!.trim(), filled: false),
              if ((task.eta ?? '').trim().isNotEmpty)
                _Pill(task.eta!.trim(), filled: false),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: !task.enabled || task.busy ? null : task.onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: IhizBrand.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: task.busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(task.ctaLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.filled});

  final String text;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? IhizBrand.blue.withValues(alpha: 0.1) : IhizBrand.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: filled ? IhizBrand.blue : IhizBrand.ink,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: IhizBrand.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.inventory_2_outlined, color: IhizBrand.blue),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: IhizBrand.ink,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              color: IhizBrand.inkSoft,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: IhizBrand.blue,
              minimumSize: const Size(44, 44),
              side: const BorderSide(color: IhizBrand.line),
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

class _BlockSkeleton extends StatelessWidget {
  const _BlockSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: IhizBrand.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class IhizCourierBottomNav extends StatelessWidget {
  const IhizCourierBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 76,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: IhizBrand.line),
            boxShadow: IhizBrand.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: 'Ana Sayfa',
                  selected: selectedIndex == 0,
                  onTap: () => onSelected(0),
                ),
                _NavItem(
                  icon: Icons.map_outlined,
                  selectedIcon: Icons.map_rounded,
                  label: 'Harita',
                  selected: selectedIndex == 1,
                  onTap: () => onSelected(1),
                ),
                _NavItem(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person_rounded,
                  label: 'Hesabım',
                  selected: selectedIndex == 2,
                  onTap: () => onSelected(2),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? IhizBrand.blue : IhizBrand.inkSoft;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected
                    ? IhizBrand.blue.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selected ? selectedIcon : icon, color: color, size: 22),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.online, required this.onTap});

  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = online ? IhizBrand.mint : IhizBrand.inkSoft;
    return Semantics(
      button: true,
      label: online ? 'Aktif' : 'Çevrimdışı',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: color),
                const SizedBox(width: 6),
                Text(
                  online ? 'Aktif' : 'Çevrimdışı',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

