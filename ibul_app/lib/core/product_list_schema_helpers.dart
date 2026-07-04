import 'package:supabase_flutter/supabase_flutter.dart';

/// Optional product_lists header columns that may be absent on older deployments.
const productListHeaderOptionalColumns = <String>[
  'category',
  'sub_category',
  'seller_id',
  'store_name',
  'follower_count',
];

bool isProductListMissingColumnError(Object error) {
  if (error is PostgrestException) {
    if (error.code == 'PGRST204') return true;
    final message = error.message.toLowerCase();
    return message.contains('could not find') && message.contains('column');
  }
  final text = error.toString().toLowerCase();
  return text.contains('pgrst204') ||
      (text.contains('could not find') && text.contains('column'));
}

/// Parses `Could not find the 'category' column of 'product_lists'...`
String? extractMissingProductListColumn(Object error) {
  if (error is PostgrestException) {
    final match = RegExp(
      r"Could not find the '([^']+)' column",
      caseSensitive: false,
    ).firstMatch(error.message);
    if (match != null) return match.group(1);
  }
  final match = RegExp(
    r"'([^']+)' column",
    caseSensitive: false,
  ).firstMatch(error.toString());
  return match?.group(1);
}

/// Drops missing optional columns from [payload] based on PostgREST schema errors.
Map<String, dynamic> stripProductListHeaderColumn(
  Map<String, dynamic> payload,
  String column,
) {
  final copy = Map<String, dynamic>.from(payload);
  copy.remove(column);
  return copy;
}
