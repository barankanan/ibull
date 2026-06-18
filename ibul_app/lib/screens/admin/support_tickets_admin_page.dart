import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/customer_support/data/support_category_catalog.dart';
import '../../features/customer_support/models/customer_support_models.dart';
import '../../features/customer_support/services/customer_support_service.dart';
import '../../features/customer_support/widgets/support_status_badge.dart';

class SupportTicketsAdminPage extends StatefulWidget {
  const SupportTicketsAdminPage({super.key});

  @override
  State<SupportTicketsAdminPage> createState() => _SupportTicketsAdminPageState();
}

class _SupportTicketsAdminPageState extends State<SupportTicketsAdminPage> {
  final _service = CustomerSupportService.instance;
  final _searchController = TextEditingController();
  final _replyController = TextEditingController();
  final _internalNoteController = TextEditingController();

  String? _statusFilter;
  String? _categoryFilter;
  String? _priorityFilter;
  late Future<List<CustomerSupportTicket>> _ticketsFuture;
  CustomerSupportTicketDetail? _selectedDetail;
  bool _loadingDetail = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _replyController.dispose();
    _internalNoteController.dispose();
    super.dispose();
  }

  void _reload() {
    _ticketsFuture = _service.adminGetTickets(
      status: _statusFilter,
      category: _categoryFilter,
      priority: _priorityFilter,
      search: _searchController.text,
    );
  }

  Future<void> _openTicket(CustomerSupportTicket ticket) async {
    setState(() {
      _loadingDetail = true;
      _selectedDetail = null;
      _replyController.clear();
      _internalNoteController.clear();
    });
    try {
      final detail = await _service.adminGetTicketDetail(ticket.id);
      if (!mounted) return;
      setState(() => _selectedDetail = detail);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  Future<void> _reply({bool requestMoreInfo = false, bool internal = false}) async {
    final detail = _selectedDetail;
    if (detail == null) return;
    final text = internal
        ? _internalNoteController.text.trim()
        : _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      if (requestMoreInfo) {
        await _service.adminRequestMoreInfo(
          ticketId: detail.ticket.id,
          message: text,
        );
      } else {
        await _service.adminReplyTicket(
          ticketId: detail.ticket.id,
          message: text,
          internalNote: internal,
        );
      }
      _replyController.clear();
      _internalNoteController.clear();
      await _openTicket(detail.ticket);
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _updateStatus(CustomerSupportStatus status, {bool close = false}) async {
    final detail = _selectedDetail;
    if (detail == null) return;
    try {
      await _service.adminUpdateStatus(
        ticketId: detail.ticket.id,
        status: status,
        close: close,
      );
      await _openTicket(detail.ticket);
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: _buildListPane()),
        const VerticalDivider(width: 1),
        Expanded(flex: 6, child: _buildDetailPane()),
      ],
    );
  }

  Widget _buildListPane() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Müşteri Talepleri',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Ara: başlık, talep no, e-posta',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setState(_reload),
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => setState(_reload),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip('Durum', _statusFilter, {
                    null: 'Tümü',
                    ...{
                      for (final s in CustomerSupportStatus.values)
                        s.dbValue: s.label,
                    },
                  }, (v) {
                    setState(() {
                      _statusFilter = v;
                      _reload();
                    });
                  }),
                  _filterChip('Kategori', _categoryFilter, {
                    null: 'Tümü',
                    for (final c in supportCategoryCatalog) c.id: c.title,
                  }, (v) {
                    setState(() {
                      _categoryFilter = v;
                      _reload();
                    });
                  }),
                  _filterChip('Öncelik', _priorityFilter, {
                    null: 'Tümü',
                    for (final p in CustomerSupportPriority.values)
                      p.dbValue: p.label,
                  }, (v) {
                    setState(() {
                      _priorityFilter = v;
                      _reload();
                    });
                  }),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<CustomerSupportTicket>>(
            future: _ticketsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }
              final tickets = snapshot.data ?? const [];
              if (tickets.isEmpty) {
                return const Center(child: Text('Talep bulunamadı.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tickets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final ticket = tickets[index];
                  final selected = _selectedDetail?.ticket.id == ticket.id;
                  return Material(
                    color: selected ? const Color(0xFFF3E8FF) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      onTap: () => _openTicket(ticket),
                      title: Text(ticket.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '#${ticket.displayTicketNumber} • ${supportCategoryTitle(ticket.category)}',
                      ),
                      trailing: SupportStatusBadge(status: ticket.status, compact: true),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(
    String label,
    String? current,
    Map<String?, String> options,
    ValueChanged<String?> onChanged,
  ) {
    return PopupMenuButton<String?>(
      onSelected: onChanged,
      itemBuilder: (context) => options.entries
          .map(
            (entry) => PopupMenuItem<String?>(
              value: entry.key,
              child: Text('$label: ${entry.value}'),
            ),
          )
          .toList(),
      child: Chip(label: Text('$label: ${options[current] ?? current ?? 'Tümü'}')),
    );
  }

  Widget _buildDetailPane() {
    if (_loadingDetail) {
      return const Center(child: CircularProgressIndicator());
    }
    final detail = _selectedDetail;
    if (detail == null) {
      return const Center(child: Text('Detay için bir talep seçin.'));
    }

    final ticket = detail.ticket;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  SupportStatusBadge(status: ticket.status),
                ],
              ),
              const SizedBox(height: 8),
              Text('Talep: #${ticket.displayTicketNumber}'),
              Text('Kullanıcı: ${ticket.userEmail ?? ticket.userId}'),
              Text('Kategori: ${supportCategoryTitle(ticket.category)} / ${ticket.subcategory}'),
              Text('Öncelik: ${ticket.priority.label}'),
              Text(
                'Oluşturulma: ${DateFormat('dd.MM.yyyy HH:mm').format(ticket.createdAt.toLocal())}',
              ),
              const Divider(height: 24),
              Text(ticket.message),
              if (detail.attachments.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Ekler', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: detail.attachments.map(_buildAttachmentTile).toList(),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Konuşma', style: TextStyle(fontWeight: FontWeight.w700)),
              ...detail.messages.where((m) => !m.isInternalNote).map(
                (m) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: m.isAdmin
                        ? const Color(0xFFF3E8FF)
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.isAdmin ? 'İBUL Destek' : 'Kullanıcı',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(m.message),
                    ],
                  ),
                ),
              ),
              ...detail.messages.where((m) => m.isInternalNote).map(
                (m) => ListTile(
                  dense: true,
                  title: Text('[Dahili] ${m.message}'),
                  subtitle: Text('${m.createdAt.toLocal()}'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _replyController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Admin cevabı',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _internalNoteController,
                decoration: const InputDecoration(
                  labelText: 'Dahili not (opsiyonel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _sending ? null : () => _reply(),
                    child: const Text('Cevapla'),
                  ),
                  OutlinedButton(
                    onPressed: _sending ? null : () => _reply(requestMoreInfo: true),
                    child: const Text('Ek bilgi iste'),
                  ),
                  OutlinedButton(
                    onPressed: _sending ? null : () => _reply(internal: true),
                    child: const Text('Dahili not'),
                  ),
                  OutlinedButton(
                    onPressed: () => _updateStatus(
                      CustomerSupportStatus.resolved,
                      close: true,
                    ),
                    child: const Text('Çözüldü'),
                  ),
                  OutlinedButton(
                    onPressed: () => _updateStatus(
                      CustomerSupportStatus.closed,
                      close: true,
                    ),
                    child: const Text('Kapat'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentTile(CustomerSupportAttachment attachment) {
    final isImage = (attachment.fileType ?? '').startsWith('image/') ||
        attachment.fileName.toLowerCase().endsWith('.png') ||
        attachment.fileName.toLowerCase().endsWith('.jpg') ||
        attachment.fileName.toLowerCase().endsWith('.jpeg') ||
        attachment.fileName.toLowerCase().endsWith('.webp');

    return InkWell(
      onTap: () => _openAttachment(attachment, isImage: isImage),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: isImage ? 96 : null,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  attachment.fileUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
                ),
              )
            else
              const Icon(Icons.attach_file, size: 32),
            const SizedBox(height: 4),
            Text(
              attachment.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _openAttachment(
    CustomerSupportAttachment attachment, {
    required bool isImage,
  }) {
    if (isImage) {
      showDialog<void>(
        context: context,
        builder: (context) => Dialog(
          child: InteractiveViewer(
            child: Image.network(
              attachment.fileUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Padding(padding: EdgeInsets.all(24), child: Text('Görsel açılamadı')),
            ),
          ),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(attachment.fileName),
        content: SelectableText(attachment.fileUrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}
