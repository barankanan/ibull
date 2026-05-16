class StoreUserNotification {
  const StoreUserNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.storeId,
    this.productId,
    this.isRead = false,
    this.data = const {},
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final String? storeId;
  final String? productId;
  final bool isRead;
  final Map<String, dynamic> data;

  factory StoreUserNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return StoreUserNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ??
          (rawData is Map ? rawData['type']?.toString() : null) ??
          '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      storeId: json['store_id']?.toString(),
      productId: json['product_id']?.toString(),
      isRead: json['is_read'] == true,
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : const <String, dynamic>{},
    );
  }

  String get iconLabel {
    switch (type) {
      case 'new_product':
        return 'Yeni ürün';
      case 'product_discount':
        return 'İndirim';
      case 'store_announcement':
        return 'Duyuru';
      case 'popular_product_update':
        return 'Popüler';
      default:
        return 'Bildirim';
    }
  }
}
