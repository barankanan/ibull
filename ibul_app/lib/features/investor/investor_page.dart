import 'package:flutter/material.dart';

import '../../app/ibul_router.dart';
import '../../core/constants.dart';
import '../../core/web_seo.dart';
import '../../screens/home_lazy_routes.dart';
import '../../widgets/web_header.dart';
import '../../widgets/web_sticky_footer_scroll_view.dart';
import 'investor_event_service.dart';
import 'investor_route_paths.dart';
import 'investor_widgets.dart';
import 'sections/investor_contact_section.dart';
import 'sections/investor_faq_section.dart';
import 'sections/investor_hero_section.dart';
import 'sections/investor_market_sections.dart';
import 'sections/investor_ops_sections.dart';
import 'sections/investor_restaurant_section.dart';
import 'sections/investor_story_sections.dart';
import 'sections/investor_strategy_sections.dart';

class InvestorPage extends StatefulWidget {
  const InvestorPage({super.key});

  @override
  State<InvestorPage> createState() => _InvestorPageState();
}

class _InvestorPageState extends State<InvestorPage> {
  final _contactKey = GlobalKey();
  final _dataRoomKey = GlobalKey();
  final _ihizKey = GlobalKey();
  final _revenueKey = GlobalKey();
  final _realEstateKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    setSeoMeta(
      title: 'İBUL Yatırımcı İlişkileri | Yerel Ticaretin Dijital Altyapısı',
      description:
          'İBUL yerel mağaza, butik, market, oto kiralama, emlak ve restorana satış kanalı açar. Ürün, İHIZ, gelir modeli ve vizyon.',
      keywords: const [
        'ibul',
        'yatırımcı',
        'investor relations',
        'ihız',
        'yerel ticaret',
      ],
      canonicalPath: InvestorRoutePaths.page,
    );
    InvestorEventService.instance.track('investor_page_view', once: true);
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _openDeck() {
    InvestorEventService.instance.track('investor_deck_click');
    InvestorEventService.instance.track('investor_data_room_click');
    _scrollTo(_dataRoomKey);
  }

  void _openContact() {
    InvestorEventService.instance.track('investor_contact_click');
    _scrollTo(_contactKey);
  }

  void _explore() {
    IbulRouter.go(context, '/home');
  }

  void _trackVisible(ScrollNotification _) {
    _emitIfVisible(_ihizKey, 'ihiz_section_view');
    _emitIfVisible(_revenueKey, 'revenue_model_view');
    _emitIfVisible(_realEstateKey, 'real_estate_section_view');
  }

  void _emitIfVisible(GlobalKey key, String event) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final offset = box.localToGlobal(Offset.zero);
    final viewHeight = MediaQuery.sizeOf(context).height;
    if (offset.dy < viewHeight * 0.88) {
      InvestorEventService.instance.track(event, once: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWebChrome = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
      backgroundColor: InvestorTokens.canvas,
      appBar: isWebChrome
          ? null
          : AppBar(
              title: const Text('Yatırımcı İlişkileri'),
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 0,
              scrolledUnderElevation: 0,
            ),
      body: Column(
        children: [
          if (isWebChrome)
            WebHeader(
              onSearch: (query) {
                HomeLazyRoutes.openSearch(context, query);
              },
            ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _trackVisible(notification);
                return false;
              },
              child: WebStickyFooterScrollView(
                child: ColoredBox(
                  color: InvestorTokens.canvas,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InvestorHeroSection(
                        onDeck: _openDeck,
                        onContact: _openContact,
                        onExplore: _explore,
                      ),
                      const InvestorWhySection(),
                      const InvestorEcosystemSection(),
                      const InvestorProductsSection(),
                      KeyedSubtree(
                        key: _ihizKey,
                        child: const InvestorIhizSection(),
                      ),
                      const InvestorLocalCommerceSection(),
                      const InvestorNearbySection(),
                      const InvestorDeliveryHourSection(),
                      const InvestorPackagingSection(),
                      const InvestorRestaurantSection(),
                      KeyedSubtree(
                        key: _revenueKey,
                        child: const InvestorRevenueSection(),
                      ),
                      KeyedSubtree(
                        key: _realEstateKey,
                        child: const InvestorRealEstateSection(),
                      ),
                      const InvestorFlywheelSection(),
                      const InvestorCompetitionSection(),
                      const InvestorGrowthSection(),
                      const InvestorMarketSection(),
                      const InvestorTractionSection(),
                      const InvestorWhyNowSection(),
                      const InvestorInvestmentSection(),
                      const InvestorLookingForSection(),
                      const InvestorTeamSection(),
                      const InvestorFaqSection(),
                      InvestorContactSection(
                        formKey: _contactKey,
                        dataRoomKey: _dataRoomKey,
                        onExplore: _explore,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
