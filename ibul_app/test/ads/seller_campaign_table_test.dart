import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/ads/enums/ad_enums.dart';
import 'package:ibul_app/ads/models/ad_campaign.dart';
import 'package:ibul_app/ads/models/ad_metrics.dart';
import 'package:ibul_app/ads/presentation/widgets/seller_campaign_table.dart';

const _visibleColumns = <String>{
  'name',
  'type',
  'status',
  'spend',
  'impressions',
  'cpm',
  'clicks',
  'ctr',
  'cpc',
  'date',
};

AdCampaign _homeFeatureCampaign({
  CampaignStatus status = CampaignStatus.pendingReview,
}) {
  final now = DateTime(2026, 7, 1);
  return AdCampaign(
    id: 'hfa-test-1',
    sellerId: 'seller-test',
    storeId: 'store-test',
    name: 'Test Ana Sayfa Reklami',
    type: AdCampaignType.homeFeature,
    objective: CampaignObjective.storeVisits,
    status: status,
    billingModel: BillingModel.flat,
    dailyBudget: 0,
    totalBudget: 0,
    currency: 'TRY',
    startsAt: now,
    endsAt: now.add(const Duration(days: 14)),
    metadata: const {
      'card_template_id': 'tpl-1',
      'category_name': 'Yemek',
      'banner_images': ['https://example.com/banner.png'],
      'selected_product_ids': ['p1'],
      'home_metrics': {
        'impressions_count': 0,
        'banner_clicks_count': 0,
        'profile_opens_count': 0,
      },
    },
    createdAt: now,
    updatedAt: now,
  );
}

SellerCampaignTableRow _row(AdCampaign campaign) => SellerCampaignTableRow(
      campaign: campaign,
      metrics: AdMetrics(campaignId: campaign.id, date: DateTime(2026, 7, 1)),
    );

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  testWidgets('empty campaign list does not crash and shows 1/1 footer',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SellerCampaignTable(
          rows: [],
          currency: 'TRY',
          visibleColumnIds: _visibleColumns,
          optionalColumnIds: {},
          totalRowCount: 0,
          pageSize: 10,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('pageSize 0 does not produce NaN page count', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SellerCampaignTable(
          rows: [],
          currency: 'TRY',
          visibleColumnIds: _visibleColumns,
          optionalColumnIds: {},
          totalRowCount: 0,
          pageSize: 0,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('pending home feature campaign row renders with status chip',
      (tester) async {
    final campaign = _homeFeatureCampaign();
    await tester.pumpWidget(
      _wrap(
        SellerCampaignTable(
          rows: [_row(campaign)],
          currency: 'TRY',
          visibleColumnIds: _visibleColumns,
          optionalColumnIds: const {},
          totalRowCount: 1,
          pageSize: 10,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Test Ana Sayfa Reklami'), findsOneWidget);
    expect(find.text('Onay Bekliyor'), findsOneWidget);
  });

  testWidgets('page count math is correct for multiple pages', (tester) async {
    final campaign = _homeFeatureCampaign(status: CampaignStatus.active);
    await tester.pumpWidget(
      _wrap(
        SellerCampaignTable(
          rows: [_row(campaign)],
          currency: 'TRY',
          visibleColumnIds: _visibleColumns,
          optionalColumnIds: const {},
          totalRowCount: 25,
          pageSize: 10,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('negative counters are sanitized instead of crashing',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SellerCampaignTable(
          rows: [],
          currency: 'TRY',
          visibleColumnIds: _visibleColumns,
          optionalColumnIds: {},
          totalRowCount: -42,
          pageSize: -5,
          pageIndex: -1,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('1 / 1'), findsOneWidget);
  });
}
