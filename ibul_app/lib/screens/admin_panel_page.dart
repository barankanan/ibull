import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'chat_page.dart';
import '../core/constants.dart';

enum AdminRole {
  superAdmin,
  storeManager,
  supportManager,
  financeManager,
}

enum DataPoolTab {
  all,
  users,
  stores,
  cargo,
}

enum AdminModule {
  dashboard,
  veriler,
  stores,
  products,
  orders,
  mapAnalytics,
  finance,
  campaigns,
  support,
  permissions,
  logs,
}

enum AnalysisDimension {
  age,
  gender,
  location,
  device,
}

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  AdminRole _selectedRole = AdminRole.superAdmin;
  AdminModule _selectedModule = AdminModule.dashboard;
  
  // New state for Audience Analysis - Multi-filter
  final Map<String, String?> _activeAnalysisFilters = {
    'age': '18-24', // Default
    'gender': null,
    'marital': null,
    'location': null,
    'device': null,
    'activity': null, // Ne zaman aktif
    'searchIntent': null, // Ne arıyor
    'cartInterest': null, // Neyi sepete atıyor
    'shoppingStyle': null, // Nasıl alışveriş yapıyor
    'loyalty': null, // Ne kadar sadık
  };

  // New state for Store Analysis
  final Map<String, String?> _activeStoreFilters = {
    'category': 'Teknoloji', // Default
    'rating': null,
    'city': null,
    'status': null,
    'joinDate': null,
    'performance': null,
  };

  // New state for Cargo Analysis
  final Map<String, String?> _activeCargoFilters = {
    'carrier': 'Yurtiçi Kargo', // Default
    'region': null,
    'status': null,
    'deliveryTime': null,
    'cost': null,
  };

  // New state for expandable report sections
  final Set<String> _expandedDetailSections = {};

  // New state for Order Search
  String _orderSearchQuery = '';

  final MapController _adminMapController = MapController();
  final List<Map<String, dynamic>> _mapSellers = [
    {
      'name': 'Teknosa Antakya',
      'category': 'Teknoloji',
      'location': LatLng(36.2025, 36.1605),
    },
    {
      'name': 'Arçelik Mağazası',
      'category': 'Teknoloji',
      'location': LatLng(36.204, 36.165),
    },
    {
      'name': 'LC Waikiki',
      'category': 'Giyim',
      'location': LatLng(36.201, 36.158),
    },
    {
      'name': 'Dönerci Ustam',
      'category': 'Restoran',
      'location': LatLng(36.203, 36.162),
    },
    {
      'name': 'Ayakkabıcı Ayhan',
      'category': 'Ayakkabı',
      'location': LatLng(36.1995, 36.159),
    },
    {
      'name': 'Mahalle Marketi',
      'category': 'Market',
      'location': LatLng(36.205, 36.157),
    },
  ];

  final List<Map<String, dynamic>> _searchHotspots = [
    {
      'label': 'Merkez - Öğrenci Bölgesi',
      'center': LatLng(36.2025, 36.1605),
      'radius': 350.0,
      'queries': ['döner', 'hamburger', 'kahveci'],
    },
    {
      'label': 'Sanayi - Tamir & Parça',
      'center': LatLng(36.199, 36.154),
      'radius': 400.0,
      'queries': ['telefon tamiri', 'lastikçi', 'yedek parça'],
    },
    {
      'label': 'Alışveriş Caddesi',
      'center': LatLng(36.205, 36.165),
      'radius': 300.0,
      'queries': ['ayakkabıcı', 'mont', 'kozmetik'],
    },
  ];

  String _selectedMapCategory = 'Hepsi';
  String _selectedRevenueRange = 'Son 12 Ay';
  String _selectedUserStoreRange = 'Son 12 Ay';
  DateTimeRange? _revenueDateRange;
  DateTimeRange? _userStoreDateRange;
  DataPoolTab _selectedDataPoolTab = DataPoolTab.all;
  final List<Map<String, dynamic>> _ageSegments = [
    {
      'label': '18-24',
      'total': 24,
      'female': 58,
      'male': 42,
      'married': 18,
      'single': 82,
      'score': 76,
      'tag': 'Büyüme',
      'children': 12,
      'shoppingFrequency': 'Ayda 2.8 sipariş',
      'locations': [
        {'label': 'İstanbul', 'value': 45},
        {'label': 'Hatay', 'value': 22},
        {'label': 'Ankara', 'value': 18},
        {'label': 'Diğer', 'value': 15},
      ],
      'devices': [
        {'label': 'Mobil', 'value': 82},
        {'label': 'Web', 'value': 12},
        {'label': 'Tablet', 'value': 6},
      ],
      'activityDailyLogins': 'Günlük 2.4 giriş',
      'activityPeakDays': 'Pzt - Çrş',
      'activityPeakHours': '20:00 - 23:00',
      'activityAvgSession': '7.5 dk',
      'purchaseAvgBasket': '₺320 ortalama sepet',
      'purchaseRepeatRate': '%28 tekrar alışveriş',
      'purchaseCategoryFocus': 'Giyim, Teknoloji',
      'searchScore': 72,
      'cartScore': 68,
      'shoppingScore': 64,
      'loyaltyScore': 59,
    },
    {
      'label': '25-34',
      'total': 38,
      'female': 52,
      'male': 48,
      'married': 46,
      'single': 54,
      'score': 88,
      'tag': 'Çekirdek',
      'children': 38,
      'shoppingFrequency': 'Ayda 3.4 sipariş',
      'locations': [
        {'label': 'İstanbul', 'value': 42},
        {'label': 'Ankara', 'value': 24},
        {'label': 'İzmir', 'value': 18},
        {'label': 'Diğer', 'value': 16},
      ],
      'devices': [
        {'label': 'Mobil', 'value': 76},
        {'label': 'Web', 'value': 18},
        {'label': 'Tablet', 'value': 6},
      ],
      'activityDailyLogins': 'Günlük 2.9 giriş',
      'activityPeakDays': 'Sal - Per',
      'activityPeakHours': '19:00 - 22:00',
      'activityAvgSession': '8.1 dk',
      'purchaseAvgBasket': '₺480 ortalama sepet',
      'purchaseRepeatRate': '%41 tekrar alışveriş',
      'purchaseCategoryFocus': 'Teknoloji, Market',
      'searchScore': 84,
      'cartScore': 88,
      'shoppingScore': 91,
      'loyaltyScore': 76,
    },
    {
      'label': '35-44',
      'total': 22,
      'female': 47,
      'male': 53,
      'married': 63,
      'single': 37,
      'score': 81,
      'tag': 'Olgun',
      'children': 54,
      'shoppingFrequency': 'Ayda 2.1 sipariş',
      'locations': [
        {'label': 'İstanbul', 'value': 38},
        {'label': 'Bursa', 'value': 22},
        {'label': 'Ankara', 'value': 20},
        {'label': 'Diğer', 'value': 20},
      ],
      'devices': [
        {'label': 'Mobil', 'value': 68},
        {'label': 'Web', 'value': 24},
        {'label': 'Tablet', 'value': 8},
      ],
      'activityDailyLogins': 'Günlük 1.7 giriş',
      'activityPeakDays': 'Çar - Cum',
      'activityPeakHours': '21:00 - 23:00',
      'activityAvgSession': '6.2 dk',
      'purchaseAvgBasket': '₺540 ortalama sepet',
      'purchaseRepeatRate': '%36 tekrar alışveriş',
      'purchaseCategoryFocus': 'Ev & Yaşam, Market',
      'searchScore': 63,
      'cartScore': 71,
      'shoppingScore': 74,
      'loyaltyScore': 69,
    },
    {
      'label': '45+',
      'total': 16,
      'female': 44,
      'male': 56,
      'married': 71,
      'single': 29,
      'score': 69,
      'tag': 'Niş',
      'children': 68,
      'shoppingFrequency': 'Ayda 1.3 sipariş',
      'locations': [
        {'label': 'İstanbul', 'value': 34},
        {'label': 'Ankara', 'value': 21},
        {'label': 'Hatay', 'value': 19},
        {'label': 'Diğer', 'value': 26},
      ],
      'devices': [
        {'label': 'Mobil', 'value': 54},
        {'label': 'Web', 'value': 30},
        {'label': 'Tablet', 'value': 16},
      ],
      'activityDailyLogins': 'Günlük 1.2 giriş',
      'activityPeakDays': 'Cum - Paz',
      'activityPeakHours': '18:00 - 21:00',
      'activityAvgSession': '5.4 dk',
      'purchaseAvgBasket': '₺610 ortalama sepet',
      'purchaseRepeatRate': '%29 tekrar alışveriş',
      'purchaseCategoryFocus': 'Ev & Yaşam, Beyaz eşya',
      'searchScore': 54,
      'cartScore': 62,
      'shoppingScore': 58,
      'loyaltyScore': 72,
    },
  ];

  List<AdminModule> get _visibleModules {
    switch (_selectedRole) {
      case AdminRole.superAdmin:
        return AdminModule.values.toList();
      case AdminRole.storeManager:
        return [
          AdminModule.dashboard,
          AdminModule.stores,
          AdminModule.products,
          AdminModule.campaigns,
          AdminModule.support,
        ];
      case AdminRole.supportManager:
        return [
          AdminModule.dashboard,
          AdminModule.orders,
          AdminModule.support,
          AdminModule.logs,
        ];
      case AdminRole.financeManager:
        return [
          AdminModule.dashboard,
          AdminModule.finance,
          AdminModule.logs,
        ];
    }
  }

  String _roleLabel(AdminRole role) {
    switch (role) {
      case AdminRole.superAdmin:
        return 'Super Admin';
      case AdminRole.storeManager:
        return 'Store Manager';
      case AdminRole.supportManager:
        return 'Support Manager';
      case AdminRole.financeManager:
        return 'Finance Manager';
    }
  }

  String _moduleLabel(AdminModule module) {
    switch (module) {
      case AdminModule.dashboard:
        return 'Dashboard';
      case AdminModule.veriler:
        return 'Veriler';
      case AdminModule.stores:
        return 'Mağaza Yönetimi';
      case AdminModule.products:
        return 'Ürün & Katalog';
      case AdminModule.orders:
        return 'Sipariş & İade';
      case AdminModule.mapAnalytics:
        return 'Harita & Arama';
      case AdminModule.finance:
        return 'Finans & Hakediş';
      case AdminModule.campaigns:
        return 'Kampanya & İçerik';
      case AdminModule.support:
        return 'Destek & Şikayet';
      case AdminModule.permissions:
        return 'Yetki Sistemi';
      case AdminModule.logs:
        return 'Log & Güvenlik';
    }
  }

  IconData _moduleIcon(AdminModule module) {
    switch (module) {
      case AdminModule.dashboard:
        return Icons.dashboard_outlined;
      case AdminModule.veriler:
        return Icons.pie_chart_outline;
      case AdminModule.stores:
        return Icons.store_mall_directory_outlined;
      case AdminModule.products:
        return Icons.inventory_2_outlined;
      case AdminModule.orders:
        return Icons.receipt_long_outlined;
      case AdminModule.mapAnalytics:
        return Icons.map_outlined;
      case AdminModule.finance:
        return Icons.account_balance_wallet_outlined;
      case AdminModule.campaigns:
        return Icons.campaign_outlined;
      case AdminModule.support:
        return Icons.headset_mic_outlined;
      case AdminModule.permissions:
        return Icons.admin_panel_settings_outlined;
      case AdminModule.logs:
        return Icons.history_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 1000;

    if (!isWeb) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          title: const Text(
            'iBul Admin Panel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          elevation: 0,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Admin panel web görünümü için tasarlandı. Lütfen geniş ekrandan erişin.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _buildContent(),
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

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'iBul Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _roleLabel(_selectedRole),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  PopupMenuButton<AdminRole>(
                    onSelected: (role) {
                      setState(() {
                        _selectedRole = role;
                        if (!_visibleModules.contains(_selectedModule)) {
                          _selectedModule = _visibleModules.first;
                        }
                      });
                    },
                    itemBuilder: (context) {
                      return AdminRole.values
                          .map(
                            (role) => PopupMenuItem(
                              value: role,
                              child: Text(_roleLabel(role)),
                            ),
                          )
                          .toList();
                    },
                    icon: const Icon(Icons.expand_more, color: Colors.white70, size: 18),
                    color: const Color(0xFF111827),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _visibleModules
                  .map(
                    (module) => _buildSidebarItem(
                      icon: _moduleIcon(module),
                      label: _moduleLabel(module),
                      isActive: _selectedModule == module,
                      onTap: () {
                        setState(() {
                          _selectedModule = module;
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(
                icon,
                size: 20,
                color: isActive ? AppColors.primary : Colors.white70,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? AppColors.primary : Colors.white70,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            _moduleLabel(_selectedModule),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  _roleLabel(_selectedRole),
                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            width: 240,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const SizedBox(width: 8),
                Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Panel içinde ara',
                      hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_outlined, size: 22, color: Color(0xFF4B5563)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: const Center(
                    child: Text(
                      'BK',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Baran',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                ),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 16, color: Colors.grey.shade600),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedModule) {
      case AdminModule.dashboard:
        return _buildDashboard();
      case AdminModule.veriler:
        return _buildVerilerModule();
      case AdminModule.stores:
        return _buildStoresModule();
      case AdminModule.products:
        return _buildProductsModule();
      case AdminModule.orders:
        return _buildOrdersModule();
      case AdminModule.mapAnalytics:
        return _buildMapAnalyticsModule();
      case AdminModule.finance:
        return _buildFinanceModule();
      case AdminModule.campaigns:
        return _buildCampaignsModule();
      case AdminModule.support:
        return _buildSupportModule();
      case AdminModule.permissions:
        return _buildPermissionsModule();
      case AdminModule.logs:
        return _buildLogsModule();
    }
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    final accent = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerilerModule() {
    final showUserBlocks =
        _selectedDataPoolTab == DataPoolTab.all || _selectedDataPoolTab == DataPoolTab.users;
    final showStoreBlocks =
        _selectedDataPoolTab == DataPoolTab.all || _selectedDataPoolTab == DataPoolTab.stores;
    final showCargoBlocks =
        _selectedDataPoolTab == DataPoolTab.all || _selectedDataPoolTab == DataPoolTab.cargo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Veri Havuzları',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kullanıcı, mağaza, sipariş ve lojistikten gelen tüm sinyalleri tek ekranda toplar.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: const [
                  Icon(Icons.insights_outlined, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Veriler = Büyüme Motoru',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildDataTabChip(DataPoolTab.all, 'Hepsi', Icons.auto_awesome),
            const SizedBox(width: 8),
            _buildDataTabChip(DataPoolTab.users, 'Kullanıcılar', Icons.person_outline),
            const SizedBox(width: 8),
            _buildDataTabChip(DataPoolTab.stores, 'Mağazalar', Icons.store_mall_directory_outlined),
            const SizedBox(width: 8),
            _buildDataTabChip(DataPoolTab.cargo, 'Kargo', Icons.local_shipping_outlined),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedDataPoolTab == DataPoolTab.all) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildOverviewCard(
                          icon: Icons.person_outline,
                          color: AppColors.primary,
                          title: 'Kullanıcı havuzu',
                          value: '12.4K',
                          subtitle: 'Aktif kullanıcı',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOverviewCard(
                          icon: Icons.timeline_outlined,
                          color: const Color(0xFF0EA5E9),
                          title: 'Davranış',
                          value: '8.2 dk',
                          subtitle: 'Ort. oturum süresi',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOverviewCard(
                          icon: Icons.shopping_bag_outlined,
                          color: const Color(0xFFF97316),
                          title: 'Sipariş',
                          value: '3.140',
                          subtitle: 'Toplam sipariş',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildOverviewCard(
                          icon: Icons.store_mall_directory_outlined,
                          color: const Color(0xFF22C55E),
                          title: 'Mağaza',
                          value: '240',
                          subtitle: 'Aktif mağaza',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildOverviewCard(
                          icon: Icons.account_balance_wallet_outlined,
                          color: const Color(0xFF6366F1),
                          title: 'Finans',
                          value: '₺1,2M',
                          subtitle: 'Son 30 gün geliri',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                Row(
                  children: [
                    if (showUserBlocks)
                      Expanded(
                        child: _buildDataLineChart(
                          title: 'Kullanıcı yaşam döngüsü',
                          subtitle: 'Yeni / aktif / alışveriş yapan kullanıcı trafiği.',
                          series1: const [820, 910, 980, 1100, 1250, 1390, 1500, 1630],
                          series2: const [420, 460, 510, 580, 640, 700, 760, 830],
                          color1: AppColors.primary,
                          color2: const Color(0xFF22C55E),
                          label1: 'Aktif kullanıcı',
                          label2: 'Sipariş veren',
                        ),
                      ),
                    if (showUserBlocks && (showStoreBlocks || showCargoBlocks))
                      const SizedBox(width: 16),
                    if (showStoreBlocks)
                      Expanded(
                        child: _buildDataLineChart(
                          title: 'Mağaza büyümesi',
                          subtitle: 'Toplam ve aktif mağaza sayısı.',
                          series1: const [40, 54, 63, 72, 86, 95, 110, 126],
                          series2: const [28, 36, 42, 51, 62, 70, 82, 95],
                          color1: const Color(0xFF0EA5E9),
                          color2: const Color(0xFFF97316),
                          label1: 'Toplam mağaza',
                          label2: 'Aktif mağaza',
                        ),
                      ),
                    if (showStoreBlocks && showCargoBlocks)
                      const SizedBox(width: 16),
                    if (showCargoBlocks || _selectedDataPoolTab == DataPoolTab.all)
                      Expanded(
                        child: _buildDataLineChart(
                          title: 'Teslimat performansı',
                          subtitle: 'Zamanında teslim ve ortalama süre eğrisi.',
                          series1: const [78, 80, 81, 83, 84, 86, 87, 88],
                          series2: const [3.4, 3.3, 3.3, 3.1, 3.0, 2.9, 2.8, 2.7],
                          color1: const Color(0xFF6366F1),
                          color2: const Color(0xFFEC4899),
                          label1: 'Zamanında teslim (%)',
                          label2: 'Teslim süresi (gün)',
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (showUserBlocks) ...[
                  _buildSectionHeader('Kullanıcı Profili'),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1, 
                        child: _buildAnalysisLeftPanel(),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4, 
                        child: _buildAnalysisDetailPanel(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
                if (showCargoBlocks) ...[
                  _buildSectionHeader('Sipariş ve Lojistik Analizi'),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1, 
                        child: _buildCargoAnalysisLeftPanel(),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4, 
                        child: _buildCargoAnalysisDetailPanel(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
                if (showStoreBlocks) ...[
                  _buildSectionHeader('Mağaza Analitiği'),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1, 
                        child: _buildStoreAnalysisLeftPanel(),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 4, 
                        child: _buildStoreAnalysisDetailPanel(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
                _buildSectionHeader('Finans, Ürün ve Pazarlama'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDataCard(
                        icon: Icons.account_balance_wallet_outlined,
                        color: AppColors.primary,
                        title: 'Finansal akış',
                        subtitle: 'Platform ve mağaza para akışı.',
                        chart: _buildFinancialFlowChart(),
                        metrics: const [
                          'Toplam platform geliri',
                          'Komisyon oranları ve mağaza bakiyeleri',
                          'Ödeme talepleri ve aylık kazanç',
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDataCard(
                        icon: Icons.insights_outlined,
                        color: const Color(0xFF22C55E),
                        title: 'Ürün analitiği',
                        subtitle: 'Hangi ürün gerçekten yıldız?',
                        chart: _buildProductAnalyticsChart(),
                        metrics: const [
                          'En çok görüntülenen / sepete eklenen ürünler',
                          'En çok satın alınan ve iade edilen ürünler',
                          'En yüksek kâr bırakan ve stoğu tükenen ürünler',
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDataCard(
                        icon: Icons.campaign_outlined,
                        color: const Color(0xFFF97316),
                        title: 'Pazarlama ve büyüme',
                        subtitle: 'Kampanya performansı ve kanal analizi.',
                        chart: _buildMarketingChart(),
                        metrics: const [
                          'Kupon kullanan kullanıcılar',
                          'Kampanya ve banner dönüşüm oranları',
                          'Reklamdan gelen siparişler, edinme kanalları',
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildDataCard(
                        icon: Icons.flag_outlined,
                        color: const Color(0xFFEF4444),
                        title: 'Davranışsal uyarılar',
                        subtitle: 'Riskli kullanıcı ve mağaza sinyalleri.',
                        metrics: const [
                          'Sahte sipariş şüphesi',
                          'Aşırı iade yapan kullanıcı',
                          'Şikayet yoğunluğu ve stok manipülasyonu',
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildDataCard(
                        icon: Icons.bug_report_outlined,
                        color: const Color(0xFF6366F1),
                        title: 'Sistem sağlığı',
                        subtitle: 'Teknik altyapı kalitesi.',
                        metrics: const [
                          'Uygulama çökme oranı ve yavaş ekranlar',
                          'Hata alan işlemler',
                          'API yanıt süreleri',
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTabChip(
    DataPoolTab tab,
    String label,
    IconData icon,
  ) {
    final selected = _selectedDataPoolTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDataPoolTab = tab;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFF1F2937),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? AppColors.primary.withOpacity(0.12)
                    : Colors.white.withOpacity(0.12),
              ),
              child: Icon(
                icon,
                size: 14,
                color: selected ? AppColors.primary : Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFF111827) : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<String> metrics,
    Widget? chart,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (chart != null) ...[
            chart,
            const SizedBox(height: 10),
          ],
          ...metrics.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataLineChart({
    required String title,
    required String subtitle,
    required List<double> series1,
    required List<double> series2,
    required Color color1,
    required Color color2,
    required String label1,
    required String label2,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _DualLineChartPainter(
                series1: series1,
                series2: series2,
                color1: color1,
                color2: color2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color1,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label1,
                style: const TextStyle(fontSize: 10),
              ),
              const SizedBox(width: 16),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color2,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label2,
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileDonutChart() {
    final segments = [
      {
        'label': 'Aktif',
        'value': 42,
        'color': Color(0xFFF97316),
      },
      {
        'label': 'Yeni',
        'value': 32,
        'color': Color(0xFF047857),
      },
      {
        'label': 'Tek seferlik',
        'value': 13,
        'color': Color(0xFFFACC15),
      },
      {
        'label': 'Riskli',
        'value': 10,
        'color': Color(0xFF2563EB),
      },
    ];

    final primary = segments[0];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(160, 160),
                painter: _DonutChartPainter(
                  values: segments
                      .map((s) => (s['value'] as int).toDouble())
                      .toList(),
                  colors: segments
                      .map((s) => s['color'] as Color)
                      .toList(),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    primary['label'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${primary['value']}%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Wrap(
            spacing: 24,
            runSpacing: 6,
            children: segments.map((segment) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: segment['color'] as Color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${segment['label']} - ${segment['value']}%',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _generateStoreReportData() {
    // 1. Determine base segment from filters
    final category = _activeStoreFilters['category'] ?? 'Tümü';
    final rating = _activeStoreFilters['rating'];
    final city = _activeStoreFilters['city'];
    final status = _activeStoreFilters['status'];

    // 2. Mock Logic
    int revenueScore = 75;
    int orderScore = 70;
    int returnRate = 12;
    double storeRating = 4.2;
    String topProduct = 'iPhone 15';
    String growth = '%15';

    if (category == 'Teknoloji') {
      revenueScore = 90;
      topProduct = 'Dyson V15';
      growth = '%25';
    } else if (category == 'Giyim') {
      returnRate = 25;
      revenueScore = 65;
      topProduct = 'Kışlık Mont';
    }

    if (city == 'İstanbul') {
      revenueScore += 10;
      orderScore += 15;
    }

    if (rating == '4.5+') {
      storeRating = 4.8;
      revenueScore += 5;
    }

    // Clamp
    revenueScore = revenueScore.clamp(0, 100);
    orderScore = orderScore.clamp(0, 100);

    return {
      'title': [category, city, rating, status].where((s) => s != null && s != 'Tümü').join(' • '),
      'segmentSize': '24 Mağaza',
      'scores': {
        'revenue': revenueScore,
        'order': orderScore,
        'rating': (storeRating * 20).toInt(),
      },
      'metrics': {
        'returnRate': '%$returnRate',
        'growth': growth,
        'topProduct': topProduct,
        'avgRating': '$storeRating',
      },
      'desc': {
        'identity': '$category kategorisinde, ${city ?? 'Türkiye geneli'} lokasyonunda faaliyet gösteren mağazalar.',
        'performance': 'Satış hacmi $growth büyüdü. En çok satan ürün: $topProduct.',
        'satisfaction': 'Ortalama puan $storeRating. İade oranı %$returnRate seviyesinde.',
      }
    };
  }

  Map<String, dynamic> _generateCargoReportData() {
    // 1. Determine base segment
    final carrier = _activeCargoFilters['carrier'] ?? 'Tümü';
    final region = _activeCargoFilters['region'];
    final status = _activeCargoFilters['status'];

    // 2. Mock Logic
    int deliveryScore = 80;
    int damageScore = 95; // High is good (low damage)
    int costScore = 60;
    String avgTime = '2.4 Gün';
    String issueRate = '%2.1';

    if (carrier == 'Yurtiçi Kargo') {
      deliveryScore = 92;
      avgTime = '1.8 Gün';
      costScore = 40; // Expensive
    } else if (carrier == 'PTT Kargo') {
      deliveryScore = 65;
      avgTime = '4.2 Gün';
      costScore = 90; // Cheap
    }

    if (region == 'Doğu Anadolu') {
      avgTime = '3.5 Gün';
      deliveryScore -= 10;
    }

    return {
      'title': [carrier, region, status].where((s) => s != null && s != 'Tümü').join(' • '),
      'segmentSize': '12.4K Paket',
      'scores': {
        'delivery': deliveryScore,
        'damage': damageScore,
        'cost': costScore,
      },
      'metrics': {
        'time': avgTime,
        'issue': issueRate,
      },
      'desc': {
        'operation': '$carrier ile ${region ?? 'tüm bölgelere'} yapılan teslimatlar.',
        'issues': 'Ortalama teslim süresi $avgTime. Sorun oranı $issueRate.',
      }
    };
  }

  Map<String, dynamic> _generateReportData() {
    // 1. Determine base persona from filters
    final age = _activeAnalysisFilters['age'] ?? 'Genel';
    final gender = _activeAnalysisFilters['gender'] ?? 'Tümü';
    final marital = _activeAnalysisFilters['marital'] ?? 'Tümü';
    final location = _activeAnalysisFilters['location'] ?? 'Türkiye';
    final device = _activeAnalysisFilters['device'] ?? 'Tümü';
    
    // New Filters
    final activity = _activeAnalysisFilters['activity'];
    final searchIntent = _activeAnalysisFilters['searchIntent'];
    final cartInterest = _activeAnalysisFilters['cartInterest'];
    final shoppingStyle = _activeAnalysisFilters['shoppingStyle'];
    final loyalty = _activeAnalysisFilters['loyalty'];

    // 2. Mock Logic: Adjust scores/text based on combinations
    // Base values (defaults)
    int searchScore = 70;
    int cartScore = 70;
    int shoppingScore = 70;
    int loyaltyScore = 70;
    
    String purchaseAvgBasket = '₺450';
    String purchaseRepeatRate = '%35';
    String purchaseCategoryFocus = 'Karışık';
    String activityDailyLogins = '2.5';
    String activityPeakDays = 'Hafta içi';
    String activityPeakHours = 'Akşam';
    String activityAvgSession = '7 dk';
    
    // Dynamic List Data
    List<String> popularSearches = ['iPhone 15', 'Airfryer', 'Spor Ayakkabı', 'Dikey Süpürge', 'Kahve Makinesi', 'Akıllı Saat'];
    Map<String, double> categoryDist = {'Teknoloji': 0.4, 'Giyim': 0.3, 'Ev': 0.2, 'Diğer': 0.1};
    List<double> demographicData = [0.75, 0.60, 0.85]; // Age, Gender, Mobile
    List<int> heatmapData = List.filled(24, 0); // 0: Low, 1: Med, 2: High
    // Default evening peak
    for (int i = 0; i < 24; i++) {
      if (i >= 19 && i <= 23) heatmapData[i] = 2;
      else if ((i >= 12 && i < 19) || (i >= 8 && i < 10)) heatmapData[i] = 1;
    }

    // Apply "Age" modifiers
    if (age == '18-24') {
      searchScore += 10; // High search
      cartScore -= 5; // Abandon cart
      purchaseAvgBasket = '₺320';
      purchaseCategoryFocus = 'Giyim, Teknoloji';
      activityAvgSession = '9.5 dk';
      popularSearches = ['iPhone 15 Kılıf', 'Sneaker', 'Oyun Konsolu', 'Kablosuz Kulaklık', 'Makyaj', 'Hoodie'];
      categoryDist = {'Giyim': 0.4, 'Teknoloji': 0.35, 'Kozmetik': 0.15, 'Diğer': 0.1};
      demographicData[0] = 0.95; // Age match
    } else if (age == '25-34') {
      cartScore += 10;
      shoppingScore += 10;
      purchaseAvgBasket = '₺580';
      purchaseCategoryFocus = 'Ev, Market, Giyim';
      popularSearches = ['Robot Süpürge', 'Bebek Bezi', 'Mobilya', 'Akıllı Saat', 'Airfryer', 'Laptop'];
      categoryDist = {'Ev': 0.4, 'Market': 0.3, 'Giyim': 0.2, 'Teknoloji': 0.1};
      demographicData[0] = 0.85;
    } else if (age == '35-44') {
      loyaltyScore += 15;
      purchaseRepeatRate = '%55';
      purchaseAvgBasket = '₺750';
      popularSearches = ['Çamaşır Makinesi', 'Televizyon', 'Okul Çantası', 'Kamp Malzemesi', 'Oto Aksesuar', 'Kitap'];
      demographicData[0] = 0.60;
    }

    // Apply "Gender" modifiers
    if (gender == 'Kadın') {
      shoppingScore += 10;
      searchScore += 5;
      purchaseCategoryFocus = age == '18-24' ? 'Kozmetik, Giyim' : 'Market, Çocuk, Ev';
      demographicData[1] = 0.90; // Female dominant
      if (age == '18-24') {
         popularSearches = ['Ruj', 'Elbise', 'Çanta', 'Cilt Bakım', 'Takı', 'Sneaker'];
         categoryDist = {'Kozmetik': 0.5, 'Giyim': 0.4, 'Diğer': 0.1};
      } else {
         popularSearches = ['Bebek Arabası', 'Tencere Seti', 'Nevresim', 'Deterjan', 'Çocuk Giyim', 'Blender'];
         categoryDist = {'Ev': 0.4, 'Market': 0.3, 'Anne&Bebek': 0.2, 'Diğer': 0.1};
      }
    } else if (gender == 'Erkek') {
      cartScore -= 5;
      purchaseAvgBasket = '₺${int.parse(purchaseAvgBasket.replaceAll(RegExp(r'[^0-9]'), '')) + 150}'; // Higher basket
      purchaseCategoryFocus = 'Teknoloji, Oto, Spor';
      demographicData[1] = 0.15; // Male dominant (low female %)
      popularSearches = ['PlayStation 5', 'Tıraş Makinesi', 'Futbol Topu', 'Lastik', 'Matkap', 'Saat'];
      categoryDist = {'Teknoloji': 0.5, 'Spor': 0.2, 'Oto': 0.2, 'Giyim': 0.1};
    }

    // Apply "Marital" modifiers
    if (marital == 'Bekar') {
      activityPeakHours = '22:00 - 01:00';
      activityPeakDays = 'Hafta sonu';
    } else if (marital == 'Evli') {
      activityPeakHours = '20:00 - 22:00';
      purchaseRepeatRate = '%${int.parse(purchaseRepeatRate.replaceAll(RegExp(r'[^0-9]'), '')) + 10}'; // Higher loyalty
    }

    // Apply "Location" modifiers
    if (location == 'İstanbul') {
      purchaseAvgBasket = '₺${int.parse(purchaseAvgBasket.replaceAll(RegExp(r'[^0-9]'), '')) + 100}';
    }

    // Apply "Device" modifiers
    if (device == 'Mobil') {
      activityDailyLogins = '4.2';
      demographicData[2] = 0.98;
    } else if (device == 'Web') {
      activityAvgSession = '14 dk';
      purchaseAvgBasket = '₺${int.parse(purchaseAvgBasket.replaceAll(RegExp(r'[^0-9]'), '')) * 1.5}'; // Much higher basket on web
      demographicData[2] = 0.30;
      popularSearches = ['Buzdolabı', 'Koltuk Takımı', 'Gaming Laptop', 'Klima', 'Ofis Sandalyesi', 'Bisiklet'];
    }

    // Apply New Filters Logic
    if (activity != null) {
       heatmapData = List.filled(24, 0); // Reset
       if (activity.contains('Hafta İçi') || activity.contains('Akşam')) {
          activityPeakHours = '18:00 - 22:00';
          for (int i = 18; i <= 22; i++) heatmapData[i] = 2;
          for (int i = 12; i < 18; i++) heatmapData[i] = 1;
       }
       if (activity.contains('Gece')) {
          activityPeakHours = '23:00 - 03:00';
          for (int i = 23; i < 24; i++) heatmapData[i] = 2;
          for (int i = 0; i <= 3; i++) heatmapData[i] = 2;
          for (int i = 20; i < 23; i++) heatmapData[i] = 1;
       }
       if (activity.contains('Mesai')) {
          activityPeakHours = '09:00 - 17:00';
          for (int i = 9; i <= 17; i++) heatmapData[i] = 2;
          for (int i = 8; i < 9; i++) heatmapData[i] = 1;
          for (int i = 18; i < 20; i++) heatmapData[i] = 1;
       }
       
       if (activity.contains('Hafta İçi')) activityPeakDays = 'Hafta İçi';
       if (activity.contains('Hafta Sonu')) activityPeakDays = 'Hafta Sonu';
    }

    if (searchIntent != null) {
      if (searchIntent == 'Fiyat Odaklı') {
        searchScore += 15;
        popularSearches = ['Ucuz Telefon', 'İndirimli Ayakkabı', 'Outlet Giyim', 'Fiyat Performans Laptop', '2. El', 'Kampanyalı Ürünler'];
        categoryDist = {'Fırsat': 0.6, 'Giyim': 0.2, 'Tekno': 0.2};
      }
      if (searchIntent == 'Marka Odaklı') {
        searchScore += 5;
        popularSearches = ['Apple', 'Samsung', 'Dyson', 'Nike', 'Adidas', 'Bosch'];
        categoryDist = {'Marka': 0.7, 'Aksesuar': 0.2, 'Diğer': 0.1};
      }
      if (searchIntent == 'Teknik Özellik') {
        shoppingScore += 10;
        popularSearches = ['RTX 4060 Laptop', '4K Monitör', 'OLED TV', '512GB SSD', 'Noise Cancelling', 'Mekanik Klavye'];
        categoryDist = {'Donanım': 0.8, 'Çevre': 0.2};
      }
      if (searchIntent == 'Kampanya') {
        shoppingScore += 10;
        popularSearches = ['1 Alana 1 Bedava', '%50 İndirim', 'Kargo Bedava', 'Günün Fırsatı', 'Sepette Ek İndirim', 'Kupon'];
      }
    }

    if (cartInterest != null) {
      purchaseCategoryFocus = cartInterest;
      cartScore += 10;
      if (cartInterest == 'Giyim & Moda') {
         popularSearches = ['Jean', 'Tişört', 'Ceket', 'Bot', 'Çanta', 'Gözlük'];
         categoryDist = {'Kadın': 0.4, 'Erkek': 0.3, 'Çocuk': 0.2, 'Aksesuar': 0.1};
      } else if (cartInterest == 'Teknoloji') {
         popularSearches = ['Telefon', 'Kulaklık', 'Şarj Aleti', 'Kılıf', 'Tablet', 'Laptop'];
         categoryDist = {'Mobil': 0.5, 'PC': 0.3, 'Ses': 0.2};
      } else if (cartInterest == 'Ev & Yaşam') {
         popularSearches = ['Masa', 'Sandalye', 'Lamba', 'Halı', 'Perde', 'Vazo'];
         categoryDist = {'Mobilya': 0.4, 'Dekor': 0.3, 'Mutfak': 0.3};
      } else if (cartInterest == 'Market') {
         popularSearches = ['Yağ', 'Çay', 'Şeker', 'Deterjan', 'Kağıt Havlu', 'Bebek Bezi'];
         categoryDist = {'Gıda': 0.6, 'Temizlik': 0.4};
      } else if (cartInterest == 'Kozmetik') {
         popularSearches = ['Parfüm', 'Krem', 'Şampuan', 'Maskara', 'Ruj', 'Serum'];
         categoryDist = {'Makyaj': 0.4, 'Bakım': 0.4, 'Parfüm': 0.2};
      }
    }

    if (shoppingStyle != null) {
      if (shoppingStyle == 'Taksitli') purchaseAvgBasket = '₺${int.parse(purchaseAvgBasket.replaceAll(RegExp(r'[^0-9]'), '')) + 200}';
      if (shoppingStyle == 'Hızlı Al') cartScore += 15;
    }

    if (loyalty != null) {
      if (loyalty == 'Sadık') { loyaltyScore = 95; purchaseRepeatRate = '%85'; }
      if (loyalty == 'Yeni Üye') { loyaltyScore = 40; purchaseRepeatRate = '%0'; }
      if (loyalty == 'Riskli') { loyaltyScore = 20; purchaseRepeatRate = '%10'; }
    }

    // Clamp scores
    searchScore = searchScore.clamp(0, 100);
    cartScore = cartScore.clamp(0, 100);
    shoppingScore = shoppingScore.clamp(0, 100);
    loyaltyScore = loyaltyScore.clamp(0, 100);

    // Calculate mock segment size
    double segmentSize = 100.0;
    if (age != 'Genel') segmentSize *= 0.4;
    if (gender != 'Tümü') segmentSize *= 0.5;
    if (marital != 'Tümü') segmentSize *= 0.6;
    if (location != 'Türkiye') segmentSize *= 0.3;
    if (device != 'Tümü') segmentSize *= 0.7;
    if (activity != null) segmentSize *= 0.8;
    if (searchIntent != null) segmentSize *= 0.8;
    if (cartInterest != null) segmentSize *= 0.5;
    if (loyalty != null) segmentSize *= 0.4;

    String segmentSizeStr = segmentSize < 1 ? '< 1%' : '${segmentSize.toStringAsFixed(1)}%';
    
    // Title construction
    final filters = [age, gender, marital, location, device, activity, searchIntent, cartInterest, loyalty];
    final title = filters.where((s) => s != null && s != 'Genel' && s != 'Tümü' && s != 'Türkiye').join(' • ');

    return {
      'title': title,
      'segmentSize': segmentSizeStr,
      'scores': {
        'search': searchScore,
        'cart': cartScore,
        'shopping': shoppingScore,
        'loyalty': loyaltyScore,
      },
      'metrics': {
        'basket': purchaseAvgBasket,
        'repeat': purchaseRepeatRate,
        'category': purchaseCategoryFocus,
        'logins': activityDailyLogins,
        'peakDays': activityPeakDays,
        'peakHours': activityPeakHours,
        'session': activityAvgSession,
      },
      'desc': {
        'who': '$age yaş grubunda, $gender ve $marital kullanıcılardan oluşan bu segment, toplam kitlenin $segmentSizeStr\'sini oluşturuyor.',
        'where': '$location ağırlıklı olmak üzere büyük şehirlerde yoğunlaşmış. Lojistik maliyeti ortalama seviyede.',
        'device': '$device kullanımı baskın. Teknoloji adaptasyonu ${age == '18-24' || age == '25-34' ? 'yüksek' : 'orta'} seviyede.',
        'active': 'En yoğun aktivite $activityPeakDays günleri, $activityPeakHours saatlerinde görülüyor. Günlük $activityDailyLogins giriş.',
        'search': '${searchIntent ?? 'Fiyat karşılaştırması ve marka aramaları yapıyor'}. Arama puanı: $searchScore/100.',
        'cart': 'Sepette ürün bekletme süresi ${age == '18-24' ? 'yüksek' : 'düşük'}. Sepet puanı: $cartScore/100.',
        'shop': 'Ortalama sepet tutarı $purchaseAvgBasket. İlgi alanları: $purchaseCategoryFocus. ${shoppingStyle != null ? 'Tercih: $shoppingStyle' : ''}',
        'loyalty': loyaltyScore > 75 ? 'Sadakati yüksek, düzenli alıcı (Puan: $loyaltyScore).' : 'Fiyat odaklı, sadakati artırılmalı (Puan: $loyaltyScore).',
      },
      'lists': {
         'searches': popularSearches,
         'categories': categoryDist,
         'demographics': demographicData,
         'heatmap': heatmapData,
       }
    };
  }

  Widget _buildAnalysisLeftPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Segment Oluşturucu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _activeAnalysisFilters['age'] = '18-24';
                    _activeAnalysisFilters['gender'] = null;
                    _activeAnalysisFilters['marital'] = null;
                    _activeAnalysisFilters['location'] = null;
                    _activeAnalysisFilters['device'] = null;
                    _activeAnalysisFilters['activity'] = null;
                    _activeAnalysisFilters['searchIntent'] = null;
                    _activeAnalysisFilters['cartInterest'] = null;
                    _activeAnalysisFilters['shoppingStyle'] = null;
                    _activeAnalysisFilters['loyalty'] = null;
                  });
                },
                child: Text(
                  'Sıfırla',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tüm veri noktalarını birleştirerek derinlemesine analiz yapın.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),

          // 1. Kim bu kullanıcı? (Yaş, Cinsiyet, Medeni Durum)
          _buildFilterSectionHeader('Kim bu kullanıcı?'),
          _buildFilterGroup('Yaş Grubu', 'age', _ageSegments.map((e) => e['label'] as String).toList()),
          _buildFilterGroup('Cinsiyet', 'gender', ['Kadın', 'Erkek']),
          _buildFilterGroup('Medeni Durum', 'marital', ['Bekar', 'Evli']),
          
          const Divider(height: 32),

          // 2. Nerede yaşıyor?
          _buildFilterSectionHeader('Nerede yaşıyor?'),
          _buildFilterGroup('Lokasyon', 'location', ['İstanbul', 'Ankara', 'İzmir', 'Diğer']),

          const Divider(height: 32),

          // 3. Hangi cihazı kullanıyor?
          _buildFilterSectionHeader('Hangi cihazı kullanıyor?'),
          _buildFilterGroup('Cihaz', 'device', ['Mobil', 'Web', 'Tablet']),

          const Divider(height: 32),

          // 4. Ne zaman aktif?
          _buildFilterSectionHeader('Ne zaman aktif?'),
          _buildFilterGroup('Aktivite Zamanı', 'activity', ['Hafta İçi Akşam', 'Hafta Sonu', 'Mesai Saatleri', 'Gece Kuşu']),

          const Divider(height: 32),

          // 5. Ne arıyor?
          _buildFilterSectionHeader('Ne arıyor?'),
          _buildFilterGroup('Arama Niyeti', 'searchIntent', ['Fiyat Odaklı', 'Marka Odaklı', 'Teknik Özellik', 'Kampanya']),

          const Divider(height: 32),

          // 6. Neyi sepete atıyor?
          _buildFilterSectionHeader('Neyi sepete atıyor?'),
          _buildFilterGroup('İlgi Alanı', 'cartInterest', ['Giyim & Moda', 'Teknoloji', 'Ev & Yaşam', 'Market', 'Kozmetik']),

          const Divider(height: 32),

          // 7. Nasıl alışveriş yapıyor?
          _buildFilterSectionHeader('Nasıl alışveriş yapıyor?'),
          _buildFilterGroup('Alışveriş Tarzı', 'shoppingStyle', ['Taksitli', 'Tek Çekim', 'Kapıda Ödeme', 'Hızlı Al']),

          const Divider(height: 32),

          // 8. Ne kadar sadık?
          _buildFilterSectionHeader('Ne kadar sadık?'),
          _buildFilterGroup('Sadakat Durumu', 'loyalty', ['Yeni Üye', 'Sadık', 'Riskli', 'Kaybedilmiş']),
        ],
      ),
    );
  }

  Widget _buildStoreAnalysisLeftPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mağaza Filtreleme',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 24),
          _buildFilterSectionHeader('Temel Bilgiler'),
          _buildFilterGroup('Kategori', 'category', ['Teknoloji', 'Giyim', 'Ev', 'Market'], map: _activeStoreFilters),
          _buildFilterGroup('Şehir', 'city', ['İstanbul', 'Ankara', 'İzmir'], map: _activeStoreFilters),
          
          const Divider(height: 32),
          _buildFilterSectionHeader('Performans'),
          _buildFilterGroup('Puan', 'rating', ['4.5+', '4.0-4.5', '3.5-4.0'], map: _activeStoreFilters),
          _buildFilterGroup('Durum', 'status', ['Aktif', 'Pasif', 'Yeni', 'İnceleniyor'], map: _activeStoreFilters),
        ],
      ),
    );
  }

  Widget _buildCargoAnalysisLeftPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lojistik Filtreleme',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 24),
          _buildFilterSectionHeader('Operasyon'),
          _buildFilterGroup('Kargo Firması', 'carrier', ['Yurtiçi Kargo', 'Aras Kargo', 'PTT Kargo', 'MNG'], map: _activeCargoFilters),
          _buildFilterGroup('Bölge', 'region', ['Marmara', 'Ege', 'İç Anadolu', 'Doğu Anadolu'], map: _activeCargoFilters),
          
          const Divider(height: 32),
          _buildFilterSectionHeader('Durum'),
          _buildFilterGroup('Paket Durumu', 'status', ['Teslim Edildi', 'Yolda', 'Dağıtımda', 'Gecikmede'], map: _activeCargoFilters),
          _buildFilterGroup('Süre', 'deliveryTime', ['0-24 Saat', '24-48 Saat', '48+ Saat'], map: _activeCargoFilters),
        ],
      ),
    );
  }

  Widget _buildFilterSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(Icons.subdirectory_arrow_right, size: 16, color: AppColors.primary.withOpacity(0.5)),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterGroup(String title, String key, List<String> options, {Map<String, String?>? map}) {
    final targetMap = map ?? _activeAnalysisFilters;
    final selectedValue = targetMap[key];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedValue == option;
            return GestureDetector(
              onTap: () {
                setState(() {
                  // Toggle logic
                  if (isSelected) {
                     if (key != 'age') targetMap[key] = null;
                  } else {
                    targetMap[key] = option;
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStoreAnalysisDetailPanel() {
    final data = _generateStoreReportData();
    final scores = data['scores'] as Map<String, int>;
    final metrics = data['metrics'] as Map<String, String>;
    final desc = data['desc'] as Map<String, String>;
    final segmentSize = data['segmentSize'] as String;
    final title = (data['title'] as String).isEmpty ? 'Tüm Mağazalar' : data['title'] as String;

    return Column(
      children: [
        _buildPersonaHeaderCard(title, segmentSize, desc['identity']!),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildNewKPICard('Ciro Potansiyeli', 'Yüksek', Icons.trending_up, Colors.green, '')),
            const SizedBox(width: 12),
            Expanded(child: _buildNewKPICard('Mağaza Puanı', '${metrics['avgRating']}', Icons.star, Colors.orange, '')),
            const SizedBox(width: 12),
            Expanded(child: _buildNewKPICard('İade Oranı', metrics['returnRate']!, Icons.assignment_return_outlined, Colors.red, '')),
            const SizedBox(width: 12),
            Expanded(child: _buildNewKPICard('Büyüme', metrics['growth']!, Icons.show_chart, Colors.blue, '')),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildDetailCard(
                    'Kimlik & Konum', 
                    Icons.store_mall_directory, 
                    const Color(0xFF6366F1), 
                    [
                      _buildReportItem('Kategori', _activeStoreFilters['category'] ?? 'Tümü', Icons.category),
                      _buildReportItem('Şehir', _activeStoreFilters['city'] ?? 'Tümü', Icons.location_on),
                      _buildReportItem('Durum', _activeStoreFilters['status'] ?? 'Tümü', Icons.info_outline),
                    ], 
                    description: desc['identity']!,
                  ),
                  const SizedBox(height: 20),
                  _buildDetailCard(
                    'Satış Performansı', 
                    Icons.sell, 
                    const Color(0xFF10B981), 
                    [
                      _buildReportItem('Ciro Skoru', '${scores['revenue']}', Icons.monetization_on),
                      _buildReportItem('Sipariş Hızı', '${scores['order']}', Icons.speed),
                      _buildReportItem('En Çok Satan', metrics['topProduct']!, Icons.shopping_bag),
                    ], 
                    description: desc['performance']!,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  _buildDetailCard(
                    'Müşteri Memnuniyeti', 
                    Icons.sentiment_satisfied_alt, 
                    const Color(0xFFEC4899), 
                    [
                      _buildReportItem('Puan Skoru', '${scores['rating']}', Icons.star_border),
                      _buildReportItem('İade', metrics['returnRate']!, Icons.assignment_return),
                    ], 
                    description: desc['satisfaction']!,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCargoAnalysisDetailPanel() {
    final data = _generateCargoReportData();
    final scores = data['scores'] as Map<String, int>;
    final metrics = data['metrics'] as Map<String, String>;
    final desc = data['desc'] as Map<String, String>;
    final segmentSize = data['segmentSize'] as String;
    final title = (data['title'] as String).isEmpty ? 'Tüm Operasyon' : data['title'] as String;

    return Column(
      children: [
        _buildPersonaHeaderCard(title, segmentSize, desc['operation']!),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildNewKPICard('Başarı Oranı', '%98', Icons.check_circle_outline, Colors.green, '')),
            const SizedBox(width: 12),
            Expanded(child: _buildNewKPICard('Ort. Süre', metrics['time']!, Icons.timer_outlined, Colors.blue, '')),
            const SizedBox(width: 12),
            Expanded(child: _buildNewKPICard('Sorun', metrics['issue']!, Icons.warning_amber, Colors.orange, '')),
            const SizedBox(width: 12),
            Expanded(child: _buildNewKPICard('Maliyet', '${scores['cost']}', Icons.attach_money, Colors.purple, '')),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildDetailCard(
                    'Operasyon Detayı', 
                    Icons.local_shipping, 
                    const Color(0xFF6366F1), 
                    [
                      _buildReportItem('Firma', _activeCargoFilters['carrier'] ?? 'Tümü', Icons.business),
                      _buildReportItem('Bölge', _activeCargoFilters['region'] ?? 'Tümü', Icons.map),
                      _buildReportItem('Durum', _activeCargoFilters['status'] ?? 'Tümü', Icons.info),
                    ], 
                    description: desc['operation']!,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                children: [
                  _buildDetailCard(
                    'Performans & Risk', 
                    Icons.speed, 
                    const Color(0xFFEF4444), 
                    [
                      _buildReportItem('Teslimat Skoru', '${scores['delivery']}', Icons.check),
                      _buildReportItem('Hasarsızlık', '${scores['damage']}', Icons.shield),
                      _buildReportItem('Süre', metrics['time']!, Icons.timer),
                    ], 
                    description: desc['issues']!,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnalysisDetailPanel() {
    final data = _generateReportData();
    final scores = data['scores'] as Map<String, int>;
    final metrics = data['metrics'] as Map<String, String>;
    final desc = data['desc'] as Map<String, String>;
    final lists = data['lists'] as Map<String, dynamic>;
    final segmentSize = data['segmentSize'] as String;
    final title = (data['title'] as String).isEmpty ? 'Genel Kullanıcı Kitlesi' : data['title'] as String;

    final demographics = lists['demographics'] as List<double>;
    final categories = lists['categories'] as Map<String, double>;
    final searches = lists['searches'] as List<String>;
    final heatmap = lists['heatmap'] as List<int>;

    return Column(
      children: [
        // 1. Persona Header (Yenilenmiş Tasarım)
        _buildPersonaHeaderCard(title, segmentSize, desc['who']!),
        const SizedBox(height: 24),

        // 2. KPI Cards (Renkli ve İkonlu)
        Row(
          children: [
            Expanded(child: _buildNewKPICard('Büyüme Potansiyeli', 'Yüksek', Icons.trending_up, const Color(0xFF10B981), '+12%')),
            const SizedBox(width: 16),
            Expanded(child: _buildNewKPICard('Risk Skoru', 'Düşük', Icons.security, Colors.indigo, 'Güvenli')),
            const SizedBox(width: 16),
            Expanded(child: _buildNewKPICard('Etkileşim Gücü', '${scores['search']}/100', Icons.touch_app, Colors.blue, 'Aktif')),
            const SizedBox(width: 16),
            Expanded(child: _buildNewKPICard('Dönüşüm Oranı', metrics['repeat']!, Icons.sync, Colors.orange, 'Tekrar')),
          ],
        ),
        const SizedBox(height: 24),

        // 3. Detaylı Analiz Grid'i
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sol Sütun: Demografi & Davranış
            Expanded(
              child: Column(
                children: [
                  _buildVisualDetailCard(
                    'Demografik Yapı',
                    Icons.people_alt_outlined,
                    const Color(0xFF6366F1),
                    content: Column(
                      children: [
                        Text(desc['where']!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
                        const SizedBox(height: 16),
                        _buildDemographicBar('Yaş Dağılımı (${_activeAnalysisFilters['age'] ?? '18-34'} Baskın)', demographics[0], Colors.blue),
                        const SizedBox(height: 8),
                        _buildDemographicBar('Cinsiyet (${_activeAnalysisFilters['gender'] ?? 'Kadın'} Ağırlıklı)', demographics[1], Colors.pink),
                        const SizedBox(height: 8),
                        _buildDemographicBar('Mobil Kullanım', demographics[2], Colors.orange),
                        const SizedBox(height: 16),
                        _buildInfoRow(Icons.location_on, 'Lokasyon', _activeAnalysisFilters['location'] ?? 'İstanbul, Ankara, İzmir'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildVisualDetailCard(
                    'Dijital Davranış',
                    Icons.fingerprint,
                    const Color(0xFF8B5CF6),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kullanıcıların gün içindeki aktiflik yoğunluğu:', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        const SizedBox(height: 12),
                        _buildActivityHeatmap(heatmap),
                        const SizedBox(height: 16),
                        _buildInfoRow(Icons.schedule, 'En Aktif Zaman', '${metrics['peakDays']} • ${metrics['peakHours']}'),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.search, 'Arama İlgisi', '${scores['search']} Puan (Yüksek)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Sağ Sütun: Alışveriş & İlgi
            Expanded(
              child: Column(
                children: [
                  _buildVisualDetailCard(
                    'Alışveriş & İlgi Alanları',
                    Icons.shopping_bag_outlined,
                    const Color(0xFF10B981),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(desc['shop']!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
                        const SizedBox(height: 16),
                        const Text('Kategori İlgi Dağılımı', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildCategoryDistribution(categories),
                        const SizedBox(height: 16),
                        const Text('Popüler Aramalar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: searches.map((e) => _buildTagChip(e)).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildVisualDetailCard(
                    'Sadakat Analizi',
                    Icons.loyalty,
                    const Color(0xFFEC4899),
                    content: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildCircleMetric('Sadakat', scores['loyalty']!, Colors.pink),
                            _buildCircleMetric('Sepet', scores['cart']!, Colors.purple),
                            _buildCircleMetric('Memnuniyet', 88, Colors.orange),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(desc['loyalty']!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPersonaHeaderCard(String title, String segmentSize, String description) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Center(
              child: Text(
                segmentSize,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Text(
                        'HEDEF KİTLE ANALİZİ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.verified, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text('Güven Skoru: 92/100', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildDetailCard(String title, IconData icon, Color color, List<Widget> children, {required String description}) {
    return _buildVisualDetailCard(
      title,
      icon,
      color,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
          const SizedBox(height: 16),
          ...children.map((child) => Padding(padding: const EdgeInsets.only(bottom: 12), child: child)),
        ],
      ),
    );
  }

  Widget _buildNewKPICard(String label, String value, IconData icon, Color color, String subValue) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(subValue, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualDetailCard(String title, IconData icon, Color color, {required Widget content}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 10),
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Padding(
            padding: const EdgeInsets.all(20),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildDemographicBar(String label, double percentage, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            Text('${(percentage * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityHeatmap(List<int> data) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('00:00', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('12:00', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text('23:59', style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(24, (index) {
            final val = data[index];
            Color color;
            if (val == 2) color = const Color(0xFF8B5CF6); // High
            else if (val == 1) color = const Color(0xFFC4B5FD); // Med
            else color = const Color(0xFFF3F4F6); // Low
            
            return Expanded(
              child: Tooltip(
                message: '$index:00 - ${val == 2 ? 'Yüksek' : (val == 1 ? 'Orta' : 'Düşük')}',
                child: Container(
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCategoryDistribution(Map<String, double> categories) {
    final colors = [Colors.blue, Colors.purple, Colors.orange, Colors.pink, Colors.green];
    int colorIndex = 0;

    return Column(
      children: [
        Row(
          children: categories.entries.map((entry) {
            final flex = (entry.value * 100).toInt();
            final color = colors[colorIndex++ % colors.length];
            return Expanded(
              flex: flex,
              child: Tooltip(
                message: '${entry.key}: ${(entry.value * 100).toInt()}%',
                child: Container(
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: categories.entries.toList().asMap().entries.map((e) {
            final index = e.key;
            final entry = e.value;
            final color = colors[index % colors.length];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('${entry.key} (%${(entry.value * 100).toInt()})', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTagChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
    );
  }

  Widget _buildCircleMetric(String label, int value, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            children: [
              CircularProgressIndicator(
                value: value / 100,
                backgroundColor: color.withOpacity(0.1),
                color: color,
                strokeWidth: 5,
              ),
              Center(child: Text('$value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Text('$label:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(width: 4),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _buildReportItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
        ),
      ],
    );
  }



  Widget _buildProductListRow(String name, String count, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.image_outlined, size: 16, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              count,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryPerformanceChart() {
    return SizedBox(
      height: 80,
      child: Row(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _DonutChartPainter(
                values: [85, 10, 5],
                colors: [const Color(0xFF22C55E), const Color(0xFFFACC15), const Color(0xFFEF4444)],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Zamanında', const Color(0xFF22C55E), '85%'),
                _buildLegendItem('Geciken', const Color(0xFFFACC15), '10%'),
                _buildLegendItem('İptal/İade', const Color(0xFFEF4444), '5%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticRiskChart() {
    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildBarColumn('Hasar', 0.6, const Color(0xFFEF4444)),
          const SizedBox(width: 8),
          _buildBarColumn('Kayıp', 0.2, const Color(0xFFF97316)),
          const SizedBox(width: 8),
          _buildBarColumn('Yanlış', 0.4, const Color(0xFFFACC15)),
          const SizedBox(width: 8),
          _buildBarColumn('Gecikme', 0.8, const Color(0xFF3B82F6)),
        ],
      ),
    );
  }

  Widget _buildStoreProfileChart() {
    return SizedBox(
      height: 80,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kategori Dağılımı', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(flex: 4, child: Container(height: 8, color: const Color(0xFF3B82F6))),
                    Expanded(flex: 3, child: Container(height: 8, color: const Color(0xFF10B981))),
                    Expanded(flex: 2, child: Container(height: 8, color: const Color(0xFFF59E0B))),
                    Expanded(flex: 1, child: Container(height: 8, color: const Color(0xFF6366F1))),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildLegendItem('Tekno', const Color(0xFF3B82F6), '40%'),
                    _buildLegendItem('Moda', const Color(0xFF10B981), '30%'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSalesChart() {
    return SizedBox(
      height: 80,
      child: CustomPaint(
        painter: _DualLineChartPainter(
          series1: [40, 60, 50, 80, 70, 90, 100],
          series2: [20, 30, 25, 40, 35, 45, 50],
          color1: const Color(0xFF22C55E),
          color2: const Color(0xFFBBF7D0),
        ),
      ),
    );
  }

  Widget _buildProductManagementChart() {
    return Row(
      children: [
        _buildCircularIndicator('Onaylı', 0.92, const Color(0xFF10B981)),
        const SizedBox(width: 16),
        _buildCircularIndicator('Bekleyen', 0.05, const Color(0xFFF59E0B)),
        const SizedBox(width: 16),
        _buildCircularIndicator('Red', 0.03, const Color(0xFFEF4444)),
      ],
    );
  }

  Widget _buildFinancialFlowChart() {
    return SizedBox(
      height: 80,
      child: CustomPaint(
        painter: _DualLineChartPainter(
          series1: [100, 120, 110, 140, 130, 160, 180],
          series2: [],
          color1: AppColors.primary,
          color2: Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildProductAnalyticsChart() {
    return Column(
      children: [
        _buildHorizontalBar('iPhone 15', 0.9, const Color(0xFF3B82F6)),
        const SizedBox(height: 4),
        _buildHorizontalBar('Dyson V15', 0.7, const Color(0xFF3B82F6)),
        const SizedBox(height: 4),
        _buildHorizontalBar('Airfryer', 0.5, const Color(0xFF3B82F6)),
      ],
    );
  }

  Widget _buildMarketingChart() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildBarColumn('Google', 0.7, const Color(0xFFF97316)),
        _buildBarColumn('Meta', 0.5, const Color(0xFF8B5CF6)),
        _buildBarColumn('Tiktok', 0.8, const Color(0xFFEC4899)),
        _buildBarColumn('Email', 0.3, const Color(0xFF10B981)),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, String value) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('$label $value', style: const TextStyle(fontSize: 10, color: Color(0xFF374151))),
      ],
    );
  }

  Widget _buildBarColumn(String label, double ratio, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 16,
          height: 50 * ratio,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
      ],
    );
  }

  Widget _buildCircularIndicator(String label, double percent, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            children: [
              CircularProgressIndicator(
                value: percent,
                strokeWidth: 4,
                backgroundColor: color.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Center(
                child: Text(
                  '${(percent * 100).toInt()}%',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF374151))),
      ],
    );
  }

  Widget _buildHorizontalBar(String label, double ratio, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF374151)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserWhoChart() {
    const data = [
      {'label': '18-24', 'value': 24},
      {'label': '25-34', 'value': 38},
      {'label': '35-44', 'value': 22},
      {'label': '45+', 'value': 16},
    ];

    final maxValue =
        data.map((e) => e['value'] as int).reduce((a, b) => a > b ? a : b);

    return Column(
      children: data.map((item) {
        final value = item['value'] as int;
        final label = item['label'] as String;
        final ratio = value / maxValue;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: AppColors.primary.withOpacity(0.12),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.2),
                            AppColors.primary,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 30,
                child: Text(
                  '%$value',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserLocationChart() {
    const data = [
      {'label': 'İstanbul', 'value': 42},
      {'label': 'Hatay', 'value': 25},
      {'label': 'Ankara', 'value': 18},
      {'label': 'Diğer', 'value': 15},
    ];

    final maxValue =
        data.map((e) => e['value'] as int).reduce((a, b) => a > b ? a : b);

    return Column(
      children: data.map((item) {
        final value = item['value'] as int;
        final label = item['label'] as String;
        final ratio = value / maxValue;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0xFF0EA5E9).withOpacity(0.12),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFBAE6FD),
                            Color(0xFF0EA5E9),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 30,
                child: Text(
                  '%$value',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserDeviceChart() {
    const data = [
      {'label': 'Mobil', 'value': 68},
      {'label': 'Web', 'value': 21},
      {'label': 'Tablet', 'value': 11},
    ];

    final maxValue =
        data.map((e) => e['value'] as int).reduce((a, b) => a > b ? a : b);

    return Column(
      children: data.map((item) {
        final value = item['value'] as int;
        final label = item['label'] as String;
        final ratio = value / maxValue;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0xFF22C55E).withOpacity(0.12),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFBBF7D0),
                            Color(0xFF22C55E),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 30,
                child: Text(
                  '%$value',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDashboard() {
    final orders = [
      {
        'id': '#12845',
        'user': 'Baran K.***',
        'store': 'Teknosa Antakya',
        'amount': '₺4.250',
        'status': 'Tamamlandı',
      },
      {
        'id': '#12846',
        'user': 'Ayşe K.***',
        'store': 'LC Waikiki',
        'amount': '₺980',
        'status': 'Hazırlanıyor',
      },
      {
        'id': '#12847',
        'user': 'Mehmet D.***',
        'store': 'Mahalle Marketi',
        'amount': '₺320',
        'status': 'Teslim Edildi',
      },
      {
        'id': '#12848',
        'user': 'Elif Y.***',
        'store': 'Dönerci Ustam',
        'amount': '₺150',
        'status': 'Hazırlanıyor',
      },
      {
        'id': '#12849',
        'user': 'Can A.***',
        'store': 'Arçelik Mağazası',
        'amount': '₺12.450',
        'status': 'Ödeme Bekliyor',
      },
      {
        'id': '#12850',
        'user': 'Zeynep S.***',
        'store': 'Ayakkabıcı Ayhan',
        'amount': '₺780',
        'status': 'Tamamlandı',
      },
    ];

    final baseSalesBars = [60, 95, 80, 110, 90, 120, 105, 98, 88, 92, 85, 100];
    final baseEarningBars = [40, 70, 65, 90, 75, 100, 82, 80, 72, 78, 69, 85];

    List<int> salesBars;
    List<int> earningBars;

    switch (_selectedRevenueRange) {
      case 'Son 3 Ay':
        salesBars = baseSalesBars.sublist(baseSalesBars.length - 3);
        earningBars = baseEarningBars.sublist(baseEarningBars.length - 3);
        break;
      case 'Son 6 Ay':
        salesBars = baseSalesBars.sublist(baseSalesBars.length - 6);
        earningBars = baseEarningBars.sublist(baseEarningBars.length - 6);
        break;
      default:
        salesBars = baseSalesBars;
        earningBars = baseEarningBars;
    }

    final baseUserCounts = [
      1200,
      1350,
      1480,
      1600,
      1750,
      1900,
      2050,
      2180,
      2300,
      2450,
      2600,
      2800,
    ];

    final baseStoreCounts = [
      80,
      90,
      95,
      105,
      115,
      126,
      135,
      142,
      150,
      158,
      167,
      175,
    ];

    List<int> userCounts;
    List<int> storeCounts;

    switch (_selectedUserStoreRange) {
      case 'Son 3 Ay':
        userCounts = baseUserCounts.sublist(baseUserCounts.length - 3);
        storeCounts = baseStoreCounts.sublist(baseStoreCounts.length - 3);
        break;
      case 'Son 6 Ay':
        userCounts = baseUserCounts.sublist(baseUserCounts.length - 6);
        storeCounts = baseStoreCounts.sublist(baseStoreCounts.length - 6);
        break;
      default:
        userCounts = baseUserCounts;
        storeCounts = baseStoreCounts;
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  label: 'Toplam Kullanıcı',
                  value: '24.580',
                  icon: Icons.people_alt_outlined,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  label: 'Aktif Kullanıcı (bugün)',
                  value: '3.280',
                  icon: Icons.bolt_outlined,
                  color: const Color(0xFF059669),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  label: 'Toplam Sipariş',
                  value: '12.840',
                  icon: Icons.shopping_cart_outlined,
                  color: const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  label: 'Bugünkü Ciro',
                  value: '₺184.250',
                  icon: Icons.payments_outlined,
                  color: const Color(0xFFF97316),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        'Sipariş & Ciro',
                        trailing: DropdownButtonHideUnderline(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedRevenueRange,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Tüm Zamanlar',
                                  child: Text('Tüm Zamanlar'),
                                ),
                                DropdownMenuItem(
                                  value: 'Son 12 Ay',
                                  child: Text('Son 12 Ay'),
                                ),
                                DropdownMenuItem(
                                  value: 'Son 6 Ay',
                                  child: Text('Son 6 Ay'),
                                ),
                                DropdownMenuItem(
                                  value: 'Son 3 Ay',
                                  child: Text('Son 3 Ay'),
                                ),
                                DropdownMenuItem(
                                  value: 'Özel Aralık',
                                  child: Text('Özel tarih aralığı'),
                                ),
                              ],
                              onChanged: (value) async {
                                if (value == null) {
                                  return;
                                }
                                if (value == 'Özel Aralık') {
                                  final pickedRange = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2020, 1, 1),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                  );
                                  if (pickedRange != null) {
                                    setState(() {
                                      _selectedRevenueRange = 'Özel Aralık';
                                      _revenueDateRange = pickedRange;
                                    });
                                  }
                                } else {
                                  setState(() {
                                    _selectedRevenueRange = value;
                                    _revenueDateRange = null;
                                  });
                                }
                              },
                              icon: const Icon(Icons.expand_more, size: 18),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sarı çizgi ciroyu, mavi çizgi sipariş adetini temsil ediyor.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      if (_selectedRevenueRange == 'Özel Aralık' &&
                          _revenueDateRange != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Seçili aralık: '
                          '${_formatDate(_revenueDateRange!.start)} - '
                          '${_formatDate(_revenueDateRange!.end)}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _showRevenueDetailsDialog,
                        child: SizedBox(
                          height: 180,
                          child: CustomPaint(
                            painter: _DualLineChartPainter(
                              series1: earningBars.map((e) => e.toDouble()).toList(),
                              series2: salesBars.map((e) => e.toDouble()).toList(),
                              color1: const Color(0xFFF97316),
                              color2: const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Ciro',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Sipariş',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Detayları görmek için grafiğe tıklayabilirsin.',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        'Kullanıcı ve Mağaza Sayıları',
                        trailing: DropdownButtonHideUnderline(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButton<String>(
                              value: _selectedUserStoreRange,
                              items: const [
                                DropdownMenuItem(
                                  value: 'Tüm Zamanlar',
                                  child: Text('Tüm Zamanlar'),
                                ),
                                DropdownMenuItem(
                                  value: 'Son 12 Ay',
                                  child: Text('Son 12 Ay'),
                                ),
                                DropdownMenuItem(
                                  value: 'Son 6 Ay',
                                  child: Text('Son 6 Ay'),
                                ),
                                DropdownMenuItem(
                                  value: 'Son 3 Ay',
                                  child: Text('Son 3 Ay'),
                                ),
                                DropdownMenuItem(
                                  value: 'Özel Aralık',
                                  child: Text('Özel tarih aralığı'),
                                ),
                              ],
                              onChanged: (value) async {
                                if (value == null) {
                                  return;
                                }
                                if (value == 'Özel Aralık') {
                                  final pickedRange = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(2020, 1, 1),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                  );
                                  if (pickedRange != null) {
                                    setState(() {
                                      _selectedUserStoreRange = 'Özel Aralık';
                                      _userStoreDateRange = pickedRange;
                                    });
                                  }
                                } else {
                                  setState(() {
                                    _selectedUserStoreRange = value;
                                    _userStoreDateRange = null;
                                  });
                                }
                              },
                              icon: const Icon(Icons.expand_more, size: 18),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mor çizgi kullanıcı sayısını, yeşil çizgi mağaza sayısını temsil ediyor.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      if (_selectedUserStoreRange == 'Özel Aralık' &&
                          _userStoreDateRange != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Seçili aralık: '
                          '${_formatDate(_userStoreDateRange!.start)} - '
                          '${_formatDate(_userStoreDateRange!.end)}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildUserStoreLineChart(userCounts, storeCounts),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Kullanıcı',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: Color(0xFF22C55E),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Mağaza',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Bölgelere Göre Satış'),
                      const SizedBox(height: 4),
                      Text(
                        'Tahmini bölge dağılımı.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      _buildRegionRow('İstanbul', 0.42, const Color(0xFF6366F1)),
                      const SizedBox(height: 8),
                      _buildRegionRow('Hatay', 0.25, const Color(0xFF10B981)),
                      const SizedBox(height: 8),
                      _buildRegionRow('Ankara', 0.18, const Color(0xFFF97316)),
                      const SizedBox(height: 8),
                      _buildRegionRow('Diğer', 0.15, const Color(0xFF6B7280)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Trafik Kaynağı'),
                      const SizedBox(height: 4),
                      Text(
                        'Son 30 gün için trafik kırılımı.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 16,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: Colors.grey.shade100,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 30,
                              child: Container(
                                color: const Color(0xFFF97316),
                              ),
                            ),
                            Expanded(
                              flex: 20,
                              child: Container(
                                color: const Color(0xFF10B981),
                              ),
                            ),
                            Expanded(
                              flex: 10,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6B7280),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildTrafficLegend('Organik', '40%', const Color(0xFF6366F1)),
                      const SizedBox(height: 8),
                      _buildTrafficLegend('Reklam', '30%', const Color(0xFFF97316)),
                      const SizedBox(height: 8),
                      _buildTrafficLegend('Direkt', '20%', const Color(0xFF10B981)),
                      const SizedBox(height: 8),
                      _buildTrafficLegend('Referans', '10%', const Color(0xFF6B7280)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Son Yorumlar'),
                      const SizedBox(height: 12),
                      _buildCommentRow(
                        name: 'Kathryn Murphy',
                        rating: 5,
                        comment: 'Ürün açıklamada anlatıldığı gibi, kargo çok hızlıydı.',
                      ),
                      const SizedBox(height: 12),
                      _buildCommentRow(
                        name: 'Leslie Alexander',
                        rating: 4,
                        comment: 'Paketlemede ufak bir sorun vardı ama destek hızlı çözdü.',
                      ),
                      const SizedBox(height: 12),
                      _buildCommentRow(
                        name: 'Ali Yılmaz',
                        rating: 3,
                        comment: 'Ürün güzel fakat teslimat beklediğimden geç geldi.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        'Anlık Sipariş Akışı',
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Son dakikalarda düşen siparişleri kullanıcı ve mağaza bazında görüyorsun.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: orders.map((order) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary.withOpacity(0.1),
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_outlined,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${order['id']} • ${order['store']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        order['user'] as String,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      order['amount'] as String,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      order['status'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Kullanıcı & Satıcı Özeti'),
                          const SizedBox(height: 12),
                          _buildQueueRow('Aktif kullanıcı (bugün)', '3.280'),
                          const SizedBox(height: 8),
                          _buildQueueRow('Yeni kayıt (7 gün)', '145'),
                          const SizedBox(height: 8),
                          _buildQueueRow('Aktif mağaza', '312'),
                          const SizedBox(height: 8),
                          _buildQueueRow('Bugün sipariş veren kullanıcı', '980'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('Kritik Kuyruklar'),
                          const SizedBox(height: 12),
                          _buildQueueRow('Bekleyen şikayet', '23'),
                          const SizedBox(height: 8),
                          _buildQueueRow('Onay bekleyen mağaza', '8'),
                          const SizedBox(height: 8),
                          _buildQueueRow('Onay bekleyen ürün', '147'),
                          const SizedBox(height: 16),
                          _buildSectionHeader('Risk Radar'),
                          const SizedBox(height: 12),
                          _buildRiskRow('Geç kargo yapan mağaza', '12'),
                          const SizedBox(height: 8),
                          _buildRiskRow('Yüksek şikayet oranı', '5'),
                          const SizedBox(height: 8),
                          _buildRiskRow('Olası sahte ürün', '3'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showRevenueDetailsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        int selectedIndex = 0;

        final products = [
          {
            'name': 'iPhone 15 128GB',
            'revenue': '₺184.250',
            'quantity': '120',
            'avgPrice': '₺15.354',
            'topPurchaseDate': '12 Şubat 2026',
            'userAge': '25-34 yaş aralığı ağırlıklı',
            'userGender': '%58 Erkek / %42 Kadın',
            'userCities': 'İstanbul, Ankara, Hatay',
            'avgDelivery': '2,1 gün',
            'purchaseWindow': 'Akşam 20:00 - 23:00 arası yoğun',
            'repeatRate': '%27 tekrar alışveriş oranı',
          },
          {
            'name': 'Samsung QLED TV 55"',
            'revenue': '₺132.600',
            'quantity': '45',
            'avgPrice': '₺2.946',
            'topPurchaseDate': '3 Şubat 2026',
            'userAge': '30-44 yaş aralığı ağırlıklı',
            'userGender': '%61 Erkek / %39 Kadın',
            'userCities': 'İstanbul, İzmir, Bursa',
            'avgDelivery': '3,4 gün',
            'purchaseWindow': 'Akşam 18:00 - 22:00 arası yoğun',
            'repeatRate': '%19 tekrar alışveriş oranı',
          },
          {
            'name': 'Xiaomi Robot Süpürge',
            'revenue': '₺89.750',
            'quantity': '72',
            'avgPrice': '₺1.247',
            'topPurchaseDate': '28 Ocak 2026',
            'userAge': '25-40 yaş aralığı ağırlıklı',
            'userGender': '%54 Kadın / %46 Erkek',
            'userCities': 'Ankara, İstanbul, Antalya',
            'avgDelivery': '2,8 gün',
            'purchaseWindow': 'Öğlen 12:00 - 15:00 arası yoğun',
            'repeatRate': '%22 tekrar alışveriş oranı',
          },
          {
            'name': 'Nike Koşu Ayakkabısı',
            'revenue': '₺64.320',
            'quantity': '96',
            'avgPrice': '₺670',
            'topPurchaseDate': '9 Şubat 2026',
            'userAge': '18-30 yaş aralığı ağırlıklı',
            'userGender': '%48 Kadın / %52 Erkek',
            'userCities': 'İstanbul, Eskişehir, Kayseri',
            'avgDelivery': '1,9 gün',
            'purchaseWindow': 'Akşam 19:00 - 23:30 arası yoğun',
            'repeatRate': '%31 tekrar alışveriş oranı',
          },
        ];

        return StatefulBuilder(
          builder: (context, setState) {
            final selectedProduct = products[selectedIndex];

            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                width: 980,
                height: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          const Text(
                            'Sipariş ve Ciro Detayları',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ürün Bazlı Ciro ve Satış Adedi',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                        columnSpacing: 24,
                                        headingRowHeight: 36,
                                        dataRowMinHeight: 40,
                                        dataRowMaxHeight: 52,
                                        columns: const [
                                          DataColumn(
                                            label: Text(
                                              'Ürün',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Satış Adedi',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Toplam Ciro',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Text(
                                              'Ort. Sepet',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                        rows: List.generate(products.length, (index) {
                                          final product = products[index];
                                          return DataRow(
                                            onSelectChanged: (_) {
                                              setState(() {
                                                selectedIndex = index;
                                              });
                                            },
                                            cells: [
                                              DataCell(
                                                Text(
                                                  product['name'] as String,
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  product['quantity'] as String,
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  product['revenue'] as String,
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                              DataCell(
                                                Text(
                                                  product['avgPrice'] as String,
                                                  style: const TextStyle(fontSize: 12),
                                                ),
                                              ),
                                            ],
                                          );
                                        }),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${selectedProduct['name']} alan kullanıcı profili',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildUserProfileRow(
                                    label: 'Yaş dağılımı',
                                    value: selectedProduct['userAge'] as String,
                                    icon: Icons.cake_outlined,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildUserProfileRow(
                                    label: 'Cinsiyet',
                                    value: selectedProduct['userGender'] as String,
                                    icon: Icons.wc_outlined,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildUserProfileRow(
                                    label: 'En çok sipariş veren iller',
                                    value: selectedProduct['userCities'] as String,
                                    icon: Icons.location_on_outlined,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildUserProfileRow(
                                    label: 'Ortalama teslimat süresi',
                                    value: selectedProduct['avgDelivery'] as String,
                                    icon: Icons.local_shipping_outlined,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildUserProfileRow(
                                    label: 'Yoğun sipariş saatleri',
                                    value: selectedProduct['purchaseWindow'] as String,
                                    icon: Icons.access_time,
                                  ),
                                  const SizedBox(height: 8),
                                  _buildUserProfileRow(
                                    label: 'Tekrar alışveriş',
                                    value: selectedProduct['repeatRate'] as String,
                                    icon: Icons.loop,
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Gösterilen veriler örnek amaçlıdır ve gerçek veritabanına bağlı değildir.',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMapAnalyticsModule() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.map_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Harita ve Satıcı Konumları',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedMapCategory,
                          items: const [
                            DropdownMenuItem(value: 'Hepsi', child: Text('Tüm kategoriler')),
                            DropdownMenuItem(value: 'Restoran', child: Text('Restoran')),
                            DropdownMenuItem(value: 'Teknoloji', child: Text('Teknoloji')),
                            DropdownMenuItem(value: 'Giyim', child: Text('Giyim')),
                            DropdownMenuItem(value: 'Ayakkabı', child: Text('Ayakkabı')),
                            DropdownMenuItem(value: 'Market', child: Text('Market')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedMapCategory = value;
                            });
                          },
                          icon: const Icon(Icons.expand_more, size: 18),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Solda satıcı konumlarını, sarı halkalarla da yoğun arama yapılan bölgeleri görüyorsun.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      mapController: _adminMapController,
                      options: MapOptions(
                        initialCenter: const LatLng(36.2025, 36.1605),
                        initialZoom: 13.0,
                        minZoom: 11.0,
                        maxZoom: 18.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.ibul_app',
                        ),
                        MarkerLayer(
                          markers: _buildHotspotMarkers(),
                        ),
                        MarkerLayer(
                          markers: _buildSellerMarkers(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mağaza Kategorileri',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildCategoryChip('Hepsi'),
                        _buildCategoryChip('Restoran'),
                        _buildCategoryChip('Teknoloji'),
                        _buildCategoryChip('Giyim'),
                        _buildCategoryChip('Ayakkabı'),
                        _buildCategoryChip('Market'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Arama Sıcak Noktaları',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Belirli bölgelerde insanlar neleri daha çok aratmış görebilirsin.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _searchHotspots.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 16,
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (context, index) {
                            final hotspot = _searchHotspots[index];
                            final queries = (hotspot['queries'] as List<dynamic>).join(', ');
                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                final center = hotspot['center'] as LatLng;
                                _adminMapController.move(center, 15.0);
                                _showHotspotDialog(hotspot);
                              },
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.amber.withOpacity(0.2),
                                    ),
                                    child: const Icon(
                                      Icons.wifi_tethering,
                                      size: 16,
                                      color: Colors.amber,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hotspot['label'] as String,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          queries,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRegionRow(String label, double ratio, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(ratio * 100).round()}%',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildTrafficLegend(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF111827),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentRow({
    required String name,
    required int rating,
    required String comment,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.12),
          ),
          child: const Center(
            child: Icon(
              Icons.person,
              size: 18,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: List.generate(5, (index) {
                  final filled = index < rating;
                  return Icon(
                    filled ? Icons.star : Icons.star_border,
                    size: 12,
                    color: const Color(0xFFFACC15),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                comment,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }

  Widget _buildUserProfileRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: AppColors.primary.withOpacity(0.08),
          ),
          child: Icon(
            icon,
            size: 16,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserStoreLineChart(
    List<int> userCounts,
    List<int> storeCounts,
  ) {
    return SizedBox(
      height: 180,
      child: CustomPaint(
        painter: _DualLineChartPainter(
          series1: userCounts.map((e) => e.toDouble()).toList(),
          series2: storeCounts.map((e) => e.toDouble()).toList(),
          color1: AppColors.primary,
          color2: const Color(0xFF22C55E),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    final selected = _selectedMapCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMapCategory = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  List<Marker> _buildSellerMarkers() {
    return _mapSellers.where((seller) {
      if (_selectedMapCategory == 'Hepsi') return true;
      return seller['category'] == _selectedMapCategory;
    }).map((seller) {
      final location = seller['location'] as LatLng;
      final category = seller['category'] as String;
      IconData iconData;
      switch (category) {
        case 'Restoran':
          iconData = Icons.restaurant;
          break;
        case 'Teknoloji':
          iconData = Icons.devices;
          break;
        case 'Giyim':
          iconData = Icons.checkroom;
          break;
        case 'Ayakkabı':
          iconData = Icons.directions_walk;
          break;
        case 'Market':
          iconData = Icons.shopping_cart;
          break;
        default:
          iconData = Icons.store;
      }
      return Marker(
        point: location,
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () {
            _showSellerDialog(seller);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  seller['name'] as String,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  iconData,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildHotspotMarkers() {
    return _searchHotspots.map((hotspot) {
      final center = hotspot['center'] as LatLng;
      final queries = (hotspot['queries'] as List<dynamic>).join(', ');
      return Marker(
        point: center,
        width: 140,
        height: 140,
        child: GestureDetector(
          onTap: () {
            _showHotspotDialog(hotspot);
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.amber.withOpacity(0.18),
              border: Border.all(color: Colors.amber, width: 3),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  queries,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  void _showSellerDialog(Map<String, dynamic> seller) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            seller['name'] as String,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kategori: ${seller['category']}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'Bu pop-up, haritadaki mağaza pinine tıklayınca göreceğin yönetim kartı için taslak.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  void _showHotspotDialog(Map<String, dynamic> hotspot) {
    final queries = hotspot['queries'] as List<dynamic>;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            hotspot['label'] as String,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bu bölgede en çok aratılan terimler:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
              ...queries.map(
                (q) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.amber),
                      const SizedBox(width: 6),
                      Text(
                        q.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQueueRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildRiskRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    );
  }

  void _showReportMissingDocDialog(BuildContext context) {
    final Map<String, bool> _selectedIssues = {
      'Vergi levhası yüklenmemiş': false,
      'Vergi levhası okunmuyor': false,
      'İmza sirküsü eksik': false,
      'Ticaret sicil gazetesi eksik': false,
      'IBAN belgesi eksik': false,
      'Kimlik belgesi eksik': false,
      'Vergi no hatalı': false,
      'Şirket ünvanı uyuşmuyor': false,
      'Adres eksik / yanlış': false,
      'Şüpheli başvuru': false,
    };
    final TextEditingController _noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 600,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Eksik Belge / Hata Bildir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Tespit Edilen Eksikler:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: _selectedIssues.keys.map((key) {
                          return CheckboxListTile(
                            title: Text(key, style: const TextStyle(fontSize: 13)),
                            value: _selectedIssues[key],
                            onChanged: (val) {
                              setState(() {
                                _selectedIssues[key] = val!;
                              });
                            },
                            dense: true,
                            activeColor: AppColors.primary,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Ek Not (Opsiyonel):', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      hintText: 'Örn: Lütfen imza sirküsünün güncel halini yükleyiniz.',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Logic to send notification
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Eksik belge bildirimi mağazaya iletildi.')),
                          );
                        },
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Bildirim Gönder'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showStoreDetail(BuildContext context, String storeName) {
    showDialog(
      context: context,
      builder: (context) {
        String _selectedTab = 'Genel Bilgiler';
        
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 1000,
                height: 850,
                padding: const EdgeInsets.all(0),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: const Icon(Icons.store, size: 32, color: AppColors.primary),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    storeName,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Başvuru İnceleniyor',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text('Başvuru Tarihi: 14.02.2026', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Sidebar (Navigation)
                          Container(
                            width: 240,
                            decoration: BoxDecoration(
                              border: Border(right: BorderSide(color: Colors.grey.shade200)),
                              color: const Color(0xFFF9FAFB),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildDetailMenuLink('Genel Bilgiler', Icons.info_outline, _selectedTab == 'Genel Bilgiler', () => setState(() => _selectedTab = 'Genel Bilgiler')),
                                _buildDetailMenuLink('Belgeler', Icons.description_outlined, _selectedTab == 'Belgeler', () => setState(() => _selectedTab = 'Belgeler')),
                                _buildDetailMenuLink('Finansal Bilgiler', Icons.account_balance_wallet_outlined, _selectedTab == 'Finansal Bilgiler', () => setState(() => _selectedTab = 'Finansal Bilgiler')),
                                _buildDetailMenuLink('Yetkili Kişi', Icons.person_outline, _selectedTab == 'Yetkili Kişi', () => setState(() => _selectedTab = 'Yetkili Kişi')),
                                _buildDetailMenuLink('Geçmiş İşlemler', Icons.history, _selectedTab == 'Geçmiş İşlemler', () => setState(() => _selectedTab = 'Geçmiş İşlemler')),
                              ],
                            ),
                          ),
                          
                          // Main Content Area
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // A) Mağaza Profil Özeti (Header Card)
                                  _buildStoreProfileSummary(),
                                  
                                  if (_selectedTab == 'Genel Bilgiler') ...[
                                    // Section: Kurumsal Kimlik
                                    const Text('Kurumsal Kimlik', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 24),
                                    _buildDetailRow('Yasal Unvan', 'Teknosa İç ve Dış Ticaret A.Ş.'),
                                    _buildDetailRow('Vergi Dairesi / No', 'Büyük Mükellefler / 1234567890'),
                                    _buildDetailRow('Mersis No', '0123456789000012'),
                                    _buildDetailRow('KEP Adresi', 'teknosa@hs01.kep.tr'),
                                    _buildDetailRow('Web Sitesi', 'www.teknosa.com'),
                                    
                                    const Divider(height: 48),
                                    
                                    // E) Otomatik Sistem Kontrolleri
                                    const Text('Otomatik Sistem Kontrolleri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),
                                    _buildSystemCheckRow('Vergi No', true, 'Doğrulandı (GİB)'),
                                    _buildSystemCheckRow('MERSİS', true, 'Aktif Kayıt'),
                                    _buildSystemCheckRow('Kara Liste', true, 'Temiz'),
                                    _buildSystemCheckRow('IP Kontrolü', true, 'Tekil Başvuru'),
                                    
                                    const Divider(height: 48),
                                    
                                    // Section: İletişim & Adres
                                    const Text('İletişim & Adres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 24),
                                    _buildDetailRow('Telefon', '+90 850 222 55 99'),
                                    _buildDetailRow('E-posta', 'satici@teknosa.com'),
                                    _buildDetailRow('Merkez Adres', 'Carrefoursa Plaza, Cevizli Mah. Tugay Yolu Cad. No:67 Blok:B Maltepe / İstanbul'),
                                    _buildDetailRow('Depo Adresi', 'Gebze Lojistik Merkezi, Kocaeli'),
                                  ] else if (_selectedTab == 'Belgeler') ...[
                                    _buildDocumentsTab(),
                                  ] else if (_selectedTab == 'Finansal Bilgiler') ...[
                                    _buildFinancialTab(),
                                  ] else if (_selectedTab == 'Yetkili Kişi') ...[
                                    _buildAuthorizedPersonTab(),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Footer Actions
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _showReportMissingDocDialog(context),
                            icon: const Icon(Icons.mail_outline, size: 18),
                            label: const Text('Eksik Belge Bildir'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mağaza başvurusu onaylandı.')));
                            },
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Başvuruyu Onayla'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
        );
      },
    );
  }

  Widget _buildStoreProfileSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryMetric('Başvuru Skoru', '4.6', Icons.score, Colors.blue),
          _buildSummaryMetric('Risk Seviyesi', 'Düşük', Icons.shield, Colors.green),
          _buildSummaryMetric('Oto. Doğrulama', 'Başarılı', Icons.verified_user, Colors.teal),
          _buildSummaryMetric('Güven Puanı', '92/100', Icons.health_and_safety, Colors.indigo),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildSystemCheckRow(String label, bool isSuccess, String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle : Icons.cancel, color: isSuccess ? Colors.green : Colors.red, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(message, style: TextStyle(color: isSuccess ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    final docs = [
      {'name': 'Vergi Levhası', 'status': 'Yüklendi', 'date': '14.02.2026', 'warning': null},
      {'name': 'İmza Sirküleri', 'status': 'Eksik', 'date': '-', 'warning': 'Zorunlu belge'},
      {'name': 'Ticaret Sicil Gazetesi', 'status': 'Yüklendi', 'date': '14.02.2026', 'warning': null},
      {'name': 'IBAN Belgesi', 'status': 'Hatalı', 'date': '15.02.2026', 'warning': 'Okunmuyor'},
      {'name': 'Kimlik (Yetkili)', 'status': 'Yüklendi', 'date': '14.02.2026', 'warning': null},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Yüklenen Belgeler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        ...docs.map((doc) => _buildDocumentRow(doc)).toList(),
      ],
    );
  }

  Widget _buildDocumentRow(Map<String, dynamic> doc) {
    Color statusColor;
    IconData statusIcon;
    
    if (doc['status'] == 'Yüklendi') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
    } else if (doc['status'] == 'Eksik') {
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.description, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Yüklenme: ${doc['date']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          if (doc['warning'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(doc['warning'], style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(doc['status'], style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          IconButton(onPressed: () {}, icon: const Icon(Icons.visibility, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildFinancialTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Finansal Güven', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildDetailRow('Hesap Türü', 'Kurumsal Şirket Hesabı'),
        _buildDetailRow('IBAN', 'TR12 0006 1000 0000 1234 5678 90'),
        _buildSystemCheckRow('IBAN Doğrulama', true, 'İsim Uyuşuyor'),
        const Divider(height: 32),
        const Text('Sistem Önerileri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildDetailRow('Ödeme Bloke Süresi', '14 Gün (Standart)'),
        _buildDetailRow('Komisyon Oranı', '%12 (Teknoloji)'),
        _buildDetailRow('Riskli Sektör', 'Hayır'),
      ],
    );
  }

  Widget _buildAuthorizedPersonTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Yetkili Kişi Bilgileri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildDetailRow('Ad Soyad', 'Ahmet Yılmaz'),
        _buildDetailRow('TC Kimlik No', '12*******90'),
        _buildSystemCheckRow('TC Doğrulama (NVİ)', true, 'Başarılı'),
        _buildSystemCheckRow('Telefon Onayı', true, 'SMS Doğrulandı'),
        _buildSystemCheckRow('E-posta Onayı', true, 'Link Doğrulandı'),
        _buildSystemCheckRow('Daha Önce Mağaza?', false, 'Hayır (İlk Başvuru)'),
      ],
    );
  }

  Widget _buildDetailMenuLink(String title, IconData icon, bool isActive, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive ? Border.all(color: Colors.grey.shade200) : null,
        boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)] : null,
      ),
      child: ListTile(
        leading: Icon(icon, size: 20, color: isActive ? AppColors.primary : Colors.grey.shade500),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? const Color(0xFF111827) : Colors.grey.shade600,
          ),
        ),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF111827), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocPreviewCard(String title, String filename) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 80,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(child: Icon(Icons.picture_as_pdf, color: Colors.red, size: 32)),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(filename, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 28),
              padding: EdgeInsets.zero,
            ),
            child: const Text('Görüntüle', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildStoresModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Mağaza Başvuruları',
          trailing: SizedBox(
            height: 32,
            child: OutlinedButton.icon(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.filter_list, size: 16),
              label: const Text(
                'Filtrele',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Mağaza adı, vergi no ile ara',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          child: const Text(
                            'Başvuru Formu Gör',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowHeight: 38,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 56,
                      columns: const [
                        DataColumn(label: Text('Mağaza', style: TextStyle(fontSize: 12))),
                        DataColumn(label: Text('Vergi No', style: TextStyle(fontSize: 12))),
                        DataColumn(label: Text('Belge Durumu', style: TextStyle(fontSize: 12))),
                        DataColumn(label: Text('Puan', style: TextStyle(fontSize: 12))),
                        DataColumn(label: Text('Komisyon', style: TextStyle(fontSize: 12))),
                        DataColumn(label: Text('İşlem', style: TextStyle(fontSize: 12))),
                      ],
                      rows: List.generate(6, (index) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.store_mall_directory_outlined,
                                        size: 16, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Teknosa Antakya', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            const DataCell(Text('1234567890', style: TextStyle(fontSize: 12))),
                            const DataCell(Text('Vergi levhası yüklü', style: TextStyle(fontSize: 12))),
                            const DataCell(Text('4.6', style: TextStyle(fontSize: 12))),
                            const DataCell(Text('%10', style: TextStyle(fontSize: 12))),
                            DataCell(
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () => _showStoreDetail(context, 'Teknosa Antakya'),
                                    child: const Text('Detay', style: TextStyle(fontSize: 11)),
                                  ),
                                  TextButton(
                                    onPressed: () {},
                                    child: const Text('Onayla', style: TextStyle(fontSize: 11)),
                                  ),
                                  TextButton(
                                    onPressed: () {},
                                    child: const Text(
                                      'Reddet',
                                      style: TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showProductApprovalDetail(BuildContext context, String productName, String sellerName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 900,
          height: 800,
          padding: const EdgeInsets.all(0),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, size: 32, color: AppColors.primary),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.store, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(sellerName, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.w600)),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Onay Bekliyor',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Images & Info
                    Expanded(
                      flex: 2,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ürün Görselleri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            Row(
                              children: List.generate(4, (index) => Container(
                                width: 100,
                                height: 100,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: const Icon(Icons.image, color: Colors.grey),
                              )),
                            ),
                            const SizedBox(height: 32),
                            const Text('Ürün Açıklaması', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: const Text(
                                'Bu ürün en son teknoloji ile üretilmiş olup, yüksek performans ve uzun pil ömrü sunar. 2 yıl garantilidir. Kutu içeriğinde şarj kablosu ve kullanım kılavuzu bulunmaktadır.',
                                style: TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF374151)),
                              ),
                            ),
                            const SizedBox(height: 32),
                            const Text('Özellikler', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildFeatureChip('Marka: Apple'),
                                _buildFeatureChip('Model: iPhone 15 Pro Max'),
                                _buildFeatureChip('Renk: Titanyum Mavi'),
                                _buildFeatureChip('Hafıza: 256 GB'),
                                _buildFeatureChip('Garanti: 24 Ay'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Right: Pricing & Variants & AI Check
                    Container(
                      width: 320,
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: Colors.grey.shade200)),
                        color: const Color(0xFFF9FAFB),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Fiyat & Stok', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildDetailRow('Satış Fiyatı', '₺84.999'),
                          _buildDetailRow('İndirimli Fiyat', '₺82.499'),
                          _buildDetailRow('Stok Adedi', '150'),
                          _buildDetailRow('KDV Oranı', '%20'),
                          
                          const Divider(height: 48),
                          
                          const Text('Yapay Zeka Kontrolü', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildAICheckItem('Görsel Kalitesi', true, 'Yüksek çözünürlük'),
                          _buildAICheckItem('Yasaklı Kelime', true, 'Tespit edilmedi'),
                          _buildAICheckItem('Fiyat Tutarlılığı', true, 'Piyasa ortalamasında'),
                          _buildAICheckItem('Kategori Eşleşmesi', true, 'Doğru kategori'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Footer Actions
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        _showQuickMessageSelector(
                          context,
                          'Reddetme Nedeni Seç',
                          [
                            'Görsel kalitesi yetersiz.',
                            'Ürün açıklaması eksik veya hatalı.',
                            'Yasaklı ürün kategorisinde.',
                            'Fiyat bilgisi hatalı görünüyor.',
                          ],
                          (message) {
                            // Logic to reject
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ürün reddedildi: $message')));
                          },
                        );
                      },
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reddet'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ürün onaylandı ve yayına alındı.')));
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Onayla ve Yayınla'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
    );
  }

  Widget _buildAICheckItem(String label, bool isSuccess, String subLabel) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.warning,
            size: 18,
            color: isSuccess ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(subLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Ürün Onay Kuyruğu',
          trailing: Row(
            children: [
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('Toplu Onay', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('Yasaklı Ürünler', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Ürün, mağaza veya kategori ile ara',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButtonHideUnderline(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButton<String>(
                            value: 'Hepsi',
                            items: const [
                              DropdownMenuItem(value: 'Hepsi', child: Text('Tüm kategoriler')),
                              DropdownMenuItem(value: 'Teknoloji', child: Text('Teknoloji')),
                              DropdownMenuItem(value: 'Giyim', child: Text('Giyim')),
                            ],
                            onChanged: (_) {},
                            icon: const Icon(Icons.expand_more, size: 18),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: DataTable(
                      showCheckboxColumn: true,
                      headingRowHeight: 38,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 56,
                      columns: const [
                        DataColumn(label: Text('Ürün', style: TextStyle(fontSize: 12))),
                        DataColumn(label: Text('Mağaza', style: TextStyle(fontSize: 12))),
                        DataColumn(label: Text('Kategori', style: TextStyle(fontSize: 12))),
                        DataColumn(label: Text('Varyant', style: TextStyle(fontSize: 12))),
                        DataColumn(label: Text('Durum', style: TextStyle(fontSize: 12))),
                        DataColumn(label: Text('İşlem', style: TextStyle(fontSize: 12))),
                      ],
                      rows: List.generate(8, (index) {
                        return DataRow(
                          selected: index == 0,
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.image_outlined,
                                        size: 18, color: Color(0xFF9CA3AF)),
                                  ),
                                  const SizedBox(width: 8),
                                  const Flexible(
                                    child: Text(
                                      'iPhone 15 Pro Max 256GB',
                                      style: TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const DataCell(Text('Teknosa Antakya', style: TextStyle(fontSize: 12))),
                            const DataCell(Text('Teknoloji > Telefon', style: TextStyle(fontSize: 12))),
                            const DataCell(Text('Renk: Mavi, Hafıza: 256GB', style: TextStyle(fontSize: 12))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEEFEC),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Onay Bekliyor',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFEA580C),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: () {},
                                    child: const Text('Yayınla', style: TextStyle(fontSize: 11)),
                                  ),
                                  TextButton(
                                    onPressed: () => _showProductApprovalDetail(context, 'iPhone 15 Pro Max 256GB', 'Teknosa Antakya'),
                                    child: const Text(
                                      'İncele',
                                      style: TextStyle(fontSize: 11, color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Seller Health Score System
  Map<String, dynamic> _calculateSellerHealth(String sellerName) {
    // Mock logic based on user request
    // In real app, this would come from backend
    double returnRate = 2.5;
    int complaints = 4;
    double shippingDelay = 1.2; // days
    int damagedReports = 1;

    // Simulate different profiles
    if (sellerName.contains('Teknosa')) {
      returnRate = 1.2; complaints = 2; shippingDelay = 0.5; damagedReports = 0;
    } else if (sellerName.contains('Arçelik')) {
      returnRate = 4.5; complaints = 8; shippingDelay = 2.4; damagedReports = 3;
    } else if (sellerName.contains('LC')) {
      returnRate = 8.2; complaints = 15; shippingDelay = 4.5; damagedReports = 6;
    }

    // Algorithm
    // Base Score: 100
    // - Return Rate * 4
    // - Complaints * 2
    // - Delay * 5
    // - Damaged * 8
    double score = 100.0;
    score -= (returnRate * 4);
    score -= (complaints * 2);
    score -= (shippingDelay * 5);
    score -= (damagedReports * 8);
    
    // Clamp
    score = score.clamp(0.0, 100.0);

    // Color Logic
    Color color;
    String status;
    IconData icon;
    
    if (score >= 80) { // Green (High Health)
       color = const Color(0xFF22C55E); 
       status = 'Mükemmel';
       icon = Icons.verified;
    } else if (score >= 50) { // Yellow (Warning)
       color = const Color(0xFFEAB308);
       status = 'Dikkat';
       icon = Icons.warning_amber;
    } else { // Red (Risky)
       color = const Color(0xFFEF4444);
       status = 'Riskli';
       icon = Icons.report_problem;
    }

    return {
      'score': score.toInt(),
      'returnRate': returnRate,
      'complaints': complaints,
      'delay': shippingDelay,
      'damaged': damagedReports,
      'color': color,
      'status': status,
      'icon': icon,
    };
  }

  void _showQuickMessageSelector(BuildContext context, String title, List<String> messages, Function(String) onSelected) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 16),
              ...messages.map((message) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context); // Close dialog
                    onSelected(message);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF374151),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              )),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('İptal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSellerProfile(BuildContext context, String sellerName) {
    final health = _calculateSellerHealth(sellerName);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 800,
          height: 700,
          padding: const EdgeInsets.all(24),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Icon(Icons.store, size: 32, color: AppColors.primary),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sellerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (health['color'] as Color).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(health['icon'] as IconData, size: 14, color: health['color'] as Color),
                                        const SizedBox(width: 4),
                                        Text(
                                          health['status'] as String, 
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: health['color'] as Color)
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text('ID: #SL-84923', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        margin: const EdgeInsets.only(right: 40), // Space for close button
                        decoration: BoxDecoration(
                          color: (health['color'] as Color).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: (health['color'] as Color).withOpacity(0.2)),
                        ),
                        child: Column(
                          children: [
                            Text('Sağlık Skoru', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            Text(
                              '${health['score']}', 
                              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: health['color'] as Color, height: 1.0)
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Key Metrics
                  Row(
                    children: [
                      Expanded(child: _buildNewKPICard('Ort. Puan', '4.7', Icons.star, Colors.orange, '')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNewKPICard('Kargo Süresi', '${health['delay']} gün', Icons.local_shipping, Colors.blue, '')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNewKPICard('İade Oranı', '%${health['returnRate']}', Icons.assignment_return, Colors.purple, '')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildNewKPICard('Şikayet', '${health['complaints']}', Icons.warning_amber, Colors.red, '')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  if ((health['returnRate'] as double) > 5)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.trending_up, color: Colors.red),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'DİKKAT: Son 7 günde iadeler %42 arttı. Acil inceleme gerekiyor.',
                              style: TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                            ),
                          ),
                          TextButton(
                            onPressed: () {}, 
                            child: const Text('Raporu Gör', style: TextStyle(color: Colors.red))
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Product Quality & Charts
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Ürün Kalitesi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        _showQuickMessageSelector(
                                          context,
                                          'Müşteri Bilgilendirme Mesajı Seç',
                                          [
                                            'Şikayetiniz Doğrultusunda Satıcıya Gerekli İşlemleri Yaptık İadeniz Yapıldı',
                                            'Paranızı 5 İş Günü İçinde İade Edilecektir',
                                            'İyi Günler Dileriz, Şikayetiniz Doğrultusunda Satıcıya Gerekli İşlemler Başlatıldı',
                                          ],
                                          (message) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ChatPage(
                                                  seller: {'name': 'Baran K.', 'image': 'assets/images/user_avatar.png'},
                                                  product: {'name': 'Dyson V15 Detect', 'price': '₺22.999'},
                                                  isSellerChat: false,
                                                  initialMessage: message,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      icon: const Icon(Icons.person_search, size: 16),
                                      label: const Text('Müşteriye Ulaş', style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildProductListRow('Dyson V15 (Hasarlı)', '12 İade', 'Kutu hasarlı gönderim'),
                                _buildProductListRow('iPhone 15 Kılıf', '8 İade', 'Yanlış renk'),
                                const SizedBox(height: 24),
                                const Text('Medya Kanıtları', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 12),
                                Row(
                                  children: List.generate(4, (index) => Container(
                                    width: 80, height: 80,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.image, color: Colors.grey),
                                  )),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        // Right: Actions & History
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Müdahale & Geçmiş', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                _buildActionRow(
                                  'Uyarı Gönder', 
                                  Icons.warning_amber, 
                                  Colors.orange,
                                  onTap: () {
                                    _showQuickMessageSelector(
                                      context,
                                      'Uyarı Mesajını Seç',
                                      [
                                        'Hatalı Ürün Gönderdiğiniz İçin -10 Puan aldınız',
                                        'Yanlış Ürün Gönderdiğiniz İçin -10 puan aldınız',
                                      ],
                                      (message) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatPage(
                                              seller: {'name': sellerName, 'image': 'assets/store_logo.png'},
                                              product: {'name': 'Sistem Uyarısı', 'price': ''},
                                              isSellerChat: true,
                                              initialMessage: message,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                _buildActionRow(
                                  'Satışı Durdur', 
                                  Icons.block, 
                                  Colors.red,
                                  onTap: () {
                                    _showQuickMessageSelector(
                                      context,
                                      'Satış Durdurma Nedeni Seç',
                                      [
                                        'Çok Fazla Hatalı Ürün Gönderdiğiniz İçin Geçeçi Olarak Satışınızı Durdurduk',
                                        'Küfür Ve Hakaretten Dolayı Satışınızı Durdurduk',
                                      ],
                                      (message) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatPage(
                                              seller: {'name': sellerName, 'image': 'assets/store_logo.png'},
                                              product: {'name': 'Hesap Durumu', 'price': ''},
                                              isSellerChat: true,
                                              initialMessage: message,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                                _buildActionRow('Komisyon Artır', Icons.trending_up, Colors.blue),
                                _buildActionRow('İletişime Geç', Icons.phone, Colors.green),
                                const Divider(height: 32),
                                const Text('Ceza Geçmişi', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 8),
                                _buildHistoryItem('12 Şub - Uyarı (Kargo Gecikmesi)'),
                                _buildHistoryItem('05 Oca - Komisyon +%2 (İade)'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                  splashRadius: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow(String label, IconData icon, Color color, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.history, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
        ],
      ),
    );
  }

  Widget _buildOrdersModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Sipariş & İade Yönetimi',
          trailing: Row(
            children: [
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButton<String>(
                    value: 'Tümü',
                    items: const [
                      DropdownMenuItem(value: 'Tümü', child: Text('Tüm durumlar')),
                      DropdownMenuItem(value: 'Yeni', child: Text('Yeni')),
                      DropdownMenuItem(value: 'Kargoda', child: Text('Kargoda')),
                      DropdownMenuItem(value: 'İade', child: Text('İade')),
                    ],
                    onChanged: (_) {},
                    icon: const Icon(Icons.expand_more, size: 18),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: const Text('Arabulucluk Ekranı', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                onChanged: (value) {
                                  setState(() {
                                    _orderSearchQuery = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Sipariş no, müşteri veya mağaza ile ara',
                                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 38,
                              dataRowMinHeight: 40,
                              dataRowMaxHeight: 56,
                              columns: const [
                                DataColumn(label: Text('Sipariş No', style: TextStyle(fontSize: 12))),
                                DataColumn(label: Text('Müşteri', style: TextStyle(fontSize: 12))),
                                DataColumn(label: Text('Mağaza', style: TextStyle(fontSize: 12))),
                                DataColumn(label: Text('Kargo', style: TextStyle(fontSize: 12))),
                                DataColumn(label: Text('Tutar', style: TextStyle(fontSize: 12))),
                                DataColumn(label: Text('Durum', style: TextStyle(fontSize: 12))),
                                DataColumn(label: Text('Risk', style: TextStyle(fontSize: 12))),
                              ],
                              rows: List.generate(10, (index) {
                                final orderNo = '#IBL2026$index';
                                final customerName = 'Baran K.';
                                final sellerName = index % 2 == 0 ? 'Teknosa Antakya' : 'Arçelik Mağazası';
                                
                                // Filter Logic
                                if (_orderSearchQuery.isNotEmpty) {
                                  final query = _orderSearchQuery.toLowerCase();
                                  if (!orderNo.toLowerCase().contains(query) &&
                                      !customerName.toLowerCase().contains(query) &&
                                      !sellerName.toLowerCase().contains(query)) {
                                    return null; // Skip this row
                                  }
                                }

                                final statusLabel = index % 4 == 0
                                    ? 'Yeni'
                                    : index % 4 == 1
                                        ? 'Kargoda'
                                        : index % 4 == 2
                                            ? 'Tamamlandı'
                                            : 'İade';
                                final statusColor = index % 4 == 0
                                    ? const Color(0xFF2563EB)
                                    : index % 4 == 1
                                        ? const Color(0xFFF97316)
                                        : index % 4 == 2
                                            ? const Color(0xFF16A34A)
                                            : const Color(0xFFDC2626);
                                
                                final health = _calculateSellerHealth(sellerName);
                                final riskLabel = health['status'] as String;
                                final riskColor = health['color'] as Color;

                                return DataRow(
                                  cells: [
                                    DataCell(Text(orderNo,
                                        style: const TextStyle(fontSize: 12))),
                                    DataCell(Text(customerName, style: const TextStyle(fontSize: 12))),
                                    DataCell(
                                      InkWell(
                                        onTap: () => _showSellerProfile(context, sellerName),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(sellerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, decoration: TextDecoration.underline)),
                                            const SizedBox(width: 4),
                                            Container(
                                              width: 8, height: 8,
                                              decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(index % 2 == 0 ? 'Yurtiçi' : 'Aras', style: const TextStyle(fontSize: 12))),
                                    const DataCell(Text('₺8.450', style: TextStyle(fontSize: 12))),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          statusLabel,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: riskColor.withOpacity(0.3)),
                                          borderRadius: BorderRadius.circular(4),
                                          color: riskColor.withOpacity(0.05),
                                        ),
                                        child: Text(
                                          riskLabel,
                                          style: TextStyle(fontSize: 10, color: riskColor, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).where((element) => element != null).cast<DataRow>().toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'İade Talepleri',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: 5,
                          separatorBuilder: (context, index) => Divider(
                            height: 16,
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (context, index) {
                            // Mock data consistent with left table
                            final sellerName = index % 2 == 0 ? 'Teknosa Antakya' : 'Arçelik Mağazası';
                            final productName = index % 2 == 0 ? 'iPhone 15 Pro Max' : 'Dyson V15 Detect';
                            final orderId = '#IBL2026${3 + index * 4}';

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.refresh_outlined,
                                    size: 18,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'İade talebi: $productName',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Mağaza: $sellerName • Sipariş: $orderId\nNeden: Ürün hasarlı geldi. Arabuluculuk bekleniyor.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: const Text(
                                              'Arabulucluk Açık',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF92400E),
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          TextButton(
                                            onPressed: () => _showSellerProfile(context, sellerName),
                                            child: const Text(
                                              'İncele',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinanceModule() {
    final payouts = [
      {
        'id': '#P-4821',
        'store': 'Teknosa Antakya',
        'period': '01-15 Şubat',
        'amount': '₺42.800',
        'status': 'Tamamlandı',
        'method': 'Havale',
      },
      {
        'id': '#P-4822',
        'store': 'LC Waikiki Eskişehir',
        'period': '01-15 Şubat',
        'amount': '₺21.450',
        'status': 'İşleniyor',
        'method': 'EFT',
      },
      {
        'id': '#P-4823',
        'store': 'Arçelik Mağazası',
        'period': '16-31 Ocak',
        'amount': '₺58.320',
        'status': 'Tamamlandı',
        'method': 'Havale',
      },
      {
        'id': '#P-4824',
        'store': 'Mahalle Marketi',
        'period': '16-31 Ocak',
        'amount': '₺8.940',
        'status': 'Beklemede',
        'method': 'EFT',
      },
    ];

    final sellerEarnings = [
      {
        'name': 'Teknosa Antakya',
        'percent': '28%',
        'earnings': '₺124.500',
        'color': const Color(0xFF6366F1),
      },
      {
        'name': 'LC Waikiki Eskişehir',
        'percent': '24%',
        'earnings': '₺98.200',
        'color': const Color(0xFF10B981),
      },
      {
        'name': 'Arçelik Mağazası',
        'percent': '20%',
        'earnings': '₺86.740',
        'color': const Color(0xFFF97316),
      },
      {
        'name': 'Mahalle Marketi',
        'percent': '15%',
        'earnings': '₺54.320',
        'color': const Color(0xFF0EA5E9),
      },
      {
        'name': 'Diğer Mağazalar',
        'percent': '13%',
        'earnings': '₺47.110',
        'color': const Color(0xFF6B7280),
      },
    ];

    final months = ['O', 'Ş', 'M', 'N', 'M', 'H'];
    final totalSales = [62.0, 80.0, 75.0, 92.0, 88.0, 95.0];
    final totalCommission = [24.0, 30.0, 28.0, 35.0, 32.0, 38.0];

    const successRate = 0.725;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Finans & Hakediş',
          trailing: SizedBox(
            height: 32,
            child: OutlinedButton.icon(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
              ),
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Rapor Dışa Aktar', style: TextStyle(fontSize: 12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: 'Toplam Satış Tutarı',
                value: '₺2.384.920',
                icon: Icons.attach_money_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                label: 'Toplam Komisyon Geliri',
                value: '₺184.320',
                icon: Icons.trending_up_outlined,
                color: const Color(0xFF22C55E),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                label: 'Ödenen Hakediş',
                value: '₺1.926.700',
                icon: Icons.payments_outlined,
                color: const Color(0xFF0EA5E9),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                label: 'Bekleyen Hakediş',
                value: '₺124.300',
                icon: Icons.schedule_outlined,
                color: const Color(0xFFF97316),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Hakediş ve Komisyon Dağılımı'),
                      const SizedBox(height: 4),
                      Text(
                        'Son 6 ayda satıcı hakedişleri ve komisyon gelirinin birlikte görünümü.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 190,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(months.length, (index) {
                            final totalHeight = totalSales[index];
                            final commissionHeight = totalCommission[index];
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: Container(
                                            height: totalHeight,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(0xFF22C55E).withOpacity(0.2),
                                                  const Color(0xFF22C55E),
                                                ],
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Container(
                                            height: commissionHeight,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(6),
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(0xFF6366F1).withOpacity(0.2),
                                                  const Color(0xFF6366F1),
                                                ],
                                                begin: Alignment.bottomCenter,
                                                end: Alignment.topCenter,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      months[index],
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Ödenen Hakediş',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Komisyon',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Ödeme Başarı Oranı'),
                      const SizedBox(height: 8),
                      Text(
                        'Son 30 günde zamanında tamamlanan satıcı ödemeleri.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 120,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 120,
                                height: 120,
                                child: CircularProgressIndicator(
                                  value: successRate,
                                  strokeWidth: 10,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF22C55E),
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${(successRate * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Zamanında Ödeme',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Tamamlanan Ödeme',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '₺86.500',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Bekleyen Ödeme',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFF97316),
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '₺18.240',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Row(
                          children: [
                            const Text(
                              'Hakediş Hareketleri',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Son 30 gün',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowHeight: 38,
                            dataRowMinHeight: 44,
                            dataRowMaxHeight: 56,
                            columns: const [
                              DataColumn(
                                  label: Text('Ödeme ID', style: TextStyle(fontSize: 12))),
                              DataColumn(
                                  label: Text('Mağaza', style: TextStyle(fontSize: 12))),
                              DataColumn(
                                  label: Text('Dönem', style: TextStyle(fontSize: 12))),
                              DataColumn(
                                  label: Text('Tutar', style: TextStyle(fontSize: 12))),
                              DataColumn(
                                  label: Text('Durum', style: TextStyle(fontSize: 12))),
                            ],
                            rows: payouts.map((payout) {
                              final status = payout['status'] as String;
                              Color statusColor;
                              Color backgroundColor;
                              switch (status) {
                                case 'Tamamlandı':
                                  statusColor = const Color(0xFF16A34A);
                                  backgroundColor = const Color(0xFFF0FDF4);
                                  break;
                                case 'İşleniyor':
                                  statusColor = const Color(0xFF2563EB);
                                  backgroundColor = const Color(0xFFE0F2FE);
                                  break;
                                default:
                                  statusColor = const Color(0xFFF97316);
                                  backgroundColor = const Color(0xFFFFFBEB);
                              }
                              return DataRow(
                                cells: [
                                  DataCell(Text(
                                    payout['id'] as String,
                                    style: const TextStyle(fontSize: 12),
                                  )),
                                  DataCell(Text(
                                    payout['store'] as String,
                                    style: const TextStyle(fontSize: 12),
                                  )),
                                  DataCell(Text(
                                    payout['period'] as String,
                                    style: const TextStyle(fontSize: 12),
                                  )),
                                  DataCell(Text(
                                    payout['amount'] as String,
                                    style: const TextStyle(fontSize: 12),
                                  )),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: backgroundColor,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Satıcı Bazlı Gelir'),
                      const SizedBox(height: 4),
                      Text(
                        'Komisyon gelirinin satıcılara göre dağılımı.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: sellerEarnings.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 16,
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (context, index) {
                            final item = sellerEarnings[index];
                            final color = item['color'] as Color;
                            return Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.storefront_outlined,
                                    size: 18,
                                    color: color,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] as String,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Komisyon payı',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      item['percent'] as String,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['earnings'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCampaignsModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Kampanya & İçerik Yönetimi',
          trailing: SizedBox(
            height: 32,
            child: ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Kampanya Oluştur', style: TextStyle(fontSize: 12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ana Sayfa Bannerları',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: 4,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return Container(
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: const BorderRadius.horizontal(
                                        left: Radius.circular(10),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.image_outlined,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Teknoloji Haftası',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Seçili ürünlerde %20 indirim',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF6B7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Switch(
                                    value: index != 3,
                                    onChanged: (_) {},
                                  ),
                                  const SizedBox(width: 12),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kupon Kodları',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: 5,
                          separatorBuilder: (context, index) => Divider(
                            height: 16,
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (context, index) {
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'IBUL${10 + 5}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '500 TL üzeri alışverişte 50 TL indirim',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Aktif',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupportModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Destek & Şikayet',
          trailing: SizedBox(
            height: 32,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Text('Ticket Oluştur', style: TextStyle(fontSize: 12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Ticket no, sipariş no veya müşteri ile ara',
                                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                  prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowHeight: 38,
                            dataRowMinHeight: 40,
                            dataRowMaxHeight: 56,
                            columns: const [
                              DataColumn(label: Text('Ticket', style: TextStyle(fontSize: 12))),
                              DataColumn(label: Text('Sipariş', style: TextStyle(fontSize: 12))),
                              DataColumn(label: Text('Konu', style: TextStyle(fontSize: 12))),
                              DataColumn(label: Text('Durum', style: TextStyle(fontSize: 12))),
                              DataColumn(label: Text('İşlem', style: TextStyle(fontSize: 12))),
                            ],
                            rows: List.generate(8, (index) {
                              final statusLabel = index % 3 == 0
                                  ? 'Açık'
                                  : index % 3 == 1
                                      ? 'İşlemde'
                                      : 'Kapandı';
                              final statusColor = index % 3 == 0
                                  ? const Color(0xFFDC2626)
                                  : index % 3 == 1
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF16A34A);
                              return DataRow(
                                cells: [
                                  DataCell(Text('#TCK$index',
                                      style: const TextStyle(fontSize: 12))),
                                  const DataCell(Text('#IBL202612',
                                      style: TextStyle(fontSize: 12))),
                                  const DataCell(
                                      Text('Hasarlı ürün', style: TextStyle(fontSize: 12))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    TextButton(
                                      onPressed: () {},
                                      child: const Text(
                                        'Detay',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ceza Puanları',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.separated(
                          itemCount: 5,
                          separatorBuilder: (context, index) => Divider(
                            height: 16,
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (context, index) {
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Mağaza: Teknosa Antakya',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Neden: Geç kargo, yüksek şikayet oranı',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Ceza: 35',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFB91C1C),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsModule() {
    final permissions = ['Görüntüleme', 'Düzenleme', 'Silme', 'Onaylama'];
    final roles = AdminRole.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Rol Bazlı Yetki Sistemi',
          trailing: SizedBox(
            height: 32,
            child: ElevatedButton.icon(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Değişiklikleri Kaydet', style: TextStyle(fontSize: 12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modül bazlı rol yetkilerini checkbox mantığında yönet.',
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.4),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 38,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 60,
                      columns: [
                        const DataColumn(
                          label: Text('Modül', style: TextStyle(fontSize: 12)),
                        ),
                        ...roles.map(
                          (role) => DataColumn(
                            label: Text(
                              _roleLabel(role),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                      rows: AdminModule.values.map((module) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _moduleLabel(module),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Yetkiler: ${permissions.join(', ')}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...roles.map(
                              (role) => DataCell(
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: permissions.map((perm) {
                                    final enabled =
                                        role == AdminRole.superAdmin || perm == 'Görüntüleme';
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: Checkbox(
                                          value: enabled,
                                          onChanged: (_) {},
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogsModule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Log & Güvenlik',
          trailing: SizedBox(
            height: 32,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Text('Dışa Aktar', style: TextStyle(fontSize: 12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Modül, kullanıcı veya işlem ile ara',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: 12,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.grey.shade200,
                    ),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Icon(
                                Icons.history_outlined,
                                size: 18,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Finance Manager, X mağazasının komisyonunu %10’dan %12’ye çıkardı.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Modül: Finans & Hakediş • Kullanıcı: finance.manager@ibul.com',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tarih: 16.02.2026 14:32',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DualLineChartPainter extends CustomPainter {
  final List<double> series1;
  final List<double> series2;
  final Color color1;
  final Color color2;

  _DualLineChartPainter({
    required this.series1,
    required this.series2,
    required this.color1,
    required this.color2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series1.isEmpty || series2.isEmpty) {
      return;
    }

    final maxLength = math.max(series1.length, series2.length);
    if (maxLength < 2) {
      return;
    }

    final allValues = <double>[];
    allValues.addAll(series1);
    allValues.addAll(series2);
    double maxValue = allValues.reduce(math.max);
    if (maxValue == 0) {
      maxValue = 1;
    }

    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1;

    for (var i = 0; i <= 3; i++) {
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }

    List<Offset> buildPoints(List<double> series) {
      final points = <Offset>[];
      final stepX =
          maxLength == 1 ? size.width : size.width / (maxLength - 1);
      for (var i = 0; i < series.length; i++) {
        final value = series[i];
        final x = stepX * i;
        final y = size.height - (value / maxValue) * size.height;
        points.add(Offset(x, y));
      }
      return points;
    }

    final points1 = buildPoints(series1);
    final points2 = buildPoints(series2);

    void drawSeries(List<Offset> points, Color color) {
      if (points.length < 2) {
        return;
      }
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = ui.Path()..moveTo(points.first.dx, points.first.dy);
      for (var i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, linePaint);

      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      for (final point in points) {
        canvas.drawCircle(point, 3, dotPaint);
      }
    }

    drawSeries(points1, color1);
    drawSeries(points2, color2);
  }

  @override
  bool shouldRepaint(covariant _DualLineChartPainter oldDelegate) {
    return oldDelegate.series1 != series1 ||
        oldDelegate.series2 != series2 ||
        oldDelegate.color1 != color1 ||
        oldDelegate.color2 != color2;
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  _DonutChartPainter({
    required this.values,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }

    final total = values.fold<double>(0, (sum, v) => sum + v);
    if (total == 0) {
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final innerRadius = radius * 0.6;
    final strokeWidth = radius - innerRadius;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final gapAngle = math.pi / 90;
    var startAngle = -math.pi / 2;

    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * (2 * math.pi - gapAngle * values.length);
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}
