import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'store_contract.dart';

class StoreContractRepository {
  StoreContractRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<StoreContractVersion?> active({
    required String sellerId,
    required String type,
  }) async {
    final raw = await _client.rpc(
      'active_store_contract',
      params: {
        'p_seller_id': sellerId,
        'p_contract_type': type,
      },
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true || map['missing'] == true) return null;
    return StoreContractVersion.fromMap({
      ...map,
      'contract_type': type,
    });
  }

  Future<List<StoreContractVersion>> listMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];
    final raw = await _client
        .from('store_contracts')
        .select(
          'id, seller_id, contract_type, title, is_active, updated_at, '
          'store_contract_versions(id, version, body_text, pdf_bucket, pdf_path, created_at)',
        )
        .eq('seller_id', uid)
        .order('updated_at', ascending: false);
    final out = <StoreContractVersion>[];
    for (final row in (raw as List).whereType<Map>()) {
      final versions = row['store_contract_versions'];
      Map? latest;
      if (versions is List && versions.isNotEmpty) {
        final sorted = [...versions.whereType<Map>()]..sort((a, b) {
          return ((b['version'] as num?)?.toInt() ?? 0).compareTo(
            (a['version'] as num?)?.toInt() ?? 0,
          );
        });
        latest = sorted.first;
      }
      out.add(
        StoreContractVersion.fromMap({
          'contract_id': row['id'],
          'version_id': latest?['id'],
          'title': row['title'],
          'contract_type': row['contract_type'],
          'version': latest?['version'] ?? 1,
          'body_text': latest?['body_text'],
          'pdf_bucket': latest?['pdf_bucket'],
          'pdf_path': latest?['pdf_path'],
          'is_active': row['is_active'],
          'created_at': row['updated_at'] ?? latest?['created_at'],
        }),
      );
    }
    return out;
  }

  Future<void> publish({
    required String type,
    required String title,
    String? bodyText,
    String? pdfPath,
  }) async {
    final raw = await _client.rpc(
      'publish_store_contract',
      params: {
        'p_contract_type': type,
        'p_title': title,
        'p_body_text': bodyText,
        'p_pdf_path': pdfPath,
        'p_pdf_bucket': 'store-contracts',
      },
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) {
      throw StateError(map['error']?.toString() ?? 'contract_save_failed');
    }
  }

  Future<String> uploadPdf({
    required String type,
    required List<int> bytes,
    required String fileName,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('auth_required');
    final safe = fileName.toLowerCase().endsWith('.pdf') ? 'pdf' : 'pdf';
    final path =
        '$uid/$type/${DateTime.now().millisecondsSinceEpoch}.$safe';
    await _client.storage.from('store-contracts').uploadBinary(
          path,
          bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
          fileOptions: const FileOptions(
            contentType: 'application/pdf',
            upsert: false,
            cacheControl: 'private, max-age=0',
          ),
        );
    return path;
  }

  Future<String?> signedPdfUrl(StoreContractVersion contract) async {
    final path = contract.pdfPath;
    if (path == null || path.isEmpty) return null;
    final bucket = (contract.pdfBucket ?? 'store-contracts').trim();
    return _client.storage.from(bucket).createSignedUrl(path, 180);
  }

  Future<void> setActive({required String type, required bool active}) {
    return _client.rpc(
      'set_store_contract_active',
      params: {'p_contract_type': type, 'p_active': active},
    );
  }

  Future<void> acceptForRental({
    required String reservationId,
    required String versionId,
  }) async {
    final raw = await _client.rpc(
      'accept_store_contract_for_rental',
      params: {
        'p_reservation_id': reservationId,
        'p_version_id': versionId,
      },
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true) {
      throw StateError(map['error']?.toString() ?? 'contract_accept_failed');
    }
  }

  Future<StoreContractVersion?> acceptedForRental(String reservationId) async {
    final raw = await _client.rpc(
      'rental_accepted_contract',
      params: {'p_reservation_id': reservationId},
    );
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['ok'] != true || map['missing'] == true) return null;
    return StoreContractVersion.fromMap(map);
  }
}
