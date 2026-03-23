import 'package:flutter/material.dart';

class IhizCourierPage extends StatefulWidget {
  const IhizCourierPage({super.key});

  @override
  State<IhizCourierPage> createState() => _IhizCourierPageState();
}

class _IhizCourierPageState extends State<IhizCourierPage> {
  bool _isOnline = true;
  int _selectedOrderIndex = 0;

  final List<_IhizOrderOpportunity> _orderPool = const [
    _IhizOrderOpportunity(
      title: 'Yakın teslimat',
      storeName: 'MacroCenter Eskişehir',
      storeAddress: 'Hoşnudiye Mah. İsmet İnönü 1 Cad. No:18',
      customerName: 'Sena A.',
      customerAddress: 'Cumhuriyet Mah. Fabrikalar Sok. No:14',
      pickupDistanceKm: 0.7,
      dropoffDistanceKm: 1.9,
      etaMinutes: 14,
      earning: 118,
      packageCount: 2,
      priority: 'Sıcak teslim',
      tags: ['Yakın rota', 'Motor uygun', 'Temassız teslim'],
      accentColor: Color(0xFF0F9D7A),
    ),
    _IhizOrderOpportunity(
      title: 'Çoklu paket',
      storeName: 'Teknosa Cassaba Modern',
      storeAddress: 'Büyükdere Cad. Cassaba Modern AVM Zemin Kat',
      customerName: 'Mert K.',
      customerAddress: 'Vişnelik Mah. Öğretmenler Cad. No:32',
      pickupDistanceKm: 1.2,
      dropoffDistanceKm: 2.8,
      etaMinutes: 21,
      earning: 164,
      packageCount: 4,
      priority: 'Yoğun saat bonusu',
      tags: ['Elektronik', 'Kimlik doğrulama', 'Bonus +24 TL'],
      accentColor: Color(0xFFE17055),
    ),
    _IhizOrderOpportunity(
      title: 'Hızlı market',
      storeName: 'A101 Gökmeydan',
      storeAddress: 'Gökmeydan Mah. Nazım Hikmet Cad. No:45',
      customerName: 'Elif T.',
      customerAddress: 'Şirintepe Mah. Yalçın Sk. No:8',
      pickupDistanceKm: 0.5,
      dropoffDistanceKm: 1.3,
      etaMinutes: 11,
      earning: 96,
      packageCount: 1,
      priority: '10 dk hedef',
      tags: ['Tek paket', 'Hafif ürün', 'Yakın müşteri'],
      accentColor: Color(0xFF3563E9),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final selectedOrder = _orderPool[_selectedOrderIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isMobile = screenWidth < 700;
            final horizontalPadding = isMobile ? 16.0 : 28.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                isMobile ? 120 : 32,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? 560 : 1180),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTopBar(context, isMobile),
                      const SizedBox(height: 18),
                      _buildHero(selectedOrder, isMobile),
                      const SizedBox(height: 18),
                      if (isMobile) ...[
                        _buildMapCard(selectedOrder, true),
                        const SizedBox(height: 18),
                        _buildOrderPool(true),
                        const SizedBox(height: 18),
                        _buildPerformanceRow(true),
                        const SizedBox(height: 18),
                        _buildWorkflowCard(true),
                        const SizedBox(height: 18),
                        _buildFeatureCards(true),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 11,
                              child: Column(
                                children: [
                                  _buildMapCard(selectedOrder, false),
                                  const SizedBox(height: 18),
                                  _buildWorkflowCard(false),
                                ],
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 8,
                              child: Column(
                                children: [
                                  _buildOrderPool(false),
                                  const SizedBox(height: 18),
                                  _buildPerformanceRow(false),
                                  const SizedBox(height: 18),
                                  _buildFeatureCards(false),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE3E8DF))),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.route_outlined),
                      label: const Text('Rotayı Aç'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF143229),
                        side: const BorderSide(color: Color(0xFFB7C8BF)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: Text(_isOnline ? 'Paketi Seç' : 'Müsaite Geç'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF143229),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/admin');
                  },
                  child: const Text('Admin Panel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isMobile) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).maybePop(),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDCE5DA)),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'İhız',
                style: TextStyle(
                  fontSize: isMobile ? 26 : 34,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF143229),
                  letterSpacing: -0.8,
                ),
              ),
              const Text(
                'Yakındaki mağazadan al, müşteriye hızlı teslim et.',
                style: TextStyle(
                  color: Color(0xFF50655D),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () {
            setState(() {
              _isOnline = !_isOnline;
            });
          },
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _isOnline
                  ? const Color(0xFFDFF7EC)
                  : const Color(0xFFF2F3F5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isOnline
                        ? const Color(0xFF0F9D7A)
                        : const Color(0xFF8B98A7),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isOnline ? 'Müsait' : 'Molada',
                  style: const TextStyle(
                    color: Color(0xFF143229),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(_IhizOrderOpportunity selectedOrder, bool isMobile) {
    final cards = [
      _MetricData(
        'Bugünkü kazanç',
        '₺842',
        '3 görev bonuslu',
        Icons.savings_outlined,
      ),
      _MetricData(
        'Aktif bölge',
        'Gökmeydan + Tepebaşı',
        'Yakın sipariş havuzu açık',
        Icons.radar_outlined,
      ),
      _MetricData(
        'Hazır paketler',
        '${_orderPool.length}',
        'Şu an seçilebilir',
        Icons.inventory_2_outlined,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 18 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF143229), Color(0xFF1E4E3F), Color(0xFF2B6A58)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildHeroChip(Icons.flash_on_outlined, 'Havuz sistemi aktif'),
              _buildHeroChip(
                Icons.schedule_outlined,
                '${selectedOrder.etaMinutes} dk teslimat hedefi',
              ),
              _buildHeroChip(
                Icons.place_outlined,
                '${selectedOrder.pickupDistanceKm.toStringAsFixed(1)} km mağazaya uzaklık',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Telefon ekranı için tasarlanmış kurye akışı',
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 28 : 40,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Kurye mağaza adresini, müşteri konumunu, rota süresini ve paket havuzunu tek akışta görür. Tek dokunuşla görevi alır, mağazadan teslim alır ve müşteriye bırakır.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.84),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          isMobile
              ? Column(
                  children: cards
                      .map(
                        (card) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildMetricCard(card, true),
                        ),
                      )
                      .toList(),
                )
              : Row(
                  children: cards
                      .map(
                        (card) => Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: card == cards.last ? 0 : 12,
                            ),
                            child: _buildMetricCard(card, false),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildMapCard(_IhizOrderOpportunity order, bool isMobile) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Canlı rota görünümü',
                style: TextStyle(
                  color: Color(0xFF143229),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3DA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  order.priority,
                  style: const TextStyle(
                    color: Color(0xFF8B5E00),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Kurye, mağaza ve müşteri adresi aynı haritada. Yakın görev seçildiğinde rota anında güncellenir.',
            style: TextStyle(
              color: const Color(0xFF50655D).withValues(alpha: 0.96),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: isMobile ? 300 : 360,
            decoration: BoxDecoration(
              color: const Color(0xFFE9F4ED),
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                const Positioned.fill(child: _IhizMapBackdrop()),
                Positioned(
                  left: 24,
                  top: 22,
                  child: _buildMapBadge(
                    icon: Icons.storefront_outlined,
                    label: 'Mağaza',
                    value: order.storeName,
                    tone: order.accentColor,
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 22,
                  child: _buildMapBadge(
                    icon: Icons.home_work_outlined,
                    label: 'Müşteri',
                    value: order.customerName,
                    tone: const Color(0xFF143229),
                  ),
                ),
                Positioned(
                  left: isMobile ? 54 : 80,
                  top: isMobile ? 118 : 138,
                  child: _buildMapPin(
                    icon: Icons.store_mall_directory_outlined,
                    color: order.accentColor,
                    label: 'Mağaza',
                  ),
                ),
                Positioned(
                  right: isMobile ? 54 : 84,
                  bottom: isMobile ? 86 : 98,
                  child: _buildMapPin(
                    icon: Icons.person_pin_circle_outlined,
                    color: const Color(0xFF143229),
                    label: 'Teslimat',
                  ),
                ),
                Positioned(
                  left: isMobile ? 148 : 212,
                  top: isMobile ? 130 : 150,
                  child: _buildCourierPulse(),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildMiniStat(
                          Icons.route_outlined,
                          'Toplam rota',
                          '${(order.pickupDistanceKm + order.dropoffDistanceKm).toStringAsFixed(1)} km',
                        ),
                        _buildMiniStat(
                          Icons.timer_outlined,
                          'Tahmini süre',
                          '${order.etaMinutes} dk',
                        ),
                        _buildMiniStat(
                          Icons.payments_outlined,
                          'Kazanç',
                          '₺${order.earning}',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          isMobile
              ? Column(
                  children: [
                    _buildAddressTile(
                      'Mağaza adresi',
                      order.storeAddress,
                      Icons.storefront_outlined,
                      order.accentColor,
                    ),
                    const SizedBox(height: 12),
                    _buildAddressTile(
                      'Müşteri adresi',
                      order.customerAddress,
                      Icons.location_on_outlined,
                      const Color(0xFF143229),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _buildAddressTile(
                        'Mağaza adresi',
                        order.storeAddress,
                        Icons.storefront_outlined,
                        order.accentColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildAddressTile(
                        'Müşteri adresi',
                        order.customerAddress,
                        Icons.location_on_outlined,
                        const Color(0xFF143229),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildOrderPool(bool isMobile) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sipariş havuzu',
            style: TextStyle(
              color: Color(0xFF143229),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kurye uygun gördüğü paketi ana akıştan seçer. Kart üstünde mesafe, kazanç, paket sayısı ve öncelik bilgisi görünür.',
            style: TextStyle(
              color: const Color(0xFF50655D).withValues(alpha: 0.96),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(_orderPool.length, (index) {
            final order = _orderPool[index];
            final isSelected = index == _selectedOrderIndex;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _orderPool.length - 1 ? 0 : 12,
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedOrderIndex = index;
                  });
                },
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                hoverColor: Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF4FBF7)
                        : const Color(0xFFF9FBF8),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected
                          ? order.accentColor
                          : const Color(0xFFE3E8DF),
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: order.accentColor.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.inventory_2_outlined,
                                        color: order.accentColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            order.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF143229),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            order.storeName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Color(0xFF50655D),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '₺${order.earning}',
                                        style: const TextStyle(
                                          color: Color(0xFF143229),
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${order.packageCount} paket',
                                        style: const TextStyle(
                                          color: Color(0xFF50655D),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: order.accentColor.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    color: order.accentColor,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.title,
                                        style: const TextStyle(
                                          color: Color(0xFF143229),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        order.storeName,
                                        style: const TextStyle(
                                          color: Color(0xFF50655D),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₺${order.earning}',
                                      style: const TextStyle(
                                        color: Color(0xFF143229),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      '${order.packageCount} paket',
                                      style: const TextStyle(
                                        color: Color(0xFF50655D),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildPoolPill(
                            Icons.near_me_outlined,
                            '${order.pickupDistanceKm.toStringAsFixed(1)} km mağazaya',
                          ),
                          _buildPoolPill(
                            Icons.home_outlined,
                            '${order.dropoffDistanceKm.toStringAsFixed(1)} km müşteriye',
                          ),
                          _buildPoolPill(
                            Icons.schedule_outlined,
                            '${order.etaMinutes} dk rota',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: order.tags
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: Color(0xFF50655D),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      isMobile
                          ? Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _selectedOrderIndex = index;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isSelected
                                          ? order.accentColor
                                          : const Color(0xFF143229),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      isSelected
                                          ? 'Seçili paket'
                                          : 'Bu paketi seç',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${order.customerName} için teslimat hazır',
                                    style: const TextStyle(
                                      color: Color(0xFF50655D),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedOrderIndex = index;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isSelected
                                        ? order.accentColor
                                        : const Color(0xFF143229),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    isSelected ? 'Seçili paket' : 'Paketi seç',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(bool isMobile) {
    final cards = const [
      _MetricData('Teslimat puanı', '4.9', 'Son 30 görev', Icons.star_outline),
      _MetricData(
        'Tamamlama',
        '%98',
        'İptalsiz çalışma',
        Icons.verified_outlined,
      ),
      _MetricData(
        'Ortalama süre',
        '13 dk',
        'Yakın lokasyon teslim',
        Icons.bolt_outlined,
      ),
    ];

    return isMobile
        ? Column(
            children: cards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildStatSummary(card),
                  ),
                )
                .toList(),
          )
        : Row(
            children: cards
                .map(
                  (card) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: card == cards.last ? 0 : 12,
                      ),
                      child: _buildStatSummary(card),
                    ),
                  ),
                )
                .toList(),
          );
  }

  Widget _buildWorkflowCard(bool isMobile) {
    final steps = const [
      _IhizStep(
        title: 'Paketi havuzdan seç',
        description:
            'Kurye mağazaya yakın görevi karttan seçer, rota ve kazanç kilitlenir.',
        icon: Icons.touch_app_outlined,
      ),
      _IhizStep(
        title: 'Mağazadan teslim al',
        description:
            'QR doğrulama, ürün adedi kontrolü ve notlar tek ekranda görünür.',
        icon: Icons.qr_code_scanner_outlined,
      ),
      _IhizStep(
        title: 'Müşteriye bırak',
        description:
            'Adres doğrulama, arama butonu ve teslim kanıtı aynı akışta tamamlanır.',
        icon: Icons.assignment_turned_in_outlined,
      ),
    ];

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kurye akışı',
            style: TextStyle(
              color: Color(0xFF143229),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'İhız ekranı kurye için sade tutuldu: görev alma, mağaza teslimi ve müşteri teslimi tek doğrusal akışta ilerliyor.',
            style: TextStyle(color: Color(0xFF50655D), height: 1.5),
          ),
          const SizedBox(height: 16),
          if (isMobile)
            ...List.generate(steps.length, (index) {
              final step = steps[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == steps.length - 1 ? 0 : 12,
                ),
                child: _buildStepCard(step, index + 1),
              );
            })
          else
            Row(
              children: List.generate(steps.length, (index) {
                final step = steps[index];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == steps.length - 1 ? 0 : 12,
                    ),
                    child: _buildStepCard(step, index + 1),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureCards(bool isMobile) {
    final features = const [
      _FeatureCardData(
        title: 'Sıcak bölge önerisi',
        description:
            'Yoğun sipariş gelen mahalleleri gösterir, boşta kalan kurye doğru noktaya yönlenir.',
        icon: Icons.local_fire_department_outlined,
        color: Color(0xFFE17055),
      ),
      _FeatureCardData(
        title: 'Mağaza notları',
        description:
            'Otopark bilgisi, teslim alma kapısı ve mağaza yoğunluk notu hızlıca görünür.',
        icon: Icons.sticky_note_2_outlined,
        color: Color(0xFF3563E9),
      ),
      _FeatureCardData(
        title: 'Teslim kanıtı',
        description:
            'Fotoğraf, kod ve müşteri imzası aynı panelde toplanır; hatalı teslimat düşer.',
        icon: Icons.shield_outlined,
        color: Color(0xFF0F9D7A),
      ),
    ];

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Özel hazırlanmış kurye sistemi',
            style: TextStyle(
              color: Color(0xFF143229),
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Standart sipariş ekranı değil; yakın lokasyon teslimatı için kurye operasyonuna özel bileşenler tasarlandı.',
            style: TextStyle(color: Color(0xFF50655D), height: 1.5),
          ),
          const SizedBox(height: 16),
          if (isMobile)
            ...List.generate(features.length, (index) {
              final feature = features[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == features.length - 1 ? 0 : 12,
                ),
                child: _buildFeatureCard(feature),
              );
            })
          else
            Row(
              children: List.generate(features.length, (index) {
                final feature = features[index];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == features.length - 1 ? 0 : 12,
                    ),
                    child: _buildFeatureCard(feature),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String text) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(_MetricData data, bool compact) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 220;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(data.icon, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    _buildMetricTexts(data, compact),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(data.icon, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildMetricTexts(data, compact)),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildStatSummary(_MetricData data) {
    return _sectionCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 180;

          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6F0),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(data.icon, color: const Color(0xFF143229)),
                    ),
                    const SizedBox(height: 12),
                    _buildStatSummaryTexts(data),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F6F0),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(data.icon, color: const Color(0xFF143229)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatSummaryTexts(data)),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildMetricTexts(_MetricData data, bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: compact ? 12 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 17 : 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          data.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatSummaryTexts(_MetricData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF50655D),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF143229),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        Text(
          data.caption,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF7B8B83)),
        ),
      ],
    );
  }

  Widget _buildStepCard(_IhizStep step, int number) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E8DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF143229),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(step.icon, color: const Color(0xFF143229)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            step.title,
            style: const TextStyle(
              color: Color(0xFF143229),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.description,
            style: const TextStyle(color: Color(0xFF50655D), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(_FeatureCardData feature) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E8DF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: feature.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(feature.icon, color: feature.color),
          ),
          const SizedBox(height: 14),
          Text(
            feature.title,
            style: const TextStyle(
              color: Color(0xFF143229),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            feature.description,
            style: const TextStyle(color: Color(0xFF50655D), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildMapBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color tone,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF7B8B83),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF143229),
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

  Widget _buildMapPin({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF143229),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildCourierPulse() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: Color(0xFF2563EB),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.my_location_rounded, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildMiniStat(IconData icon, String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 156),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7F2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF143229)),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7B8B83),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF143229),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF7B8B83),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF143229),
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoolPill(IconData icon, String text) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF143229)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF143229),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE3E8DF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _IhizMapBackdrop extends StatelessWidget {
  const _IhizMapBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _IhizMapPainter(),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFE9F4ED),
              const Color(0xFFDFF0E4),
              const Color(0xFFF4F8F2).withValues(alpha: 0.92),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    );
  }
}

class _IhizMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFC8D9CE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    final thinRoadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    final routePaint = Paint()
      ..color = const Color(0xFF143229)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final mainPath = Path()
      ..moveTo(size.width * 0.08, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.34,
        size.height * 0.1,
        size.width * 0.52,
        size.height * 0.32,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.56,
        size.width * 0.9,
        size.height * 0.82,
      );

    final sidePath = Path()
      ..moveTo(size.width * 0.16, size.height * 0.86)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.66,
        size.width * 0.48,
        size.height * 0.54,
      )
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.45,
        size.width * 0.82,
        size.height * 0.34,
      );

    final connectionPath = Path()
      ..moveTo(size.width * 0.42, size.height * 0.1)
      ..quadraticBezierTo(
        size.width * 0.44,
        size.height * 0.44,
        size.width * 0.16,
        size.height * 0.74,
      );

    canvas.drawPath(mainPath, roadPaint);
    canvas.drawPath(sidePath, roadPaint);
    canvas.drawPath(connectionPath, roadPaint);
    canvas.drawPath(mainPath, thinRoadPaint);
    canvas.drawPath(sidePath, thinRoadPaint);
    canvas.drawPath(connectionPath, thinRoadPaint);

    final routePath = Path()
      ..moveTo(size.width * 0.2, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.36,
        size.height * 0.36,
        size.width * 0.44,
        size.height * 0.46,
      )
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.62,
        size.width * 0.76,
        size.height * 0.7,
      );

    canvas.drawPath(routePath, routePaint);

    final dashPaint = Paint()
      ..color = const Color(0xFF143229)
      ..style = PaintingStyle.fill;

    for (double t = 0; t <= 1; t += 0.12) {
      final point = _pointOnQuadraticPath(routePath, t);
      canvas.drawCircle(point, 3.5, dashPaint);
    }

    final parkPaint = Paint()
      ..color = const Color(0xFFB8D9B2).withValues(alpha: 0.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.2, size.height * 0.18),
        width: 110,
        height: 58,
      ),
      parkPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.78, size.height * 0.18),
        width: 90,
        height: 44,
      ),
      parkPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.78, size.height * 0.9),
        width: 118,
        height: 56,
      ),
      parkPaint,
    );
  }

  Offset _pointOnQuadraticPath(Path path, double t) {
    final metrics = path.computeMetrics().first;
    final tangent = metrics.getTangentForOffset(metrics.length * t);
    return tangent?.position ?? Offset.zero;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _IhizOrderOpportunity {
  const _IhizOrderOpportunity({
    required this.title,
    required this.storeName,
    required this.storeAddress,
    required this.customerName,
    required this.customerAddress,
    required this.pickupDistanceKm,
    required this.dropoffDistanceKm,
    required this.etaMinutes,
    required this.earning,
    required this.packageCount,
    required this.priority,
    required this.tags,
    required this.accentColor,
  });

  final String title;
  final String storeName;
  final String storeAddress;
  final String customerName;
  final String customerAddress;
  final double pickupDistanceKm;
  final double dropoffDistanceKm;
  final int etaMinutes;
  final int earning;
  final int packageCount;
  final String priority;
  final List<String> tags;
  final Color accentColor;
}

class _IhizStep {
  const _IhizStep({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class _MetricData {
  const _MetricData(this.label, this.value, this.caption, this.icon);

  final String label;
  final String value;
  final String caption;
  final IconData icon;
}

class _FeatureCardData {
  const _FeatureCardData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
}
