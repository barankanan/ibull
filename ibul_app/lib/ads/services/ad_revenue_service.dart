import 'package:flutter/foundation.dart';

import '../helpers/ad_wallet_helper.dart';
import '../models/ad_revenue_overview.dart';
import '../models/ad_revenue_record.dart';
import '../repositories/ads_repository.dart';

class AdRevenueService {
  AdRevenueService({AdsRepository? repository})
    : _repository = repository ?? AdsRepository();

  final AdsRepository _repository;

  Future<AdRevenueOverview> getRevenueOverview({
    String? sellerId,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    debugPrint('AdRevenueService revenue load started sellerId=${sellerId ?? 'all'}');
    final recordsFuture = _repository.getRevenueRecords(sellerId: sellerId);
    final walletTransactionsFuture = _repository.getWalletTransactions(
      sellerId: sellerId,
    );
    final records = await recordsFuture;
    debugPrint('AdRevenueService revenue records loaded count=${records.length}');
    final walletTransactions = await walletTransactionsFuture;
    debugPrint(
      'AdRevenueService wallet transactions loaded count=${walletTransactions.length}',
    );
    return AdWalletHelper.buildAdminRevenueSummary(
      records: records,
      walletTransactions: walletTransactions,
      now: current,
    );
  }

  Future<List<AdRevenueRecord>> getCampaignRevenueRecords(String campaignId) {
    return _repository.getRevenueRecords(campaignId: campaignId);
  }

  Future<Map<String, double>> getSellerSpendSummary(String sellerId) async {
    final transactions = await _repository.getWalletTransactions(
      sellerId: sellerId,
    );
    final records = await _repository.getRevenueRecords(sellerId: sellerId);
    return AdWalletHelper.buildSellerSpendSummary(
      transactions: transactions,
      records: records,
    );
  }
}
