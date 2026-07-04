import 'package:flutter/material.dart';

class TeamTasksPage extends StatelessWidget {
  const TeamTasksPage({super.key});

  static const _placeholderTasks = [
    _TaskRow(
      title: 'Reklam onay kuyruğu kontrolü',
      assignee: 'Operasyon',
      priority: 'Yüksek',
      status: 'Açık',
      dueDate: 'Bugün',
    ),
    _TaskRow(
      title: 'Haftalık destek özeti',
      assignee: 'Destek',
      priority: 'Orta',
      status: 'Devam ediyor',
      dueDate: 'Cuma',
    ),
    _TaskRow(
      title: 'Mağaza başvuru incelemesi',
      assignee: 'Ticaret',
      priority: 'Düşük',
      status: 'Planlandı',
      dueDate: 'Pazartesi',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHero(),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 3
                : constraints.maxWidth >= 640
                ? 2
                : 1;
            const spacing = 10.0;
            final itemWidth =
                (constraints.maxWidth - (columns - 1) * spacing) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: _kpiCard(
                    'Açık görevler',
                    '12',
                    Icons.assignment_outlined,
                    const Color(0xFFEA580C),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _kpiCard(
                    'Bugün tamamlanan',
                    '4',
                    Icons.task_alt_rounded,
                    const Color(0xFF16A34A),
                  ),
                ),
                SizedBox(
                  width: itemWidth,
                  child: _kpiCard(
                    'Ekip üyesi',
                    '8',
                    Icons.groups_outlined,
                    const Color(0xFF2563EB),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _buildTaskTable(),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ekip & Görevler',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Admin ekibinin görevlerini, sorumluluklarını ve operasyon takibini buradan yönetin.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.14),
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
              foregroundColor: Colors.white.withValues(alpha: 0.55),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Yeni görev'),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minHeight: 96, maxHeight: 110),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Text(
              'Görev listesi',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 720),
              child: Column(
                children: [
                  _tableHeader(),
                  ..._placeholderTasks.map(_tableRow),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _tableHeader() {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: const Row(
        children: [
          _HeaderCell('Görev adı', flex: 3),
          _HeaderCell('Sorumlu', flex: 2),
          _HeaderCell('Öncelik', flex: 2),
          _HeaderCell('Durum', flex: 2),
          _HeaderCell('Son tarih', flex: 2),
        ],
      ),
    );
  }

  Widget _tableRow(_TaskRow task) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          _BodyCell(task.title, flex: 3, bold: true),
          _BodyCell(task.assignee, flex: 2),
          _BodyCell(task.priority, flex: 2),
          _BodyCell(task.status, flex: 2),
          _BodyCell(task.dueDate, flex: 2),
        ],
      ),
    );
  }
}

class _TaskRow {
  const _TaskRow({
    required this.title,
    required this.assignee,
    required this.priority,
    required this.status,
    required this.dueDate,
  });

  final String title;
  final String assignee;
  final String priority;
  final String status;
  final String dueDate;
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, {required this.flex});

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell(this.value, {required this.flex, this.bold = false});

  final String value;
  final int flex;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: const Color(0xFF0F172A),
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
