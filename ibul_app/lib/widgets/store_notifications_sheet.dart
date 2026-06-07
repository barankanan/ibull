import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/store_user_notification.dart';
import '../services/store_follow_service.dart';
import '../models/product_model.dart';
import '../screens/product_detail_page.dart';
import '../services/supabase_service.dart';

class StoreNotificationsSheet extends StatefulWidget {
  const StoreNotificationsSheet({
    super.key,
    required this.storeId,
    required this.storeName,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
    this.business,
  });

  final String storeId;
  final String storeName;
  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsChanged;
  final Map<String, dynamic>? business;

  @override
  State<StoreNotificationsSheet> createState() =>
      _StoreNotificationsSheetState();
}

class _StoreNotificationsSheetState extends State<StoreNotificationsSheet> {
  final StoreFollowService _service = StoreFollowService.instance;
  bool _notificationsEnabled = false;
  bool _toggleLoading = false;
  bool _listLoading = true;
  List<StoreUserNotification> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.notificationsEnabled;
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _listLoading = true);
    final rows = await _service.fetchStoreNotifications(widget.storeId);
    if (!mounted) return;
    setState(() {
      _notifications = rows;
      _listLoading = false;
    });
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() => _toggleLoading = true);
    try {
      final result = await _service.toggleStoreNotifications(
        widget.storeId,
        enabled: enabled,
      );
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = result;
        _toggleLoading = false;
      });
      widget.onNotificationsChanged(result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _toggleLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(StoreFollowService.userFriendlyError(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openNotification(StoreUserNotification notification) async {
    await _service.markNotificationAsRead(notification.id);
    if (!mounted) return;

    setState(() {
      _notifications = _notifications
          .map(
            (item) => item.id == notification.id
                ? StoreUserNotification(
                    id: item.id,
                    title: item.title,
                    body: item.body,
                    type: item.type,
                    createdAt: item.createdAt,
                    storeId: item.storeId,
                    productId: item.productId,
                    isRead: true,
                    data: item.data,
                  )
                : item,
          )
          .toList(growable: false);
    });

    final productId =
        notification.productId ?? notification.data['product_id']?.toString();
    if (productId != null && productId.isNotEmpty) {
      final rows = await SupabaseService.instance.getProductsByIds([productId]);
      if (!mounted) return;
      if (rows.isNotEmpty) {
        final product = Product.fromDBProduct(rows.first);
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.storeName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          unreadCount > 0
                              ? '$unreadCount okunmamış bildirim'
                              : 'Mağaza bildirimleri',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_toggleLoading)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Switch(
                      value: _notificationsEnabled,
                      activeThumbColor: AppColors.primary,
                      onChanged: _toggleNotifications,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            if (_listLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )
            else if (_notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Bu mağazadan henüz bildirim yok.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _notifications[index];
                    return Material(
                      color: item.isRead
                          ? Colors.grey.shade50
                          : const Color(0xFFF4F0FF),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openNotification(item),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _iconForType(item.type),
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: TextStyle(
                                              fontWeight: item.isRead
                                                  ? FontWeight.w600
                                                  : FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        if (!item.isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.body,
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.iconLabel,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11,
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
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'new_product':
        return Icons.shopping_bag_outlined;
      case 'product_discount':
        return Icons.local_offer_outlined;
      case 'store_announcement':
        return Icons.campaign_outlined;
      case 'popular_product_update':
        return Icons.trending_up;
      default:
        return Icons.notifications_outlined;
    }
  }
}
