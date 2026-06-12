import 'package:flutter/material.dart';
import 'package:ibul_app/utils/order_status_constants.dart';


import '../../services/admin_service.dart';
import '../../services/product_question_service.dart';
import '../../services/support_service.dart';

enum AdminSupportScope { all, ihizCourierOnly }

class AdminSupportComplaintsPage extends StatefulWidget {
  const AdminSupportComplaintsPage({
    super.key,
    this.scope = AdminSupportScope.all,
  });

  final AdminSupportScope scope;

  @override
  State<AdminSupportComplaintsPage> createState() =>
      _AdminSupportComplaintsPageState();
}

class _AdminSupportComplaintsPageState
    extends State<AdminSupportComplaintsPage> {
  final AdminService _adminService = AdminService();
  final SupportService _supportService = SupportService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'Tum Talepler';
  late Future<List<Map<String, dynamic>>> _questionsFuture;
  bool get _isCourierOnly => widget.scope == AdminSupportScope.ihizCourierOnly;

  @override
  void initState() {
    super.initState();
    _questionsFuture = ProductQuestionService.instance.getAllQuestions();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _refreshQuestions() {
    setState(() {
      _questionsFuture = ProductQuestionService.instance.getAllQuestions();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCourierOnly) {
      return StreamBuilder<List<SupportTicket>>(
        stream: _supportService.getAllTickets(),
        builder: (context, supportSnapshot) {
          return _buildPage(
            supportTickets: _filterSupportTicketsByScope(
              supportSnapshot.data ?? const [],
            ),
            deletionRequests: const [],
            questions: const [],
            supportError: supportSnapshot.error,
            deletionError: null,
          );
        },
      );
    }

    return StreamBuilder<List<SupportTicket>>(
      stream: _supportService.getAllTickets(),
      builder: (context, supportSnapshot) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _adminService.getStoreDeletionRequestsStream(),
          builder: (context, deletionSnapshot) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: _questionsFuture,
              builder: (context, questionsSnapshot) {
                final supportTickets = _filterSupportTicketsByScope(
                  supportSnapshot.data ?? const [],
                );
                final deletionRequests = deletionSnapshot.data ?? const [];
                final questions = questionsSnapshot.data ?? const [];

                return _buildPage(
                  supportTickets: supportTickets,
                  deletionRequests: deletionRequests,
                  questions: questions,
                  supportError: supportSnapshot.error,
                  deletionError: deletionSnapshot.error,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPage({
    required List<SupportTicket> supportTickets,
    required List<Map<String, dynamic>> deletionRequests,
    required List<Map<String, dynamic>> questions,
    required Object? supportError,
    required Object? deletionError,
  }) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildHeroSection(
          supportTickets: supportTickets,
          deletionRequests: deletionRequests,
          questions: questions,
        ),
        const SizedBox(height: 20),
        _buildSummaryRow(
          supportTickets: supportTickets,
          deletionRequests: deletionRequests,
          questions: questions,
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: _buildTrendCard(
                supportTickets: supportTickets,
                deletionRequests: deletionRequests,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 5,
              child: _buildSignalPanel(
                supportTickets: supportTickets,
                deletionRequests: deletionRequests,
                questions: questions,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildErrorBanner(
          supportError: supportError,
          deletionError: deletionError,
        ),
        const SizedBox(height: 20),
        _buildToolbar(),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: _buildActivityBoard(
                supportTickets: supportTickets,
                deletionRequests: deletionRequests,
                questions: questions,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _buildQueuePanel(
                    supportTickets: supportTickets,
                    deletionRequests: deletionRequests,
                    questions: questions,
                  ),
                  const SizedBox(height: 20),
                  _buildAttentionPanel(
                    supportTickets: supportTickets,
                    deletionRequests: deletionRequests,
                    questions: questions,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<SupportTicket> _filterSupportTicketsByScope(
    List<SupportTicket> tickets,
  ) {
    if (!_isCourierOnly) {
      return tickets;
    }
    return tickets.where(_isIhizCourierTicket).toList();
  }

  bool _isIhizCourierTicket(SupportTicket ticket) {
    if (ticket.userType == 'courier') {
      return true;
    }
    final category = ticket.category.trim().toLowerCase();
    final subject = ticket.subject.trim().toLowerCase();
    final text = '${ticket.category} ${ticket.subject} ${ticket.description}'
        .toLowerCase();
    return category.startsWith('kurye /') ||
        category.startsWith('ihiz /') ||
        subject.startsWith('[kurye]') ||
        subject.startsWith('[ihiz]') ||
        subject.contains('teslimat gecikmesi bildirimi') ||
        subject.contains('adres doğrulama sorunu') ||
        subject.contains('adres dogrulama sorunu') ||
        subject.contains('ödeme/dekont sorunu') ||
        subject.contains('odeme/dekont sorunu') ||
        subject.contains('uygulama teknik hata bildirimi') ||
        subject.contains('canlı sohbet talebi') ||
        subject.contains('canli sohbet talebi') ||
        text.contains('kurye notu:') ||
        text.contains('kurye canlı sohbet') ||
        text.contains('kurye canli sohbet');
  }

  Widget _buildHeroSection({
    required List<SupportTicket> supportTickets,
    required List<Map<String, dynamic>> deletionRequests,
    required List<Map<String, dynamic>> questions,
  }) {
    final openSupport = supportTickets
        .where((ticket) => ticket.status != TicketStatus.closed)
        .length;
    final pendingDeletion = deletionRequests
        .where((request) => _readStatus(request) == AdminApprovalStatusConstants.pending)
        .length;
    final unansweredQuestions = questions
        .where((question) => _isQuestionUnanswered(question))
        .length;
    final resolvedSupport = supportTickets
        .where((ticket) => ticket.status == TicketStatus.resolved)
        .length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1F2A44)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCourierOnly
                      ? 'IHIZ kurye destek operasyon merkezi'
                      : 'Canli destek operasyon merkezi',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isCourierOnly
                      ? 'Kurye destek ve sikayet sinyallerini tek ekranda yonetin.'
                      : 'Kullanici, satici ve magaza kaynakli tum destek sinyalleri tek ekranda.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isCourierOnly
                      ? 'Kurye destek taleplerini, canli sohbet baslangiclarini ve eskalasyonlari bu ekrandan yonetin.'
                      : 'Acil destek taleplerini, magaza kapatma isteklerini ve cevapsiz urun sorularini bu ekrandan yonetin.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _isCourierOnly
                      ? [
                          _heroStatPill('Acil Destek', '$openSupport aktif'),
                          _heroStatPill(
                            'Sikayet Sinyali',
                            '${supportTickets.where((ticket) => _isComplaintLike(ticket)).length} kayit',
                          ),
                          _heroStatPill('Cozulen', '$resolvedSupport kayit'),
                        ]
                      : [
                          _heroStatPill('Acil Destek', '$openSupport aktif'),
                          _heroStatPill(
                            'Kapatma Talebi',
                            '$pendingDeletion bekliyor',
                          ),
                          _heroStatPill(
                            'Cevapsiz Soru',
                            '$unansweredQuestions musteri sorusu',
                          ),
                        ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Color(0xFFFBBF24)),
                    SizedBox(width: 8),
                    Text(
                      'Bugunku Durum',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _heroStatusRow(
                  'Toplam gelen kayit',
                  '${supportTickets.length + deletionRequests.length + questions.length}',
                ),
                if (_isCourierOnly) ...[
                  _heroStatusRow('Acil destek', '$openSupport'),
                  _heroStatusRow('Cozulen destek', '$resolvedSupport'),
                ] else ...[
                  _heroStatusRow(
                    'Satici kaynakli kayit',
                    '${supportTickets.where((ticket) => ticket.userType == 'seller').length + deletionRequests.length}',
                  ),
                  _heroStatusRow(
                    'Kullanici kaynakli kayit',
                    '${supportTickets.where((ticket) => ticket.userType != 'seller').length + questions.length}',
                  ),
                ],
                _heroStatusRow(
                  'Yuksek oncelik',
                  '${supportTickets.where((ticket) => ticket.priority == TicketPriority.high).length}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required List<SupportTicket> supportTickets,
    required List<Map<String, dynamic>> deletionRequests,
    required List<Map<String, dynamic>> questions,
  }) {
    final resolvedSupport = supportTickets
        .where((ticket) => ticket.status == TicketStatus.resolved)
        .length;
    final avgHours = _calculateAverageResponseHours(supportTickets);
    final complaintSignals =
        supportTickets.where((ticket) => _isComplaintLike(ticket)).length +
        deletionRequests
            .where((request) => _readStatus(request) == AdminApprovalStatusConstants.pending)
            .length;

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            icon: Icons.support_agent_rounded,
            iconColor: const Color(0xFF6366F1),
            background: const Color(0xFFEEF2FF),
            borderColor: const Color(0xFFC7D2FE),
            title: 'Acik Destek',
            value:
                '${supportTickets.where((ticket) => ticket.status != TicketStatus.closed && ticket.status != TicketStatus.resolved).length}',
            subtitle: 'Yanıt veya islem bekliyor',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _summaryCard(
            icon: Icons.task_alt_rounded,
            iconColor: const Color(0xFF10B981),
            background: const Color(0xFFECFDF5),
            borderColor: const Color(0xFFA7F3D0),
            title: 'Cozulen Kayit',
            value: '$resolvedSupport',
            subtitle: 'Kapatilan destek kaydi',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _summaryCard(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFF97316),
            background: const Color(0xFFFFF7ED),
            borderColor: const Color(0xFFFED7AA),
            title: 'Sikayet Sinyali',
            value: '$complaintSignals',
            subtitle: 'Yuksek oncelik ve eskalasyon',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _summaryCard(
            icon: Icons.schedule_rounded,
            iconColor: const Color(0xFF8B5CF6),
            background: const Color(0xFFF5F3FF),
            borderColor: const Color(0xFFDDD6FE),
            title: 'Ort. Geri Donus',
            value: avgHours == null ? '-' : '${avgHours.toStringAsFixed(1)} sa',
            subtitle: 'Guncellenme suresine gore',
          ),
        ),
      ],
    );
  }

  Widget _buildTrendCard({
    required List<SupportTicket> supportTickets,
    required List<Map<String, dynamic>> deletionRequests,
  }) {
    final chartData = _buildTrendData(supportTickets, deletionRequests);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
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
                      'Destek Akisi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isCourierOnly
                          ? 'Son 7 gunde acilan kurye destek ve sikayet kayitlari'
                          : 'Son 7 gunde acilan destek, sikayet sinyali ve magaza kapatma talepleri',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              _legendBadge(const Color(0xFF6C63FF), 'Destek'),
              const SizedBox(width: 8),
              _legendBadge(const Color(0xFFF97316), 'Sikayet'),
              if (!_isCourierOnly) ...[
                const SizedBox(width: 8),
                _legendBadge(const Color(0xFFEF4444), 'Kapatma'),
              ],
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 240,
            child: CustomPaint(
              painter: _AdminSupportTrendPainter(chartData: chartData),
              child: Container(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: chartData
                .map(
                  (point) => Expanded(
                    child: Text(
                      point.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalPanel({
    required List<SupportTicket> supportTickets,
    required List<Map<String, dynamic>> deletionRequests,
    required List<Map<String, dynamic>> questions,
  }) {
    final sellerTickets = supportTickets
        .where((ticket) => ticket.userType == 'seller')
        .length;
    final userTickets = supportTickets.length - sellerTickets;
    final complaintTickets = supportTickets
        .where((ticket) => _isComplaintLike(ticket))
        .length;
    final liveChatTickets = supportTickets
        .where(
          (ticket) =>
              ticket.category.toLowerCase().contains('canlı sohbet') ||
              ticket.subject.toLowerCase().contains('canlı sohbet') ||
              ticket.category.toLowerCase().contains('canli sohbet') ||
              ticket.subject.toLowerCase().contains('canli sohbet'),
        )
        .length;
    final unansweredQuestions = questions
        .where((question) => _isQuestionUnanswered(question))
        .length;
    final pendingDeletion = deletionRequests
        .where((request) => _readStatus(request) == AdminApprovalStatusConstants.pending)
        .length;

    final maxValue = _isCourierOnly
        ? [
            supportTickets.length,
            complaintTickets,
            liveChatTickets,
            1,
          ].reduce((a, b) => a > b ? a : b)
        : [
            sellerTickets,
            userTickets,
            unansweredQuestions,
            pendingDeletion,
            1,
          ].reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kuyruk Dagilimi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isCourierOnly
                ? 'Kurye destek hattinda bugun yonetilecek kuyruk'
                : 'Operasyon ekibinin bugun yonetecegi basliklar',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 22),
          if (_isCourierOnly) ...[
            _progressSignal(
              label: 'Toplam kurye talepleri',
              value: supportTickets.length,
              maxValue: maxValue,
              color: const Color(0xFF6366F1),
            ),
            _progressSignal(
              label: 'Sikayet sinyalleri',
              value: complaintTickets,
              maxValue: maxValue,
              color: const Color(0xFFF97316),
            ),
            _progressSignal(
              label: 'Canli sohbet talepleri',
              value: liveChatTickets,
              maxValue: maxValue,
              color: const Color(0xFF06B6D4),
            ),
            _progressSignal(
              label: 'Yuksek oncelikli kayit',
              value: supportTickets
                  .where((ticket) => ticket.priority == TicketPriority.high)
                  .length,
              maxValue: maxValue,
              color: const Color(0xFFEF4444),
            ),
          ] else ...[
            _progressSignal(
              label: 'Satici destekleri',
              value: sellerTickets,
              maxValue: maxValue,
              color: const Color(0xFF6366F1),
            ),
            _progressSignal(
              label: 'Kullanici destekleri',
              value: userTickets,
              maxValue: maxValue,
              color: const Color(0xFF06B6D4),
            ),
            _progressSignal(
              label: 'Cevapsiz urun sorulari',
              value: unansweredQuestions,
              maxValue: maxValue,
              color: const Color(0xFFF59E0B),
            ),
            _progressSignal(
              label: 'Magaza kapatma talepleri',
              value: pendingDeletion,
              maxValue: maxValue,
              color: const Color(0xFFEF4444),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isCourierOnly
                        ? 'Yuksek oncelikli kurye kayitlarini once isleme alip canli sohbet taleplerine hizli donus yapin.'
                        : 'Yuksek oncelikli kayitlari once isleme alip satici kaynakli eskalasyonlari gun icinde kapatmaniz onerilir.',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner({
    required Object? supportError,
    required Object? deletionError,
  }) {
    final issues = <String>[];
    if (supportError != null) {
      issues.add(supportError.toString().replaceFirst('Exception: ', ''));
    }
    if (deletionError != null) {
      issues.add(deletionError.toString().replaceFirst('Exception: ', ''));
    }
    if (issues.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 10),
              Text(
                'Kurulum gerekli',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...issues.map(
            (issue) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• $issue',
                style: const TextStyle(color: Color(0xFF92400E), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final filters = _isCourierOnly
        ? ['Tum Talepler', 'Destek', 'Sikayet']
        : ['Tum Talepler', 'Destek', 'Sikayet', 'Kapatma', 'Sorular'];

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _isCourierOnly
                          ? 'Talep, konu veya kurye ara'
                          : 'Talep, konu, kullanici veya urun ara',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        ...filters.map(
          (filter) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _filterChip(
              filter,
              isSelected: _selectedFilter == filter,
              onTap: () => setState(() => _selectedFilter = filter),
            ),
          ),
        ),
        if (!_isCourierOnly) ...[
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _refreshQuestions,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Yenile'),
          ),
        ],
      ],
    );
  }

  Widget _buildActivityBoard({
    required List<SupportTicket> supportTickets,
    required List<Map<String, dynamic>> deletionRequests,
    required List<Map<String, dynamic>> questions,
  }) {
    final items = _buildUnifiedActivityFeed(
      supportTickets: supportTickets,
      deletionRequests: deletionRequests,
      questions: questions,
    );

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Canli Talep Akisi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isCourierOnly
                ? 'IHIZ kurye uygulamasindan gelen destek ve sikayet akisi'
                : 'Uygulama icindeki destek, sikayet ve operasyonel sinyaller',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          if (items.isEmpty)
            Container(
              height: 320,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Filtreye uyan aktif kayit bulunmuyor.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 15),
              ),
            )
          else
            ...items.map(_buildFeedCard),
        ],
      ),
    );
  }

  Widget _buildQueuePanel({
    required List<SupportTicket> supportTickets,
    required List<Map<String, dynamic>> deletionRequests,
    required List<Map<String, dynamic>> questions,
  }) {
    final urgentTickets = supportTickets
        .where((ticket) => ticket.priority == TicketPriority.high)
        .take(3)
        .toList();
    final pendingDeletion = deletionRequests
        .where((request) => _readStatus(request) == AdminApprovalStatusConstants.pending)
        .take(3)
        .toList();
    final unansweredQuestions = questions
        .where((question) => _isQuestionUnanswered(question))
        .take(3)
        .toList();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acil Isler',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 18),
          ...urgentTickets.map(
            (ticket) => _queueItem(
              color: const Color(0xFFFEF2F2),
              borderColor: const Color(0xFFFECACA),
              icon: Icons.priority_high_rounded,
              iconColor: const Color(0xFFEF4444),
              title: _cleanTicketSubject(ticket.subject),
              subtitle:
                  '${_isCourierOnly ? 'Kurye' : (ticket.userType == 'seller' ? 'Satici' : 'Kullanici')} • ${ticket.category}',
            ),
          ),
          if (!_isCourierOnly) ...[
            ...pendingDeletion.map(
              (request) => _queueItem(
                color: const Color(0xFFFFF7ED),
                borderColor: const Color(0xFFFED7AA),
                icon: Icons.store_mall_directory_rounded,
                iconColor: const Color(0xFFF97316),
                title: 'Magaza kapatma talebi',
                subtitle: _shortUserId(request['seller_id']),
              ),
            ),
            ...unansweredQuestions.map(
              (question) => _queueItem(
                color: const Color(0xFFECFEFF),
                borderColor: const Color(0xFFA5F3FC),
                icon: Icons.help_outline_rounded,
                iconColor: const Color(0xFF0891B2),
                title: question['productName']?.toString().isNotEmpty == true
                    ? question['productName'].toString()
                    : 'Musteri sorusu',
                subtitle: question['question']?.toString() ?? '',
              ),
            ),
          ],
          if (urgentTickets.isEmpty &&
              (_isCourierOnly ||
                  (pendingDeletion.isEmpty && unansweredQuestions.isEmpty)))
            const Text(
              'Acil sirada kayit yok.',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
        ],
      ),
    );
  }

  Widget _buildAttentionPanel({
    required List<SupportTicket> supportTickets,
    required List<Map<String, dynamic>> deletionRequests,
    required List<Map<String, dynamic>> questions,
  }) {
    final sellerTickets = supportTickets
        .where((ticket) => ticket.userType == 'seller')
        .length;
    final userTickets = supportTickets.length - sellerTickets;
    final resolved = supportTickets
        .where((ticket) => ticket.status == TicketStatus.resolved)
        .length;
    final complaintCount = supportTickets
        .where((ticket) => _isComplaintLike(ticket))
        .length;
    final total = supportTickets.isEmpty ? 1 : supportTickets.length;
    final resolveRatio = resolved / total;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operasyon Notlari',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          _infoMetric(
            'Cozum orani',
            '%${(resolveRatio * 100).round()}',
            const Color(0xFF10B981),
          ),
          _infoMetric(
            _isCourierOnly ? 'Sikayet sinyali' : 'Satici talepleri',
            _isCourierOnly ? '$complaintCount' : '$sellerTickets',
            const Color(0xFF6C63FF),
          ),
          _infoMetric(
            _isCourierOnly ? 'Kurye talepleri' : 'Kullanici talepleri',
            _isCourierOnly ? '${supportTickets.length}' : '$userTickets',
            const Color(0xFF06B6D4),
          ),
          if (_isCourierOnly) ...[
            _infoMetric(
              'Yuksek oncelik',
              '${supportTickets.where((ticket) => ticket.priority == TicketPriority.high).length}',
              const Color(0xFFEF4444),
            ),
            _infoMetric(
              'Canli sohbet',
              '${supportTickets.where((ticket) => ticket.category.toLowerCase().contains('canli sohbet') || ticket.subject.toLowerCase().contains('canli sohbet') || ticket.category.toLowerCase().contains('canlı sohbet') || ticket.subject.toLowerCase().contains('canlı sohbet')).length}',
              const Color(0xFFF59E0B),
            ),
          ] else ...[
            _infoMetric(
              'Bekleyen kapatma',
              '${deletionRequests.where((request) => _readStatus(request) == AdminApprovalStatusConstants.pending).length}',
              const Color(0xFFEF4444),
            ),
            _infoMetric(
              'Cevapsiz sorular',
              '${questions.where((question) => _isQuestionUnanswered(question)).length}',
              const Color(0xFFF59E0B),
            ),
          ],
        ],
      ),
    );
  }

  List<_AdminFeedItem> _buildUnifiedActivityFeed({
    required List<SupportTicket> supportTickets,
    required List<Map<String, dynamic>> deletionRequests,
    required List<Map<String, dynamic>> questions,
  }) {
    final search = _searchController.text.trim().toLowerCase();
    final items = <_AdminFeedItem>[
      ...supportTickets.map(
        (ticket) => _AdminFeedItem(
          id: ticket.id,
          type: _isComplaintLike(ticket) ? 'Sikayet' : 'Destek',
          title: ticket.subject.isEmpty
              ? 'Destek talebi'
              : _cleanTicketSubject(ticket.subject),
          description: ticket.description,
          sourceLabel: _isCourierOnly
              ? 'Kurye • ${_shortUserId(ticket.userId)}'
              : (ticket.userType == 'seller'
                    ? 'Satici • ${_shortUserId(ticket.userId)}'
                    : 'Kullanici • ${_shortUserId(ticket.userId)}'),
          status: _ticketStatusLabel(ticket.status),
          priority: _ticketPriorityLabel(ticket.priority),
          createdAt: ticket.createdAt,
          accentColor: _ticketColor(ticket),
          raw: ticket,
        ),
      ),
      if (!_isCourierOnly) ...[
        ...deletionRequests.map(
          (request) => _AdminFeedItem(
            id: request['id']?.toString() ?? '',
            type: 'Kapatma',
            title: 'Satici hesabini kapatma talebi',
            description: request['reason']?.toString().trim().isNotEmpty == true
                ? request['reason'].toString()
                : 'Aciklama girilmemis.',
            sourceLabel: 'Satici • ${_shortUserId(request['seller_id'])}',
            status: _deletionStatusLabel(_readStatus(request)),
            priority: 'Kritik',
            createdAt: _parseDate(request['created_at']),
            accentColor: const Color(0xFFEF4444),
            raw: request,
          ),
        ),
        ...questions.map(
          (question) => _AdminFeedItem(
            id: question['id']?.toString() ?? '',
            type: 'Sorular',
            title: question['productName']?.toString().isNotEmpty == true
                ? question['productName'].toString()
                : 'Urun sorusu',
            description: question['question']?.toString() ?? '',
            sourceLabel:
                '${question['userName'] ?? 'Kullanici'} • ${question['storeName'] ?? 'Magaza'}',
            status: _isQuestionUnanswered(question) ? 'Cevapsiz' : 'Yanitlandi',
            priority: _isQuestionUnanswered(question) ? 'Orta' : 'Dusuk',
            createdAt: _parseDate(question['createdAt']),
            accentColor: _isQuestionUnanswered(question)
                ? const Color(0xFFF59E0B)
                : const Color(0xFF10B981),
            raw: question,
          ),
        ),
      ],
    ];

    return items.where((item) {
      if (_selectedFilter != 'Tum Talepler' && item.type != _selectedFilter) {
        return false;
      }
      if (search.isEmpty) return true;
      final haystack =
          '${item.title} ${item.description} ${item.sourceLabel} ${item.status}'
              .toLowerCase();
      return haystack.contains(search);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  String _cleanTicketSubject(String subject) {
    return subject
        .replaceFirst(RegExp(r'^\s*\[KURYE\]\s*', caseSensitive: false), '')
        .replaceFirst(RegExp(r'^\s*\[IHIZ\]\s*', caseSensitive: false), '')
        .trim();
  }

  Widget _buildFeedCard(_AdminFeedItem item) {
    if (item.type == 'Kapatma') {
      return _buildDeletionCard(item);
    }
    if (item.type == 'Destek' || item.type == 'Sikayet') {
      return _buildSupportCard(item);
    }
    return _buildQuestionCard(item);
  }

  Widget _buildSupportCard(_AdminFeedItem item) {
    final ticket = item.raw as SupportTicket;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: item.accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _tag(
                item.type,
                item.accentColor.withValues(alpha: 0.12),
                item.accentColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.description,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(
                item.sourceLabel,
                const Color(0xFFF3F4F6),
                const Color(0xFF4B5563),
              ),
              _tag(
                item.status,
                const Color(0xFFEEF2FF),
                const Color(0xFF4F46E5),
              ),
              _tag(
                item.priority,
                const Color(0xFFFFF7ED),
                const Color(0xFFEA580C),
              ),
              _tag(
                ticket.category,
                const Color(0xFFECFEFF),
                const Color(0xFF0F766E),
              ),
              _tag(
                _formatDateTime(item.createdAt),
                const Color(0xFFF8FAFC),
                const Color(0xFF64748B),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: () =>
                    _updateSupportTicket(ticket, TicketStatus.inProgress),
                child: const Text('Isleme Al'),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () =>
                    _updateSupportTicket(ticket, TicketStatus.resolved),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cozuldu'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeletionCard(_AdminFeedItem item) {
    final request = item.raw as Map<String, dynamic>;
    final isPending = _readStatus(request) == AdminApprovalStatusConstants.pending;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gpp_maybe_rounded, color: Color(0xFFEF4444)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _tag('Kapatma', const Color(0xFFFEE2E2), const Color(0xFFB91C1C)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.description,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(
                item.sourceLabel,
                const Color(0xFFF3F4F6),
                const Color(0xFF4B5563),
              ),
              _tag(
                item.status,
                const Color(0xFFFFF7ED),
                const Color(0xFFB45309),
              ),
              _tag(
                _formatDateTime(item.createdAt),
                const Color(0xFFF8FAFC),
                const Color(0xFF64748B),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton(
                  onPressed: () => _rejectDeletionRequest(request),
                  child: const Text('Reddet'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _approveDeletionRequest(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Onayla'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(_AdminFeedItem item) {
    final question = item.raw as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum_outlined, color: Color(0xFFF59E0B)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              _tag('Sorular', const Color(0xFFFFFBEB), const Color(0xFFD97706)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.description,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _tag(
                item.sourceLabel,
                const Color(0xFFF3F4F6),
                const Color(0xFF4B5563),
              ),
              _tag(
                item.status,
                const Color(0xFFFFFBEB),
                const Color(0xFFD97706),
              ),
              _tag(
                _formatDateTime(item.createdAt),
                const Color(0xFFF8FAFC),
                const Color(0xFF64748B),
              ),
            ],
          ),
          if (_isQuestionUnanswered(question)) ...[
            const SizedBox(height: 14),
            const Text(
              'Bu soru satici tarafinda henuz yanitlanmamis.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFFB45309),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _updateSupportTicket(
    SupportTicket ticket,
    TicketStatus nextStatus,
  ) async {
    try {
      await _supportService.updateTicketStatus(ticket.id, nextStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Destek kaydi ${_ticketStatusLabel(nextStatus).toLowerCase()} durumuna alindi.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _approveDeletionRequest(Map<String, dynamic> request) async {
    final requestId = request['id']?.toString();
    final sellerId = request['seller_id']?.toString();
    if (requestId == null || sellerId == null) return;
    try {
      await _adminService.approveStoreDeletion(requestId, sellerId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Magaza kapatma talebi onaylandi.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hata: $error')));
    }
  }

  Future<void> _rejectDeletionRequest(Map<String, dynamic> request) async {
    final requestId = request['id']?.toString();
    if (requestId == null) return;
    final noteController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Talebi Reddet'),
          content: TextField(
            controller: noteController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Reddetme notu',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgec'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _adminService.rejectStoreDeletion(
                    requestId,
                    noteController.text.trim().isEmpty
                        ? 'Admin tarafindan reddedildi'
                        : noteController.text.trim(),
                  );
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Talep reddedildi.')),
                  );
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Hata: $error')));
                }
              },
              child: const Text('Reddet'),
            ),
          ],
        );
      },
    );
  }

  List<_TrendPoint> _buildTrendData(
    List<SupportTicket> supportTickets,
    List<Map<String, dynamic>> deletionRequests,
  ) {
    final now = DateTime.now();
    return List.generate(7, (index) {
      final day = DateTime(now.year, now.month, now.day - (6 - index));
      final nextDay = day.add(const Duration(days: 1));
      final opened = supportTickets.where((ticket) {
        return !ticket.createdAt.isBefore(day) &&
            ticket.createdAt.isBefore(nextDay);
      }).length;
      final complaints = supportTickets.where((ticket) {
        return _isComplaintLike(ticket) &&
            !ticket.createdAt.isBefore(day) &&
            ticket.createdAt.isBefore(nextDay);
      }).length;
      final deletion = deletionRequests.where((request) {
        final createdAt = _parseDate(request['created_at']);
        return !createdAt.isBefore(day) && createdAt.isBefore(nextDay);
      }).length;
      return _TrendPoint(
        label: _weekdayShort(day.weekday),
        supportCount: opened,
        complaintCount: complaints,
        deletionCount: deletion,
      );
    });
  }

  bool _isComplaintLike(SupportTicket ticket) {
    final text = '${ticket.subject} ${ticket.description} ${ticket.category}'
        .toLowerCase();
    return ticket.priority == TicketPriority.high ||
        text.contains('sikayet') ||
        text.contains('iptal') ||
        text.contains('magdur');
  }

  Color _ticketColor(SupportTicket ticket) {
    if (_isComplaintLike(ticket)) {
      return const Color(0xFFF97316);
    }
    switch (ticket.priority) {
      case TicketPriority.high:
        return const Color(0xFFEF4444);
      case TicketPriority.medium:
        return const Color(0xFF6C63FF);
      case TicketPriority.low:
        return const Color(0xFF10B981);
    }
  }

  bool _isQuestionUnanswered(Map<String, dynamic> question) {
    return question['answer']?.toString().trim().isEmpty ?? true;
  }

  String _ticketStatusLabel(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return 'Acik';
      case TicketStatus.inProgress:
        return 'Islemde';
      case TicketStatus.closed:
        return 'Kapali';
      case TicketStatus.resolved:
        return 'Cozuldu';
    }
  }

  String _ticketPriorityLabel(TicketPriority priority) {
    switch (priority) {
      case TicketPriority.low:
        return 'Dusuk';
      case TicketPriority.medium:
        return 'Orta';
      case TicketPriority.high:
        return 'Yuksek';
    }
  }

  String _deletionStatusLabel(String status) {
    switch (status) {
      case AdminApprovalStatusConstants.approved:
        return 'Onaylandi';
      case AdminApprovalStatusConstants.rejected:
        return 'Reddedildi';
      default:
        return 'Onay Bekliyor';
    }
  }

  String _readStatus(Map<String, dynamic> row) {
    return row['status']?.toString().toLowerCase() ?? AdminApprovalStatusConstants.pending;
  }

  DateTime _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  String _shortUserId(dynamic value) {
    final text = value?.toString() ?? '-';
    if (text.length <= 8) return text;
    return '${text.substring(0, 4)}...${text.substring(text.length - 4)}';
  }

  String _formatDateTime(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  String _weekdayShort(int weekday) {
    const labels = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];
    return labels[weekday - 1];
  }

  double? _calculateAverageResponseHours(List<SupportTicket> supportTickets) {
    final items = supportTickets
        .where((ticket) => ticket.updatedAt != null)
        .toList();
    if (items.isEmpty) return null;
    final totalHours = items.fold<double>(0, (sum, ticket) {
      return sum +
          ticket.updatedAt!.difference(ticket.createdAt).inMinutes / 60.0;
    });
    return totalHours / items.length;
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A111827),
          blurRadius: 24,
          offset: Offset(0, 12),
        ),
      ],
    );
  }

  Widget _heroStatPill(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white),
          children: [
            TextSpan(
              text: '$title: ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required Color iconColor,
    required Color background,
    required Color borderColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _legendBadge(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressSignal({
    required String label,
    required int value,
    required int maxValue,
    required Color color,
  }) {
    final ratio = maxValue == 0 ? 0.0 : value / maxValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    String label, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF111827)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _queueItem({
    required Color color,
    required Color borderColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoMetric(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _AdminFeedItem {
  const _AdminFeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.sourceLabel,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.accentColor,
    required this.raw,
  });

  final String id;
  final String type;
  final String title;
  final String description;
  final String sourceLabel;
  final String status;
  final String priority;
  final DateTime createdAt;
  final Color accentColor;
  final Object raw;
}

class _TrendPoint {
  const _TrendPoint({
    required this.label,
    required this.supportCount,
    required this.complaintCount,
    required this.deletionCount,
  });

  final String label;
  final int supportCount;
  final int complaintCount;
  final int deletionCount;
}

class _AdminSupportTrendPainter extends CustomPainter {
  const _AdminSupportTrendPainter({required this.chartData});

  final List<_TrendPoint> chartData;

  @override
  void paint(Canvas canvas, Size size) {
    if (chartData.isEmpty) return;

    const leftPadding = 8.0;
    const rightPadding = 8.0;
    const bottomPadding = 18.0;
    const topPadding = 8.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    final maxValue = chartData
        .map(
          (point) => [
            point.supportCount,
            point.complaintCount,
            point.deletionCount,
          ].reduce((a, b) => a > b ? a : b),
        )
        .reduce((a, b) => a > b ? a : b)
        .clamp(1, 9999);

    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = topPadding + (chartHeight / 3) * i;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    final step = chartData.length == 1
        ? 0.0
        : chartWidth / (chartData.length - 1);
    final supportPath = Path();
    final complaintPath = Path();
    final deletionPath = Path();

    Offset pointFor(int index, int value) {
      final x = leftPadding + step * index;
      final normalized = value / maxValue;
      final y = topPadding + chartHeight - (normalized * chartHeight);
      return Offset(x, y);
    }

    for (var i = 0; i < chartData.length; i++) {
      final supportPoint = pointFor(i, chartData[i].supportCount);
      final complaintPoint = pointFor(i, chartData[i].complaintCount);
      final deletionPoint = pointFor(i, chartData[i].deletionCount);

      if (i == 0) {
        supportPath.moveTo(supportPoint.dx, supportPoint.dy);
        complaintPath.moveTo(complaintPoint.dx, complaintPoint.dy);
        deletionPath.moveTo(deletionPoint.dx, deletionPoint.dy);
      } else {
        supportPath.lineTo(supportPoint.dx, supportPoint.dy);
        complaintPath.lineTo(complaintPoint.dx, complaintPoint.dy);
        deletionPath.lineTo(deletionPoint.dx, deletionPoint.dy);
      }
    }

    final supportPaint = Paint()
      ..color = const Color(0xFF6C63FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final complaintPaint = Paint()
      ..color = const Color(0xFFF97316)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final deletionPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(supportPath, supportPaint);
    canvas.drawPath(complaintPath, complaintPaint);
    canvas.drawPath(deletionPath, deletionPaint);
  }

  @override
  bool shouldRepaint(covariant _AdminSupportTrendPainter oldDelegate) {
    return oldDelegate.chartData != chartData;
  }
}
