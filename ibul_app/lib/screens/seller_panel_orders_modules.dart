part of 'seller_panel_page.dart';

extension _SellerPanelOrdersModules on _SellerPanelPageState {
  Widget _buildMobileOrdersModuleImpl() {
    final filteredOrders = _getFilteredSellerOrders();
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildMobileModuleHero(
          title: 'Sipariş Yönetimi',
          subtitle: 'Sipariş akışı, filtreleme ve hızlı aksiyonlar',
          icon: Icons.receipt_long_rounded,
          primary: const Color(0xFF1E3A8A),
          secondary: const Color(0xFF2563EB),
        ),
        const SizedBox(height: 12),
        _buildMobileSectionTitle('Sipariş Arama', icon: Icons.search_rounded),
        const SizedBox(height: 10),
        TextField(
          controller: _sellerOrderSearchController,
          onChanged: _handleSellerOrderSearchChanged,
          decoration: InputDecoration(
            hintText: 'Sipariş no, ürün adı veya müşteri ara...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildMobileOrderFilterChip('all', 'Tümü'),
              _buildMobileOrderFilterChip('new', 'Yeni'),
              _buildMobileOrderFilterChip('preparing', 'Hazırlanıyor'),
              _buildMobileOrderFilterChip('ready_to_ship', 'Hazır'),
              _buildMobileOrderFilterChip('shipped', 'Kargoda'),
              _buildMobileOrderFilterChip('returns', 'İade'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (filteredOrders.isEmpty)
          _mobileSurfaceCard(
            child: Center(
              child: Text(
                'Bu filtreye uygun sipariş bulunamadı.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ...filteredOrders.map(_buildMobileOrderCard),
      ],
    );
  }

  Widget _buildOrdersModuleImpl() {
    final selectedId = _selectedSellerOrderItemId;
    if (selectedId != null) {
      final resolved =
          _sellerOrderById[selectedId] ?? _selectedSellerOrderDetail;
      if (resolved != null && _shouldIncludeInSellerOrdersModule(resolved)) {
        return _buildSellerOrderDetailPage(resolved);
      }
      if (_selectedSellerOrderDetail != null &&
          _shouldIncludeInSellerOrdersModule(_selectedSellerOrderDetail!)) {
        return _buildSellerOrderDetailPage(_selectedSellerOrderDetail!);
      }
    } else if (_selectedSellerOrderDetail != null &&
        _shouldIncludeInSellerOrdersModule(_selectedSellerOrderDetail!)) {
      return _buildSellerOrderDetailPage(_selectedSellerOrderDetail!);
    }

    final statusCounts = _sellerOrderStatusCounts();
    final filteredOrders = _getFilteredSellerOrders();
    final query = _debouncedSellerOrderQuery;
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sellerOrderSearchController,
                      onChanged: _handleSellerOrderSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Sipariş no, ürün adı veya müşteri ara...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE4E7EC),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE4E7EC),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await _loadSellerOrders();
                      await _loadSellerQuestions();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Yenile'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: const Color(0xFF4A5568),
                      side: const BorderSide(color: Color(0xFFE4E7EC)),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sipariş Yönetimi',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF182032),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Siparişleri hazırlayın, paketleyin ve kargoya verin',
                      style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSellerExternalCargoEntryArea(),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  SizedBox(
                    width: 220,
                    child: _buildSellerOrderKpiCard(
                      title: 'Yeni Sipariş',
                      value: '${statusCounts['new'] ?? 0}',
                      caption: '',
                      icon: Icons.error_outline_rounded,
                      accent: const Color(0xFF2D64F1),
                      background: const Color(0xFFF1F6FF),
                      border: const Color(0xFFD6E5FF),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _buildSellerOrderKpiCard(
                      title: 'Hazırlanıyor',
                      value: '${statusCounts['preparing'] ?? 0}',
                      caption: '',
                      icon: Icons.schedule_rounded,
                      accent: const Color(0xFFDE7A00),
                      background: const Color(0xFFFFF8EA),
                      border: const Color(0xFFFFE3A7),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _buildSellerOrderKpiCard(
                      title: 'Gönderime Hazır',
                      value: '${statusCounts['ready_to_ship'] ?? 0}',
                      caption: '',
                      icon: Icons.check_circle_outline_rounded,
                      accent: const Color(0xFF159B67),
                      background: const Color(0xFFEFFAF5),
                      border: const Color(0xFFB7E8D1),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _buildSellerOrderKpiCard(
                      title: 'Ayrı Sipariş',
                      value: '${statusCounts['external'] ?? 0}',
                      caption: '',
                      icon: Icons.widgets_outlined,
                      accent: const Color(0xFF4C6FFF),
                      background: const Color(0xFFF3F6FF),
                      border: const Color(0xFFD9E2FF),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: _buildSellerOrderKpiCard(
                      title: 'Toplam Sipariş',
                      value: '${statusCounts['all'] ?? 0}',
                      caption: '',
                      icon: Icons.inventory_2_outlined,
                      accent: const Color(0xFF5B4CF0),
                      background: const Color(0xFFF2F3FF),
                      border: const Color(0xFFD9DFFF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSellerOrderFilterChip(
                        keyName: 'all',
                        label: 'Tümü',
                        count: statusCounts['all'] ?? 0,
                        color: AppColors.primary,
                      ),
                      _buildSellerOrderFilterChip(
                        keyName: 'new',
                        label: 'Yeni',
                        count: statusCounts['new'] ?? 0,
                        color: const Color(0xFF2D64F1),
                      ),
                      _buildSellerOrderFilterChip(
                        keyName: 'preparing',
                        label: 'Hazırlıyor',
                        count: statusCounts['preparing'] ?? 0,
                        color: const Color(0xFFDE7A00),
                      ),
                      _buildSellerOrderFilterChip(
                        keyName: 'ready_to_ship',
                        label: 'Hazır',
                        count: statusCounts['ready_to_ship'] ?? 0,
                        color: const Color(0xFF159B67),
                      ),
                      _buildSellerOrderFilterChip(
                        keyName: 'returns',
                        label: 'İade Talepleri',
                        count: statusCounts['returns'] ?? 0,
                        color: const Color(0xFFB45309),
                      ),
                      _buildSellerOrderFilterChip(
                        keyName: 'external',
                        label: 'Ayrı Sipariş',
                        count: statusCounts['external'] ?? 0,
                        color: const Color(0xFF4C6FFF),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoadingSellerOrders)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filteredOrders.isEmpty)
                _buildSellerOrdersEmptyState(query: query)
              else
                Column(
                  children: [
                    for (var i = 0; i < filteredOrders.length; i++) ...[
                      _buildSellerOrderCard(filteredOrders[i]),
                      if (i != filteredOrders.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
