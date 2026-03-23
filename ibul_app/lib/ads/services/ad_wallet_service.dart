import '../helpers/ad_wallet_helper.dart';
import '../enums/ad_enums.dart';
import '../models/ad_campaign.dart';
import '../models/ad_revenue_record.dart';
import '../models/ad_wallet_transaction.dart';
import '../repositories/ads_repository.dart';

class AdWalletService {
  AdWalletService({AdsRepository? repository})
    : _repository = repository ?? AdsRepository();

  final AdsRepository _repository;

  Future<List<AdWalletTransaction>> getTransactions({
    required String sellerId,
    String? campaignId,
  }) {
    return _repository.getWalletTransactions(
      sellerId: sellerId,
      campaignId: campaignId,
    );
  }

  Future<double> getAvailableBalance(String sellerId) async {
    final transactions = await getTransactions(sellerId: sellerId);
    return AdWalletHelper.availableBalance(transactions);
  }

  Future<AdWalletTransaction> topUp({
    required String sellerId,
    required double amount,
    String? note,
    String? reference,
  }) async {
    final currentBalance = await getAvailableBalance(sellerId);
    final transaction = AdWalletHelper.buildTopUpTransaction(
      id: 'wallet-${DateTime.now().microsecondsSinceEpoch}',
      sellerId: sellerId,
      amount: amount,
      currentBalance: currentBalance,
      note: note,
      reference: reference,
    );
    return _repository.createWalletTransaction(transaction);
  }

  Future<AdWalletTransaction> spend({
    required String sellerId,
    required String campaignId,
    required double amount,
    String? note,
  }) async {
    final currentBalance = await getAvailableBalance(sellerId);
    final transaction = AdWalletHelper.buildSpendTransaction(
      id: 'wallet-${DateTime.now().microsecondsSinceEpoch}',
      sellerId: sellerId,
      campaignId: campaignId,
      amount: amount,
      currentBalance: currentBalance,
      note: note,
    );
    return _repository.createWalletTransaction(transaction);
  }

  Future<AdWalletTransaction> refund({
    required String sellerId,
    required double amount,
    String? campaignId,
    String? note,
  }) async {
    final currentBalance = await getAvailableBalance(sellerId);
    final transaction = AdWalletHelper.buildRefundTransaction(
      id: 'wallet-${DateTime.now().microsecondsSinceEpoch}',
      sellerId: sellerId,
      campaignId: campaignId,
      amount: amount,
      currentBalance: currentBalance,
      note: note,
    );
    return _repository.createWalletTransaction(transaction);
  }

  Future<AdWalletTransaction> grantBonusCredit({
    required String sellerId,
    required double amount,
    String? note,
    String? reference,
    String? approvedBy,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final currentBalance = await getAvailableBalance(sellerId);
    final transaction = AdWalletTransaction(
      id: 'wallet-${DateTime.now().microsecondsSinceEpoch}',
      sellerId: sellerId,
      type: WalletTransactionType.bonusCredit,
      status: WalletTransactionStatus.succeeded,
      amount: amount,
      balanceBefore: currentBalance,
      balanceAfter: currentBalance + amount,
      reference: reference,
      approvedBy: approvedBy,
      note: note,
      metadata: metadata,
      createdAt: DateTime.now(),
    );
    return _repository.createWalletTransaction(transaction);
  }

  Future<AdRevenueRecord> spendAndBuildRevenueRecord({
    required AdCampaign campaign,
    required double amount,
    String? note,
  }) async {
    final transaction = await spend(
      sellerId: campaign.sellerId,
      campaignId: campaign.id,
      amount: amount,
      note: note,
    );
    final record = AdWalletHelper.buildRevenueRecord(
      id: 'revenue-${DateTime.now().microsecondsSinceEpoch}',
      campaign: campaign,
      transaction: transaction,
    );
    return _repository.createRevenueRecord(record);
  }
}
