part of 'seller_panel_page.dart';

extension _SellerPanelSupportModules on _SellerPanelPageState {
  Widget _buildMobileSupportModuleImpl() {
    final tickets = List<SupportTicket>.from(_supportTickets)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final filteredTickets = _filterSupportTickets(tickets);
    final openCount = tickets
        .where(
          (ticket) =>
              ticket.status == TicketStatus.open ||
              ticket.status == TicketStatus.in_progress,
        )
        .length;
    final resolvedCount = tickets
        .where(
          (ticket) =>
              ticket.status == TicketStatus.closed ||
              ticket.status == TicketStatus.resolved,
        )
        .length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildMobileModuleHero(
          title: 'Destek Merkezi',
          subtitle: 'Destek taleplerini hızlı şekilde oluştur ve yanıtla',
          icon: Icons.support_agent_rounded,
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFF334155),
        ),
        const SizedBox(height: 10),
        _mobileSurfaceCard(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _mobileBadge('Açık Talep', '$openCount'),
              _mobileBadge('Çözülen', '$resolvedCount'),
              _mobileBadge('Toplam', '${tickets.length}'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _mobileSurfaceCard(
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showNewSupportTicketDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni Destek Talebi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _supportSearchController,
                onChanged: _scheduleSupportSearch,
                decoration: InputDecoration(
                  hintText: 'Talep no, konu veya kategori ara...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSupportTabButton(
                    'Tümü',
                    _selectedSupportTab == 'Tümü',
                    () => _setSelectedSupportTab('Tümü'),
                  ),
                  _buildSupportTabButton(
                    'Açık',
                    _selectedSupportTab == 'Açık',
                    () => _setSelectedSupportTab('Açık'),
                  ),
                  _buildSupportTabButton(
                    'Kapalı',
                    _selectedSupportTab == 'Kapalı',
                    () => _setSelectedSupportTab('Kapalı'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (filteredTickets.isEmpty)
          _mobileSurfaceCard(
            child: Center(
              child: Text(
                tickets.isEmpty
                    ? 'Henüz destek talebi bulunmuyor.'
                    : 'Bu filtrede kayıt bulunamadı.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ...filteredTickets
              .map(
                (ticket) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildSupportTicketCard(ticket),
                ),
              ),
      ],
    );
  }

  Widget _buildSupportModuleImpl() {
    final tickets = List<SupportTicket>.from(_supportTickets)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final filteredTickets = _filterSupportTickets(tickets);
    final openCount = tickets
        .where(
          (ticket) =>
              ticket.status == TicketStatus.open ||
              ticket.status == TicketStatus.in_progress,
        )
        .length;
    final resolvedThisMonth = tickets.where((ticket) {
      final now = DateTime.now();
      final isResolved =
          ticket.status == TicketStatus.closed ||
          ticket.status == TicketStatus.resolved;
      return isResolved &&
          ticket.updatedAt != null &&
          ticket.updatedAt!.year == now.year &&
          ticket.updatedAt!.month == now.month;
    }).length;
    final responseHours = tickets
        .where(
          (ticket) =>
              ticket.updatedAt != null &&
              ticket.updatedAt!.isAfter(ticket.createdAt),
        )
        .map(
          (ticket) =>
              ticket.updatedAt!.difference(ticket.createdAt).inMinutes / 60,
        )
        .toList();
    final avgResponseHours = responseHours.isEmpty
        ? null
        : responseHours.reduce((a, b) => a + b) / responseHours.length;
    final resolutionRate = tickets.isEmpty
        ? 0
        : ((tickets
                          .where(
                            (ticket) =>
                                ticket.status == TicketStatus.closed ||
                                ticket.status == TicketStatus.resolved,
                          )
                          .length /
                      tickets.length) *
                  100)
              .round();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildSupportSummaryCard(
                'Açık Talepler',
                '$openCount',
                Icons.support_agent,
                Colors.orange,
                subtitle: 'Yanıt veya aksiyon bekliyor',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSupportSummaryCard(
                'Çözülen',
                '$resolvedThisMonth',
                Icons.check_circle,
                Colors.green,
                subtitle: 'Bu ay çözülen kayıt',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSupportSummaryCard(
                'Ortalama Yanıt',
                avgResponseHours == null
                    ? '-'
                    : '${avgResponseHours.toStringAsFixed(1)}s',
                Icons.timer,
                Colors.blue,
                subtitle: 'Güncelleme süresine göre',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSupportSummaryCard(
                'Çözüm Oranı',
                '%$resolutionRate',
                Icons.insights_rounded,
                Colors.purple,
                subtitle: 'Kapalı + çözülen talepler',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildSupportTrendCard(tickets)),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: _buildSupportCategoryCard(tickets)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _showNewSupportTicketDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Yeni Destek Talebi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _supportSearchController,
                  onChanged: _scheduleSupportSearch,
                  decoration: InputDecoration(
                    hintText: 'Talep no, konu veya kategori ara...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildSupportTabButton(
                      'Tümü',
                      _selectedSupportTab == 'Tümü',
                      () => _setSelectedSupportTab('Tümü'),
                    ),
                    _buildSupportTabButton(
                      'Açık',
                      _selectedSupportTab == 'Açık',
                      () => _setSelectedSupportTab('Açık'),
                    ),
                    _buildSupportTabButton(
                      'Kapalı',
                      _selectedSupportTab == 'Kapalı',
                      () => _setSelectedSupportTab('Kapalı'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: filteredTickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.headset_mic_outlined,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tickets.isEmpty
                            ? 'Henüz destek talebi bulunmuyor'
                            : 'Bu filtreye uygun destek talebi bulunamadı',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredTickets.length,
                  itemBuilder: (context, index) =>
                      _buildSupportTicketCard(filteredTickets[index]),
                ),
        ),
      ],
    );
  }
}
