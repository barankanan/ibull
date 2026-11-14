import 'package:flutter/material.dart';

import '../../services/store/store_customer_directory.dart';

const _accent = Color(0xFF6C63FF);

Future<void> showStoreCustomerPicker({
  required BuildContext context,
  required String storeId,
  required int tableNumber,
  required bool canEdit,
  StoreCustomerDirectory? directory,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => _StoreCustomerPicker(
      storeId: storeId,
      tableNumber: tableNumber,
      canEdit: canEdit,
      directory: directory ?? StoreCustomerDirectory(),
    ),
  );
}

class _StoreCustomerPicker extends StatefulWidget {
  const _StoreCustomerPicker({
    required this.storeId,
    required this.tableNumber,
    required this.canEdit,
    required this.directory,
  });

  final String storeId;
  final int tableNumber;
  final bool canEdit;
  final StoreCustomerDirectory directory;

  @override
  State<_StoreCustomerPicker> createState() => _StoreCustomerPickerState();
}

class _StoreCustomerPickerState extends State<_StoreCustomerPicker> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  List<StoreCustomer> _results = const <StoreCustomer>[];
  StoreCustomer? _selected;
  String? _error;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final selected = await widget.directory.selectionForTable(
        storeId: widget.storeId,
        tableNumber: widget.tableNumber,
      );
      final results = await widget.directory.search(
        storeId: widget.storeId,
        query: _search.text,
      );
      if (!mounted) return;
      setState(() {
        _selected = selected;
        _results = results;
        _loading = false;
      });
    } on StoreCustomerDirectoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _choose(StoreCustomer customer) async {
    if (!widget.canEdit || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.directory.selectForTable(
        storeId: widget.storeId,
        tableNumber: widget.tableNumber,
        customerId: customer.id,
      );
      if (!mounted) return;
      setState(() {
        _selected = customer;
        _busy = false;
        _error = null;
      });
    } on StoreCustomerDirectoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  Future<void> _clear() async {
    if (!widget.canEdit || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.directory.clearTable(
        storeId: widget.storeId,
        tableNumber: widget.tableNumber,
      );
      if (!mounted) return;
      setState(() {
        _selected = null;
        _busy = false;
        _error = null;
      });
    } on StoreCustomerDirectoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  Future<void> _create() async {
    if (!widget.canEdit || _busy) return;
    setState(() => _busy = true);
    try {
      final created = await widget.directory.create(
        storeId: widget.storeId,
        name: _name.text,
        phone: _phone.text,
      );
      await widget.directory.selectForTable(
        storeId: widget.storeId,
        tableNumber: widget.tableNumber,
        customerId: created.id,
      );
      _name.clear();
      _phone.clear();
      if (!mounted) return;
      setState(() {
        _selected = created;
        _busy = false;
        _error = null;
      });
      await _load();
    } on StoreCustomerDirectoryException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: const Color(0xFFF7F7F8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width > 520 ? 480 : width - 32,
          maxHeight: 560,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Müşteri Seç',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                'Masa ${widget.tableNumber}. Seçim siparişi, ödemeyi ve masa durumunu değiştirmez.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 8),
              if (_selected != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selected!.name}'
                          '${_selected!.phone.isEmpty ? '' : ' · ${_selected!.phone}'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      TextButton(
                        onPressed: widget.canEdit && !_busy ? _clear : null,
                        child: const Text('Seçimi kaldır'),
                      ),
                    ],
                  ),
                )
              else
                const Text(
                  'Bu masada seçili müşteri yok.',
                  style: TextStyle(fontSize: 12),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'İsim veya telefon',
                  prefixIcon: Icon(Icons.search, size: 18),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _load(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : _load,
                  child: const Text('Ara'),
                ),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _results.isEmpty
                    ? const Center(child: Text('Bu işletmede eşleşen müşteri yok.'))
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final customer = _results[index];
                          final active = customer.id == _selected?.id;
                          return ListTile(
                            dense: true,
                            tileColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: active ? _accent : const Color(0xFFE5E7EB),
                              ),
                            ),
                            title: Text(customer.name),
                            subtitle: Text(
                              customer.phone.isEmpty ? 'Telefon yok' : customer.phone,
                            ),
                            trailing: widget.canEdit
                                ? TextButton(
                                    onPressed: _busy ? null : () => _choose(customer),
                                    child: Text(active ? 'Seçili' : 'Seç'),
                                  )
                                : null,
                          );
                        },
                      ),
              ),
              if (widget.canEdit) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _name,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Yeni ad',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phone,
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Telefon',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _create,
                    child: const Text('Kaydet ve seç'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
