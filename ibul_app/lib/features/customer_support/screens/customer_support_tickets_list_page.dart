import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/constants.dart';
import '../data/support_category_catalog.dart';
import '../models/customer_support_models.dart';
import '../services/customer_support_service.dart';
import '../widgets/support_responsive_center.dart';
import '../widgets/support_status_badge.dart';
import 'customer_support_chat_page.dart';

class CustomerSupportTicketsListPage extends StatefulWidget {
  const CustomerSupportTicketsListPage({super.key});

  @override
  State<CustomerSupportTicketsListPage> createState() =>
      _CustomerSupportTicketsListPageState();
}

class _CustomerSupportTicketsListPageState
    extends State<CustomerSupportTicketsListPage> {
  final _service = CustomerSupportService.instance;
  late Future<List<CustomerSupportTicket>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _ticketsFuture = _service.getMyTickets();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AppState>().isLoggedIn;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FA),
      appBar: AppBar(
        title: const Text('Taleplerim'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
      ),
      body: SupportResponsiveCenter(
        maxWidth: 720,
        child: !isLoggedIn
            ? const Center(child: Text('Taleplerini görmek için giriş yap.'))
            : FutureBuilder<List<CustomerSupportTicket>>(
                future: _ticketsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        snapshot.error.toString().replaceFirst('Exception: ', ''),
                      ),
                    );
                  }
                  final tickets = snapshot.data ?? const [];
                  if (tickets.isEmpty) {
                    return const Center(child: Text('Henüz destek talebin yok.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: tickets.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final ticket = tickets[index];
                      final updated = ticket.updatedAt ?? ticket.createdAt;
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          title: Text(ticket.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            '${supportCategoryTitle(ticket.category)} • ${DateFormat('dd MMM, HH:mm').format(updated.toLocal())}',
                          ),
                          trailing: SupportStatusBadge(status: ticket.status, compact: true),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CustomerSupportChatPage(ticketId: ticket.id),
                              ),
                            ).then((_) {
                              if (mounted) setState(_reload);
                            });
                          },
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
