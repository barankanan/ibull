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

  /// Every table's selected customer for one store, in a single read. The
  /// waiter board shows the name under the table number.
  Future<Map<int, StoreCustomer>> selectionsForStore({
    required String storeId,
  }) async {
    try {
      final rows = await _client
          .from('store_table_customer_selections')
          .select(
            'table_number, store_customers(id, display_name, phone)',
          )
          .eq('store_id', storeId);
      return tableCustomersFromRows(
        List<Map<String, dynamic>>.from(rows as List),
      );
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

  /// Quick entry from the table card. A phone that this store already has
  /// selects that customer instead of creating a second record; otherwise a
  /// new customer is created. Either way the table then shows the name.
  Future<StoreCustomer> attachQuickCustomer({
    required String storeId,
    required int tableNumber,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final name = quickCustomerDisplayName(firstName, lastName);
    if (name.isEmpty) {
      throw const StoreCustomerDirectoryException('Müşteri adı gerekli.');
    }
    final normalizedPhone = phone?.trim() ?? '';
    StoreCustomer? customer;
    if (normalizedPhone.isNotEmpty) {
      try {
        final row = await _client
            .from('store_customers')
            .select('id, display_name, phone')
            .eq('store_id', storeId)
            .eq('phone', normalizedPhone)
            .maybeSingle();
        if (row != null) {
          customer = StoreCustomer.fromMap(Map<String, dynamic>.from(row));
        }
      } on PostgrestException catch (error) {
        throw StoreCustomerDirectoryException(_customerDirectoryError(error));
      }
    }
    customer ??= await create(
      storeId: storeId,
      name: name,
      phone: normalizedPhone,
    );
    await selectForTable(
      storeId: storeId,
      tableNumber: tableNumber,
      customerId: customer.id,
    );
    return customer;
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

/// Rows of `store_table_customer_selections` (with the nested customer) as a
/// table-number map. Rows without a table number or a customer are skipped.
Map<int, StoreCustomer> tableCustomersFromRows(
  List<Map<String, dynamic>> rows,
) {
  final result = <int, StoreCustomer>{};
  for (final row in rows) {
    final number = int.tryParse(row['table_number']?.toString() ?? '');
    final nested = row['store_customers'];
    if (number == null || number <= 0 || nested is! Map) continue;
    final customer = StoreCustomer.fromMap(Map<String, dynamic>.from(nested));
    if (customer.name.trim().isEmpty) continue;
    result[number] = customer;
  }
  return result;
}

/// "Ad Soyad" from the two quick-entry fields, with single spaces.
String quickCustomerDisplayName(String firstName, String lastName) {
  return '${firstName.trim()} ${lastName.trim()}'
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}
