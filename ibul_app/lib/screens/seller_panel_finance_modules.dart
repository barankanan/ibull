part of 'seller_panel_page.dart';

extension _SellerPanelFinanceModules on _SellerPanelPageState {
  Widget _buildMobileFinanceModuleImpl() {
    final finance = _buildFinanceSummary();
    final chartPoints =
        finance['chartPoints'] as List<SellerDashboardSeriesPoint>;
    final transactions = finance['transactions'] as List<Map<String, dynamic>>;
    final availableBalance = finance['availableBalance'] as double;
    final pendingBalance = finance['pendingBalance'] as double;
    final monthNetRevenue = finance['monthNetRevenue'] as double;
    final monthOrderCount = finance['monthOrderCount'] as int;
    final totalGrossRevenue = finance['totalGrossRevenue'] as double;

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildMobileModuleHero(
          title: 'Finans Merkezi',
          subtitle: 'Bakiye, ödeme özeti ve işlem hareketleri',
          icon: Icons.account_balance_wallet_rounded,
          primary: const Color(0xFF065F46),
          secondary: const Color(0xFF10B981),
        ),
        const SizedBox(height: 12),
        _mobileSurfaceCard(
          backgroundColor: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMobileStatCard(
                      width: double.infinity,
                      icon: Icons.account_balance_wallet_outlined,
                      color: const Color(0xFF3B82F6),
                      title: 'Kullanılabilir Bakiye',
                      value: _formatDashboardCurrency(availableBalance),
                      subtitle: 'Ödemeye hazır',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMobileStatCard(
                      width: double.infinity,
                      icon: Icons.schedule_outlined,
                      color: const Color(0xFFF59E0B),
                      title: 'Bekleyen Tahsilat',
                      value: _formatDashboardCurrency(pendingBalance),
                      subtitle: '${finance['pendingOrders']} sipariş',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildMobileStatCard(
                      width: double.infinity,
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF16A34A),
                      title: 'Bu Ay Net',
                      value: _formatDashboardCurrency(monthNetRevenue),
                      subtitle: '$monthOrderCount sipariş',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMobileStatCard(
                      width: double.infinity,
                      icon: Icons.shopping_cart_checkout_rounded,
                      color: const Color(0xFF8B5CF6),
                      title: 'Toplam Ciro',
                      value: _formatDashboardCurrency(totalGrossRevenue),
                      subtitle: '${finance['totalOrders']} satış',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _mobileSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kazanç Performansı',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDashboardRangeCaption(
                  _financeDateRange.start,
                  _financeDateRange.end,
                ),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDashboardRangeChip(
                    label: '7 Gün',
                    selected:
                        _financeRangePreset ==
                        SellerDashboardRangePreset.last7Days,
                    onTap: () => _setFinanceRangePreset(
                      SellerDashboardRangePreset.last7Days,
                    ),
                  ),
                  _buildDashboardRangeChip(
                    label: '30 Gün',
                    selected:
                        _financeRangePreset ==
                        SellerDashboardRangePreset.last30Days,
                    onTap: () => _setFinanceRangePreset(
                      SellerDashboardRangePreset.last30Days,
                    ),
                  ),
                  _buildDashboardRangeChip(
                    label: '3 Ay',
                    selected: _isFinanceRollingRangeSelected(90),
                    onTap: () => _setFinanceRollingRange(90),
                  ),
                  _buildDashboardRangeChip(
                    label: '6 Ay',
                    selected: _isFinanceRollingRangeSelected(180),
                    onTap: () => _setFinanceRollingRange(180),
                  ),
                  _buildDashboardRangeChip(
                    label: 'Tarih',
                    icon: Icons.calendar_month_outlined,
                    selected:
                        _financeRangePreset ==
                            SellerDashboardRangePreset.custom &&
                        !_isFinanceRollingRangeSelected(90) &&
                        !_isFinanceRollingRangeSelected(180),
                    onTap: _showFinanceRangeDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _mobileBadge(
                    'Brüt',
                    _formatDashboardCurrency(
                      finance['periodGrossRevenue'] as double,
                    ),
                  ),
                  _mobileBadge(
                    'Net',
                    _formatDashboardCurrency(
                      finance['periodNetRevenue'] as double,
                    ),
                  ),
                  _mobileBadge(
                    'Komisyon',
                    _formatDashboardCurrency(
                      finance['periodCommission'] as double,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFinancePerformanceChart(chartPoints),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _mobileSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMobileSectionTitle(
                'Ödeme Özeti',
                icon: Icons.payments_outlined,
              ),
              const SizedBox(height: 10),
              _buildFinanceInfoRow(
                'Tahsilat oranı',
                '%${(finance['collectionRate'] as double).toStringAsFixed(0)}',
              ),
              _buildFinanceInfoRow(
                'Ortalama sepet',
                _formatDashboardCurrency(
                  finance['averageOrderValue'] as double,
                ),
              ),
              _buildFinanceInfoRow(
                'Sonraki ödeme günü',
                finance['nextPayoutDate'] as String,
              ),
              _buildFinanceInfoRow(
                'Komisyon',
                _formatDashboardCurrency(finance['periodCommission'] as double),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _mobileSurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMobileSectionTitle(
                'İşlem Geçmişi',
                icon: Icons.history_toggle_off_rounded,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _financeTransactionTypeFilter,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Tum Islemler',
                    child: Text('Tüm İşlemler'),
                  ),
                  DropdownMenuItem(value: 'Satis', child: Text('Satışlar')),
                  DropdownMenuItem(value: 'Bekleyen', child: Text('Bekleyen')),
                  DropdownMenuItem(value: 'Komisyon', child: Text('Komisyon')),
                  DropdownMenuItem(value: 'Iade', child: Text('İade')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  _setFinanceTransactionTypeFilter(value);
                },
              ),
              const SizedBox(height: 10),
              if (transactions.isEmpty)
                Text(
                  'Bu aralıkta işlem kaydı bulunmuyor.',
                  style: TextStyle(color: Colors.grey.shade600),
                )
              else
                ...transactions.take(60).map((row) {
                  final date = row['date'];
                  final parsedDate = date is DateTime
                      ? date
                      : DateTime.tryParse(date?.toString() ?? '');
                  final amount = (row['amount'] as num?)?.toDouble() ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: (row['color'] as Color).withValues(
                              alpha: 0.12,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            row['icon'] as IconData,
                            color: row['color'] as Color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row['title']?.toString() ?? '-',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                row['subtitle']?.toString() ?? '-',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (parsedDate != null)
                                Text(
                                  _formatDateShort(parsedDate),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '${amount >= 0 ? '+' : '-'}${_formatDashboardCurrency(amount.abs())}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: amount >= 0
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinanceModuleImpl() {
    final finance = _buildFinanceSummary();
    final transactions = finance['transactions'] as List<Map<String, dynamic>>;
    final chartPoints =
        finance['chartPoints'] as List<SellerDashboardSeriesPoint>;
    final totalOrders = finance['totalOrders'] as int;
    final deliveredOrders = finance['deliveredOrders'] as int;
    final availableBalance = finance['availableBalance'] as double;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDashboardSectionLabel('FİNANS MERKEZİ'),
          const SizedBox(height: 12),
          _buildDashboardGrid([
            _buildFinanceSummaryCard(
              title: 'Kullanılabilir Bakiye',
              value: _formatDashboardCurrency(availableBalance),
              subtitle: 'Ödemeye hazır net bakiye',
              icon: Icons.account_balance_wallet_outlined,
              accent: const Color(0xFF3B82F6),
              accentSoft: const Color(0xFFE8F0FF),
              trend: finance['availableTrend'] as String,
              trendColor: finance['availableTrendColor'] as Color,
            ),
            _buildFinanceSummaryCard(
              title: 'Bekleyen Tahsilat',
              value: _formatDashboardCurrency(
                finance['pendingBalance'] as double,
              ),
              subtitle: 'Teslimat ve mutabakat bekliyor',
              icon: Icons.schedule_outlined,
              accent: const Color(0xFFF59E0B),
              accentSoft: const Color(0xFFFFF4DB),
              trend: '${finance['pendingOrders']} sipariş',
              trendColor: const Color(0xFFF59E0B),
            ),
            _buildFinanceSummaryCard(
              title: 'Bu Ay Net Kazanç',
              value: _formatDashboardCurrency(
                finance['monthNetRevenue'] as double,
              ),
              subtitle: '${finance['monthOrderCount']} sipariş',
              icon: Icons.trending_up_rounded,
              accent: const Color(0xFF16A34A),
              accentSoft: const Color(0xFFDCFCE7),
              trend: finance['monthTrend'] as String,
              trendColor: finance['monthTrendColor'] as Color,
            ),
            _buildFinanceSummaryCard(
              title: 'Toplam Ciro',
              value: _formatDashboardCurrency(
                finance['totalGrossRevenue'] as double,
              ),
              subtitle: '$totalOrders satış kaydı',
              icon: Icons.shopping_cart_checkout_rounded,
              accent: const Color(0xFF8B5CF6),
              accentSoft: const Color(0xFFF1E8FF),
              trend:
                  '%${(finance['collectionRate'] as double).toStringAsFixed(0)} tahsilat',
              trendColor: const Color(0xFF8B5CF6),
            ),
            _buildFinanceSummaryCard(
              title: 'Kesilen Komisyon',
              value: _formatDashboardCurrency(
                finance['periodCommission'] as double,
              ),
              subtitle: '%15 platform komisyonu',
              icon: Icons.percent_rounded,
              accent: const Color(0xFFEC4899),
              accentSoft: const Color(0xFFFCE7F3),
              trend: _formatChangeLabel(finance['commissionChange'] as double),
              trendColor: (finance['commissionChange'] as double) >= 0
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFEF4444),
            ),
          ], minItemWidth: 220),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildOverviewCardShell(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Kazanç Performansı',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDashboardRangeCaption(
                                      _financeDateRange.start,
                                      _financeDateRange.end,
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildDashboardRangeChip(
                                  label: '7 Gün',
                                  selected:
                                      _financeRangePreset ==
                                      SellerDashboardRangePreset.last7Days,
                                  onTap: () => _setFinanceRangePreset(
                                    SellerDashboardRangePreset.last7Days,
                                  ),
                                ),
                                _buildDashboardRangeChip(
                                  label: '30 Gün',
                                  selected:
                                      _financeRangePreset ==
                                      SellerDashboardRangePreset.last30Days,
                                  onTap: () => _setFinanceRangePreset(
                                    SellerDashboardRangePreset.last30Days,
                                  ),
                                ),
                                _buildDashboardRangeChip(
                                  label: '3 Ay',
                                  selected: _isFinanceRollingRangeSelected(90),
                                  onTap: () => _setFinanceRollingRange(90),
                                ),
                                _buildDashboardRangeChip(
                                  label: '6 Ay',
                                  selected: _isFinanceRollingRangeSelected(180),
                                  onTap: () => _setFinanceRollingRange(180),
                                ),
                                _buildDashboardRangeChip(
                                  label: 'Tarih',
                                  icon: Icons.calendar_month_outlined,
                                  selected:
                                      _financeRangePreset ==
                                          SellerDashboardRangePreset.custom &&
                                      !_isFinanceRollingRangeSelected(90) &&
                                      !_isFinanceRollingRangeSelected(180),
                                  onTap: _showFinanceRangeDialog,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                        child: Row(
                          children: [
                            _buildOverviewMetricInline(
                              'Brüt Gelir',
                              _formatDashboardCurrency(
                                finance['periodGrossRevenue'] as double,
                              ),
                              const Color(0xFF7C3AED),
                            ),
                            _buildOverviewInlineDivider(),
                            _buildOverviewMetricInline(
                              'Net Kazanç',
                              _formatDashboardCurrency(
                                finance['periodNetRevenue'] as double,
                              ),
                              const Color(0xFF10B981),
                            ),
                            _buildOverviewInlineDivider(),
                            _buildOverviewMetricInline(
                              'İadeler',
                              _formatDashboardCurrency(
                                finance['periodRefunds'] as double,
                              ),
                              const Color(0xFFEF4444),
                            ),
                            const Spacer(),
                            _buildLegendPill(
                              label: 'Net Kazanç',
                              color: const Color(0xFF7C3AED),
                            ),
                          ],
                        ),
                      ),
                      Container(height: 1, color: const Color(0xFFE5E7EB)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                        child: _buildFinancePerformanceChart(chartPoints),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _buildOverviewCardShell(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ödeme Özeti',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildFinanceInfoRow(
                            'Teslim edilen sipariş',
                            '$deliveredOrders',
                          ),
                          _buildFinanceInfoRow(
                            'Tahsilat oranı',
                            '%${(finance['collectionRate'] as double).toStringAsFixed(0)}',
                          ),
                          _buildFinanceInfoRow(
                            'Bekleyen sipariş',
                            '${finance['pendingOrders']}',
                          ),
                          _buildFinanceInfoRow(
                            'Ortalama sepet',
                            _formatDashboardCurrency(
                              finance['averageOrderValue'] as double,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value:
                                  (finance['collectionRate'] as double) / 100,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildOverviewCardShell(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.calendar_month_rounded,
                                color: Color(0xFF7C3AED),
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Ödeme Takvimi',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildFinanceInfoRow(
                            'Sonraki ödeme günü',
                            finance['nextPayoutDate'] as String,
                          ),
                          _buildFinanceInfoRow(
                            'Planlanan ödeme',
                            _formatDashboardCurrency(availableBalance),
                          ),
                          _buildFinanceInfoRow(
                            'Mutabakat modeli',
                            'T+7 çalışma günü',
                          ),
                          _buildFinanceInfoRow('Komisyon oranı', '%15'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildOverviewCardShell(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance_outlined,
                                color: Color(0xFF7C3AED),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Banka / Kurumsal Bilgi',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _setSelectedModule(SellerModule.store),
                                child: const Text('Düzenle'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _buildFinanceInfoRow(
                            'Şirket',
                            _companyNameController.text.trim().isEmpty
                                ? 'Tanımlanmadı'
                                : _companyNameController.text.trim(),
                          ),
                          _buildFinanceInfoRow(
                            'Ünvan',
                            _companyTitleController.text.trim().isEmpty
                                ? _companyType
                                : _companyTitleController.text.trim(),
                          ),
                          _buildFinanceInfoRow(
                            'Vergi Dairesi',
                            _taxOfficeController.text.trim().isEmpty
                                ? '-'
                                : _taxOfficeController.text.trim(),
                          ),
                          _buildFinanceInfoRow(
                            'Vergi No',
                            _taxNumberController.text.trim().isEmpty
                                ? '-'
                                : _taxNumberController.text.trim(),
                          ),
                          _buildFinanceInfoRow(
                            'İletişim',
                            _emailController.text.trim().isEmpty
                                ? _phoneController.text.trim().isEmpty
                                      ? '-'
                                      : _phoneController.text.trim()
                                : _emailController.text.trim(),
                          ),
                          if (_companyNameController.text.trim().isEmpty &&
                              _taxNumberController.text.trim().isEmpty) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Banka hesabı alanı projede henüz ayrı tutulmuyor. Mağaza profili üzerinden kurumsal/ödeme bilgilerinizi tamamlayabilirsiniz.',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildOverviewCardShell(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_rounded,
                              color: Color(0xFF7C3AED),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'İşlem Geçmişi',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _downloadFinanceReport(transactions),
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 16,
                              ),
                              label: const Text('Rapor İndir'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF7C3AED),
                                side: const BorderSide(
                                  color: Color(0xFFD8C8FF),
                                ),
                                backgroundColor: const Color(0xFFF8F5FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildFinanceFilterDropdown(
                                value: _financeTransactionTypeFilter,
                                items: const [
                                  'Tum Islemler',
                                  'Satis',
                                  'Bekleyen',
                                  'Komisyon',
                                  'Iade',
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  _setFinanceTransactionTypeFilter(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: _showFinanceRangeDialog,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.date_range_rounded,
                                        size: 18,
                                        color: Color(0xFF7C3AED),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _financeRangeLabel(),
                                          style: const TextStyle(
                                            color: Color(0xFF334155),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.expand_more_rounded,
                                        size: 18,
                                        color: Color(0xFF64748B),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(height: 1, color: const Color(0xFFE5E7EB)),
                      if (transactions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(36),
                          child: Column(
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 44,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Seçili filtrelerde finans işlemi bulunmuyor',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      else
                        ...transactions
                            .take(12)
                            .map(
                              (transaction) =>
                                  _buildFinanceTransactionRow(transaction),
                            ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _buildOverviewCardShell(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Finans Sağlığı',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildFinanceHealthMetric(
                            'Net marj',
                            finance['marginRate'] as double,
                            const Color(0xFF10B981),
                          ),
                          const SizedBox(height: 16),
                          _buildFinanceHealthMetric(
                            'Komisyon etkisi',
                            finance['commissionRatePercent'] as double,
                            const Color(0xFFF59E0B),
                          ),
                          const SizedBox(height: 16),
                          _buildFinanceHealthMetric(
                            'İade oranı',
                            finance['refundRate'] as double,
                            const Color(0xFFEF4444),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildOverviewCardShell(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mutabakat Notları',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFinanceNoteTile(
                            color: const Color(0xFFE8F0FF),
                            accent: const Color(0xFF3B82F6),
                            icon: Icons.payments_outlined,
                            title: 'Ödeme için hazır',
                            subtitle:
                                '${_formatDashboardCurrency(availableBalance)} tutar bir sonraki ödeme döngüsüne uygun.',
                          ),
                          const SizedBox(height: 12),
                          _buildFinanceNoteTile(
                            color: const Color(0xFFFFF7ED),
                            accent: const Color(0xFFF97316),
                            icon: Icons.schedule_send_outlined,
                            title: 'Bekleyen tahsilat',
                            subtitle:
                                '${_formatDashboardCurrency(finance['pendingBalance'] as double)} teslimat veya T+7 mutabakat sürecinde.',
                          ),
                          const SizedBox(height: 12),
                          _buildFinanceNoteTile(
                            color: const Color(0xFFF8FAFC),
                            accent: const Color(0xFF64748B),
                            icon: Icons.info_outline_rounded,
                            title: 'Raporlama',
                            subtitle:
                                'İşlem geçmişi ve kazanç özetini CSV olarak dışa aktarabilirsiniz.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
