import 'package:flutter/material.dart';

import '../../../models/sub_admin.dart';
import 'staff_directory_actions.dart';

class _StaffDeleteDialog extends StatefulWidget {
  const _StaffDeleteDialog({required this.contact});

  final String contact;

  @override
  State<_StaffDeleteDialog> createState() => _StaffDeleteDialogState();
}

class _StaffDeleteDialogState extends State<_StaffDeleteDialog> {
  final TextEditingController _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allowed = canConfirmStaffRemoval(
      typed: _typed.text,
      contact: widget.contact,
    );
    return AlertDialog(
      title: const Text('Personeli sil'),
      content: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.contact.isEmpty
                ? 'İletişim bilgisi olmayan personel buradan silinemez. Önce pasifleştirin.'
                : 'Kalıcı silme için ${widget.contact} yazın. Sipariş geçmişi silinmez.',
          ),
          if (widget.contact.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _typed,
              decoration: const InputDecoration(
                labelText: 'İletişim bilgisini yazın',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: allowed ? () => Navigator.pop(context, true) : null,
          child: const Text('Sil'),
        ),
      ],
    );
  }
}

class StaffDirectoryView extends StatefulWidget {
  const StaffDirectoryView({
    super.key,
    required this.staff,
    required this.onInvite,
    required this.onEditPermissions,
    required this.onSetStatus,
    required this.onDelete,
  });

  final List<SubAdmin> staff;
  final VoidCallback onInvite;
  final ValueChanged<SubAdmin> onEditPermissions;
  final Future<void> Function(SubAdmin person, String status) onSetStatus;
  final Future<void> Function(SubAdmin person) onDelete;

  @override
  State<StaffDirectoryView> createState() => _StaffDirectoryViewState();
}

class _StaffDirectoryViewState extends State<StaffDirectoryView> {
  final TextEditingController _search = TextEditingController();
  String _status = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SubAdmin> get _visible {
    return filterStaffDirectory(
      staff: widget.staff,
      query: _search.text,
      status: _status,
    );
  }

  Future<void> _confirmDelete(SubAdmin person) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _StaffDeleteDialog(contact: staffContact(person));
      },
    );
    if (approved == true && mounted) {
      await widget.onDelete(person);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(wide),
        const SizedBox(height: 12),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('Bu filtrede personel yok.'))
              : wide
              ? _table(visible)
              : _cards(visible),
        ),
      ],
    );
  }

  Widget _toolbar(bool wide) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: widget.onInvite,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Personel ekle'),
        ),
        SizedBox(
          width: wide ? 280 : double.infinity,
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search),
              hintText: 'Ad, e-posta veya telefon',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('Tümü')),
            ButtonSegment(value: staffStatusActive, label: Text('Aktif')),
            ButtonSegment(value: staffStatusInvited, label: Text('Davetli')),
            ButtonSegment(value: staffStatusInactive, label: Text('Pasif')),
          ],
          selected: {_status},
          onSelectionChanged: (value) {
            setState(() => _status = value.first);
          },
        ),
      ],
    );
  }

  Widget _table(List<SubAdmin> people) {
    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Personel')),
            DataColumn(label: Text('İletişim')),
            DataColumn(label: Text('Yetkiler')),
            DataColumn(label: Text('Durum')),
            DataColumn(label: Text('İşlem')),
          ],
          rows: [
            for (final person in people)
              DataRow(
                cells: [
                  DataCell(Text(staffDisplayName(person))),
                  DataCell(Text(staffContact(person).isEmpty
                      ? '-'
                      : staffContact(person))),
                  DataCell(
                    Text(
                      person.permissions
                          .map(sellerPermissionShortLabel)
                          .join(', '),
                    ),
                  ),
                  DataCell(Text(staffStatusLabel(person.status))),
                  DataCell(_actions(person)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _cards(List<SubAdmin> people) {
    return ListView.separated(
      itemCount: people.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final person = people[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staffDisplayName(person),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(staffContact(person).isEmpty ? '-' : staffContact(person)),
                const SizedBox(height: 4),
                Text(staffStatusLabel(person.status)),
                const SizedBox(height: 8),
                _actions(person),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actions(SubAdmin person) {
    final deactivate = staffCanBeDeactivated(person);
    return Wrap(
      spacing: 4,
      children: [
        IconButton(
          tooltip: 'Yetki ver',
          onPressed: () => widget.onEditPermissions(person),
          icon: const Icon(Icons.admin_panel_settings_outlined),
        ),
        IconButton(
          tooltip: deactivate ? 'Pasifleştir' : 'Yeniden etkinleştir',
          onPressed: () => widget.onSetStatus(person, nextStaffStatus(person)),
          icon: Icon(deactivate ? Icons.pause_circle_outline : Icons.play_circle_outline),
        ),
        IconButton(
          tooltip: 'Güvenli sil',
          onPressed: () => _confirmDelete(person),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }
}
