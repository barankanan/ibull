import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/app_state.dart';
import '../../../core/auth/user_identity.dart';
import '../../../core/constants.dart';
import '../../../widgets/account_sidebar.dart';
import '../../../widgets/web_header.dart';
import '../../../widgets/web_sticky_footer_scroll_view.dart';
import '../helpers/order_history_navigation.dart';
import '../models/order_history_models.dart';
import '../services/order_history_service.dart';
import '../widgets/order_history_filter_bar.dart';
import '../widgets/order_history_order_card.dart';
import '../widgets/order_history_states.dart';
import 'past_order_detail_page.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final _service = OrderHistoryService.instance;

  bool _loading = true;
  bool _error = false;
  List<Map<String, dynamic>> _orders = const [];
  OrderHistoryFilter _filter = const OrderHistoryFilter();

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final appState = context.read<AppState>();
    final userId = appState.currentUser?['uid']?.toString();
    final isGuest = UserIdentity.isGuest(appState.currentUser);
    if (userId == null || userId.isEmpty || isGuest) {
      setState(() {
        _loading = false;
        _orders = const [];
        _error = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final orders = await _service.getMyPastOrders(userId);
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredOrders =>
      _service.filterPastOrders(orders: _orders, filter: _filter);

  void _openDetail(Map<String, dynamic> order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PastOrderDetailPage(order: order),
      ),
    );
  }

  void _openProduct(Map<String, dynamic> order) {
    final items =
        (order['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ürün şu anda görüntülenemiyor.')),
      );
      return;
    }
    OrderHistoryNavigation.openProductForReorder(context, items.first);
  }

  void _goShop() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.sizeOf(context).width >= 800;
    if (isWeb) return _buildWeb();
    return _buildMobile();
  }

  Widget _buildMobile() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FA),
      appBar: AppBar(
        title: const Text('Eski Siparişlerim'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrders,
        child: _buildBody(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24)),
      ),
    );
  }

  Widget _buildWeb() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4FA),
      body: Column(
        children: [
          WebHeader(onSearch: (_) {}, activeMenu: 'account'),
          Expanded(
            child: WebStickyFooterScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 280,
                          child: AccountSidebar(activePage: 'Siparişlerim'),
                        ),
                        const SizedBox(width: 32),
                        Expanded(child: _buildBody(padding: EdgeInsets.zero)),
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

  Widget _buildBody({required EdgeInsets padding}) {
    return ListView(
      padding: padding,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          'Daha önce aldıklarını burada görebilir, tekrar sipariş verebilirsin.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 14),
        OrderHistoryFilterBar(
          filter: _filter,
          years: _availableYears(),
          onChanged: (value) => setState(() => _filter = value),
          onClear: () => setState(() => _filter = const OrderHistoryFilter()),
        ),
        const SizedBox(height: 14),
        if (_loading)
          const OrderHistoryLoadingList()
        else if (_error)
          OrderHistoryErrorState(onRetry: _loadOrders)
        else if (_filteredOrders.isEmpty)
          OrderHistoryEmptyState(onShop: _goShop)
        else
          ..._filteredOrders.map((order) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OrderHistoryOrderCard(
                order: order,
                onTap: () => _openDetail(order),
                onOpenProduct: () => _openProduct(order),
              ),
            );
          }),
        const SizedBox(height: 10),
        const SmartReorderFooter(),
        const SizedBox(height: 6),
      ],
    );
  }

  List<int> _availableYears() {
    final years = <int>{DateTime.now().year};
    for (final order in _orders) {
      final createdAt = DateTime.tryParse(order['created_at']?.toString() ?? '');
      if (createdAt != null) years.add(createdAt.year);
    }
    return years.toList()..sort((a, b) => b.compareTo(a));
  }
}
