import 'ad_campaign.dart';

class AdCampaignPage {
  const AdCampaignPage({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  final List<AdCampaign> items;
  final int totalCount;
  final int page;
  final int pageSize;

  bool get hasNextPage => (page + 1) * pageSize < totalCount;
}
