import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/constants.dart';
import '../../../widgets/account_sidebar.dart';
import '../../../widgets/web_header.dart';
import '../../../widgets/web_sticky_footer_scroll_view.dart';
import '../data/support_category_catalog.dart';
import '../models/customer_support_models.dart';
import '../services/customer_support_service.dart';
import '../widgets/support_responsive_center.dart';
import '../widgets/support_status_badge.dart';
import 'customer_support_chat_page.dart';
import 'customer_support_tickets_list_page.dart';

class CustomerSupportPage extends StatefulWidget {
  const CustomerSupportPage({super.key});

  @override
  State<CustomerSupportPage> createState() => _CustomerSupportPageState();
}

class _CustomerSupportPageState extends State<CustomerSupportPage> {
  final _service = CustomerSupportService.instance;
  late Future<List<CustomerSupportTicket>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _reloadTickets();
  }

  void _reloadTickets() {
    _ticketsFuture = _service.getMyTickets();
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerSupportChatPage(),
      ),
    ).then((_) {
      if (mounted) setState(_reloadTickets);
    });
  }

  void _openTicket(CustomerSupportTicket ticket) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerSupportChatPage(ticketId: ticket.id),
      ),
    ).then((_) {
      if (mounted) setState(_reloadTickets);
    });
  }

  void _openAllTickets() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CustomerSupportTicketsListPage(),
      ),
    ).then((_) {
      if (mounted) setState(_reloadTickets);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.select<AppState, bool>((s) => s.isLoggedIn);
    final isWeb = MediaQuery.sizeOf(context).width >= 800;

    if (isWeb) {
      return _buildWebView(isLoggedIn);
    }
    return _buildMobileView(isLoggedIn);
  }

  Widget _buildMobileView(bool isLoggedIn) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FA),
      appBar: AppBar(
        title: const Text('Müşteri Hizmetleri'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_reloadTickets);
          await _ticketsFuture;
        },
        child: SupportResponsiveCenter(
          maxWidth: kSupportHubMaxWidth,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: ListView(
            children: [
              _buildLeftColumn(),
              const SizedBox(height: 20),
              _buildTicketsSection(isLoggedIn),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebView(bool isLoggedIn) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FA),
      body: Column(
        children: [
          WebHeader(onSearch: (_) {}, activeMenu: 'account'),
          Expanded(
            child: WebStickyFooterScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 24,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 280,
                          child: AccountSidebar(
                            activePage: 'Müşteri Hizmetleri',
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Müşteri Hizmetleri',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Destek ve talepler',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 24),
                              SupportResponsiveCenter(
                                maxWidth: kSupportHubMaxWidth,
                                padding: EdgeInsets.zero,
                                child: _buildHubGrid(isLoggedIn),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHubGrid(bool isLoggedIn) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;
        if (!isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildLeftColumn(),
              const SizedBox(height: 24),
              _buildTicketsSection(isLoggedIn),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 11,
              child: _buildLeftColumn(),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 10,
              child: _buildTicketsSection(isLoggedIn),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPremiumHero(),
        const SizedBox(height: 16),
        _buildQuickActions(),
      ],
    );
  }

  Widget _buildPremiumHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.82),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Müşteri Hizmetleri',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bize yaz, sorununu hızlıca çözelim.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Destek taleplerin İBUL ekibine iletilir.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.support_agent_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 36,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: _openChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Mesajla Destek Al',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white70,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Sesli Arama • Yakında',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final messageCard = _quickCard(
      icon: Icons.chat_bubble_outline,
      title: 'Mesajla Destek',
      subtitle: 'Yazışarak destek al.',
      onTap: _openChat,
    );
    final voiceCard = _quickCard(
      icon: Icons.call_outlined,
      title: 'Sesli Destek',
      subtitle: 'Yakında aktif.',
      onTap: null,
      badge: 'Yakında',
    );
    final aiCard = _quickCard(
      icon: Icons.psychology_outlined,
      title: 'AI Destek Asistanı',
      subtitle: 'Yakında aktif.',
      onTap: null,
      badge: 'Yakında',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackVertically = constraints.maxWidth < 560;
        if (stackVertically) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              messageCard,
              const SizedBox(height: 10),
              voiceCard,
              const SizedBox(height: 10),
              aiCard,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: messageCard),
            const SizedBox(width: 10),
            Expanded(child: voiceCard),
            const SizedBox(width: 10),
            Expanded(child: aiCard),
          ],
        );
      },
    );
  }

  Widget _quickCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    String? badge,
  }) {
    final enabled = onTap != null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: enabled ? AppColors.primary.withValues(alpha: 0.04) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: enabled ? AppColors.primary : Colors.grey, size: 22),
                  if (badge != null) ...[
                    const Spacer(),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: enabled ? Colors.black87 : Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketsSection(bool isLoggedIn) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8EAF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Taleplerim',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (!isLoggedIn)
            _emptyTickets('Giriş yapınca taleplerin burada görünür.')
          else
            FutureBuilder<List<CustomerSupportTicket>>(
              future: _ticketsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return _emptyTickets('Talepler yüklenemedi.');
                }
                final tickets = snapshot.data ?? const [];
                if (tickets.isEmpty) {
                  return _emptyTickets('Henüz destek talebin yok.');
                }

                final preview = tickets.take(3).toList();
                return Column(
                  children: [
                    ...preview.map(_buildTicketPreview),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: _openAllTickets,
                        child: const Text('Tüm taleplerimi gör'),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _emptyTickets(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }

  Widget _buildTicketPreview(CustomerSupportTicket ticket) {
    final updated = ticket.updatedAt ?? ticket.createdAt;
    final date = DateFormat('dd MMM, HH:mm').format(updated.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openTicket(ticket),
          hoverColor: AppColors.primary.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          _miniChip(supportCategoryTitle(ticket.category)),
                          SupportStatusBadge(status: ticket.status, compact: true),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }
}
