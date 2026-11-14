import 'package:supabase_flutter/supabase_flutter.dart';

class StoreCustomer {
  const StoreCustomer({
    required this.id,
    required this.name,
    required this.phone,
  });

  final String id;
  final String name;
  final String phone;

  factory StoreCustomer.fromMap(Map<String, dynamic> map) {
    return StoreCustomer(
      id: map['id']?.toString() ?? '',
      name: map['display_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
    );
  }
}

class StoreCustomerDirectoryException implements Exception {
  const StoreCustomerDirectoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class StoreCustomerDirectory {
  StoreCustomerDirectory({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<StoreCustomer>> search({
    required String storeId,
    required String query,
  }) async {
    final trimmed = query.trim();
    try {
      var request = _client
          .from('store_customers')
          .select('id, display_name, phone')
          .eq('store_id', storeId);
      if (trimmed.isNotEmpty) {
        final escaped = trimmed.replaceAll(',', ' ');
        request = request.or(
          'display_name.ilike.%$escaped%,phone.ilike.%$escaped%',
        );
      }
      final rows = await request.order('display_name').limit(30);
      return (rows as List)
          .map(
            (row) => StoreCustomer.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .where((customer) => customer.id.isNotEmpty)
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw StoreCustomerDirectoryException(_customerDirectoryError(error));
    }
  }

  Future<StoreCustomer?> selectionForTable({
    required String storeId,
    required int tableNumber,
  }) async {
    try {
      final row = await _client
          .from('store_table_customer_selections')
          .select('customer_id, store_customers(id, display_name, phone)')
          .eq('store_id', storeId)
          .eq('table_number', tableNumber)
          .maybeSingle();
      if (row == null) return null;
      final nested = row['store_customers'];
      if (nested is Map) {
        return StoreCustomer.fromMap(Map<String, dynamic>.from(nested));
      }
      return null;
    } on PostgrestException catch (error) {
      throw StoreCustomerDirectoryException(_customerDirectoryError(error));
    }
  }

  Future<StoreCustomer> create({
    required String storeId,
    required String name,
    String? phone,
  }) async {
    final displayName = name.trim();
    final normalizedPhone = phone?.trim() ?? '';
    if (displayName.isEmpty || displayName.length > 80) {
      throw const StoreCustomerDirectoryException('Müşteri adı gerekli.');
    }
    try {
      final row = await _client
          .from('store_customers')
          .insert({
            'store_id': storeId,
            'display_name': displayName,
            if (normalizedPhone.isNotEmpty) 'phone': normalizedPhone,
          })
          .select('id, display_name, phone')
          .single();
      return StoreCustomer.fromMap(Map<String, dynamic>.from(row));
    } on PostgrestException catch (error) {
      throw StoreCustomerDirectoryException(_customerDirectoryError(error));
    }
  }

  /// Links the customer to the table. Orders, payments, and table status stay.
  Future<void> selectForTable({
    required String storeId,
    required int tableNumber,
    required String customerId,
  }) async {
    try {
      await _client.from('store_table_customer_selections').upsert({
        'store_id': storeId,
        'table_number': tableNumber,
        'customer_id': customerId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on PostgrestException catch (error) {
      throw StoreCustomerDirectoryException(_customerDirectoryError(error));
    }
  }

  Future<void> clearTable({
    required String storeId,
    required int tableNumber,
  }) async {
    try {
      await _client
          .from('store_table_customer_selections')
          .delete()
          .eq('store_id', storeId)
          .eq('table_number', tableNumber);
    } on PostgrestException catch (error) {
      throw StoreCustomerDirectoryException(_customerDirectoryError(error));
    }
  }
}

String _customerDirectoryError(PostgrestException error) {
  final text = '${error.code} ${error.message}'.toLowerCase();
  if (error.code == '42P01' ||
      text.contains('store_customers') && text.contains('does not exist') ||
      text.contains('schema cache')) {
    return 'Müşteri tablosu sunucuda yok. Seçim kaydedilmedi.';
  }
  if (error.code == '42501' || text.contains('row-level security')) {
    return 'Bu işletmenin müşteri kaydını görme yetkiniz yok.';
  }
  if (text.contains('store_customers_store_phone_uidx')) {
    return 'Bu telefon bu işletmede kayıtlı.';
  }
  return 'Müşteri seçimi kaydedilemedi.';
}
