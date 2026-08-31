import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/seller_saved_address.dart';

class SellerSavedAddressService {
  SellerSavedAddressService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static const String table = 'seller_saved_addresses';
  static const int listLimit = 200;

  static final SellerSavedAddressService instance = SellerSavedAddressService();

  SupabaseClient? get _db {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _sessionSellerId {
    try {
      return _db?.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  Future<List<SellerSavedAddress>> listForCurrentSeller() async {
    final db = _db;
    final sellerId = (_sessionSellerId ?? '').trim();
    if (db == null || sellerId.isEmpty) return const <SellerSavedAddress>[];

    try {
      final rows = await db
          .from(table)
          .select()
          .eq('seller_id', sellerId)
          .order('created_at', ascending: false)
          .limit(listLimit);
      return (rows as List)
          .map(
            (row) => SellerSavedAddress.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .where((row) => row.id.isNotEmpty && row.sellerId == sellerId)
          .toList(growable: false);
    } catch (error) {
      throw Exception(_mapError(error));
    }
  }

  Future<SellerSavedAddress> saveForCurrentSeller({
    required String customerName,
    required String customerPhone,
    required String city,
    required String district,
    required String address,
    String building = '',
    double? latitude,
    double? longitude,
  }) async {
    final db = _db;
    final sellerId = (_sessionSellerId ?? '').trim();
    if (db == null) {
      throw Exception('Supabase bağlantısı hazır değil.');
    }
    if (sellerId.isEmpty) {
      throw Exception('Satıcı oturumu doğrulanamadı.');
    }

    final normalizedName = customerName.trim();
    final normalizedPhone = customerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final normalizedCity = city.trim();
    final normalizedDistrict = district.trim();
    final normalizedAddress = address.trim();
    final normalizedBuilding = building.trim();

    if (normalizedName.isEmpty) {
      throw Exception('Müşteri adı zorunludur.');
    }
    if (normalizedPhone.length < 10 || normalizedPhone.length > 11) {
      throw Exception('Telefon numarası 10 veya 11 haneli olmalıdır.');
    }
    if (normalizedCity.isEmpty || normalizedDistrict.isEmpty) {
      throw Exception('Lütfen il ve ilçe seçin.');
    }
    if (normalizedAddress.isEmpty) {
      throw Exception('Açık adres zorunludur.');
    }

    final payload = SellerSavedAddress(
      id: '',
      sellerId: sellerId,
      customerName: normalizedName,
      customerPhone: normalizedPhone,
      city: normalizedCity,
      district: normalizedDistrict,
      building: normalizedBuilding,
      address: normalizedAddress,
      latitude: latitude,
      longitude: longitude,
    ).toInsertMap();

    try {
      final row = await db.from(table).insert(payload).select().single();
      final saved = SellerSavedAddress.fromMap(Map<String, dynamic>.from(row));
      if (saved.sellerId != sellerId) {
        throw Exception('Adres kaydı doğrulanamadı.');
      }
      return saved;
    } catch (error) {
      throw Exception(_mapError(error));
    }
  }

  String _mapError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains(table) &&
        (text.contains('does not exist') ||
            text.contains('schema cache') ||
            text.contains('could not find') ||
            text.contains('42p01'))) {
      return 'Kayıtlı adres tablosu henüz kurulmadı. '
          'Supabase\'de SUPABASE_SELLER_SAVED_ADDRESSES.sql '
          '(veya 20260815_seller_saved_addresses.sql) migration\'ını çalıştırın.';
    }
    if (text.contains('row-level security') || text.contains('42501')) {
      return 'Bu adres kaydı yalnızca kendi satıcı hesabınıza aittir.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
