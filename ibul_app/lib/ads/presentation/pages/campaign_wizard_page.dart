import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/ads_defaults.dart';
import '../../enums/ad_enums.dart';
import '../../helpers/ad_campaign_helper.dart';
import '../../models/ad_campaign.dart';
import '../../models/ad_credit_code.dart';
import '../../models/campaign_asset.dart';
import '../../models/campaign_target.dart';
import '../../services/ad_credit_code_service.dart';
import '../../services/campaign_service.dart';
import '../../services/ad_wallet_service.dart';
import '../../../core/app_state.dart';
import '../../../models/product_list_model.dart';
import '../../../services/store_service.dart';
import '../../../services/product_list_service.dart';
import '../../../screens/seller/collections_management_page.dart';
import '../widgets/ad_type_selector.dart';
import '../widgets/audience_selector.dart';
import '../widgets/budget_planner.dart';
import '../widgets/campaign_objective_selector.dart';
import '../widgets/campaign_preview_panel.dart';
import '../widgets/campaign_stepper.dart';

class CampaignWizardPage extends StatefulWidget {
  const CampaignWizardPage({
    required this.sellerId,
    this.existingCampaign,
    this.initialCampaignType,
    this.initialCollectionId,
    this.initialCollectionTitle,
    this.initialCollectionImageUrl,
    super.key,
  });

  final String sellerId;
  final AdCampaign? existingCampaign;
  final AdCampaignType? initialCampaignType;
  final String? initialCollectionId;
  final String? initialCollectionTitle;
  final String? initialCollectionImageUrl;

  @override
  State<CampaignWizardPage> createState() => _CampaignWizardPageState();
}

class _CampaignWizardPageState extends State<CampaignWizardPage> {
  final AppState _appState = AppState();
  final CampaignService _campaignService = CampaignService();
  final AdWalletService _adWalletService = AdWalletService();
  final AdCreditCodeService _adCreditCodeService = AdCreditCodeService();
  final StoreService _storeService = StoreService();
  final ProductListService _productListService = ProductListService.instance;

  final TextEditingController _campaignNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _creativeTitleController =
      TextEditingController();
  final TextEditingController _entityLabelController = TextEditingController();
  final TextEditingController _dailyBudgetController = TextEditingController();
  final TextEditingController _totalBudgetController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _offerController = TextEditingController();
  final TextEditingController _timePlanController = TextEditingController();
  final TextEditingController _creditCodeController = TextEditingController();
  final TextEditingController _giftSellerController = TextEditingController();
  final TextEditingController _giftAmountController = TextEditingController();

  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _distanceEnabled = true;
  bool _couponEnabled = false;
  bool _runWeekdays = true;
  bool _runWeekends = true;
  bool _premiumPlacement = true;
  bool _useAiSuggestions = true;
  bool _audienceConfigured = false;
  bool _cityConfigured = false;
  bool _budgetConfigured = false;
  bool _scheduleConfigured = false;
  bool _campaignTypeCustomized = false;
  bool _giftCreditEnabled = false;
  String? _sellerCity;
  String? _sellerDistrict;
  String _selectedObjectiveId = 'views';
  String _selectedPaymentMethod = 'card';
  AdCampaignType _selectedCampaignType = AdCampaignType.productBoost;
  AudienceTargetingState _audienceTargeting = const AudienceTargetingState();
  Set<String> _selectedCities = <String>{};
  String? _selectedDistrict;
  double _distanceKm = 8;
  double _dailyBudget = 450;
  double _totalBudget = 6300;
  int _durationDays = 14;
  DateTimeRange? _schedule;
  _EntityOption? _selectedEntity;
  _EntityOption? _sellerStoreOption;
  List<_EntityOption> _sellerProducts = const <_EntityOption>[];
  List<_EntityOption> _sellerCollections = const <_EntityOption>[];
  bool _isLoadingSellerProducts = false;
  bool _isLoadingSellerCollections = false;
  bool _isLoadingAdCreditBalance = false;
  bool _isCheckingCreditCode = false;
  bool _isRedeemingCreditCode = false;
  String? _sellerProductsError;
  String? _sellerCollectionsError;
  double _availableAdCreditBalance = 0;
  Timer? _creditCodeLookupDebounce;
  AdCreditCodePreview? _creditCodePreview;
  String? _redeemedCreditCode;
  double? _redeemedCreditAmount;

  static const List<String> _audienceCategories = <String>[
    'Erkek',
    'Kadin',
    'Elektronik',
    'Ayakkabi & Canta',
    'Saat & Aksesuar',
    'Ev & Yasam',
    'Oto',
    'Emlak',
    'Otel',
    'Restoran',
  ];

  static const Map<String, List<String>> _audienceSubcategories =
      <String, List<String>>{
        'Erkek': <String>['Gomlek', 'Ayakkabi', 'Saat', 'Spor giyim'],
        'Kadin': <String>['Elbise', 'Canta', 'Ayakkabi', 'Takilar'],
        'Elektronik': <String>[
          'Akilli telefon',
          'Bilgisayar',
          'Gaming',
          'Akilli saat',
        ],
        'Ayakkabi & Canta': <String>[
          'Sneaker',
          'Topuklu ayakkabi',
          'Sirt cantasi',
          'Luks canta',
        ],
        'Saat & Aksesuar': <String>[
          'Akilli saat',
          'Klasik saat',
          'Bileklik',
          'Gunes gozlukleri',
        ],
        'Ev & Yasam': <String>['Mobilya', 'Dekorasyon', 'Mutfak', 'Bahce'],
        'Oto': <String>['Aksesuar', 'Elektrikli arac', 'Lastik', 'Bakim'],
        'Emlak': <String>['Kiralik', 'Satilik', 'Yatirimlik', 'Luks konut'],
        'Otel': <String>['Sehir oteli', 'Tatil koyu', 'Spa', 'Butik otel'],
        'Restoran': <String>['Kafe', 'Fine dining', 'Fast food', 'Tatli'],
      };

  static const List<String> _cities = <String>[
    'Adana',
    'Adiyaman',
    'Afyonkarahisar',
    'Agri',
    'Aksaray',
    'Amasya',
    'Ankara',
    'Antalya',
    'Ardahan',
    'Artvin',
    'Aydin',
    'Balikesir',
    'Bartin',
    'Batman',
    'Bayburt',
    'Bilecik',
    'Bingol',
    'Bitlis',
    'Bolu',
    'Burdur',
    'Bursa',
    'Canakkale',
    'Cankiri',
    'Corum',
    'Denizli',
    'Diyarbakir',
    'Duzce',
    'Edirne',
    'Elazig',
    'Erzincan',
    'Erzurum',
    'Eskisehir',
    'Gaziantep',
    'Giresun',
    'Gumushane',
    'Hakkari',
    'Hatay',
    'Igdir',
    'Isparta',
    'Istanbul',
    'Izmir',
    'Kahramanmaras',
    'Karabuk',
    'Karaman',
    'Kars',
    'Kastamonu',
    'Kayseri',
    'Kirikkale',
    'Kirklareli',
    'Kirsehir',
    'Kilis',
    'Kocaeli',
    'Konya',
    'Kutahya',
    'Malatya',
    'Manisa',
    'Mardin',
    'Mersin',
    'Mugla',
    'Mus',
    'Nevsehir',
    'Nigde',
    'Ordu',
    'Osmaniye',
    'Rize',
    'Sakarya',
    'Samsun',
    'Siirt',
    'Sinop',
    'Sivas',
    'Sanliurfa',
    'Sirnak',
    'Tekirdag',
    'Tokat',
    'Trabzon',
    'Tunceli',
    'Usak',
    'Van',
    'Yalova',
    'Yozgat',
    'Zonguldak',
  ];

  static const Map<String, List<String>> _districtsByCity =
      <String, List<String>>{
        'Istanbul': <String>[
          'Adalar',
          'Arnavutkoy',
          'Atasehir',
          'Avcilar',
          'Bagcilar',
          'Bahcelievler',
          'Bakirkoy',
          'Basaksehir',
          'Bayrampasa',
          'Besiktas',
          'Beykoz',
          'Beylikduzu',
          'Beyoglu',
          'Buyukcekmece',
          'Catalca',
          'Cekmekoy',
          'Esenler',
          'Esenyurt',
          'Eyupsultan',
          'Fatih',
          'Gaziosmanpasa',
          'Gungoren',
          'Kadikoy',
          'Kagithane',
          'Kartal',
          'Kucukcekmece',
          'Maltepe',
          'Pendik',
          'Sancaktepe',
          'Sariyer',
          'Silivri',
          'Sultanbeyli',
          'Sultangazi',
          'Sile',
          'Sisli',
          'Tuzla',
          'Umraniye',
          'Uskudar',
          'Zeytinburnu',
        ],
        'Ankara': <String>[
          'Altindag',
          'Ayas',
          'Bala',
          'Beypazari',
          'Cankaya',
          'Etimesgut',
          'Golbasi',
          'Kahramankazan',
          'Kecioren',
          'Mamak',
          'Polatli',
          'Sincan',
          'Yenimahalle',
        ],
        'Izmir': <String>[
          'Aliaga',
          'Balcova',
          'Bayrakli',
          'Bornova',
          'Buca',
          'Cesme',
          'Gaziemir',
          'Karabaglar',
          'Karsiyaka',
          'Konak',
          'Menemen',
          'Narlidere',
          'Torbali',
        ],
        'Bursa': <String>[
          'Gemlik',
          'Gursu',
          'Inegol',
          'Mudanya',
          'Nilufer',
          'Osmangazi',
          'Yildirim',
        ],
        'Antalya': <String>[
          'Aksu',
          'Alanya',
          'Dosemealti',
          'Kepez',
          'Konyaalti',
          'Kumluca',
          'Manavgat',
          'Muratpasa',
          'Serik',
        ],
        'Adana': <String>[
          'Cukurova',
          'Saricam',
          'Seyhan',
          'Yuregir',
          'Ceyhan',
          'Kozan',
        ],
        'Mersin': <String>[
          'Akdeniz',
          'Erdemli',
          'Mezitli',
          'Silifke',
          'Tarsus',
          'Toroslar',
          'Yenisehir',
        ],
        'Kocaeli': <String>[
          'Basiskele',
          'Cayirova',
          'Darica',
          'Derince',
          'Gebze',
          'Golcuk',
          'Izmit',
          'Karamursel',
          'Kartepe',
          'Korfez',
        ],
        'Konya': <String>[
          'Aksehir',
          'Beysehir',
          'Eregli',
          'Karatay',
          'Meram',
          'Selcuklu',
        ],
        'Gaziantep': <String>[
          'Araban',
          'Islahiye',
          'Nizip',
          'Nurdagi',
          'Oguzeli',
          'Sahinbey',
          'Sehitkamil',
        ],
        'Hatay': <String>[
          'Antakya',
          'Arsuz',
          'Defne',
          'Dortyol',
          'Iskenderun',
          'Kirikhan',
          'Samandag',
        ],
      };

  String get _effectiveSellerId {
    final widgetSellerId = widget.sellerId.trim();
    if (widgetSellerId.isNotEmpty) {
      return widgetSellerId;
    }
    return _storeService.currentUserId?.trim() ?? '';
  }

  static const List<_SchedulePreset> _schedulePresets = <_SchedulePreset>[
    _SchedulePreset(label: 'Sabah', value: '09:00 - 12:00'),
    _SchedulePreset(label: 'Oglen', value: '12:00 - 16:00'),
    _SchedulePreset(label: 'Aksam', value: '18:00 - 23:00'),
    _SchedulePreset(label: 'Tum gun', value: '09:00 - 23:00'),
  ];

  late final List<CampaignStepData> _steps = <CampaignStepData>[
    const CampaignStepData(
      title: 'Kampanya Amaci',
      icon: Icons.flag_circle_outlined,
      subtitle: 'Hedefinize uygun teslim modeli',
    ),
    const CampaignStepData(
      title: 'Yayin Formati',
      icon: Icons.ads_click_outlined,
      subtitle: 'Sistem onerir, istersen degistir',
    ),
    const CampaignStepData(
      title: 'Reklam Icerigi',
      icon: Icons.perm_media_outlined,
      subtitle: 'Kreatif alanlar ve reklam hedefi',
    ),
    const CampaignStepData(
      title: 'Hedef Kitle',
      icon: Icons.people_alt_outlined,
      subtitle: 'Kategori, sehir ve mesafe secimi',
    ),
    const CampaignStepData(
      title: 'Butce ve Sure',
      icon: Icons.stacked_line_chart_outlined,
      subtitle: 'Gunluk plan ve tahmini performans',
    ),
    const CampaignStepData(
      title: 'Kupon / Teklif',
      icon: Icons.local_offer_outlined,
      subtitle: 'Kuponlu reklam ve ozel teklif ayari',
    ),
    const CampaignStepData(
      title: 'Yayin Plani',
      icon: Icons.schedule_outlined,
      subtitle: 'Saat bazli yayin akisi',
    ),
    const CampaignStepData(
      title: 'Onizleme',
      icon: Icons.visibility_outlined,
      subtitle: 'Kampanya gorunumu ve ozet',
    ),
    const CampaignStepData(
      title: 'Yayinlama',
      icon: Icons.publish_outlined,
      subtitle: 'Kontrol et ve incelemeye gonder',
    ),
  ];

  late final List<CampaignObjectiveOption>
  _objectiveOptions = <CampaignObjectiveOption>[
    const CampaignObjectiveOption(
      id: 'views',
      title: 'Daha fazla goruntulenme',
      description:
          'Urunlerinizi ana sayfa ve benzer urun alanlarinda daha fazla kullaniciya gosterir.',
      icon: Icons.visibility_outlined,
    ),
    const CampaignObjectiveOption(
      id: 'store_visits',
      title: 'Magaza ziyareti',
      description:
          'Magazanizi harita ve magaza listelerinde daha cok kullanici ile bulusturur.',
      icon: Icons.store_mall_directory_outlined,
    ),
    const CampaignObjectiveOption(
      id: 'collection_discovery',
      title: 'Liste kesfi',
      description:
          'Listelerinizi kesfet alaninda daha ilgili kitlelerle bulusturur.',
      icon: Icons.collections_bookmark_outlined,
    ),
    const CampaignObjectiveOption(
      id: 'favorite',
      title: 'Favori',
      description:
          'Favori ekleme egilimi yuksek kullanicilara ulasarak ilgiyi buyutur.',
      icon: Icons.favorite_border_rounded,
    ),
    const CampaignObjectiveOption(
      id: 'add_to_cart',
      title: 'Sepete ekleme',
      description:
          'Sepete ekleme ihtimali yuksek kullanicilari hedefleyerek niyeti artirir.',
      icon: Icons.add_shopping_cart_outlined,
    ),
    const CampaignObjectiveOption(
      id: 'order',
      title: 'Siparis',
      description:
          'Siparis odakli reklam teslimi ile daha hizli ticari sonuc hedefler.',
      icon: Icons.inventory_2_outlined,
    ),
    const CampaignObjectiveOption(
      id: 'purchase',
      title: 'Satin alma',
      description:
          'Satin almaya yatkin kullanicilara reklam gosterir ve donusum oraninizi artirmayi hedefler.',
      icon: Icons.shopping_bag_outlined,
    ),
    const CampaignObjectiveOption(
      id: 'nearby',
      title: 'Yakindaki kullanicilara bildirim gonder',
      description:
          'Magazanizin yakinindaki kullanicilara konum bazli bildirim gonderir.',
      icon: Icons.near_me_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bootstrapFromCampaign();
    _creditCodeController.addListener(_handleCreditCodeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadInitialData();
      _scheduleCreditCodeLookup();
    });
  }

  void _loadInitialData() {
    _loadSellerStore();
    _loadSellerProducts();
    _loadSellerCollections();
    _loadAdCreditBalance();
  }

  Future<void> _openCollectionsCreationFlow() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SellerCollectionsManagementContent(),
      ),
    );
    if (!mounted) return;
    await _loadSellerCollections();
    if (_sellerCollections.isNotEmpty && _selectedEntity == null) {
      setState(() {
        _selectedEntity = _sellerCollections.first;
        _entityLabelController.text = _selectedEntity!.title;
      });
    }
  }

  Future<void> _ensureCollectionAvailableOrRedirect() async {
    if (_selectedCampaignType != AdCampaignType.collectionBoost) return;
    if (_isLoadingSellerCollections) return;
    if (_resolvedSellerCollections.isEmpty) {
      await _loadSellerCollections();
      if (!mounted) return;
    }
    if (_resolvedSellerCollections.isNotEmpty) {
      _applyDefaultCollectionSelectionIfNeeded();
      return;
    }
    if (!mounted) return;

    final shouldNavigate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Önce liste oluşturun'),
          content: const Text(
            'Liste reklamı vermeden önce aynı kategoride ürünlerden oluşan bir liste hazırlamanız gerekiyor. Sizi liste oluşturma ekranına gönderelim.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Liste oluştur'),
            ),
          ],
        );
      },
    );

    if (shouldNavigate == true && mounted) {
      await _openCollectionsCreationFlow();
    }
  }

  void _bootstrapFromCampaign() {
    final campaign = widget.existingCampaign;
    if (campaign == null) {
      if (widget.initialCampaignType != null) {
        _selectedCampaignType = widget.initialCampaignType!;
        _campaignTypeCustomized = true;
      }
      if ((widget.initialCollectionId ?? '').trim().isNotEmpty) {
        _selectedEntity = _EntityOption(
          id: widget.initialCollectionId!.trim(),
          title: widget.initialCollectionTitle?.trim().isNotEmpty == true
              ? widget.initialCollectionTitle!.trim()
              : 'Secili liste',
          subtitle: 'Liste reklami icin secildi',
          imageUrl: widget.initialCollectionImageUrl,
        );
        _entityLabelController.text = _selectedEntity!.title;
      }
      _schedule = DateTimeRange(
        start: DateTime.now(),
        end: DateTime.now().add(const Duration(days: 14)),
      );
      _durationDays = 14;
      _dailyBudget = 0;
      _totalBudget = 0;
      _dailyBudgetController.clear();
      _totalBudgetController.clear();
      _durationController.text = _durationDays.toString();
      _distanceEnabled = false;
      _timePlanController.clear();
      _creditCodeController.clear();
      _giftSellerController.clear();
      _giftAmountController.clear();
      _applySellerLocationDefaultsIfNeeded();
      return;
    }

    _campaignNameController.text = campaign.name;
    _descriptionController.text = campaign.description ?? '';
    _creativeTitleController.text = campaign.assets.isNotEmpty
        ? (campaign.assets.first.title ?? '')
        : '';
    _selectedCampaignType = campaign.type;
    _campaignTypeCustomized = true;
    _selectedObjectiveId = _objectiveIdForCampaign(campaign);
    if (!_campaignService
        .getAvailableTypes(_objectiveForId(_selectedObjectiveId))
        .contains(_selectedCampaignType)) {
      _selectedCampaignType = _recommendedCampaignTypeForSelectedGoal;
      _campaignTypeCustomized = false;
    }
    _premiumPlacement = campaign.isPremiumPlacementEnabled;
    _useAiSuggestions = campaign.useAiSuggestions;
    final savedTargeting = AudienceTargetingState.fromMetadata(
      (campaign.target?.metadata['advanced_targeting'] as Map?)
          ?.cast<String, dynamic>(),
    );
    final savedCategories = campaign.target?.categories ?? const <String>[];
    _audienceTargeting = savedTargeting.copyWith(
      primaryCategory:
          savedTargeting.primaryCategory ??
          (savedCategories.isNotEmpty ? savedCategories.first : null),
      subcategories: savedTargeting.subcategories.isNotEmpty
          ? savedTargeting.subcategories
          : savedCategories.skip(1).toSet(),
    );
    _selectedCities = {...?campaign.target?.cityCodes};
    _selectedDistrict = campaign.target?.metadata['selected_district']
        ?.toString();
    _audienceConfigured = _audienceTargeting.hasAnySelection;
    _cityConfigured = _selectedCities.isNotEmpty;
    _distanceEnabled = campaign.target?.radiusMeters != null;
    if (_selectedObjectiveId == 'nearby') {
      _distanceEnabled = true;
    }
    _distanceKm =
        ((campaign.target?.radiusMeters ?? AdsDefaults.defaultGeoRadiusMeters) /
                1000)
            .toDouble()
            .clamp(1, 50);
    _dailyBudget = campaign.dailyBudget;
    _totalBudget = campaign.totalBudget;
    _budgetConfigured = true;
    _durationDays = campaign.endsAt
        .difference(campaign.startsAt)
        .inDays
        .clamp(1, 365);
    _couponEnabled = (campaign.metadata['coupon_enabled'] as bool?) ?? false;
    _couponController.text = campaign.metadata['coupon_code']?.toString() ?? '';
    _offerController.text = campaign.metadata['offer_note']?.toString() ?? '';
    _timePlanController.text =
        campaign.metadata['time_plan']?.toString() ?? '18:00 - 23:00';
    _selectedPaymentMethod =
        campaign.metadata['payment_method']?.toString() == 'ad_credit'
        ? 'ad_credit'
        : 'card';
    _creditCodeController.text =
        campaign.metadata['ad_credit_code']?.toString() ?? '';
    _giftCreditEnabled =
        (campaign.metadata['gift_credit_enabled'] as bool?) ?? false;
    _giftSellerController.text =
        campaign.metadata['gift_credit_recipient_seller_id']?.toString() ?? '';
    _giftAmountController.text =
        campaign.metadata['gift_credit_amount']?.toString() ?? '';
    _runWeekdays = (campaign.metadata['run_weekdays'] as bool?) ?? _runWeekdays;
    _runWeekends = (campaign.metadata['run_weekends'] as bool?) ?? _runWeekends;
    _schedule = DateTimeRange(start: campaign.startsAt, end: campaign.endsAt);
    _scheduleConfigured =
        _timePlanController.text.trim().isNotEmpty && _schedule != null;
    final entityId = campaign.assets.isNotEmpty
        ? campaign.assets.first.entityId
        : null;
    if ((entityId ?? '').isNotEmpty) {
      _selectedEntity = _entityOptionsForType(_selectedCampaignType).firstWhere(
        (item) => item.id == entityId,
        orElse: () => _EntityOption(
          id: entityId!,
          title: entityId,
          subtitle: 'Mevcut secim',
        ),
      );
      _entityLabelController.text = _selectedEntity!.title;
    }
    _dailyBudgetController.text = _dailyBudget.toStringAsFixed(0);
    _totalBudgetController.text = _totalBudget.toStringAsFixed(0);
    _durationController.text = _durationDays.toString();
    _applySellerLocationDefaultsIfNeeded();
  }

  String get _normalizedCreditCode =>
      _adCreditCodeService.normalizeCode(_creditCodeController.text);

  void _handleCreditCodeChanged() {
    if (!mounted) return;
    final currentCode = _normalizedCreditCode;
    if (currentCode.isEmpty) {
      setState(() {
        _creditCodePreview = null;
        _redeemedCreditCode = null;
        _redeemedCreditAmount = null;
      });
      _creditCodeLookupDebounce?.cancel();
      return;
    }
    if (_redeemedCreditCode != currentCode) {
      setState(() {
        _redeemedCreditAmount = null;
      });
    }
    _scheduleCreditCodeLookup();
  }

  void _scheduleCreditCodeLookup() {
    _creditCodeLookupDebounce?.cancel();
    final code = _normalizedCreditCode;
    if (code.isEmpty) {
      return;
    }
    _creditCodeLookupDebounce = Timer(const Duration(milliseconds: 350), () {
      _lookupCreditCode(code: code);
    });
  }

  Future<void> _loadAdCreditBalance({bool silent = false}) async {
    final sellerId = _effectiveSellerId;
    if (sellerId.isEmpty) return;
    if (mounted && !silent) {
      setState(() => _isLoadingAdCreditBalance = true);
    }
    try {
      final balance = await _adWalletService.getAvailableBalance(sellerId);
      if (!mounted) return;
      setState(() {
        _availableAdCreditBalance = balance;
      });
    } catch (error) {
      debugPrint('CampaignWizard ad credit balance load warning: $error');
    } finally {
      if (mounted && !silent) {
        setState(() => _isLoadingAdCreditBalance = false);
      }
    }
  }

  Future<void> _lookupCreditCode({String? code}) async {
    final requestedCode = _adCreditCodeService.normalizeCode(
      code ?? _creditCodeController.text,
    );
    if (requestedCode.isEmpty) {
      if (!mounted) return;
      setState(() {
        _creditCodePreview = null;
        _isCheckingCreditCode = false;
      });
      return;
    }
    if (mounted) {
      setState(() => _isCheckingCreditCode = true);
    }
    debugPrint('[AdCredit][Seller] lookup request started code=$requestedCode');
    try {
      final preview = await _adCreditCodeService.previewCode(requestedCode);
      if (!mounted) return;
      if (_normalizedCreditCode != requestedCode) {
        return;
      }
      setState(() {
        _creditCodePreview = preview;
      });
      debugPrint(
        '[AdCredit][Seller] lookup request completed code=$requestedCode canRedeem=${preview?.canRedeem} reason=${preview?.reason}',
      );
    } catch (error) {
      debugPrint(
        '[AdCredit][Seller] lookup request failed code=$requestedCode error=$error',
      );
      if (!mounted) return;
      if (_normalizedCreditCode != requestedCode) {
        return;
      }
      setState(() {
        _creditCodePreview = AdCreditCodePreview(
          code: requestedCode,
          amount: 0,
          status: 'missing',
          canRedeem: false,
          reason: 'lookup_failed',
          isActive: false,
          usageLimit: 0,
          usedCount: 0,
        );
      });
    } finally {
      if (mounted && _normalizedCreditCode == requestedCode) {
        setState(() => _isCheckingCreditCode = false);
      }
    }
  }

  Future<bool> _redeemCreditCodeIfNeeded({bool showSnackBar = true}) async {
    final code = _normalizedCreditCode;
    if (_selectedPaymentMethod != 'ad_credit' || code.isEmpty) {
      return true;
    }
    if (_redeemedCreditCode == code && (_redeemedCreditAmount ?? 0) > 0) {
      return true;
    }
    if (_creditCodePreview == null || _creditCodePreview!.code != code) {
      await _lookupCreditCode(code: code);
    }
    final preview = _creditCodePreview;
    if (preview == null || !preview.canRedeem) {
      if (showSnackBar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _creditCodeReasonLabel(preview?.reason ?? 'not_found'),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return false;
    }
    if (mounted) {
      setState(() => _isRedeemingCreditCode = true);
    }
    debugPrint('[AdCredit][Seller] redeem request started code=$code');
    try {
      final result = await _adCreditCodeService.redeemCode(code);
      if (!mounted) return false;
      setState(() {
        _redeemedCreditCode = code;
        _redeemedCreditAmount = result.amount;
        _creditCodePreview = preview.copyWith(
          status: 'redeemed',
          canRedeem: false,
          reason: 'already_used_by_seller',
          usedCount: preview.usedCount + 1,
        );
      });
      await _loadAdCreditBalance(silent: true);
      debugPrint(
        '[AdCredit][Seller] redeem request success code=$code amount=${result.amount} balance=${result.balanceAfter}',
      );
      if (!mounted) return true;
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.amount.toStringAsFixed(0)} TRY reklam kredisi bakiyenize eklendi.',
            ),
          ),
        );
      }
      return true;
    } catch (error) {
      debugPrint(
        '[AdCredit][Seller] redeem request failed code=$code error=$error',
      );
      if (mounted && showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mapRedeemErrorMessage(error)),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isRedeemingCreditCode = false);
      }
    }
  }

  String _creditCodeReasonLabel(String reason) {
    return switch (reason) {
      'ready' => 'Kod kullanima hazir.',
      'already_used_by_seller' => 'Bu kodu zaten kullanmissiniz.',
      'redeemed_by_current_seller' => 'Bu kod zaten sizin bakiyenize eklenmis.',
      'redeemed' => 'Bu kod daha once kullanilmis.',
      'usage_limit_reached' => 'Bu kodun kullanim hakki bitmis.',
      'exhausted' => 'Bu kodun kullanim hakki bitmis.',
      'assigned_to_another_seller' => 'Bu kod farkli bir saticiya atanmis.',
      'expired' => 'Bu kredi kodunun suresi dolmus.',
      'inactive' => 'Bu kredi kodu aktif degil.',
      'lookup_failed' => 'Kod kontrol edilemedi. Tekrar deneyin.',
      _ => 'Kod bulunamadi.',
    };
  }

  Color _creditCodeAccent(AdCreditCodePreview preview) {
    if (preview.canRedeem ||
        preview.reason == 'redeemed_by_current_seller' ||
        preview.reason == 'already_used_by_seller') {
      return const Color(0xFF16A34A);
    }
    if (preview.reason == 'assigned_to_another_seller' ||
        preview.reason == 'usage_limit_reached') {
      return const Color(0xFFEA580C);
    }
    return const Color(0xFFDC2626);
  }

  String _mapRedeemErrorMessage(Object error) {
    final raw = error.toString().toUpperCase();
    if (raw.contains('INVALID_CREDIT_CODE')) {
      return 'Kod bulunamadi.';
    }
    if (raw.contains('CREDIT_CODE_EXPIRED')) {
      return 'Bu kredi kodunun suresi dolmus.';
    }
    if (raw.contains('CREDIT_CODE_INACTIVE') ||
        raw.contains('CREDIT_CODE_NOT_ACTIVE')) {
      return 'Bu kredi kodu aktif degil.';
    }
    if (raw.contains('CREDIT_CODE_USAGE_LIMIT_REACHED')) {
      return 'Bu kredi kodunun kullanim hakki bitmis.';
    }
    if (raw.contains('CREDIT_CODE_ALREADY_USED_BY_THIS_SELLER')) {
      return 'Bu kodu zaten kullanmissiniz.';
    }
    if (raw.contains('CREDIT_CODE_NOT_ASSIGNED_TO_THIS_SELLER')) {
      return 'Bu kod farkli bir saticiya atanmis.';
    }
    if (raw.contains('AUTH_REQUIRED')) {
      return 'Kodu kullanmak icin tekrar giris yapin.';
    }
    return 'Kod kullanilamadi: $error';
  }

  Widget _buildAdCreditStatusPanel() {
    final preview = _creditCodePreview;
    final activeAmount = _redeemedCreditAmount ?? preview?.amount ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPaymentInfoPanel(
          icon: Icons.account_balance_wallet_rounded,
          accent: const Color(0xFF7C3AED),
          title: _isLoadingAdCreditBalance
              ? 'Reklam kredisi bakiyesi yukleniyor'
              : 'Mevcut reklam kredisi: ${_availableAdCreditBalance.toStringAsFixed(0)} TRY',
          description: _isLoadingAdCreditBalance
              ? 'Cuzdan bakiyeniz kontrol ediliyor.'
              : 'Kullanilan kredi kodlari ve bonus reklam puanlari burada birikir.',
        ),
        if (preview != null) ...[
          const SizedBox(height: 12),
          _buildPaymentInfoPanel(
            icon: preview.canRedeem
                ? Icons.qr_code_2_rounded
                : preview.reason == 'redeemed_by_current_seller'
                ? Icons.verified_rounded
                : Icons.info_outline_rounded,
            accent: _creditCodeAccent(preview),
            title: activeAmount > 0
                ? '${activeAmount.toStringAsFixed(0)} TRY kredi kodu'
                : 'Kredi kodu kontrolu',
            description:
                '${_creditCodeReasonLabel(preview.reason)}${preview.note?.trim().isNotEmpty == true ? ' Not: ${preview.note!.trim()}' : ''}',
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _creditCodeLookupDebounce?.cancel();
    _creditCodeController.removeListener(_handleCreditCodeChanged);
    _campaignNameController.dispose();
    _descriptionController.dispose();
    _creativeTitleController.dispose();
    _entityLabelController.dispose();
    _dailyBudgetController.dispose();
    _totalBudgetController.dispose();
    _durationController.dispose();
    _couponController.dispose();
    _offerController.dispose();
    _timePlanController.dispose();
    _creditCodeController.dispose();
    _giftSellerController.dispose();
    _giftAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F7FB),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _saveDraft,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Taslak Kaydet'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _publishCampaign,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.publish_outlined),
                  label: const Text('Yayinla'),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1280;
              final isTablet = constraints.maxWidth >= 900;
              final outerPadding = isDesktop ? 16.0 : 14.0;
              final leftPanel = SizedBox(
                width: isDesktop ? 248 : (isTablet ? 220 : double.infinity),
                child: CampaignStepper(
                  steps: _steps,
                  currentStep: _currentStep,
                  onStepSelected: (value) {
                    setState(() => _currentStep = value);
                  },
                  onClose: () => Navigator.of(context).maybePop(),
                ),
              );

              final centerPanel = Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildTopWorkspaceBar(),
                      const SizedBox(height: 18),
                      _buildContentCard(),
                    ],
                  ),
                ),
              );

              final rightPanel = SizedBox(
                width: isDesktop ? 316 : double.infinity,
                child: CampaignPreviewPanel(
                  previewTitle: _selectedObjectiveOption.title,
                  previewDescription: _previewDescription,
                  summaryItems: _summaryItems,
                  recommendations: _recommendations,
                  estimatedConversions: _estimatedConversions,
                ),
              );

              if (isDesktop) {
                return Padding(
                  padding: EdgeInsets.all(outerPadding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leftPanel,
                      const SizedBox(width: 14),
                      centerPanel,
                      const SizedBox(width: 14),
                      rightPanel,
                    ],
                  ),
                );
              }

              if (isTablet) {
                return Padding(
                  padding: EdgeInsets.all(outerPadding),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leftPanel,
                      const SizedBox(width: 14),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildTopWorkspaceBar(),
                              const SizedBox(height: 14),
                              _buildContentCard(),
                              const SizedBox(height: 14),
                              rightPanel,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SizedBox(height: 360, child: leftPanel),
                    const SizedBox(height: 16),
                    _buildTopWorkspaceBar(),
                    const SizedBox(height: 16),
                    _buildContentCard(),
                    const SizedBox(height: 16),
                    rightPanel,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopWorkspaceBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          const Icon(Icons.campaign_outlined, color: Color(0xFF2563EB)),
          Text(
            widget.existingCampaign == null
                ? 'Yeni Kampanya'
                : 'Kampanya Duzenle',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
          Text(
            _steps[_currentStep].title,
            style: const TextStyle(
              color: Color(0xFF334155),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _steps[_currentStep].title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _stepDescription(_currentStep),
            style: const TextStyle(
              color: Color(0xFF64748B),
              height: 1.5,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 18),
          _buildStepBody(),
          const SizedBox(height: 20),
          Row(
            children: [
              if (_currentStep > 0)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _currentStep -= 1),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Onceki'),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  if (_currentStep == _steps.length - 1) {
                    _publishCampaign();
                    return;
                  }
                  if (_validateStep(_currentStep)) {
                    setState(() => _currentStep += 1);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(
                  _currentStep == _steps.length - 1
                      ? Icons.publish_outlined
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  _currentStep == _steps.length - 1
                      ? 'Yayinla'
                      : 'Sonraki Adim',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_currentStep) {
      case 0:
        return CampaignObjectiveSelector(
          options: _objectiveOptions,
          selectedId: _selectedObjectiveId,
          onSelected: (value) {
            setState(() {
              _selectedObjectiveId = value;
              _selectedCampaignType = _recommendedCampaignTypeForSelectedGoal;
              _campaignTypeCustomized = false;
              _selectedEntity = null;
              _entityLabelController.clear();
              if (_selectedObjectiveId == 'nearby') {
                _distanceEnabled = true;
              }
              _applySellerLocationDefaultsIfNeeded();
            });
            _applyDefaultEntitySelection();
          },
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFormatRecommendationCard(),
            const SizedBox(height: 14),
            AdTypeSelector(
              options: _typeOptions,
              selectedId: _selectedCampaignType.dbValue,
              onSelected: (value) {
                final selectedType = _typeFromDbValue(value);
                setState(() {
                  _selectedCampaignType = selectedType;
                  _campaignTypeCustomized = true;
                  _selectedEntity = null;
                  _entityLabelController.clear();
                  if (_selectedCampaignType == AdCampaignType.storeBoost ||
                      _selectedCampaignType == AdCampaignType.geoPush) {
                    final sellerStore = _sellerStoreOption;
                    if (sellerStore != null) {
                      _selectedEntity = sellerStore;
                      _entityLabelController.text = sellerStore.title;
                    }
                  }
                  _applySellerLocationDefaultsIfNeeded();
                });
                if (selectedType == AdCampaignType.collectionBoost) {
                  unawaited(_ensureCollectionAvailableOrRedirect());
                }
              },
            ),
          ],
        );
      case 2:
        return _buildCreativeForm();
      case 3:
        return AudienceSelector(
          categories: _audienceCategories,
          subcategoryMap: _audienceSubcategories,
          targetingState: _audienceTargeting,
          onTargetingChanged: (value) {
            setState(() {
              _audienceTargeting = value;
              _audienceConfigured = value.hasAnySelection;
            });
          },
          onOpenCitySelector: _openCitySelector,
          cityLabel: _cityLabel,
          locationLocked: _isStoreLocationLocked,
          distanceEnabled: _distanceEnabled,
          distanceKm: _distanceKm,
          onDistanceToggle: (value) {
            setState(() {
              if (_isStoreLocationLocked) {
                _distanceEnabled = true;
                return;
              }
              _distanceEnabled = value;
              _cityConfigured = _selectedCities.isNotEmpty;
            });
          },
          onDistanceChanged: (value) {
            setState(() {
              _distanceKm = value;
              _cityConfigured = _selectedCities.isNotEmpty;
            });
          },
        );
      case 4:
        return BudgetPlanner(
          dailyBudgetController: _dailyBudgetController,
          totalBudgetController: _totalBudgetController,
          durationController: _durationController,
          onDailyBudgetChanged: _handleDailyBudgetChanged,
          onTotalBudgetChanged: _handleTotalBudgetChanged,
          onDurationChanged: _handleDurationChanged,
          estimatedConversions: _estimatedConversions,
          suggestedDailyBudget: _suggestedDailyBudget,
          suggestedTotalBudget: _suggestedTotalBudget,
          budgetConfigured: _budgetConfigured,
          onApplySuggestedBudget: _applySuggestedBudgetPreset,
        );
      case 5:
        return _buildOfferStep();
      case 6:
        return _buildScheduleStep();
      case 7:
        return _buildPreviewStep();
      case 8:
        return _buildPublishStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCreativeForm() {
    return Column(
      children: [
        TextField(
          controller: _campaignNameController,
          decoration: const InputDecoration(labelText: 'Kampanya adi'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Kisa aciklama'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _creativeTitleController,
          decoration: const InputDecoration(labelText: 'Kreatif baslik'),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: _openEntitySelector,
          child: AbsorbPointer(
            child: TextField(
              controller: _entityLabelController,
              decoration: InputDecoration(
                labelText: _entityFieldLabel,
                suffixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfferStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _couponEnabled,
          onChanged: (value) => setState(() => _couponEnabled = value),
          title: const Text('Kuponlu reklam aktif'),
          subtitle: const Text(
            'Sponsorlu urun + indirim veya ilk siparis kuponu gibi teklifleri acin.',
          ),
        ),
        if (_couponEnabled) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _couponController,
            decoration: const InputDecoration(labelText: 'Kupon kodu'),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _offerController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Teklif aciklamasi',
            hintText:
                'Sepete ekleyip almayanlara ozel teklif, ilk siparise %10 indirim vb.',
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleStep() {
    final range = _schedule;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _pickDateRange,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range_outlined, color: Color(0xFF2563EB)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    range == null
                        ? 'Tarih araligi secin'
                        : '${_formatDate(range.start)} - ${_formatDate(range.end)}',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _schedulePresets
              .map((preset) {
                final selected =
                    _timePlanController.text.trim() == preset.value;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _timePlanController.text = preset.value;
                      _scheduleConfigured = true;
                    });
                  },
                  label: Text(preset.label),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _timePlanController,
          onChanged: (_) {
            setState(() {
              _scheduleConfigured = _timePlanController.text.trim().isNotEmpty;
            });
          },
          decoration: const InputDecoration(labelText: 'Yayin saatleri'),
        ),
        const SizedBox(height: 14),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _runWeekdays,
          onChanged: (value) => setState(() => _runWeekdays = value),
          title: const Text('Hafta ici yayinda kalsin'),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _runWeekends,
          onChanged: (value) => setState(() => _runWeekends = value),
          title: const Text('Hafta sonu yayinda kalsin'),
        ),
      ],
    );
  }

  Widget _buildPreviewStep() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Panel onizlemesi',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _previewDescription,
            style: const TextStyle(color: Color(0xFF475569), height: 1.6),
          ),
          const SizedBox(height: 18),
          ..._summaryItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      item.label,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.value,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublishStep() {
    final giftAmount = double.tryParse(_giftAmountController.text.trim()) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChecklistTile(
          title: 'Kampanya amaci secildi',
          subtitle: _selectedObjectiveOption.title,
        ),
        _ChecklistTile(
          title: 'Reklam tipi belirlendi',
          subtitle: _campaignTypeTitle(_selectedCampaignType),
        ),
        _ChecklistTile(
          title: 'Icerik tamamlandi',
          subtitle: _selectedEntity?.title ?? 'Secim bekleniyor',
        ),
        _ChecklistTile(
          title: 'Hedefleme ve sehir secildi',
          subtitle: _cityLabel,
        ),
        _ChecklistTile(
          title: 'Butce ve yayin plani hazir',
          subtitle:
              '${_dailyBudget.toStringAsFixed(0)} TRY / ${_durationDays.toString()} gun',
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Odeme yonetimi',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Yayinlama oncesi odeme tipini secin. Kart ile odeme veya reklam kredisi kullanabilirsiniz.',
                    style: TextStyle(color: Color(0xFF64748B), height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  if (compact)
                    Column(
                      children: [
                        _buildPaymentMethodCard(
                          value: 'card',
                          title: 'Kart ile odeme',
                          description:
                              'Guvenli odeme altyapisi ile kampanya tahsilatini karttan yonetin.',
                          icon: Icons.credit_card_rounded,
                        ),
                        const SizedBox(height: 12),
                        _buildPaymentMethodCard(
                          value: 'ad_credit',
                          title: 'Reklam kredisi',
                          description:
                              'Mevcut reklam kredinizi veya size tanimlanan kodu kullanin.',
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: _buildPaymentMethodCard(
                            value: 'card',
                            title: 'Kart ile odeme',
                            description:
                                'Guvenli odeme altyapisi ile kampanya tahsilatini karttan yonetin.',
                            icon: Icons.credit_card_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildPaymentMethodCard(
                            value: 'ad_credit',
                            title: 'Reklam kredisi',
                            description:
                                'Mevcut reklam kredinizi veya size tanimlanan kodu kullanin.',
                            icon: Icons.account_balance_wallet_rounded,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  if (_selectedPaymentMethod == 'card')
                    _buildPaymentInfoPanel(
                      icon: Icons.shield_outlined,
                      accent: const Color(0xFF2563EB),
                      title: 'Kart ile odeme secildi',
                      description:
                          'Kart tahsilati yayin oncesi odeme adiminda islenir. Kampanya metadata alaninda kart verisi tutulmaz.',
                    )
                  else ...[
                    TextField(
                      controller: _creditCodeController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Reklam kredisi kodu',
                        hintText: 'Varsa hediye veya promosyon kodunu yazin',
                        prefixIcon: const Icon(Icons.qr_code_rounded),
                        suffixIcon: _isCheckingCreditCode
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAdCreditStatusPanel(),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed:
                                _isRedeemingCreditCode ||
                                    _normalizedCreditCode.isEmpty ||
                                    (_redeemedCreditCode ==
                                            _normalizedCreditCode &&
                                        (_redeemedCreditAmount ?? 0) > 0)
                                ? null
                                : _redeemCreditCodeIfNeeded,
                            icon: _isRedeemingCreditCode
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.redeem_rounded),
                            label: Text(
                              _redeemedCreditCode == _normalizedCreditCode &&
                                      (_redeemedCreditAmount ?? 0) > 0
                                  ? 'Kod kullanildi'
                                  : 'Kodu kullan',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _giftCreditEnabled,
                      onChanged: (value) =>
                          setState(() => _giftCreditEnabled = value),
                      title: const Text(
                        'Baska bir saticiya reklam hediyesi tanimla',
                      ),
                      subtitle: const Text(
                        'Istediginiz satici icin reklam kredisi tanimlayin.',
                      ),
                    ),
                    if (_giftCreditEnabled) ...[
                      const SizedBox(height: 12),
                      if (compact)
                        Column(
                          children: [
                            TextField(
                              controller: _giftSellerController,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Alici satici ID',
                                hintText: 'Hediye verilecek satici ID',
                                prefixIcon: Icon(Icons.storefront_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _giftAmountController,
                              onChanged: (_) => setState(() {}),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Hediye kredi tutari',
                                hintText: 'Orn. 500',
                                suffixText: 'TRY',
                                prefixIcon: Icon(Icons.card_giftcard_rounded),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _giftSellerController,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  labelText: 'Alici satici ID',
                                  hintText: 'Hediye verilecek satici ID',
                                  prefixIcon: Icon(Icons.storefront_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _giftAmountController,
                                onChanged: (_) => setState(() {}),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Hediye kredi tutari',
                                  hintText: 'Orn. 500',
                                  suffixText: 'TRY',
                                  prefixIcon: Icon(Icons.card_giftcard_rounded),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      _buildPaymentInfoPanel(
                        icon: Icons.redeem_rounded,
                        accent: const Color(0xFF7C3AED),
                        title: 'Hediye reklam kredisi',
                        description: giftAmount > 0
                            ? '${giftAmount.toStringAsFixed(0)} TRY reklam kredisi, ${_giftSellerController.text.trim().isEmpty ? 'secilecek saticiya' : _giftSellerController.text.trim()} icin yayinlama sirasinda tanimlanir.'
                            : 'Tutar ve alici satici ID girildiginde yayinlama sirasinda bonus reklam kredisi tanimlanir.',
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard({
    required String value,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final selected = _selectedPaymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFDBEAFE)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: selected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInfoPanel({
    required IconData icon,
    required Color accent,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _schedule,
    );
    if (result == null) return;
    setState(() {
      _schedule = result;
      _durationDays = result.duration.inDays.clamp(1, 365);
      _durationController.text = _durationDays.toString();
      _totalBudget = _dailyBudget * _durationDays;
      _totalBudgetController.text = _totalBudget.toStringAsFixed(0);
    });
  }

  Future<void> _openEntitySelector() async {
    if (_selectedCampaignType == AdCampaignType.collectionBoost &&
        _resolvedSellerCollections.isEmpty &&
        !_isLoadingSellerCollections) {
      await _ensureCollectionAvailableOrRedirect();
      if (!mounted) return;
      if (_resolvedSellerCollections.isEmpty) return;
    }
    final entities = _entityOptionsForType(_selectedCampaignType);
    final selected = await showDialog<_EntityOption>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560, maxHeight: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _entityFieldLabel,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      if (_selectedCampaignType ==
                          AdCampaignType.collectionBoost)
                        OutlinedButton.icon(
                          onPressed: _showCreateCollectionDialog,
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Liste olustur'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildEntitySelectionList(entities)),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null) return;
    setState(() {
      _selectedEntity = selected;
      _entityLabelController.text = selected.title;
    });
  }

  Future<void> _showCreateCollectionDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    var visibility = ProductListVisibility.private;
    var isSubmitting = false;

    final createdOption = await showDialog<_EntityOption>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Liste adi girmelisiniz.')),
                );
                return;
              }

              setModalState(() => isSubmitting = true);
              try {
                final listId = _appState.createProductList(
                  name,
                  description: descriptionController.text.trim(),
                  visibility: visibility,
                );
                await _loadSellerCollections();
                _EntityOption? option;
                for (final item in _sellerCollections) {
                  if (item.id == listId) {
                    option = item;
                    break;
                  }
                }
                option ??= _EntityOption(
                  id: listId,
                  title: name,
                  subtitle: descriptionController.text.trim().isEmpty
                      ? 'Henuz urun eklenmedi'
                      : descriptionController.text.trim(),
                );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(option);
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Liste olusturulamadi: $error')),
                );
              } finally {
                if (dialogContext.mounted) {
                  setModalState(() => isSubmitting = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Yeni liste olustur'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Liste adi',
                        hintText: 'Ornek: Yeni sezon one cikanlar',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Aciklama',
                        hintText: 'Listeyi kisaca anlatin',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ProductListVisibility>(
                      initialValue: visibility,
                      decoration: const InputDecoration(
                        labelText: 'Gorunurluk',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ProductListVisibility.private,
                          child: Text('Ozel'),
                        ),
                        DropdownMenuItem(
                          value: ProductListVisibility.public,
                          child: Text('Herkese acik'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() => visibility = value);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Vazgec'),
                ),
                FilledButton.icon(
                  onPressed: isSubmitting ? null : submit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded, size: 18),
                  label: Text(isSubmitting ? 'Olusturuluyor...' : 'Olustur'),
                ),
              ],
            );
          },
        );
      },
    );

    if (createdOption == null || !mounted) return;
    setState(() {
      _selectedEntity = createdOption;
      _entityLabelController.text = createdOption.title;
    });
  }

  Widget _buildEntitySelectionList(List<_EntityOption> entities) {
    if ((_selectedCampaignType == AdCampaignType.productBoost &&
            _isLoadingSellerProducts) ||
        (_selectedCampaignType == AdCampaignType.collectionBoost &&
            _isLoadingSellerCollections)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_selectedCampaignType == AdCampaignType.productBoost &&
        (_sellerProductsError ?? '').isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 36,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            const Text(
              'Urunler yuklenemedi',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _sellerProductsError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadSellerProducts,
              child: const Text('Tekrar dene'),
            ),
          ],
        ),
      );
    }
    if (_selectedCampaignType == AdCampaignType.collectionBoost &&
        (_sellerCollectionsError ?? '').isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.collections_bookmark_outlined,
              size: 36,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            const Text(
              'Listeler yuklenemedi',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _sellerCollectionsError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  onPressed: _loadSellerCollections,
                  child: const Text('Tekrar dene'),
                ),
                OutlinedButton.icon(
                  onPressed: _showCreateCollectionDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Liste olustur'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    if (entities.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _selectedCampaignType == AdCampaignType.collectionBoost
                  ? Icons.collections_bookmark_outlined
                  : Icons.inventory_2_outlined,
              size: 36,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            Text(
              _selectedCampaignType == AdCampaignType.productBoost
                  ? 'Bu saticiya ait urun bulunamadi'
                  : _selectedCampaignType == AdCampaignType.collectionBoost
                  ? 'Bu saticiya ait liste bulunamadi'
                  : 'Secilebilir kayit bulunmuyor',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            if (_selectedCampaignType == AdCampaignType.collectionBoost) ...[
              const SizedBox(height: 10),
              const Text(
                'Yeni bir liste olusturup bu kampanyada hemen kullanabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), height: 1.5),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _showCreateCollectionDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Liste olustur'),
              ),
            ],
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: entities.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final option = entities[index];
        return InkWell(
          onTap: () => Navigator.of(context).pop(option),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                if ((option.imageUrl ?? '').isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      option.imageUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: Color(0xFF64748B),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF64748B),
                    ),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        option.subtitle,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCitySelector() async {
    if (_isStoreLocationLocked) return;
    final initialCity = _selectedCities.isNotEmpty
        ? _selectedCities.first
        : null;
    final initialDistrict = _selectedDistrict;
    final result = await showDialog<_CitySelectionResult>(
      context: context,
      builder: (context) {
        var selectedCity = initialCity;
        var selectedDistrict = initialDistrict;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final districtOptions = selectedCity == null
                ? const <String>[]
                : (_districtsByCity[selectedCity] ?? const <String>[]);
            return Dialog(
              insetPadding: const EdgeInsets.all(24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 540,
                  maxHeight: 520,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Il / Ilce secimi',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Once il secin, sonra isterseniz ilce ile hedeflemeyi daraltin.',
                        style: TextStyle(color: Color(0xFF64748B), height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCity,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Il',
                          hintText: 'Il secin',
                        ),
                        items: _cities
                            .map(
                              (city) => DropdownMenuItem<String>(
                                value: city,
                                child: Text(city),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setStateDialog(() {
                            selectedCity = value;
                            selectedDistrict = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: districtOptions.contains(selectedDistrict)
                            ? selectedDistrict
                            : '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Ilce',
                          hintText: 'Tum ilceler',
                        ),
                        items: <DropdownMenuItem<String>>[
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Tum ilceler'),
                          ),
                          ...districtOptions.map(
                            (district) => DropdownMenuItem<String>(
                              value: district,
                              child: Text(district),
                            ),
                          ),
                        ],
                        onChanged: selectedCity == null
                            ? null
                            : (value) {
                                setStateDialog(() {
                                  selectedDistrict = (value ?? '').isEmpty
                                      ? null
                                      : value;
                                });
                              },
                      ),
                      if (selectedCity != null && districtOptions.isEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Bu il icin ilce listesi henuz tanimli degil. Il bazli hedefleme kullanilacak.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                      const Spacer(),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Vazgec'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: selectedCity == null
                                ? null
                                : () {
                                    Navigator.of(context).pop(
                                      _CitySelectionResult(
                                        city: selectedCity!,
                                        district: selectedDistrict,
                                      ),
                                    );
                                  },
                            child: const Text('Kaydet'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    setState(() {
      _selectedCities = <String>{result.city};
      _selectedDistrict = result.district;
      _cityConfigured = true;
    });
  }

  void _handleDailyBudgetChanged(String value) {
    setState(() {
      _dailyBudget = double.tryParse(value) ?? 0;
      _totalBudget = _dailyBudget * _durationDays;
      _totalBudgetController.text = _totalBudget.toStringAsFixed(0);
      _budgetConfigured = _dailyBudget > 0 && _totalBudget >= _dailyBudget;
    });
  }

  void _handleTotalBudgetChanged(String value) {
    setState(() {
      _totalBudget = double.tryParse(value) ?? 0;
      _budgetConfigured = _dailyBudget > 0 && _totalBudget >= _dailyBudget;
    });
  }

  void _handleDurationChanged(String value) {
    setState(() {
      _durationDays = int.tryParse(value) ?? _durationDays;
      if (_durationDays <= 0) _durationDays = 1;
      _totalBudget = _dailyBudget * _durationDays;
      _totalBudgetController.text = _totalBudget.toStringAsFixed(0);
      _budgetConfigured = _dailyBudget > 0 && _totalBudget >= _dailyBudget;
      if (_schedule != null) {
        _schedule = DateTimeRange(
          start: _schedule!.start,
          end: _schedule!.start.add(Duration(days: _durationDays)),
        );
        _scheduleConfigured = true;
      }
    });
  }

  Future<void> _loadSellerProducts() async {
    setState(() {
      _isLoadingSellerProducts = true;
      _sellerProductsError = null;
    });
    try {
      final requestedSellerId = _effectiveSellerId;
      final fallbackSellerId = _storeService.currentUserId?.trim() ?? '';
      var rows = await _storeService.getProductsBySellerId(requestedSellerId);
      if (rows.isEmpty &&
          fallbackSellerId.isNotEmpty &&
          fallbackSellerId != requestedSellerId) {
        rows = await _storeService.getProductsBySellerId(fallbackSellerId);
      }
      final items = rows
          .map(_mapSellerProductToOption)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
      if (!mounted) return;
      setState(() {
        _sellerProducts = items;
        _isLoadingSellerProducts = false;
      });
      _syncSelectedEntityFromExisting();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sellerProductsError = error.toString();
        _isLoadingSellerProducts = false;
      });
    }
  }

  Future<void> _loadSellerCollections() async {
    setState(() {
      _isLoadingSellerCollections = true;
      _sellerCollectionsError = null;
    });
    try {
      final lists = await _productListService.getOwnedLists();
      final remoteItems = lists
          .map(_mapProductListToOption)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
      final items = _mergeCollectionOptions(remoteItems);
      if (!mounted) return;
      setState(() {
        _sellerCollections = items;
        _isLoadingSellerCollections = false;
      });
      _syncSelectedEntityFromExisting();
      _applyDefaultCollectionSelectionIfNeeded();
    } catch (error) {
      final fallbackItems = _mergeCollectionOptions(const <_EntityOption>[]);
      if (!mounted) return;
      setState(() {
        _sellerCollections = fallbackItems;
        _sellerCollectionsError = fallbackItems.isEmpty
            ? error.toString()
            : null;
        _isLoadingSellerCollections = false;
      });
      _applyDefaultCollectionSelectionIfNeeded();
    }
  }

  List<_EntityOption> get _localSellerCollections {
    return _appState.productLists
        .map(_mapProductListToOption)
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  List<_EntityOption> get _resolvedSellerCollections =>
      _mergeCollectionOptions(_sellerCollections);

  List<_EntityOption> _mergeCollectionOptions(List<_EntityOption> base) {
    final merged = <String, _EntityOption>{};
    for (final item in <_EntityOption>[...base, ..._localSellerCollections]) {
      final id = item.id.trim();
      if (id.isEmpty) continue;
      merged[id] = item;
    }
    final items = merged.values.toList(growable: false);
    items.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
    return items;
  }

  void _applyDefaultCollectionSelectionIfNeeded() {
    if (!mounted || _selectedCampaignType != AdCampaignType.collectionBoost) {
      return;
    }
    final collections = _resolvedSellerCollections;
    if (collections.isEmpty) return;
    final selectedId = _selectedEntity?.id.trim() ?? '';
    final stillExists = collections.any((item) => item.id == selectedId);
    if (stillExists) return;
    setState(() {
      _selectedEntity = collections.first;
      _entityLabelController.text = collections.first.title;
    });
  }

  Future<void> _loadSellerStore() async {
    try {
      final summary = await _storeService.getBusinessSummaryBySellerId(
        _effectiveSellerId,
      );
      final storeProfile = await _storeService.getStoreProfile();
      if (!mounted) return;
      if (summary == null && storeProfile == null) return;

      final businessName =
          summary?['name']?.toString().trim() ??
          storeProfile?['storeName']?.toString().trim() ??
          '';
      if (businessName.isEmpty) return;

      final category =
          summary?['category']?.toString().trim() ??
          storeProfile?['category']?.toString().trim() ??
          '';
      final option = _EntityOption(
        id: summary?['seller_id']?.toString().trim().isNotEmpty == true
            ? summary!['seller_id'].toString().trim()
            : _effectiveSellerId,
        title: businessName,
        subtitle: category.isEmpty
            ? 'Kendi magazaniz'
            : '$category • Kendi magazaniz',
        imageUrl: summary?['logo']?.toString(),
      );

      final storeCity = storeProfile?['city']?.toString().trim();
      final storeDistrict = storeProfile?['district']?.toString().trim();

      setState(() {
        _sellerStoreOption = option;
        _sellerCity = (storeCity ?? '').isEmpty ? null : storeCity;
        _sellerDistrict = (storeDistrict ?? '').isEmpty ? null : storeDistrict;
      });

      _applySellerLocationDefaultsIfNeeded();
      _syncSelectedEntityFromExisting();
      _applyDefaultEntitySelection();
    } catch (_) {}
  }

  bool get _isStoreLocationLocked {
    return _selectedObjectiveId == 'nearby' && (_sellerCity ?? '').isNotEmpty;
  }

  void _applySellerLocationDefaultsIfNeeded() {
    if (!_isStoreLocationLocked) return;
    final city = (_sellerCity ?? '').trim();
    if (city.isEmpty) return;
    _selectedCities = <String>{city};
    _selectedDistrict = (_sellerDistrict ?? '').trim().isEmpty
        ? null
        : _sellerDistrict!.trim();
    _cityConfigured = true;
    _distanceEnabled = true;
  }

  _EntityOption _mapSellerProductToOption(Map<String, dynamic> row) {
    final price = (row['price'] as num?)?.toDouble() ?? 0;
    final stock = (row['stock'] as num?)?.toInt() ?? 0;
    final category =
        row['main_category']?.toString() ??
        row['sub_category']?.toString() ??
        'Kategori';
    final imageUrls = row['image_urls'];
    String? imageUrl = row['image_url']?.toString();
    if ((imageUrl ?? '').isEmpty && imageUrls is List && imageUrls.isNotEmpty) {
      imageUrl = imageUrls.first?.toString();
    }
    return _EntityOption(
      id: row['id']?.toString() ?? '',
      title: row['name']?.toString() ?? 'Adsiz urun',
      subtitle:
          '$category • ${price.toStringAsFixed(0)} TRY${stock > 0 ? ' • Stok: $stock' : ''}',
      imageUrl: imageUrl,
    );
  }

  _EntityOption _mapProductListToOption(dynamic list) {
    final productCount = list.productIds.isNotEmpty
        ? list.productIds.length
        : list.products.length;
    final description = (list.description?.toString().trim() ?? '');
    final countLabel = productCount > 0
        ? '$productCount urun'
        : 'Henuz urun eklenmedi';
    return _EntityOption(
      id: list.id?.toString() ?? '',
      title: list.name?.toString() ?? 'Adsiz liste',
      subtitle: description.isNotEmpty
          ? '$countLabel • $description'
          : countLabel,
      imageUrl: list.iconUrl?.toString(),
    );
  }

  void _syncSelectedEntityFromExisting() {
    final campaign = widget.existingCampaign;
    if (campaign == null || _selectedEntity != null) return;
    final entityId = campaign.assets.isNotEmpty
        ? campaign.assets.first.entityId
        : null;
    if ((entityId ?? '').isEmpty) return;
    final options = _entityOptionsForType(campaign.type);
    for (final item in options) {
      if (item.id == entityId) {
        if (!mounted) return;
        setState(() {
          _selectedEntity = item;
          _entityLabelController.text = item.title;
        });
        return;
      }
    }
  }

  void _applyDefaultEntitySelection() {
    if (!mounted ||
        widget.existingCampaign != null ||
        _selectedEntity != null) {
      return;
    }

    if ((_selectedCampaignType == AdCampaignType.storeBoost ||
            _selectedCampaignType == AdCampaignType.geoPush) &&
        _sellerStoreOption != null) {
      setState(() {
        _selectedEntity = _sellerStoreOption;
        _entityLabelController.text = _sellerStoreOption!.title;
      });
    }
  }

  ProductList? get _selectedCollectionModel {
    if (_selectedCampaignType != AdCampaignType.collectionBoost) return null;
    final entityId = _selectedEntity?.id.trim() ?? '';
    if (entityId.isEmpty) return null;
    return _appState.getProductListById(entityId);
  }

  Future<void> _ensurePromotedCollectionIsPublic() async {
    final list = _selectedCollectionModel;
    if (list == null || list.isPublic) return;
    _appState.updateProductListVisibility(
      list.id,
      ProductListVisibility.public,
    );
  }

  void _closeWithCampaignResult(AdCampaign campaign) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop(campaign);
      return;
    }
    Navigator.of(context, rootNavigator: true).pop(campaign);
  }

  Future<void> _saveDraft() async {
    setState(() => _isSubmitting = true);
    try {
      await _ensurePromotedCollectionIsPublic();
      final draftCampaign = _buildCampaign(status: CampaignStatus.draft);
      if (draftCampaign.sellerId.trim() != _effectiveSellerId) {
        debugPrint(
          'Seller ads sellerId mismatch fixed. campaignSellerId=${draftCampaign.sellerId} widgetSellerId=${widget.sellerId}',
        );
      }
      debugPrint(
        'Seller ads draft save requested id=${draftCampaign.id} status=${draftCampaign.status.dbValue} sellerId=${draftCampaign.sellerId} storeId=${draftCampaign.storeId} widgetSellerId=${widget.sellerId}',
      );
      final saved = await _campaignService.saveCampaign(draftCampaign);
      debugPrint(
        'Seller ads draft save completed id=${saved.id} status=${saved.status.dbValue} sellerId=${saved.sellerId} storeId=${saved.storeId}',
      );
      if (!mounted) return;
      _closeWithCampaignResult(saved);
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString();
      final userMsg = msg.contains('does not exist') || msg.contains('42P01')
          ? 'Reklam sistemi henüz kurulmamış. Lütfen yöneticinize başvurun.'
          : msg.contains('permission denied') || msg.contains('42501')
          ? 'Kampanya kaydedilemedi: yetki hatası. Lütfen tekrar giriş yapın.'
          : msg.contains('TimeoutException')
          ? 'Kampanya kaydedilemedi: sunucu zamanında yanıt vermedi.'
          : msg.contains('Failed host lookup') ||
                msg.contains('SocketException') ||
                msg.contains('ClientException')
          ? 'Kampanya kaydedilemedi: bağlantı hatası oluştu.'
          : 'Kampanya kaydedilemedi: $msg';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMsg),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _publishCampaign() async {
    if (!_validatePublish()) return;
    setState(() => _isSubmitting = true);
    try {
      final creditReady = await _redeemCreditCodeIfNeeded(showSnackBar: true);
      if (!creditReady) {
        if (mounted) {
          setState(() {
            _currentStep = 8;
          });
        }
        return;
      }
      await _ensurePromotedCollectionIsPublic();
      final draft = await _campaignService.saveCampaign(
        _buildCampaign(status: CampaignStatus.draft),
      );
      final submitted = await _campaignService.submitForReview(draft);
      try {
        await _grantGiftCreditIfNeeded(submitted);
      } catch (error) {
        debugPrint('Seller ads gift credit grant warning: $error');
      }
      if (!mounted) return;
      _closeWithCampaignResult(submitted);
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString();
      final userMsg = msg.contains('does not exist') || msg.contains('42P01')
          ? 'Reklam sistemi henüz kurulmamış. Lütfen yöneticinize başvurun.'
          : msg.contains('permission denied') || msg.contains('42501')
          ? 'Kampanya gönderilemedi: yetki hatası. Lütfen tekrar giriş yapın.'
          : 'Kampanya gönderilemedi: $msg';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userMsg),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  bool _validatePublish() {
    for (var step = 0; step <= 6; step += 1) {
      if (!_validateStep(step, showError: false)) {
        setState(() => _currentStep = step);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_validationMessageForStep(step))),
        );
        return false;
      }
    }
    if (!_validatePaymentSettings(showError: false)) {
      setState(() => _currentStep = 8);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_validationMessageForStep(8))));
      return false;
    }
    return true;
  }

  bool _validateStep(int step, {bool showError = true}) {
    final valid = switch (step) {
      0 => _selectedObjectiveId.isNotEmpty,
      1 => true,
      2 =>
        _campaignNameController.text.trim().isNotEmpty &&
            _creativeTitleController.text.trim().isNotEmpty &&
            _selectedEntity != null,
      3 =>
        (_audienceTargeting.primaryCategory ?? '').isNotEmpty &&
            _selectedCities.isNotEmpty,
      4 =>
        _dailyBudget > 0 && _durationDays > 0 && _totalBudget >= _dailyBudget,
      5 => !_couponEnabled || _couponController.text.trim().isNotEmpty,
      6 => _timePlanController.text.trim().isNotEmpty && _schedule != null,
      8 => _validatePaymentSettings(showError: false),
      _ => true,
    };
    if (!valid && showError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_validationMessageForStep(step))));
    }
    return valid;
  }

  String _validationMessageForStep(int step) {
    return switch (step) {
      2 => 'Kampanya adi, kreatif baslik ve reklam hedefi secilmeli.',
      3 => 'Kategori, detayli hedefleme ve sehir secimi tamamlanmali.',
      4 => 'Butce ve sure alanlarini gecerli doldurun.',
      5 => 'Kupon aciksa kupon kodu girin.',
      6 => 'Yayin saatleri ve tarih araligi belirleyin.',
      8 =>
        'Yetersiz bakiye. Reklam kredisi seciliyse toplam butceyi karsilayacak kredi olmali; kart ile odeme seciliyse odeme tamamlanmadan yayinlanmaz.',
      _ => 'Bu adim tamamlanmali.',
    };
  }

  bool _validatePaymentSettings({bool showError = true}) {
    final giftAmount = double.tryParse(_giftAmountController.text.trim()) ?? 0;
    final previewAmount = (_creditCodePreview?.canRedeem ?? false)
        ? _creditCodePreview!.amount
        : 0;
    final resolvedAdCreditBalance = _availableAdCreditBalance + previewAmount;
    final hasAdCreditBalance =
        _totalBudget > 0 && resolvedAdCreditBalance >= _totalBudget;
    const cardPaymentCompleted = false;
    final valid =
        _selectedPaymentMethod.isNotEmpty &&
        (_selectedPaymentMethod == 'ad_credit'
            ? hasAdCreditBalance
            : cardPaymentCompleted) &&
        (_selectedPaymentMethod != 'ad_credit' ||
            !_giftCreditEnabled ||
            (_giftSellerController.text.trim().isNotEmpty && giftAmount > 0));
    if (!valid && showError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_validationMessageForStep(8))));
    }
    return valid;
  }

  Future<void> _grantGiftCreditIfNeeded(AdCampaign campaign) async {
    if (_selectedPaymentMethod != 'ad_credit' || !_giftCreditEnabled) {
      return;
    }
    final recipientSellerId = _giftSellerController.text.trim();
    final giftAmount = double.tryParse(_giftAmountController.text.trim()) ?? 0;
    if (recipientSellerId.isEmpty || giftAmount <= 0) {
      return;
    }
    await _adWalletService.grantBonusCredit(
      sellerId: recipientSellerId,
      amount: giftAmount,
      reference: campaign.id,
      approvedBy: _effectiveSellerId,
      note:
          '${campaign.name} kampanyasi yayinlanirken tanimlanan hediye reklam kredisi',
      metadata: <String, dynamic>{
        'campaign_id': campaign.id,
        'source_seller_id': _effectiveSellerId,
        'ad_credit_code': _normalizedCreditCode,
        'gift_payment_method': _selectedPaymentMethod,
      },
    );
  }

  AdCampaign _buildCampaign({required CampaignStatus status}) {
    final now = DateTime.now();
    final id =
        widget.existingCampaign?.id ?? 'cmp-${now.microsecondsSinceEpoch}';
    final resolvedSellerId =
        (widget.existingCampaign?.sellerId ?? _effectiveSellerId).trim();
    final objective = _objectiveForId(_selectedObjectiveId);
    final schedule =
        _schedule ??
        DateTimeRange(
          start: now,
          end: now.add(Duration(days: _durationDays)),
        );
    final selectedCollection = _selectedCollectionModel;
    final asset = CampaignAsset(
      id: widget.existingCampaign?.assets.isNotEmpty == true
          ? widget.existingCampaign!.assets.first.id
          : null,
      campaignId: id,
      assetType: _assetTypeForCampaign(_selectedCampaignType),
      entityId: _selectedEntity?.id,
      title: _creativeTitleController.text.trim(),
      subtitle: _descriptionController.text.trim(),
      mediaUrl: _selectedEntity?.imageUrl,
      placements: AdCampaignHelper.defaultPlacementsForType(
        _selectedCampaignType,
      ),
      metadata: <String, dynamic>{
        'collection_category': selectedCollection?.category,
        'collection_sub_category': selectedCollection?.subCategory,
      },
    );
    final target = CampaignTarget(
      id: widget.existingCampaign?.target?.id,
      campaignId: id,
      objective: objective,
      placements: AdCampaignHelper.defaultPlacementsForType(
        _selectedCampaignType,
      ),
      categories: _audienceCategoryPayload,
      cityCodes: _selectedCities.toList(growable: false),
      radiusMeters: _distanceEnabled ? (_distanceKm * 1000).round() : null,
      eventLookbackDays: AdsDefaults.defaultLookbackDays,
      frequencyCapPerDay:
          widget.existingCampaign?.frequencyCapPerUser ??
          AdsDefaults.defaultFrequencyCapPerUser,
      retargetingWindowDays: AdsDefaults.defaultRetargetingWindowDays,
      metadata: <String, dynamic>{
        'all_cities': false,
        'selected_district': _selectedDistrict,
        'advanced_targeting': _audienceTargeting.toMetadata(),
      },
    );
    return (widget.existingCampaign ??
            AdCampaign(
              id: id,
              sellerId: resolvedSellerId,
              storeId: widget.existingCampaign?.storeId,
              name: _campaignNameController.text.trim().isEmpty
                  ? 'Taslak Kampanya'
                  : _campaignNameController.text.trim(),
              description: _descriptionController.text.trim(),
              type: _selectedCampaignType,
              objective: objective,
              status: status,
              billingModel: AdCampaignHelper.defaultBillingModelForObjective(
                objective,
              ),
              dailyBudget: _dailyBudget,
              totalBudget: _totalBudget,
              spentAmount: widget.existingCampaign?.spentAmount ?? 0,
              remainingBalance: _totalBudget,
              bidAmount: AdsDefaults.defaultBidAmount,
              currency: AdsDefaults.defaultCurrency,
              startsAt: schedule.start,
              endsAt: schedule.end,
              isPremiumPlacementEnabled: _premiumPlacement,
              useAiSuggestions: _useAiSuggestions,
              frequencyCapPerUser: AdsDefaults.defaultFrequencyCapPerUser,
              target: target,
              assets: <CampaignAsset>[asset],
              metadata: const <String, dynamic>{},
              createdAt: widget.existingCampaign?.createdAt ?? now,
              updatedAt: now,
            ))
        .copyWith(
          sellerId: resolvedSellerId,
          name: _campaignNameController.text.trim().isEmpty
              ? 'Taslak Kampanya'
              : _campaignNameController.text.trim(),
          description: _descriptionController.text.trim(),
          type: _selectedCampaignType,
          objective: objective,
          status: status,
          dailyBudget: _dailyBudget,
          totalBudget: _totalBudget,
          remainingBalance:
              (_totalBudget - (widget.existingCampaign?.spentAmount ?? 0))
                  .clamp(0.0, _totalBudget),
          startsAt: schedule.start,
          endsAt: schedule.end,
          assets: <CampaignAsset>[asset],
          target: target,
          isPremiumPlacementEnabled: _premiumPlacement,
          useAiSuggestions: _useAiSuggestions,
          metadata: <String, dynamic>{
            ...?widget.existingCampaign?.metadata,
            'objective_id': _selectedObjectiveId,
            'coupon_enabled': _couponEnabled,
            'coupon_code': _couponController.text.trim(),
            'offer_note': _offerController.text.trim(),
            'time_plan': _timePlanController.text.trim(),
            'run_weekdays': _runWeekdays,
            'run_weekends': _runWeekends,
            'entity_label': _selectedEntity?.title,
            'collection_category': selectedCollection?.category,
            'collection_sub_category': selectedCollection?.subCategory,
            'payment_method': _selectedPaymentMethod,
            'ad_credit_code': _normalizedCreditCode,
            'ad_credit_balance': _availableAdCreditBalance,
            'ad_credit_redeemed_amount':
                _redeemedCreditCode == _normalizedCreditCode
                ? (_redeemedCreditAmount ?? 0)
                : 0,
            'gift_credit_enabled':
                _selectedPaymentMethod == 'ad_credit' && _giftCreditEnabled,
            'gift_credit_recipient_seller_id':
                _selectedPaymentMethod == 'ad_credit'
                ? _giftSellerController.text.trim()
                : '',
            'gift_credit_amount': _selectedPaymentMethod == 'ad_credit'
                ? _giftAmountController.text.trim()
                : '',
          },
        );
  }

  double get _suggestedDailyBudget => AdCampaignHelper.suggestedDailyBudget(
    objective: _objectiveForId(_selectedObjectiveId),
    premiumPlacement: _premiumPlacement,
  );

  double get _suggestedTotalBudget => _suggestedDailyBudget * _durationDays;

  String get _paymentMethodLabel => _selectedPaymentMethod == 'ad_credit'
      ? 'Reklam kredisi'
      : 'Kart ile odeme';

  void _applySuggestedBudgetPreset() {
    _dailyBudget = _suggestedDailyBudget;
    _totalBudget = _suggestedTotalBudget;
    _dailyBudgetController.text = _dailyBudget.toStringAsFixed(0);
    _totalBudgetController.text = _totalBudget.toStringAsFixed(0);
    _budgetConfigured = true;
  }

  List<AdTypeOption> get _typeOptions {
    final available = _campaignService.getAvailableTypes(
      _objectiveForId(_selectedObjectiveId),
    );
    final recommended = _campaignService.getRecommendedTypes(
      _objectiveForId(_selectedObjectiveId),
    );
    return <AdTypeOption>[
          AdTypeOption(
            id: AdCampaignType.productBoost.dbValue,
            title: 'Urun one cikarma',
            description:
                'Urunlerinizi ana sayfa, arama sonuclari ve benzer urun alanlarinda sponsorlu olarak one cikarir.',
            icon: Icons.shopping_bag_outlined,
            recommended: recommended.contains(AdCampaignType.productBoost),
          ),
          AdTypeOption(
            id: AdCampaignType.storeBoost.dbValue,
            title: 'Magaza one cikarma',
            description:
                'Magazanizi harita ve magaza listelerinde one cikarir.',
            icon: Icons.storefront_outlined,
            recommended: recommended.contains(AdCampaignType.storeBoost),
          ),
          AdTypeOption(
            id: AdCampaignType.collectionBoost.dbValue,
            title: 'Liste one cikar',
            description:
                'Listelerinizi kesfet alaninda sponsorlu olarak gosterir.',
            icon: Icons.collections_bookmark_outlined,
            recommended: recommended.contains(AdCampaignType.collectionBoost),
          ),
          AdTypeOption(
            id: AdCampaignType.geoPush.dbValue,
            title: 'Konum bazli bildirim',
            description:
                'Magazanizin yakinindaki kullanicilara konum bazli bildirim gonderir.',
            icon: Icons.near_me_outlined,
            recommended: recommended.contains(AdCampaignType.geoPush),
          ),
        ]
        .where((item) => available.any((type) => type.dbValue == item.id))
        .toList(growable: false);
  }

  CampaignObjectiveOption get _selectedObjectiveOption {
    return _objectiveOptions.firstWhere(
      (item) => item.id == _selectedObjectiveId,
      orElse: () => _objectiveOptions.first,
    );
  }

  String get _previewDescription {
    return switch (_selectedObjectiveId) {
      'views' =>
        'Urunlerinizi daha fazla kullaniciya gosterir ve gorunurlugunuzu artirir.',
      'store_visits' =>
        'Magazanizi ziyaret etmeye yatkin kullanicilari daha etkili sekilde hedefler.',
      'collection_discovery' =>
        'Listelerinizi kesfet alaninda ilgili kullanicilarla bulusturur.',
      'favorite' =>
        'Favori eklemeye yatkin kitleleri yakalayarak tekrar etkilesimi buyutur.',
      'add_to_cart' =>
        'Sepete ekleme egilimi yuksek kullanicilar ile daha nitelikli trafik olusturur.',
      'order' =>
        'Siparise donusme potansiyeli yuksek kitlelerde kampanyayi optimize eder.',
      'purchase' =>
        'Satin almaya yatkin kullanicilara reklam gosterir ve donusumu artirmayi hedefler.',
      'nearby' =>
        'Magazanizin yakinindaki kullanicilara konum bazli bildirim gonderir.',
      _ => _selectedObjectiveOption.description,
    };
  }

  List<String> get _audienceCategoryPayload {
    final result = <String>[
      if ((_audienceTargeting.primaryCategory ?? '').isNotEmpty)
        _audienceTargeting.primaryCategory!,
      ..._audienceTargeting.subcategories,
    ];
    return result;
  }

  String get _audienceSummary {
    final parts = _audienceTargeting.summaryTokens;
    if (parts.isEmpty) {
      return 'Genis hedefleme';
    }
    return parts.take(5).join(', ');
  }

  List<PreviewSummaryItem> get _summaryItems {
    return <PreviewSummaryItem>[
      PreviewSummaryItem(label: 'Hedef', value: _selectedObjectiveOption.title),
      PreviewSummaryItem(
        label: 'Format',
        value: _campaignTypeTitle(_selectedCampaignType),
      ),
      PreviewSummaryItem(
        label: 'Hedef kitle',
        value: !_audienceConfigured ? '-' : _audienceSummary,
      ),
      PreviewSummaryItem(
        label: 'Il / Ilce',
        value: _cityConfigured ? _cityLabel : '-',
      ),
      PreviewSummaryItem(
        label: 'Butce',
        value: !_budgetConfigured
            ? '-'
            : '${_dailyBudget.toStringAsFixed(0)} TRY / gunluk • ${_totalBudget.toStringAsFixed(0)} TRY toplam',
      ),
      PreviewSummaryItem(label: 'Odeme', value: _paymentMethodLabel),
      PreviewSummaryItem(
        label: 'Yayin',
        value: _scheduleConfigured && _timePlanController.text.trim().isNotEmpty
            ? _timePlanController.text.trim()
            : '-',
      ),
    ];
  }

  List<String> get _recommendations {
    return <String>[
      if (_selectedObjectiveId == 'views')
        'Bu hedefte urun one cikarma ve liste one cikarma genelde daha yuksek gorunurluk saglar.',
      if (_selectedObjectiveId == 'purchase' || _selectedObjectiveId == 'order')
        'Satin alma odakli kampanyalarda gorsel ve teklif mesaji net olmali.',
      if (_selectedCampaignType == AdCampaignType.collectionBoost)
        'Liste one cikar, kesfet alaninda birden fazla urunu birlikte one cikarmak icin verimli olur.',
      if (_selectedCampaignType == AdCampaignType.geoPush)
        'Geo push icin mesafeyi fazla daraltmak teslimi dusurebilir, 5-10 km araligi idealdir.',
      if (_dailyBudget < 300)
        'Butceniz dusukse tek hedefe odaklanmak daha saglikli performans verir.',
      'Aksam saatleri genelde daha yuksek etkilesim getirir; yayin planinizi bu saatlerde agirlastirin.',
    ];
  }

  int get _estimatedConversions {
    final objectiveMultiplier = switch (_selectedObjectiveId) {
      'views' => 0.022,
      'store_visits' => 0.03,
      'collection_discovery' => 0.026,
      'favorite' => 0.019,
      'add_to_cart' => 0.017,
      'order' => 0.013,
      'purchase' => 0.011,
      'nearby' => 0.028,
      _ => 0.016,
    };
    final typeMultiplier = switch (_selectedCampaignType) {
      AdCampaignType.productBoost => 1.0,
      AdCampaignType.storeBoost => 0.94,
      AdCampaignType.collectionBoost => 0.98,
      AdCampaignType.geoPush => 1.08,
      AdCampaignType.banner => 0.88,
      AdCampaignType.categorySponsor => 0.92,
    };
    return (_totalBudget * objectiveMultiplier * typeMultiplier).round();
  }

  String get _cityLabel {
    if (_selectedCities.isEmpty) return 'Il / Ilce secilmedi';
    final city = _selectedCities.first;
    if ((_selectedDistrict ?? '').isNotEmpty) {
      return '$city / $_selectedDistrict';
    }
    return city;
  }

  String get _entityFieldLabel {
    return switch (_selectedCampaignType) {
      AdCampaignType.productBoost => 'Urun sec',
      AdCampaignType.storeBoost => 'Magaza sec',
      AdCampaignType.collectionBoost => 'Liste sec',
      AdCampaignType.geoPush => 'Magaza sec',
      AdCampaignType.banner => 'Banner sec',
      AdCampaignType.categorySponsor => 'Kategori sec',
    };
  }

  String _stepDescription(int step) {
    return switch (step) {
      0 =>
        'Burada sonucu secersiniz: goruntulenme, siparis, magaza ziyareti gibi. Sistem bir sonraki adimda bu hedefe uygun formati otomatik onerir.',
      1 =>
        'Burada reklam formatini secersiniz. Yani reklam hangi varlikla ve hangi yuzeyde yayinlanacak: urun, magaza, liste veya geo push. Sistem sizin icin en uygun formati secili getirir, isterseniz degistirebilirsiniz.',
      2 =>
        'Kampanya metinleri, kreatif baslik ve reklam verilecek varligi bu adimda hazirlarsiniz.',
      3 =>
        'Kategori, sehir ve mesafe ile reklam teslimini daha nitelikli hale getirin.',
      4 =>
        'Gunluk ve toplam butceyi sureye gore planlayin. Tahmini donusum burada guncellenir.',
      5 =>
        'Kupon, ozel teklif veya ilk siparis avantaji gibi teklifleri tanimlayin.',
      6 =>
        'Yayin gunlerini ve saat araliklarini belirleyerek teslim ritmini yonetin.',
      7 =>
        'Kampanya ozetini son kez kontrol edin ve panel gorunumunu inceleyin.',
      8 => 'Tum bilgileri dogrulayin ve kampanyayi incelemeye gonderin.',
      _ => '',
    };
  }

  List<_EntityOption> _entityOptionsForType(AdCampaignType type) {
    return switch (type) {
      AdCampaignType.productBoost => _sellerProducts,
      AdCampaignType.storeBoost =>
        _sellerStoreOption == null
            ? const <_EntityOption>[]
            : <_EntityOption>[_sellerStoreOption!],
      AdCampaignType.collectionBoost => _resolvedSellerCollections,
      AdCampaignType.geoPush =>
        _sellerStoreOption == null
            ? const <_EntityOption>[]
            : <_EntityOption>[_sellerStoreOption!],
      AdCampaignType.banner => _sellerProducts,
      AdCampaignType.categorySponsor => _resolvedSellerCollections,
    };
  }

  CampaignObjective _objectiveForId(String id) {
    return switch (id) {
      'views' => CampaignObjective.productViews,
      'store_visits' => CampaignObjective.storeVisits,
      'collection_discovery' => CampaignObjective.collectionDiscovery,
      'favorite' => CampaignObjective.favorites,
      'add_to_cart' => CampaignObjective.addToCart,
      'order' => CampaignObjective.orders,
      'purchase' => CampaignObjective.orders,
      'nearby' => CampaignObjective.driveNearbyTraffic,
      _ => CampaignObjective.productViews,
    };
  }

  String _objectiveIdForCampaign(AdCampaign campaign) {
    final saved = campaign.metadata['objective_id']?.toString();
    if ((saved ?? '').isNotEmpty) {
      return saved!;
    }
    return switch (campaign.objective) {
      CampaignObjective.productViews => 'views',
      CampaignObjective.storeVisits => 'store_visits',
      CampaignObjective.collectionDiscovery => 'collection_discovery',
      CampaignObjective.favorites => 'favorite',
      CampaignObjective.addToCart => 'add_to_cart',
      CampaignObjective.orders => 'purchase',
      CampaignObjective.driveNearbyTraffic => 'nearby',
    };
  }

  AdCampaignType _typeFromDbValue(String raw) {
    return AdCampaignType.values.firstWhere(
      (item) => item.dbValue == raw,
      orElse: () => AdCampaignType.productBoost,
    );
  }

  String _campaignTypeTitle(AdCampaignType type) {
    return switch (type) {
      AdCampaignType.productBoost => 'Urun one cikarma',
      AdCampaignType.storeBoost => 'Magaza one cikarma',
      AdCampaignType.collectionBoost => 'Liste one cikar',
      AdCampaignType.geoPush => 'Konum bazli bildirim',
      AdCampaignType.banner => 'Banner',
      AdCampaignType.categorySponsor => 'Kategori Sponsor',
    };
  }

  AdAssetType _assetTypeForCampaign(AdCampaignType type) {
    return switch (type) {
      AdCampaignType.productBoost => AdAssetType.product,
      AdCampaignType.storeBoost => AdAssetType.store,
      AdCampaignType.collectionBoost => AdAssetType.collection,
      AdCampaignType.geoPush => AdAssetType.notification,
      AdCampaignType.banner => AdAssetType.image,
      AdCampaignType.categorySponsor => AdAssetType.image,
    };
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  List<AdCampaignType> get _recommendedCampaignTypes {
    return _campaignService.getRecommendedTypes(
      _objectiveForId(_selectedObjectiveId),
    );
  }

  List<AdCampaignType> get _availableCampaignTypes {
    return _campaignService.getAvailableTypes(
      _objectiveForId(_selectedObjectiveId),
    );
  }

  AdCampaignType get _recommendedCampaignTypeForSelectedGoal {
    final recommended = _recommendedCampaignTypes;
    if (recommended.isEmpty) {
      final available = _availableCampaignTypes;
      return available.isEmpty ? AdCampaignType.productBoost : available.first;
    }
    return recommended.first;
  }

  String get _campaignTypePurposeLabel {
    return switch (_selectedCampaignType) {
      AdCampaignType.productBoost =>
        'Tekil urunlerinizi sponsorlu alanlarda one cikarir.',
      AdCampaignType.storeBoost =>
        'Magaza sayfanizi ve listeleme yuzeylerini one cikarir.',
      AdCampaignType.collectionBoost =>
        'Birden fazla urunu liste olarak kesfet alanina tasir.',
      AdCampaignType.geoPush =>
        'Magazaniza yakin kullanicilara konum bazli bildirim gonderir.',
      AdCampaignType.banner =>
        'Gorsel banner alanlarinda daha genis gorunurluk saglar.',
      AdCampaignType.categorySponsor =>
        'Kategori seviyesinde sponsorlu gorunurluk saglar.',
    };
  }

  Widget _buildFormatRecommendationCard() {
    final recommendedType = _recommendedCampaignTypeForSelectedGoal;
    final availableTypes = _availableCampaignTypes;
    final isUsingRecommended = _selectedCampaignType == recommendedType;
    final selectedTypeTitle = _campaignTypeTitle(_selectedCampaignType);
    final recommendedTitle = _campaignTypeTitle(recommendedType);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Amac ve format farki',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isUsingRecommended
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isUsingRecommended ? 'Onerilen secili' : 'Elle degistirildi',
                  style: TextStyle(
                    color: isUsingRecommended
                        ? const Color(0xFF166534)
                        : const Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Kampanya amaci sonuctur: "${_selectedObjectiveOption.title}". '
            'Yayin formati ise bu sonuca hangi reklam yapisiyla gideceginizi belirler.',
            style: const TextStyle(
              color: Color(0xFF475569),
              height: 1.45,
              fontSize: 12.8,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildFormatInfoPill(
                label: 'Sistem onerisi',
                value: recommendedTitle,
              ),
              _buildFormatInfoPill(
                label: 'Su an secili',
                value: selectedTypeTitle,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isUsingRecommended
                ? '$selectedTypeTitle bu hedef icin en dogal format olarak otomatik secildi. Asagida sadece bu amaca uygun formatlar gosteriliyor.'
                : 'Su an varsayilan oneriden farkli ama yine uyumlu bir format kullaniyorsunuz. $_campaignTypePurposeLabel',
            style: const TextStyle(
              color: Color(0xFF334155),
              height: 1.45,
              fontSize: 12.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Uygun formatlar: ${availableTypes.map(_campaignTypeTitle).join(', ')}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              height: 1.45,
              fontSize: 12.2,
            ),
          ),
          if (_campaignTypeCustomized && !isUsingRecommended) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedCampaignType = recommendedType;
                  _campaignTypeCustomized = false;
                  _selectedEntity = null;
                  _entityLabelController.clear();
                });
              },
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Onerilen formata don'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormatInfoPill({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontFamily: 'inherit'),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntityOption {
  const _EntityOption({
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
}

class _SchedulePreset {
  const _SchedulePreset({required this.label, required this.value});

  final String label;
  final String value;
}

class _CitySelectionResult {
  const _CitySelectionResult({required this.city, this.district});

  final String city;
  final String? district;
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.check_rounded, color: Color(0xFF15803D)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
