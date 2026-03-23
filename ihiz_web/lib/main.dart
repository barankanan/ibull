import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart'
    show
        CameraFit,
        CircleLayer,
        CircleMarker,
        FlutterMap,
        LatLngBounds,
        MapController,
        MapOptions,
        Marker,
        MarkerLayer,
        Polygon,
        PolygonLayer,
        Polyline,
        PolylineLayer,
        StrokePattern,
        TileLayer;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'src/sections/ihiz_login_marketing_section.dart';
import 'src/widgets/ihiz_landing_widgets.dart';
import 'src/widgets/ihiz_marketing_chrome.dart';

part 'src/models/ihiz_application_models.dart';
part 'src/models/ihiz_pricing_models.dart';
part 'src/models/ihiz_supporting_models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://ihmixxzqnpamcwmrfibx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlobWl4eHpxbnBhbWN3bXJmaWJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3MDE0NTEsImV4cCI6MjA4NzI3NzQ1MX0.EZkjZAq2mwg-gfBhwotAGp4stb1D-rmWHuzVsz2yzX0',
  );

  runApp(const IhizWebApp());
}

class IhizWebApp extends StatelessWidget {
  const IhizWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'İhız Kurye',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F7FD),
        fontFamily: 'sans-serif',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF163B73),
          primary: const Color(0xFF163B73),
          surface: Colors.white,
        ),
      ),
      home: const IhizEntryPage(),
    );
  }
}

class IhizEntryPage extends StatefulWidget {
  const IhizEntryPage({super.key});

  @override
  State<IhizEntryPage> createState() => _IhizEntryPageState();
}

class _IhizEntryPageState extends State<IhizEntryPage> {
  _IhizView _view = _IhizView.landing;
  CourierApplicationData? _applicationData;
  IhizPricingConfig _pricingConfig = IhizPricingConfig.defaults;
  StreamSubscription<List<Map<String, dynamic>>>? _pricingConfigSubscription;
  StreamSubscription<AuthState>? _authStateSubscription;
  Timer? _pricingConfigPollTimer;
  bool _restoringSession = false;

  @override
  void initState() {
    super.initState();
    _bootstrapPricingConfig();
    _subscribePricingConfig();
    _startPricingConfigPolling();
    _subscribeAuthState();
    unawaited(_restoreLoggedInCourierSession());
  }

  Future<void> _bootstrapPricingConfig() async {
    IhizPricingConfig? latestConfig;
    try {
      final rows = await Supabase.instance.client
          .from('ihiz_pricing_rule_versions')
          .select('config')
          .eq('is_active', true)
          .order('version', ascending: false)
          .limit(1);
      latestConfig = _extractActivePricingConfig(rows);
    } catch (_) {}

    latestConfig ??= await _fetchActivePricingConfigViaRpc();
    if (latestConfig == null || !mounted) return;
    setState(() {
      _pricingConfig = latestConfig!;
    });
  }

  Future<IhizPricingConfig?> _fetchActivePricingConfigViaRpc() async {
    try {
      final response = await Supabase.instance.client.rpc(
        'get_active_ihiz_pricing_config',
      );
      if (response is! Map) return null;
      final configMap = response.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (configMap.isEmpty) return null;
      return IhizPricingConfig.fromJson(configMap);
    } catch (_) {
      return null;
    }
  }

  void _subscribePricingConfig() {
    try {
      _pricingConfigSubscription = Supabase.instance.client
          .from('ihiz_pricing_rule_versions')
          .stream(primaryKey: ['version'])
          .eq('is_active', true)
          .listen((rows) {
            final latestConfig = _extractActivePricingConfig(rows);
            if (latestConfig == null || !mounted) return;
            setState(() {
              _pricingConfig = latestConfig;
            });
          });
    } catch (_) {
      // Realtime mevcut değilse eski davranış korunur.
    }
  }

  void _startPricingConfigPolling() {
    _pricingConfigPollTimer?.cancel();
    _pricingConfigPollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      unawaited(_bootstrapPricingConfig());
    });
  }

  IhizPricingConfig? _extractActivePricingConfig(dynamic rows) {
    if (rows is! List) return null;
    final list = rows
        .whereType<Map<String, dynamic>>()
        .where((row) => row.isNotEmpty)
        .toList(growable: false);
    if (list.isEmpty) return null;

    Map<String, dynamic> selected = list.first;
    for (final row in list.skip(1)) {
      final rowVersion = row['version'];
      final selectedVersion = selected['version'];
      final normalizedRowVersion = rowVersion is int
          ? rowVersion
          : int.tryParse(rowVersion?.toString() ?? '') ?? -1;
      final normalizedSelectedVersion = selectedVersion is int
          ? selectedVersion
          : int.tryParse(selectedVersion?.toString() ?? '') ?? -1;
      if (normalizedRowVersion > normalizedSelectedVersion) {
        selected = row;
      }
    }

    final rawConfig = selected['config'];
    final configMap = rawConfig is Map
        ? rawConfig.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};
    return IhizPricingConfig.fromJson(configMap);
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return fallback;
  }

  CourierApplicationData _applicationDataFromRow(Map<String, dynamic> row) {
    final fullName = (row['full_name'] ?? '').toString();
    return CourierApplicationData(
      fullName: fullName,
      phone: (row['phone'] ?? '').toString(),
      tcNumber: (row['tc_number'] ?? '').toString(),
      birthDate: (row['birth_date'] ?? '').toString(),
      licenseType: (row['license_type'] ?? '').toString(),
      motorType: (row['motor_type'] ?? '').toString(),
      criminalRecord: (row['criminal_record'] ?? '').toString(),
      companyType: (row['company_type'] ?? '').toString(),
      city: (row['city'] ?? '').toString(),
      district: (row['district'] ?? '').toString(),
      availability: (row['availability'] ?? '').toString(),
      email: (row['email'] ?? '').toString(),
      note: (row['note'] ?? '').toString(),
      pushNotificationsEnabled: _asBool(
        row['push_notifications_enabled'],
        fallback: true,
      ),
      soundAlertsEnabled: _asBool(row['sound_alerts_enabled'], fallback: true),
      nightModeEnabled: _asBool(row['night_mode_enabled'], fallback: false),
      faceIdEnabled: _asBool(row['face_id_enabled'], fallback: true),
      paymentAccountHolder: (row['payment_account_holder'] ?? '').toString(),
      paymentIban: (row['payment_iban'] ?? '').toString(),
      paymentBankName: (row['payment_bank_name'] ?? '').toString(),
      driverLicenseFileName: (row['driver_license_front_file_name'] ?? '')
          .toString(),
      driverLicenseFileSize: _asInt(row['driver_license_front_file_size']),
      driverLicenseFrontFileName: (row['driver_license_front_file_name'] ?? '')
          .toString(),
      driverLicenseFrontFileSize: _asInt(row['driver_license_front_file_size']),
      driverLicenseBackFileName: (row['driver_license_back_file_name'] ?? '')
          .toString(),
      driverLicenseBackFileSize: _asInt(row['driver_license_back_file_size']),
      vehicleRegistrationFileName: (row['vehicle_registration_file_name'] ?? '')
          .toString(),
      vehicleRegistrationFileSize: _asInt(
        row['vehicle_registration_file_size'],
      ),
    );
  }

  void _subscribeAuthState() {
    _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
        .listen((state) {
          if (!mounted) return;
          if (state.event == AuthChangeEvent.signedOut) {
            setState(() {
              _applicationData = null;
              _view = _IhizView.landing;
            });
            return;
          }
          if (state.event == AuthChangeEvent.signedIn ||
              state.event == AuthChangeEvent.initialSession) {
            unawaited(_restoreLoggedInCourierSession());
          }
        });
  }

  Future<void> _restoreLoggedInCourierSession() async {
    if (_restoringSession) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    _restoringSession = true;
    try {
      final row = await client
          .from('ihiz_courier_applications')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (!mounted) return;
      if (row is! Map) {
        await client.auth.signOut();
        return;
      }

      final data = Map<String, dynamic>.from(row as Map);
      final status = (data['status'] ?? 'pending').toString().toLowerCase();
      if (status != 'approved') {
        await client.auth.signOut();
        return;
      }

      setState(() {
        _applicationData = _applicationDataFromRow(data);
        _view = _IhizView.dashboard;
      });
    } catch (error) {
      debugPrint('IHIZ session restore error: $error');
    } finally {
      _restoringSession = false;
    }
  }

  Future<void> _handleDashboardExit() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _applicationData = null;
      _view = _IhizView.landing;
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _pricingConfigSubscription?.cancel();
    _pricingConfigPollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_view) {
      case _IhizView.landing:
        return _IhizLandingPage(
          onLogin: () => setState(() => _view = _IhizView.login),
          onApply: () => setState(() => _view = _IhizView.apply),
        );
      case _IhizView.login:
        return _IhizLoginPage(
          onBack: () => setState(() => _view = _IhizView.landing),
          onApply: () => setState(() => _view = _IhizView.apply),
          onLoginSuccess: (applicationData) {
            setState(() {
              _applicationData = applicationData;
              _view = _IhizView.dashboard;
            });
          },
        );
      case _IhizView.apply:
        return _IhizApplyPage(
          onBack: () => setState(() => _view = _IhizView.landing),
          onGoLogin: () => setState(() => _view = _IhizView.login),
          onApplicationSaved: (data) {
            setState(() {
              _applicationData = data;
            });
          },
        );
      case _IhizView.dashboard:
        return IhizSitePage(
          onExit: () {
            unawaited(_handleDashboardExit());
          },
          applicationData: _applicationData,
          pricingConfig: _pricingConfig,
          onApplicationDataChanged: (data) {
            setState(() {
              _applicationData = data;
            });
          },
          onPricingConfigChanged: (config) {
            setState(() {
              _pricingConfig = config;
            });
          },
        );
    }
  }
}

class _IhizLandingPage extends StatelessWidget {
  const _IhizLandingPage({required this.onLogin, required this.onApply});

  final VoidCallback onLogin;
  final VoidCallback onApply;

  static const Color _ink = Color(0xFF102941);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 920;

        return Scaffold(
          backgroundColor: const Color(0xFFF2F7FB),
          body: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: -180,
                  right: -120,
                  child: Container(
                    width: 420,
                    height: 420,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1D7ABF).withValues(alpha: 0.13),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -210,
                  left: -140,
                  child: Container(
                    width: 460,
                    height: 460,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF09A66D).withValues(alpha: 0.1),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isMobile ? 14 : 28,
                    18,
                    isMobile ? 14 : 28,
                    28,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? 560 : 1220,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LandingFirstFold(
                            isMobile: isMobile,
                            onLogin: onLogin,
                            onApply: onApply,
                          ),
                          const SizedBox(height: 10),
                          _ComparisonCard(isMobile: isMobile),
                          const SizedBox(height: 14),
                          IhizSectionShell(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: const Color(
                                          0xFF2E73FF,
                                        ).withValues(alpha: 0.12),
                                      ),
                                      child: const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: Color(0xFF2E73FF),
                                        size: 21,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Ne Yapıyoruz?',
                                      style: TextStyle(
                                        color: _ink,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Satıcıları tek haritada topluyor, siparişi sana hızla ulaştırıyoruz.',
                                  style: TextStyle(
                                    color: _ink.withValues(alpha: 0.74),
                                    fontSize: isMobile ? 14 : 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: const [
                                    IhizLandingBadge(
                                      icon: Icons.map_outlined,
                                      label: 'Tek haritada satıcı',
                                    ),
                                    IhizLandingBadge(
                                      icon: Icons.schedule_rounded,
                                      label: '1 saat / 3 saat',
                                    ),
                                    IhizLandingBadge(
                                      icon: Icons.verified_rounded,
                                      label: '5 dk deneme & iade',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isMobile ? 14 : 18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10345F), Color(0xFF1A5A9B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: const Color(0xFF2E6FB0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF123E72,
                                  ).withValues(alpha: 0.24),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.route_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '3 Adımda İHIZ',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isMobile ? 18 : 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.22,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Hızlı Akış',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (isMobile)
                                  const Column(
                                    children: [
                                      _LandingFlowStep(
                                        step: '01',
                                        title: 'Eşleşme',
                                        subtitle: 'Yakın satıcı + müşteri',
                                        icon: Icons.link_rounded,
                                      ),
                                      SizedBox(height: 8),
                                      _LandingFlowStep(
                                        step: '02',
                                        title: 'Alım',
                                        subtitle: 'Kurye ürünü alır',
                                        icon: Icons.inventory_2_outlined,
                                      ),
                                      SizedBox(height: 8),
                                      _LandingFlowStep(
                                        step: '03',
                                        title: 'Teslim',
                                        subtitle: 'Kapıda hızlı teslim',
                                        icon: Icons.local_shipping_outlined,
                                      ),
                                    ],
                                  )
                                else
                                  const Row(
                                    children: [
                                      Expanded(
                                        child: _LandingFlowStep(
                                          step: '01',
                                          title: 'Eşleşme',
                                          subtitle: 'Yakın satıcı + müşteri',
                                          icon: Icons.link_rounded,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: _LandingFlowStep(
                                          step: '02',
                                          title: 'Alım',
                                          subtitle: 'Kurye ürünü alır',
                                          icon: Icons.inventory_2_outlined,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: _LandingFlowStep(
                                          step: '03',
                                          title: 'Teslim',
                                          subtitle: 'Kapıda hızlı teslim',
                                          icon: Icons.local_shipping_outlined,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          IhizSectionShell(
                            child: Column(
                              children: [
                                if (isMobile)
                                  const Column(
                                    children: [
                                      IhizLandingQuickCard(
                                        title: 'Müşteri',
                                        value: 'Yakındaki ürünü hızlıca görür',
                                        icon: Icons.person_search_outlined,
                                        accent: Color(0xFF2E73FF),
                                      ),
                                      SizedBox(height: 10),
                                      IhizLandingQuickCard(
                                        title: 'Satıcı',
                                        value: 'Haritada daha görünür olur',
                                        icon: Icons.storefront_outlined,
                                        accent: Color(0xFF1F64D6),
                                      ),
                                      SizedBox(height: 10),
                                      IhizLandingQuickCard(
                                        title: 'Kurye',
                                        value: 'Teslim + deneme + iade yönetir',
                                        icon: Icons.two_wheeler_outlined,
                                        accent: Color(0xFF0F5CB0),
                                      ),
                                    ],
                                  )
                                else
                                  const Row(
                                    children: [
                                      Expanded(
                                        child: IhizLandingQuickCard(
                                          title: 'Müşteri',
                                          value:
                                              'Yakındaki ürünü hızlıca görür',
                                          icon: Icons.person_search_outlined,
                                          accent: Color(0xFF2E73FF),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: IhizLandingQuickCard(
                                          title: 'Satıcı',
                                          value: 'Haritada daha görünür olur',
                                          icon: Icons.storefront_outlined,
                                          accent: Color(0xFF1F64D6),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: IhizLandingQuickCard(
                                          title: 'Kurye',
                                          value:
                                              'Teslim + deneme + iade yönetir',
                                          icon: Icons.two_wheeler_outlined,
                                          accent: Color(0xFF0F5CB0),
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 10),
                                const Row(
                                  children: [
                                    Expanded(
                                      child: IhizLandingMiniStat(
                                        value: '1 Saat',
                                        label: 'Ekspres',
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: IhizLandingMiniStat(
                                        value: '5 Dakika',
                                        label: 'Deneme',
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: IhizLandingMiniStat(
                                        value: 'Gününde',
                                        label: 'İade',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          IhizSectionShell(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: _ink.withValues(alpha: 0.42),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'iBul satıcı ağı + İHIZ kurye ile yerel ticaret tek akışta.',
                                    style: TextStyle(
                                      color: _ink.withValues(alpha: 0.68),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  '© 2026',
                                  style: TextStyle(
                                    color: _ink.withValues(alpha: 0.56),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LandingFirstFold extends StatelessWidget {
  const _LandingFirstFold({
    required this.isMobile,
    required this.onLogin,
    required this.onApply,
  });

  final bool isMobile;
  final VoidCallback onLogin;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final viewportHeight = MediaQuery.sizeOf(context).height;
        final titleSize = (width * (isMobile ? 0.132 : 0.078)).clamp(
          42.0,
          72.0,
        );
        final headlineSize = (width * (isMobile ? 0.106 : 0.066)).clamp(
          30.0,
          62.0,
        );
        final contentMaxWidth = isMobile ? width : 860.0;
        final buttonGapFromHeader =
            (viewportHeight * (isMobile ? 0.365 : 0.305)).clamp(206.0, 360.0);
        final bottomInset = (viewportHeight * (isMobile ? 0.03 : 0.035)).clamp(
          16.0,
          40.0,
        );

        return Container(
          constraints: BoxConstraints(minHeight: isMobile ? 620 : 720),
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            isMobile ? 14 : 26,
            isMobile ? 18 : 28,
            isMobile ? 14 : 26,
            isMobile ? 14 : 28,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            image: const DecorationImage(
              image: AssetImage('assets/hero/hero_bg.png'),
              fit: BoxFit.cover,
              alignment: Alignment(0, 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF144E87).withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 10 : 18,
                isMobile ? 8 : 16,
                isMobile ? 10 : 18,
                isMobile ? 12 : 20,
              ),
              child: Column(
                children: [
                  _HeroHeader(
                    isMobile: isMobile,
                    brandSize: titleSize,
                    headlineSize: headlineSize,
                  ),
                  SizedBox(height: buttonGapFromHeader),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: _ActionButtons(
                      isMobile: isMobile,
                      onLogin: onLogin,
                      onApply: onApply,
                    ),
                  ),
                  SizedBox(height: bottomInset),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// Responsive kararlar:
// - Hero yüksekliği sabit değil; ekrana göre dinamik alt boşluk kullanılıyor.
// - Başlık ve marka tipografisi clamp ile küçük/büyük cihazlara uyarlanıyor.
// - Alt bölümde kartlar mobilde dikey, geniş ekranda yatay akışa geçiyor.
// - Butonlar ve kart içerikleri taşmayı önlemek için esnek genişlikte tutuluyor.

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.isMobile,
    required this.brandSize,
    required this.headlineSize,
  });

  final bool isMobile;
  final double brandSize;
  final double headlineSize;

  @override
  Widget build(BuildContext context) {
    final sloganSize = (brandSize * 0.44).clamp(17.0, 29.0);
    final logoSize = (brandSize * 0.76).clamp(40.0, 68.0);
    final ihizSize = (brandSize * 0.89).clamp(38.0, 62.0);
    final lockupWidth = (ihizSize * 2.2 + logoSize).clamp(210.0, 450.0);
    final headingSize = (headlineSize * 0.9).clamp(28.0, 56.0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: logoSize + (isMobile ? 12 : 16),
              height: logoSize + (isMobile ? 12 : 16),
              padding: EdgeInsets.all(isMobile ? 6 : 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Image.asset(
                'assets/hero/ihiz_logo.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.local_shipping_outlined,
                    color: Color(0xFF3D64F4),
                  );
                },
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Text(
              'İHIZ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: ihizSize,
                letterSpacing: 1.2,
                shadows: const [
                  Shadow(
                    color: Color(0x660A2C58),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 2 : 3),
        Container(
          width: lockupWidth,
          height: 2.4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        SizedBox(height: isMobile ? 1 : 2),
        Text(
          'İstediğin HIZ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.98),
            fontWeight: FontWeight.w600,
            fontSize: sloganSize,
          ),
        ),
        SizedBox(height: isMobile ? 5 : 8),
        Text(
          '1 Saate Kapında,\nGününde Teslimat!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.98),
            fontWeight: FontWeight.w600,
            fontSize: headingSize,
            fontFamily: 'Trebuchet MS',
            height: 1.05,
            shadows: const [
              Shadow(
                color: Color(0x66223A66),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final titleSize = isMobile ? 13.5 : 18.0;
    final valueSize = isMobile ? 13.0 : 16.0;
    final valueHeight = isMobile ? 34.0 : 42.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 10 : 14,
        isMobile ? 10 : 14,
        isMobile ? 10 : 14,
        isMobile ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF).withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEAF1FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF224B86).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _ComparisonColumn(
              title: 'Teslimat',
              oldValue: '3 Gün',
              newValue: '1 Saat',
              titleSize: titleSize,
              valueSize: valueSize,
              pillHeight: valueHeight,
              showCheck: true,
            ),
          ),
          _softDivider(isMobile),
          Expanded(
            child: _ComparisonColumn(
              title: 'Ürün Deneme',
              oldValue: 'Yok',
              newValue: '5 Dakika',
              titleSize: titleSize,
              valueSize: valueSize,
              pillHeight: valueHeight,
            ),
          ),
          _softDivider(isMobile),
          Expanded(
            child: _ComparisonColumn(
              title: 'İade',
              oldValue: '3 Gün',
              newValue: 'Gününde',
              titleSize: titleSize,
              valueSize: valueSize,
              pillHeight: valueHeight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _softDivider(bool isMobile) {
    return Container(
      width: 1,
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 10, vertical: 6),
      color: const Color(0xFFDCE6FA),
    );
  }
}

class _ComparisonColumn extends StatelessWidget {
  const _ComparisonColumn({
    required this.title,
    required this.oldValue,
    required this.newValue,
    required this.titleSize,
    required this.valueSize,
    required this.pillHeight,
    this.showCheck = false,
  });

  final String title;
  final String oldValue;
  final String newValue;
  final double titleSize;
  final double valueSize;
  final double pillHeight;
  final bool showCheck;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF26497A),
            fontWeight: FontWeight.w700,
            fontSize: titleSize,
          ),
        ),
        const SizedBox(height: 8),
        _ComparisonPill(
          text: oldValue,
          fontSize: valueSize,
          height: pillHeight,
          oldStyle: true,
        ),
        const SizedBox(height: 8),
        _ComparisonPill(
          text: newValue,
          fontSize: valueSize,
          height: pillHeight,
          showCheck: showCheck,
        ),
      ],
    );
  }
}

class _ComparisonPill extends StatelessWidget {
  const _ComparisonPill({
    required this.text,
    required this.fontSize,
    required this.height,
    this.showCheck = false,
    this.oldStyle = false,
  });

  final String text;
  final double fontSize;
  final double height;
  final bool showCheck;
  final bool oldStyle;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: oldStyle
            ? const LinearGradient(
                colors: [Color(0xFFDEE2F0), Color(0xFFD2D8ED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF3EA6FF), Color(0xFF2E73FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showCheck) ...[
              const Icon(Icons.check_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: oldStyle ? const Color(0xFF4A5B7D) : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: fontSize,
                  decoration: oldStyle ? TextDecoration.lineThrough : null,
                  decorationThickness: 2,
                  decorationColor: const Color(0xFF5E6F8F),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.isMobile,
    required this.onLogin,
    required this.onApply,
  });

  final bool isMobile;
  final VoidCallback onLogin;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final buttonHeight = isMobile ? 56.0 : 64.0;
    final fontSize = isMobile ? 20.0 : 25.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonWidth =
            (((constraints.maxWidth - 10) / 2) * (isMobile ? 0.84 : 0.82))
                .clamp(130.0, 310.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: buttonWidth,
              child: ElevatedButton(
                onPressed: onLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F64D6),
                  foregroundColor: Colors.white,
                  minimumSize: Size.fromHeight(buttonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.92),
                    width: 1.8,
                  ),
                  elevation: 7,
                  shadowColor: const Color(0x6616449D),
                  textStyle: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: fontSize,
                  ),
                ),
                child: const Text('Giriş Yap'),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: buttonWidth,
              child: ElevatedButton(
                onPressed: onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.96),
                  foregroundColor: const Color(0xFF245BB1),
                  minimumSize: Size.fromHeight(buttonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 6,
                  shadowColor: const Color(0x332A4E8E),
                  textStyle: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: fontSize,
                  ),
                ),
                child: const Text('Kayıt Ol'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LandingFlowStep extends StatelessWidget {
  const _LandingFlowStep({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String step;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, color: Colors.white.withValues(alpha: 0.86), size: 18),
        ],
      ),
    );
  }
}

class _IhizLoginPage extends StatefulWidget {
  const _IhizLoginPage({
    required this.onBack,
    required this.onApply,
    required this.onLoginSuccess,
  });

  final VoidCallback onBack;
  final VoidCallback onApply;
  final ValueChanged<CourierApplicationData> onLoginSuccess;

  @override
  State<_IhizLoginPage> createState() => _IhizLoginPageState();
}

class _IhizLoginPageState extends State<_IhizLoginPage> {
  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _cleanErrorMessage(Object error) {
    final raw = error.toString().replaceAll('Exception:', '').trim();
    if (error is AuthException) {
      if (error.code == 'invalid_credentials') {
        return 'E-posta veya şifre hatalı.';
      }
      if (error.code == 'email_not_confirmed') {
        return 'E-posta hesabı henüz doğrulanmamış.';
      }
    }
    return raw.isEmpty ? 'Giriş sırasında hata oluştu.' : raw;
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = (value ?? '').toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
    return fallback;
  }

  CourierApplicationData _applicationDataFromRow(Map<String, dynamic> row) {
    final fullName = (row['full_name'] ?? '').toString();
    return CourierApplicationData(
      fullName: fullName,
      phone: (row['phone'] ?? '').toString(),
      tcNumber: (row['tc_number'] ?? '').toString(),
      birthDate: (row['birth_date'] ?? '').toString(),
      licenseType: (row['license_type'] ?? '').toString(),
      motorType: (row['motor_type'] ?? '').toString(),
      criminalRecord: (row['criminal_record'] ?? '').toString(),
      companyType: (row['company_type'] ?? '').toString(),
      city: (row['city'] ?? '').toString(),
      district: (row['district'] ?? '').toString(),
      availability: (row['availability'] ?? '').toString(),
      email: (row['email'] ?? '').toString(),
      note: (row['note'] ?? '').toString(),
      pushNotificationsEnabled: _asBool(
        row['push_notifications_enabled'],
        fallback: true,
      ),
      soundAlertsEnabled: _asBool(row['sound_alerts_enabled'], fallback: true),
      nightModeEnabled: _asBool(row['night_mode_enabled'], fallback: false),
      faceIdEnabled: _asBool(row['face_id_enabled'], fallback: true),
      paymentAccountHolder: (row['payment_account_holder'] ?? '').toString(),
      paymentIban: (row['payment_iban'] ?? '').toString(),
      paymentBankName: (row['payment_bank_name'] ?? '').toString(),
      driverLicenseFileName: (row['driver_license_front_file_name'] ?? '')
          .toString(),
      driverLicenseFileSize: _asInt(row['driver_license_front_file_size']),
      driverLicenseFrontFileName: (row['driver_license_front_file_name'] ?? '')
          .toString(),
      driverLicenseFrontFileSize: _asInt(row['driver_license_front_file_size']),
      driverLicenseBackFileName: (row['driver_license_back_file_name'] ?? '')
          .toString(),
      driverLicenseBackFileSize: _asInt(row['driver_license_back_file_size']),
      vehicleRegistrationFileName: (row['vehicle_registration_file_name'] ?? '')
          .toString(),
      vehicleRegistrationFileSize: _asInt(
        row['vehicle_registration_file_size'],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-posta ve şifre zorunlu.')),
      );
      return;
    }
    if (!identifier.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giriş için başvurudaki e-posta adresinizi kullanın.'),
        ),
      );
      return;
    }

    final email = identifier.toLowerCase();
    final client = Supabase.instance.client;

    setState(() {
      _isLoading = true;
    });

    try {
      await client.auth.signInWithPassword(email: email, password: password);
      final user = client.auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı oturumu açılamadı.');
      }

      final row = await client
          .from('ihiz_courier_applications')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (row == null) {
        await client.auth.signOut();
        throw Exception(
          'Bu hesap için kayıtlı bir kurye başvurusu bulunamadı.',
        );
      }

      final status = (row['status'] ?? 'pending').toString();
      if (status != 'approved') {
        await client.auth.signOut();
        if (status == 'rejected') {
          final reason = (row['rejection_reason'] ?? '').toString().trim();
          final suffix = reason.isEmpty ? '' : ' Red nedeni: $reason';
          throw Exception('Başvurunuz reddedildi.$suffix');
        }
        throw Exception(
          'Başvurunuz henüz onaylanmadı. Lütfen admin onayını bekleyin.',
        );
      }

      if (!mounted) return;
      widget.onLoginSuccess(
        _applicationDataFromRow(Map<String, dynamic>.from(row)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanErrorMessage(error)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Geri',
        ),
        title: const Text('Giriş Yap'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 900;

                  return isMobile
                      ? Column(
                          children: [
                            _loginForm(),
                            const SizedBox(height: 18),
                            _loginAside(),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: _loginAside()),
                            const SizedBox(width: 18),
                            Expanded(flex: 5, child: _loginForm()),
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginAside() {
    return const IhizLoginMarketingSection();
  }

  Widget _loginForm() {
    return IhizSectionShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Giriş Yap',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Color(0xFF163B73),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Onaylı kurye hesabınızla giriş yapın. Onaylanmayan hesaplar panele erişemez.',
            style: TextStyle(color: Color(0xFF5B6B86), height: 1.5),
          ),
          const SizedBox(height: 20),
          const _FieldLabel('E-posta'),
          const SizedBox(height: 8),
          _IhizInput(
            hint: 'ornek@ihiz.com',
            controller: _identifierController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Şifre'),
          const SizedBox(height: 8),
          _IhizInput(
            hint: '••••••••',
            obscure: true,
            controller: _passwordController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleLogin(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF163B73),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Kurye Paneline Gir',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TextButton(
                onPressed: widget.onApply,
                child: const Text('Kayıt Ol / Başvur'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IhizApplyPage extends StatefulWidget {
  const _IhizApplyPage({
    required this.onBack,
    required this.onGoLogin,
    required this.onApplicationSaved,
  });

  final VoidCallback onBack;
  final VoidCallback onGoLogin;
  final ValueChanged<CourierApplicationData> onApplicationSaved;

  @override
  State<_IhizApplyPage> createState() => _IhizApplyPageState();
}

class _IhizApplyPageState extends State<_IhizApplyPage> {
  static const String _turkiyeProvincesApi =
      'https://turkiyeapi.dev/api/v1/provinces';
  static const String _documentBucket = 'ihiz-courier-documents';
  static const int _maxDocumentBytes = 10 * 1024 * 1024;
  static const Set<String> _allowedDocumentExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
  };
  static const Set<String> _allowedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  int _currentStep = 0;
  bool _submitted = false;
  bool _isSubmitting = false;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _tcController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _availabilityController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _taxNumberController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _paymentAccountHolderController =
      TextEditingController();
  final TextEditingController _paymentIbanController = TextEditingController();
  final TextEditingController _paymentBankNameController =
      TextEditingController();

  String? _licenseType;
  String? _motorType;
  String? _criminalRecord;
  String? _companyType;
  String? _selectedCity;
  String? _selectedDistrict;
  bool _citiesLoading = false;
  bool _districtsLoading = false;
  List<String> _cityOptions = const [];
  List<String> _districtOptions = const [];
  _ApplyPickedDocument? _driverLicenseFrontDocument;
  _ApplyPickedDocument? _driverLicenseBackDocument;
  _ApplyPickedDocument? _vehicleRegistrationDocument;
  bool _isPickingDriverFrontDocument = false;
  bool _isPickingDriverBackDocument = false;
  bool _isPickingVehicleRegistrationDocument = false;
  final Set<String> _invalidFieldKeys = <String>{};
  final Set<int> _invalidStepCards = <int>{};

  static const Set<String> _stepOneFieldKeys = {
    'first_name',
    'last_name',
    'phone',
    'tc_number',
    'birth_date',
    'email',
    'password',
  };
  static const Set<String> _stepTwoFieldKeys = {
    'license_type',
    'motor_type',
    'criminal_record',
    'company_type',
    'tax_number',
  };
  static const Set<String> _stepThreeFieldKeys = {
    'city',
    'district',
    'availability',
    'note',
  };
  static const Set<String> _stepFourFieldKeys = {
    'driver_license_front',
    'driver_license_back',
    'vehicle_registration',
  };
  static const Set<String> _stepFiveFieldKeys = {
    'payment_account_holder',
    'payment_iban',
    'payment_bank_name',
  };

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _tcController.dispose();
    _birthDateController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _availabilityController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _taxNumberController.dispose();
    _noteController.dispose();
    _paymentAccountHolderController.dispose();
    _paymentIbanController.dispose();
    _paymentBankNameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      _currentStep = (_currentStep + 1).clamp(0, 4);
    });
  }

  void _previousStep() {
    setState(() {
      _currentStep = (_currentStep - 1).clamp(0, 4);
    });
  }

  String get _fullName {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    return '$firstName $lastName'.trim();
  }

  bool _hasStepError(int step) => _invalidStepCards.contains(step);

  bool _hasFieldError(String key) => _invalidFieldKeys.contains(key);

  String? _fieldErrorText(String key, String text) {
    if (!_hasFieldError(key)) return null;
    return text;
  }

  int? _stepForField(String key) {
    if (_stepOneFieldKeys.contains(key)) return 0;
    if (_stepTwoFieldKeys.contains(key)) return 1;
    if (_stepThreeFieldKeys.contains(key)) return 2;
    if (_stepFourFieldKeys.contains(key)) return 3;
    if (_stepFiveFieldKeys.contains(key)) return 4;
    return null;
  }

  void _setStepValidationResult({
    required int step,
    required Set<String> invalidFields,
    required String warningMessage,
  }) {
    setState(() {
      _invalidFieldKeys.removeWhere((key) => _stepForField(key) == step);
      _invalidFieldKeys.addAll(invalidFields);
      if (invalidFields.isEmpty) {
        _invalidStepCards.remove(step);
      } else {
        _invalidStepCards.add(step);
      }
    });
    if (invalidFields.isNotEmpty) {
      _showUploadMessage(warningMessage);
    }
  }

  void _clearFieldError(String key) {
    if (!_invalidFieldKeys.contains(key)) return;
    setState(() {
      _invalidFieldKeys.remove(key);
      final step = _stepForField(key);
      if (step != null) {
        final stillInvalid = _invalidFieldKeys.any(
          (fieldKey) => _stepForField(fieldKey) == step,
        );
        if (!stillInvalid) {
          _invalidStepCards.remove(step);
        }
      }
    });
  }

  bool _validateStepOne() {
    final invalid = <String>{};
    if (_firstNameController.text.trim().isEmpty) invalid.add('first_name');
    if (_lastNameController.text.trim().isEmpty) invalid.add('last_name');
    if (_phoneController.text.trim().length != 11) invalid.add('phone');
    if (_tcController.text.trim().length != 11) invalid.add('tc_number');
    final birthDate = _birthDateController.text.trim();
    if (birthDate.isEmpty || _parseBirthDate(birthDate) == null) {
      invalid.add('birth_date');
    }
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) invalid.add('email');
    if (_passwordController.text.trim().length < 6) invalid.add('password');
    _setStepValidationResult(
      step: 0,
      invalidFields: invalid,
      warningMessage: 'Kimlik kartındaki zorunlu alanları doldurun.',
    );
    return invalid.isEmpty;
  }

  bool _validateStepTwo() {
    final invalid = <String>{};
    if ((_licenseType ?? '').trim().isEmpty) invalid.add('license_type');
    if ((_motorType ?? '').trim().isEmpty) invalid.add('motor_type');
    if ((_criminalRecord ?? '').trim().isEmpty) invalid.add('criminal_record');
    if ((_companyType ?? '').trim().isEmpty) invalid.add('company_type');
    if (_companyType != 'Şirketim yok' &&
        _taxNumberController.text.trim().length != 10) {
      invalid.add('tax_number');
    }
    _setStepValidationResult(
      step: 1,
      invalidFields: invalid,
      warningMessage: 'Sürücü ve şirket kartındaki zorunlu alanları doldurun.',
    );
    return invalid.isEmpty;
  }

  bool _validateStepThree() {
    final invalid = <String>{};
    if (_cityController.text.trim().isEmpty) invalid.add('city');
    if (_districtController.text.trim().isEmpty) invalid.add('district');
    if (_availabilityController.text.trim().isEmpty) {
      invalid.add('availability');
    }
    if (_noteController.text.trim().isEmpty) invalid.add('note');
    _setStepValidationResult(
      step: 2,
      invalidFields: invalid,
      warningMessage: 'Bölge kartındaki zorunlu alanları doldurun.',
    );
    return invalid.isEmpty;
  }

  bool _validateStepFour() {
    final invalid = <String>{};
    if (_driverLicenseFrontDocument == null) {
      invalid.add('driver_license_front');
    }
    if (_driverLicenseBackDocument == null) {
      invalid.add('driver_license_back');
    }
    if (_vehicleRegistrationDocument == null) {
      invalid.add('vehicle_registration');
    }
    _setStepValidationResult(
      step: 3,
      invalidFields: invalid,
      warningMessage: 'Belge kartındaki zorunlu alanları tamamlayın.',
    );
    return invalid.isEmpty;
  }

  String _normalizedIban(String value) {
    return value.replaceAll(' ', '').toUpperCase();
  }

  bool _validateStepFive() {
    final invalid = <String>{};
    if (_paymentAccountHolderController.text.trim().isEmpty) {
      invalid.add('payment_account_holder');
    }
    if (_paymentBankNameController.text.trim().isEmpty) {
      invalid.add('payment_bank_name');
    }
    final iban = _normalizedIban(_paymentIbanController.text.trim());
    final ibanPattern = RegExp(r'^TR[0-9]{24}$');
    if (!ibanPattern.hasMatch(iban)) {
      invalid.add('payment_iban');
    }
    _setStepValidationResult(
      step: 4,
      invalidFields: invalid,
      warningMessage: 'Ödeme kartındaki zorunlu alanları doldurun.',
    );
    return invalid.isEmpty;
  }

  void _goToNextStep() {
    bool isValid = true;
    switch (_currentStep) {
      case 0:
        isValid = _validateStepOne();
        break;
      case 1:
        isValid = _validateStepTwo();
        break;
      case 2:
        isValid = _validateStepThree();
        break;
      case 3:
        isValid = _validateStepFour();
        break;
      default:
        break;
    }
    if (!isValid) return;
    _nextStep();
  }

  DateTime? _parseBirthDate(String value) {
    final normalized = value.replaceAll(' ', '');
    final parts = normalized.split('/');
    if (parts.length != 3) {
      return null;
    }
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) {
      return null;
    }
    try {
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final parsedDate = _parseBirthDate(_birthDateController.text.trim());
    final initialDate = parsedDate == null || parsedDate.isAfter(now)
        ? now
        : parsedDate;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (!mounted || pickedDate == null) {
      return;
    }
    final formattedDate =
        '${pickedDate.day.toString().padLeft(2, '0')} / ${pickedDate.month.toString().padLeft(2, '0')} / ${pickedDate.year.toString().padLeft(4, '0')}';
    setState(() {
      _birthDateController.text = formattedDate;
    });
    _clearFieldError('birth_date');
  }

  Future<void> _loadCities() async {
    setState(() {
      _citiesLoading = true;
    });
    try {
      final response = await http.get(Uri.parse(_turkiyeProvincesApi));
      if (response.statusCode != 200) {
        return;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = (decoded['data'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      final cities =
          data
              .map((city) => (city['name'] ?? '').toString().trim())
              .where((name) => name.isNotEmpty)
              .toList()
            ..sort((a, b) => a.compareTo(b));

      final initialCity = _cityController.text.trim();
      final selectedCity = cities.contains(initialCity) ? initialCity : null;
      if (!mounted) {
        return;
      }
      setState(() {
        _cityOptions = cities;
        _selectedCity = selectedCity;
      });
      if (selectedCity != null) {
        await _loadDistricts(selectedCity);
      }
    } catch (_) {
      // No-op: fallback to empty list when API is unavailable.
    } finally {
      if (mounted) {
        setState(() {
          _citiesLoading = false;
        });
      }
    }
  }

  Future<void> _loadDistricts(String city) async {
    setState(() {
      _districtsLoading = true;
    });
    try {
      final uri = Uri.parse(
        '$_turkiyeProvincesApi?name=${Uri.encodeQueryComponent(city)}',
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        return;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final cityData = (decoded['data'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      final districtsRaw = cityData.isEmpty
          ? const <dynamic>[]
          : (cityData.first['districts'] as List<dynamic>? ?? const []);
      final districts =
          districtsRaw
              .map(
                (district) => ((district as Map<String, dynamic>)['name'] ?? '')
                    .toString()
                    .trim(),
              )
              .where((name) => name.isNotEmpty)
              .toList()
            ..sort((a, b) => a.compareTo(b));

      final initialDistrict = _districtController.text.trim();
      final selectedDistrict = districts.contains(initialDistrict)
          ? initialDistrict
          : null;
      if (!mounted) {
        return;
      }
      setState(() {
        _districtOptions = districts;
        _selectedDistrict = selectedDistrict;
      });
    } catch (_) {
      // No-op: fallback to empty district list when API is unavailable.
    } finally {
      if (mounted) {
        setState(() {
          _districtsLoading = false;
        });
      }
    }
  }

  Future<void> _onCityChanged(String? city) async {
    setState(() {
      _selectedCity = city;
      _selectedDistrict = null;
      _cityController.text = city ?? '';
      _districtController.clear();
      _districtOptions = const [];
    });
    _clearFieldError('city');
    _clearFieldError('district');
    if (city == null || city.isEmpty) {
      return;
    }
    await _loadDistricts(city);
  }

  void _onDistrictChanged(String? district) {
    setState(() {
      _selectedDistrict = district;
      _districtController.text = district ?? '';
    });
    _clearFieldError('district');
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  bool _isPickingForSlot(_ApplyDocumentSlot slot) {
    switch (slot) {
      case _ApplyDocumentSlot.driverLicenseFront:
        return _isPickingDriverFrontDocument;
      case _ApplyDocumentSlot.driverLicenseBack:
        return _isPickingDriverBackDocument;
      case _ApplyDocumentSlot.vehicleRegistration:
        return _isPickingVehicleRegistrationDocument;
    }
  }

  void _setPickingForSlot(_ApplyDocumentSlot slot, bool value) {
    switch (slot) {
      case _ApplyDocumentSlot.driverLicenseFront:
        _isPickingDriverFrontDocument = value;
        break;
      case _ApplyDocumentSlot.driverLicenseBack:
        _isPickingDriverBackDocument = value;
        break;
      case _ApplyDocumentSlot.vehicleRegistration:
        _isPickingVehicleRegistrationDocument = value;
        break;
    }
  }

  void _setDocumentForSlot(
    _ApplyDocumentSlot slot,
    _ApplyPickedDocument? document,
  ) {
    switch (slot) {
      case _ApplyDocumentSlot.driverLicenseFront:
        _driverLicenseFrontDocument = document;
        if (document != null) _clearFieldError('driver_license_front');
        break;
      case _ApplyDocumentSlot.driverLicenseBack:
        _driverLicenseBackDocument = document;
        if (document != null) _clearFieldError('driver_license_back');
        break;
      case _ApplyDocumentSlot.vehicleRegistration:
        _vehicleRegistrationDocument = document;
        if (document != null) _clearFieldError('vehicle_registration');
        break;
    }
  }

  void _showUploadMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  bool _isAllowedDocumentName(String fileName, _ApplyDocumentSlot slot) {
    final normalized = fileName.trim().toLowerCase();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == normalized.length - 1) {
      return false;
    }
    final extension = normalized.substring(dotIndex + 1);
    if (slot == _ApplyDocumentSlot.vehicleRegistration) {
      return _allowedDocumentExtensions.contains(extension);
    }
    return _allowedImageExtensions.contains(extension);
  }

  String _extensionFromFileName(String fileName) {
    final normalized = fileName.trim().toLowerCase();
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex >= normalized.length - 1) {
      return '';
    }
    return normalized.substring(dotIndex + 1);
  }

  String _mimeTypeForExtension(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  String _sanitizePathSegment(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Future<_UploadedDocumentMeta> _uploadDocumentToStorage({
    required String userId,
    required String key,
    required _ApplyPickedDocument document,
  }) async {
    final extension = _extensionFromFileName(document.name);
    final safeExtension = extension.isEmpty ? 'bin' : extension;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeFileName = _sanitizePathSegment(document.name);
    final objectPath = '$userId/$key-$timestamp-$safeFileName';
    final contentType = _mimeTypeForExtension(safeExtension);

    final bucket = Supabase.instance.client.storage.from(_documentBucket);
    await bucket.uploadBinary(
      objectPath,
      document.bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: true),
    );
    final publicUrl = bucket.getPublicUrl(objectPath);

    return _UploadedDocumentMeta(
      fileName: document.name,
      fileSize: document.sizeBytes,
      publicUrl: publicUrl,
    );
  }

  Future<Uint8List?> _resolvePlatformFileBytes(PlatformFile picked) async {
    final directBytes = picked.bytes;
    if (directBytes != null && directBytes.isNotEmpty) {
      return directBytes;
    }

    final stream = picked.readStream;
    if (stream == null) {
      return null;
    }

    final allBytes = <int>[];
    await for (final chunk in stream) {
      allBytes.addAll(chunk);
      if (allBytes.length > _maxDocumentBytes) {
        break;
      }
    }
    if (allBytes.isEmpty) {
      return null;
    }
    return Uint8List.fromList(allBytes);
  }

  String _documentPickerError(dynamic error) {
    if (error is MissingPluginException) {
      return 'Dosya seçici başlatılamadı. Uygulamayı tamamen kapatıp yeniden açın.';
    }
    if (error is PlatformException &&
        (error.message?.trim().isNotEmpty ?? false)) {
      return error.message!.trim();
    }
    return 'Belge seçilirken hata oluştu. Tekrar deneyin.';
  }

  Future<void> _pickDocument(_ApplyDocumentSlot slot) async {
    if (_isPickingForSlot(slot)) return;
    setState(() {
      _setPickingForSlot(slot, true);
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: true,
        withReadStream: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final picked = result.files.first;
      if (!_isAllowedDocumentName(picked.name, slot)) {
        final isVehicleSlot = slot == _ApplyDocumentSlot.vehicleRegistration;
        _showUploadMessage(
          isVehicleSlot
              ? 'Desteklenmeyen dosya türü. Lütfen JPG, PNG, WEBP veya PDF seçin.'
              : 'Ehliyet için sadece görsel yüklenebilir (JPG, PNG, WEBP).',
        );
        return;
      }

      final bytes = await _resolvePlatformFileBytes(picked);
      if (bytes == null || bytes.isEmpty) {
        _showUploadMessage(
          'Dosya okunamadı. Farklı bir dosya seçin veya uygulamayı yeniden başlatın.',
        );
        return;
      }
      if (bytes.lengthInBytes > _maxDocumentBytes) {
        _showUploadMessage(
          'Dosya çok büyük (${_formatFileSize(bytes.lengthInBytes)}). En fazla 10 MB yükleyebilirsiniz.',
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _setDocumentForSlot(
          slot,
          _ApplyPickedDocument(name: picked.name, bytes: bytes),
        );
      });
      _showUploadMessage('Belge yüklendi: ${picked.name}');
    } catch (error) {
      debugPrint('Document picker error: $error');
      _showUploadMessage(_documentPickerError(error));
    } finally {
      if (mounted) {
        setState(() {
          _setPickingForSlot(slot, false);
        });
      }
    }
  }

  void _removeDocument(_ApplyDocumentSlot slot) {
    setState(() {
      _setDocumentForSlot(slot, null);
    });
  }

  String _normalizeSubmissionError(Object error) {
    final normalized = error.toString().replaceAll('Exception:', '').trim();
    if (error is StorageException) {
      return 'Belge yüklenemedi. Supabase tarafında `ihiz-courier-documents` bucket/policy kurulumunu doğrulayın.';
    }
    if (error is AuthException) {
      if (error.code == 'user_already_exists') {
        return 'Bu e-posta için hesap zaten var. Şifreyi doğru girerek tekrar deneyin.';
      }
      if (error.code == 'email_address_invalid') {
        return 'Geçerli bir e-posta adresi girin.';
      }
      if (error.code == 'weak_password') {
        return 'Şifre en az 6 karakter olmalı.';
      }
    }
    return normalized.isEmpty
        ? 'Başvuru gönderilirken hata oluştu.'
        : normalized;
  }

  bool _isAlreadyRegisteredError(Object error) {
    if (error is AuthException && error.code == 'user_already_exists') {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('already registered') ||
        text.contains('already exists');
  }

  bool _validateBeforeSubmit() {
    if (!_validateStepOne()) return false;
    if (!_validateStepTwo()) return false;
    if (!_validateStepThree()) return false;
    if (!_validateStepFour()) return false;
    if (!_validateStepFive()) return false;
    return true;
  }

  Future<void> _submitToBackend() async {
    if (_isSubmitting) return;
    if (!_validateBeforeSubmit()) return;

    setState(() {
      _isSubmitting = true;
    });

    final client = Supabase.instance.client;
    final nowIso = DateTime.now().toIso8601String();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    try {
      AuthResponse authResponse;
      try {
        authResponse = await client.auth.signUp(
          email: email,
          password: password,
          data: {'display_name': _fullName},
        );
      } catch (error) {
        if (!_isAlreadyRegisteredError(error)) rethrow;
        authResponse = await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }

      if (client.auth.currentSession == null) {
        try {
          authResponse = await client.auth.signInWithPassword(
            email: email,
            password: password,
          );
        } catch (_) {
          throw Exception(
            'Hesap oluşturuldu ancak oturum açılamadı. E-posta doğrulamasını tamamlayıp tekrar giriş yapın.',
          );
        }
      }

      final user = authResponse.user ?? client.auth.currentUser;
      if (user == null) {
        throw Exception('Kullanıcı hesabı oluşturulamadı.');
      }
      final normalizedPaymentIban = _normalizedIban(
        _paymentIbanController.text.trim(),
      );

      final driverFrontDocument = _driverLicenseFrontDocument;
      final driverBackDocument = _driverLicenseBackDocument;
      final vehicleRegistrationDocument = _vehicleRegistrationDocument;
      if (driverFrontDocument == null ||
          driverBackDocument == null ||
          vehicleRegistrationDocument == null) {
        throw Exception('Belge yüklemeleri eksik. Lütfen tüm belgeleri seçin.');
      }

      final uploadedDriverFront = await _uploadDocumentToStorage(
        userId: user.id,
        key: 'driver-license-front',
        document: driverFrontDocument,
      );
      final uploadedDriverBack = await _uploadDocumentToStorage(
        userId: user.id,
        key: 'driver-license-back',
        document: driverBackDocument,
      );
      final uploadedVehicleRegistration = await _uploadDocumentToStorage(
        userId: user.id,
        key: 'vehicle-registration',
        document: vehicleRegistrationDocument,
      );

      await client.from('users').upsert({
        'id': user.id,
        'email': email,
        'display_name': _fullName,
        'phone': _phoneController.text.trim(),
        'is_ihiz_approved': false,
        'updated_at': nowIso,
      }, onConflict: 'id');

      await client.from('ihiz_courier_applications').upsert({
        'user_id': user.id,
        'status': 'pending',
        'full_name': _fullName,
        'phone': _phoneController.text.trim(),
        'tc_number': _tcController.text.trim(),
        'birth_date': _birthDateController.text.trim(),
        'license_type': (_licenseType ?? '').trim(),
        'motor_type': (_motorType ?? '').trim(),
        'criminal_record': (_criminalRecord ?? '').trim(),
        'company_type': (_companyType ?? '').trim(),
        'tax_number': _taxNumberController.text.trim(),
        'city': _cityController.text.trim(),
        'district': _districtController.text.trim(),
        'availability': _availabilityController.text.trim(),
        'email': email,
        'note': _noteController.text.trim(),
        'push_notifications_enabled': true,
        'sound_alerts_enabled': true,
        'night_mode_enabled': false,
        'face_id_enabled': true,
        'payment_account_holder': _paymentAccountHolderController.text.trim(),
        'payment_bank_name': _paymentBankNameController.text.trim(),
        'payment_iban': normalizedPaymentIban,
        'driver_license_front_file_name': uploadedDriverFront.fileName,
        'driver_license_front_file_size': uploadedDriverFront.fileSize,
        'driver_license_front_url': uploadedDriverFront.publicUrl,
        'driver_license_back_file_name': uploadedDriverBack.fileName,
        'driver_license_back_file_size': uploadedDriverBack.fileSize,
        'driver_license_back_url': uploadedDriverBack.publicUrl,
        'vehicle_registration_file_name': uploadedVehicleRegistration.fileName,
        'vehicle_registration_file_size': uploadedVehicleRegistration.fileSize,
        'vehicle_registration_url': uploadedVehicleRegistration.publicUrl,
        'rejection_reason': null,
        'approved_at': null,
        'updated_at': nowIso,
      }, onConflict: 'user_id');

      if (!mounted) return;
      widget.onApplicationSaved(
        CourierApplicationData(
          fullName: _fullName,
          phone: _phoneController.text.trim(),
          tcNumber: _tcController.text.trim(),
          birthDate: _birthDateController.text.trim(),
          licenseType: (_licenseType ?? '').trim(),
          motorType: (_motorType ?? '').trim(),
          criminalRecord: (_criminalRecord ?? '').trim(),
          companyType: (_companyType ?? '').trim(),
          city: _cityController.text.trim(),
          district: _districtController.text.trim(),
          availability: _availabilityController.text.trim(),
          email: email,
          note: _noteController.text.trim(),
          pushNotificationsEnabled: true,
          soundAlertsEnabled: true,
          nightModeEnabled: false,
          faceIdEnabled: true,
          paymentAccountHolder: _paymentAccountHolderController.text.trim(),
          paymentBankName: _paymentBankNameController.text.trim(),
          paymentIban: normalizedPaymentIban,
          driverLicenseFileName: uploadedDriverFront.fileName,
          driverLicenseFileSize: uploadedDriverFront.fileSize,
          driverLicenseFrontFileName: uploadedDriverFront.fileName,
          driverLicenseFrontFileSize: uploadedDriverFront.fileSize,
          driverLicenseBackFileName: uploadedDriverBack.fileName,
          driverLicenseBackFileSize: uploadedDriverBack.fileSize,
          vehicleRegistrationFileName: uploadedVehicleRegistration.fileName,
          vehicleRegistrationFileSize: uploadedVehicleRegistration.fileSize,
        ),
      );
      setState(() {
        _submitted = true;
      });
    } catch (error) {
      if (!mounted) return;
      _showUploadMessage(_normalizeSubmissionError(error));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _submit() {
    if (_isSubmitting) return;
    unawaited(_submitToBackend());
  }

  String _valueOrFallback(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String get _stepOneSummary =>
      '${_valueOrFallback(_fullName, 'Ad-soyad')} • ${_valueOrFallback(_phoneController.text, 'Telefon')}';

  String get _stepTwoSummary =>
      '${_licenseType ?? 'Ehliyet seçilmedi'} • ${_motorType ?? 'Motor bilgisi yok'}';

  String get _stepThreeSummary =>
      '${_valueOrFallback(_cityController.text, 'İl')} / ${_valueOrFallback(_districtController.text, 'İlçe')} • ${_valueOrFallback(_availabilityController.text, 'Müsaitlik')}';

  String get _stepFourSummary {
    final front = _driverLicenseFrontDocument != null
        ? 'Ehliyet ön ✓'
        : 'Ehliyet ön ✗';
    final back = _driverLicenseBackDocument != null
        ? 'Ehliyet arka ✓'
        : 'Ehliyet arka ✗';
    final vehicle = _vehicleRegistrationDocument != null
        ? 'Ruhsat ✓'
        : 'Ruhsat ✗';
    return '$front • $back • $vehicle';
  }

  String get _stepFiveSummary =>
      '${_valueOrFallback(_paymentBankNameController.text, 'Banka adı')} • ${_valueOrFallback(_paymentIbanController.text, 'IBAN')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Geri',
        ),
        title: const Text('Kayıt Ol / Başvur'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: _submitted ? _buildSubmittedView() : _buildWizardView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWizardView() {
    return IhizSectionShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 760;
          final fieldWidth = isNarrow
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kayıt Ol / Başvur',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF163B73),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Başvuruyu adım adım tamamlayın. Her kart bittiğinde bir sonraki bilgi grubuna geçilir, en sonda ödeme bilgileri alınır.',
                style: TextStyle(color: Color(0xFF5B6B86), height: 1.5),
              ),
              const SizedBox(height: 18),
              _ApplyProgressHeader(currentStep: _currentStep),
              const SizedBox(height: 20),
              if (_currentStep > 0)
                _ApplyCompletedCard(
                  step: '1. Kart',
                  title: 'Kimlik Bilgileri',
                  summary: _stepOneSummary,
                ),
              if (_currentStep == 0)
                _ApplyStepCard(
                  step: '1. Kart',
                  title: 'Kimlik Bilgileri',
                  description:
                      'Önce temel kimlik ve iletişim bilgilerini girin.',
                  hasError: _hasStepError(0),
                  actions: [
                    _ApplyPrimaryButton(
                      label: 'Tamam, devam et',
                      onPressed: _goToNextStep,
                    ),
                  ],
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplyField(
                          label: 'Ad',
                          hint: 'Adınız',
                          controller: _firstNameController,
                          hasError: _hasFieldError('first_name'),
                          errorText: _fieldErrorText(
                            'first_name',
                            'Ad zorunlu',
                          ),
                          onChanged: (_) => _clearFieldError('first_name'),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplyField(
                          label: 'Soyad',
                          hint: 'Soyadınız',
                          controller: _lastNameController,
                          hasError: _hasFieldError('last_name'),
                          errorText: _fieldErrorText(
                            'last_name',
                            'Soyad zorunlu',
                          ),
                          onChanged: (_) => _clearFieldError('last_name'),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplyField(
                          label: 'Telefon',
                          hint: '05xx xxx xx xx',
                          controller: _phoneController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          maxLength: 11,
                          hasError: _hasFieldError('phone'),
                          errorText: _fieldErrorText(
                            'phone',
                            'Telefon 11 haneli olmalı',
                          ),
                          onChanged: (_) => _clearFieldError('phone'),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplyField(
                          label: 'TC Kimlik Numarası',
                          hint: '11 haneli kimlik numarası',
                          controller: _tcController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          maxLength: 11,
                          hasError: _hasFieldError('tc_number'),
                          errorText: _fieldErrorText(
                            'tc_number',
                            'TC kimlik no 11 haneli olmalı',
                          ),
                          onChanged: (_) => _clearFieldError('tc_number'),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplyField(
                          label: 'Doğum Tarihi',
                          hint: 'GG / AA / YYYY',
                          controller: _birthDateController,
                          readOnly: true,
                          onTap: _pickBirthDate,
                          suffixIcon: const Icon(Icons.calendar_today_outlined),
                          hasError: _hasFieldError('birth_date'),
                          errorText: _fieldErrorText(
                            'birth_date',
                            'Geçerli doğum tarihi gerekli',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplyField(
                          label: 'E-posta',
                          hint: 'ornek@ihiz.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          hasError: _hasFieldError('email'),
                          errorText: _fieldErrorText(
                            'email',
                            'Geçerli e-posta girin',
                          ),
                          onChanged: (_) => _clearFieldError('email'),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplyField(
                          label: 'Şifre',
                          hint: 'Şifre giriniz',
                          controller: _passwordController,
                          obscureText: true,
                          hasError: _hasFieldError('password'),
                          errorText: _fieldErrorText(
                            'password',
                            'Şifre en az 6 karakter olmalı',
                          ),
                          onChanged: (_) => _clearFieldError('password'),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_currentStep > 1)
                _ApplyCompletedCard(
                  step: '2. Kart',
                  title: 'Sürücü ve Şirket Bilgileri',
                  summary: _stepTwoSummary,
                ),
              if (_currentStep == 1)
                _ApplyStepCard(
                  step: '2. Kart',
                  title: 'Sürücü ve Şirket Bilgileri',
                  description: 'Ehliyet, motor ve şirket durumunuzu seçin.',
                  hasError: _hasStepError(1),
                  actions: [
                    _ApplySecondaryButton(
                      label: 'Geri',
                      onPressed: _previousStep,
                    ),
                    _ApplyPrimaryButton(
                      label: 'Tamam, devam et',
                      onPressed: _goToNextStep,
                    ),
                  ],
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplySelectField(
                          label: 'Ehliyet Türü',
                          hint: 'Ehliyet türü seçin',
                          value: _licenseType,
                          items: const ['A1', 'A2', 'B', 'Diğer'],
                          onChanged: (value) {
                            setState(() {
                              _licenseType = value;
                            });
                            _clearFieldError('license_type');
                          },
                          hasError: _hasFieldError('license_type'),
                          errorText: _fieldErrorText(
                            'license_type',
                            'Ehliyet türü zorunlu',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplySelectField(
                          label: 'Motorsiklet Türü',
                          hint: 'Motor türü seçin',
                          value: _motorType,
                          items: const [
                            '110 CC ve üzeri',
                            '50 CC',
                            'Motorum yok',
                          ],
                          onChanged: (value) {
                            setState(() {
                              _motorType = value;
                            });
                            _clearFieldError('motor_type');
                          },
                          hasError: _hasFieldError('motor_type'),
                          errorText: _fieldErrorText(
                            'motor_type',
                            'Motosiklet türü zorunlu',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplySelectField(
                          label: 'Adli Sicil Kaydı',
                          hint: 'Durum seçin',
                          value: _criminalRecord,
                          items: const ['Var', 'Yok'],
                          onChanged: (value) {
                            setState(() {
                              _criminalRecord = value;
                            });
                            _clearFieldError('criminal_record');
                          },
                          hasError: _hasFieldError('criminal_record'),
                          errorText: _fieldErrorText(
                            'criminal_record',
                            'Adli sicil seçimi zorunlu',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplySelectField(
                          label: 'Şirket Türü',
                          hint: 'Şirket türü seçin',
                          value: _companyType,
                          items: const [
                            'Şahıs Şirketi',
                            'Limited Şirket',
                            'Şirketim yok',
                          ],
                          onChanged: (value) {
                            setState(() {
                              _companyType = value;
                              if (value == 'Şirketim yok') {
                                _taxNumberController.clear();
                                _clearFieldError('tax_number');
                              }
                            });
                            _clearFieldError('company_type');
                          },
                          hasError: _hasFieldError('company_type'),
                          errorText: _fieldErrorText(
                            'company_type',
                            'Şirket türü zorunlu',
                          ),
                        ),
                      ),
                      if (_companyType != null &&
                          _companyType != 'Şirketim yok')
                        SizedBox(
                          width: fieldWidth,
                          child: _ApplyField(
                            label: 'Vergi Numarası',
                            hint: 'Vergi numarası giriniz',
                            controller: _taxNumberController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            maxLength: 10,
                            hasError: _hasFieldError('tax_number'),
                            errorText: _fieldErrorText(
                              'tax_number',
                              'Vergi no 10 haneli olmalı',
                            ),
                            onChanged: (_) => _clearFieldError('tax_number'),
                          ),
                        ),
                    ],
                  ),
                ),
              if (_currentStep > 2)
                _ApplyCompletedCard(
                  step: '3. Kart',
                  title: 'Bölge ve Çalışma Bilgileri',
                  summary: _stepThreeSummary,
                ),
              if (_currentStep == 2)
                _ApplyStepCard(
                  step: '3. Kart',
                  title: 'Bölge ve Çalışma Bilgileri',
                  description:
                      'Çalışmak istediğiniz bölge ve müsaitlik bilgilerini girin.',
                  hasError: _hasStepError(2),
                  actions: [
                    _ApplySecondaryButton(
                      label: 'Geri',
                      onPressed: _previousStep,
                    ),
                    _ApplyPrimaryButton(
                      label: 'Belgeleri aç',
                      onPressed: _goToNextStep,
                    ),
                  ],
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplySelectField(
                          label: 'İl',
                          hint: _citiesLoading
                              ? 'İller yükleniyor...'
                              : 'İl seçin',
                          value: _selectedCity,
                          items: _cityOptions,
                          onChanged: (value) {
                            _onCityChanged(value);
                          },
                          hasError: _hasFieldError('city'),
                          errorText: _fieldErrorText(
                            'city',
                            'İl seçimi zorunlu',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplySelectField(
                          label: 'İlçe',
                          hint: _selectedCity == null
                              ? 'Önce il seçin'
                              : (_districtsLoading
                                    ? 'İlçeler yükleniyor...'
                                    : 'İlçe seçin'),
                          value: _selectedDistrict,
                          items: _districtOptions,
                          onChanged: (value) {
                            _onDistrictChanged(value);
                          },
                          hasError: _hasFieldError('district'),
                          errorText: _fieldErrorText(
                            'district',
                            'İlçe seçimi zorunlu',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplyField(
                          label: 'Müsaitlik',
                          hint: 'Tam zamanlı / Yarı zamanlı',
                          controller: _availabilityController,
                          hasError: _hasFieldError('availability'),
                          errorText: _fieldErrorText(
                            'availability',
                            'Müsaitlik bilgisi zorunlu',
                          ),
                          onChanged: (_) => _clearFieldError('availability'),
                        ),
                      ),
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _ApplyField(
                          label: 'Kısa not',
                          hint:
                              'Teslimat deneyiminiz, çalışmak istediğiniz bölge veya ek açıklamalar',
                          maxLines: 4,
                          controller: _noteController,
                          hasError: _hasFieldError('note'),
                          errorText: _fieldErrorText('note', 'Bu alan zorunlu'),
                          onChanged: (_) => _clearFieldError('note'),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_currentStep == 3)
                _ApplyStepCard(
                  step: '4. Kart',
                  title: 'Belge Yükleme',
                  description:
                      'Başvuruyu göndermeden önce zorunlu belge alanlarını tamamlayın.',
                  hasError: _hasStepError(3),
                  actions: [
                    _ApplySecondaryButton(
                      label: 'Geri',
                      onPressed: _previousStep,
                    ),
                    _ApplyPrimaryButton(
                      label: 'Ödeme bilgileri',
                      onPressed: _goToNextStep,
                    ),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: _ApplyDriverLicenseUploadField(
                              label: 'Sürücü belge görseli',
                              caption:
                                  'Ehliyetin ön ve arka yüzünü görsel olarak yükleyin',
                              frontDocument: _driverLicenseFrontDocument,
                              backDocument: _driverLicenseBackDocument,
                              isPickingFront: _isPickingDriverFrontDocument,
                              isPickingBack: _isPickingDriverBackDocument,
                              hasError:
                                  _hasFieldError('driver_license_front') ||
                                  _hasFieldError('driver_license_back'),
                              errorText:
                                  (_hasFieldError('driver_license_front') ||
                                      _hasFieldError('driver_license_back'))
                                  ? 'Ehliyet ön ve arka yüz zorunlu'
                                  : null,
                              onPickFront: () => _pickDocument(
                                _ApplyDocumentSlot.driverLicenseFront,
                              ),
                              onPickBack: () => _pickDocument(
                                _ApplyDocumentSlot.driverLicenseBack,
                              ),
                              onClearFront: () => _removeDocument(
                                _ApplyDocumentSlot.driverLicenseFront,
                              ),
                              onClearBack: () => _removeDocument(
                                _ApplyDocumentSlot.driverLicenseBack,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _ApplyUploadField(
                              label: 'Araç ruhsatı',
                              caption:
                                  'Ruhsat görseli veya PDF belgesini ekleyin',
                              document: _vehicleRegistrationDocument,
                              isPicking: _isPickingVehicleRegistrationDocument,
                              hasError: _hasFieldError('vehicle_registration'),
                              errorText: _fieldErrorText(
                                'vehicle_registration',
                                'Araç ruhsatı zorunlu',
                              ),
                              onPick: () => _pickDocument(
                                _ApplyDocumentSlot.vehicleRegistration,
                              ),
                              onClear: () => _removeDocument(
                                _ApplyDocumentSlot.vehicleRegistration,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F9FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'Bu adımda dosyanızı cihazınızdan seçip başvuruya ekleyebilirsiniz. Kabul edilen dosya tipleri: JPG, PNG, WEBP ve PDF (maksimum 10 MB).',
                          style: TextStyle(
                            color: Color(0xFF163B73),
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_currentStep > 3)
                _ApplyCompletedCard(
                  step: '4. Kart',
                  title: 'Belge Yükleme',
                  summary: _stepFourSummary,
                ),
              if (_currentStep == 4)
                _ApplyStepCard(
                  step: '5. Kart',
                  title: 'Ödeme Bilgileri',
                  description:
                      'Ödeme aktarımı için banka ve hesap bilgilerinizi girin.',
                  hasError: _hasStepError(4),
                  actions: [
                    _ApplySecondaryButton(
                      label: 'Geri',
                      onPressed: _previousStep,
                    ),
                    _ApplyPrimaryButton(
                      label: _isSubmitting
                          ? 'Gönderiliyor...'
                          : 'Başvuruyu Gönder',
                      onPressed: _isSubmitting ? null : _submit,
                    ),
                  ],
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplyField(
                          label: 'Hesap Sahibi',
                          hint: 'Ad Soyad',
                          controller: _paymentAccountHolderController,
                          hasError: _hasFieldError('payment_account_holder'),
                          errorText: _fieldErrorText(
                            'payment_account_holder',
                            'Hesap sahibi zorunlu',
                          ),
                          onChanged: (_) =>
                              _clearFieldError('payment_account_holder'),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _ApplyField(
                          label: 'Banka Adı',
                          hint: 'Örn: Ziraat Bankası',
                          controller: _paymentBankNameController,
                          hasError: _hasFieldError('payment_bank_name'),
                          errorText: _fieldErrorText(
                            'payment_bank_name',
                            'Banka adı zorunlu',
                          ),
                          onChanged: (_) =>
                              _clearFieldError('payment_bank_name'),
                        ),
                      ),
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _ApplyField(
                          label: 'IBAN',
                          hint: 'TR00 0000 0000 0000 0000 0000 00',
                          controller: _paymentIbanController,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[A-Za-z0-9 ]'),
                            ),
                            LengthLimitingTextInputFormatter(32),
                          ],
                          hasError: _hasFieldError('payment_iban'),
                          errorText: _fieldErrorText(
                            'payment_iban',
                            'Geçerli TR IBAN girin',
                          ),
                          onChanged: (_) => _clearFieldError('payment_iban'),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_currentStep > 4)
                _ApplyCompletedCard(
                  step: '5. Kart',
                  title: 'Ödeme Bilgileri',
                  summary: _stepFiveSummary,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubmittedView() {
    return IhizSectionShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF163B73), Color(0xFF4A90E2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: Colors.white,
              size: 42,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Başvurunuz Alındı',
            style: TextStyle(
              color: Color(0xFF163B73),
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Kurye başvurunuz ön inceleme sırasına alındı. Kimlik, sürücü ve belge bilgileriniz operasyon ekibine iletildi. Onay sonrası giriş ekranından panelinize geçebileceksiniz.',
            style: TextStyle(color: Color(0xFF5B6B86), height: 1.6),
          ),
          const SizedBox(height: 22),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ApplyStatusChip('Kimlik bilgileri alındı'),
              _ApplyStatusChip('Belgeler incelemeye gönderildi'),
              _ApplyStatusChip('Operasyon geri dönüşü bekleniyor'),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F9FF),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFDDE6F4)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sonraki adımlar',
                  style: TextStyle(
                    color: Color(0xFF163B73),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 12),
                _SuccessLine(
                  'Başvurunuz operasyon ekibi tarafından incelenir.',
                ),
                SizedBox(height: 10),
                _SuccessLine(
                  'Gerekirse belge doğrulaması için sizinle iletişime geçilir.',
                ),
                SizedBox(height: 10),
                _SuccessLine(
                  'Onaylandığınızda giriş ekranından panelinize geçersiniz.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton(
                onPressed: widget.onGoLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF163B73),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Giriş Ekranına Geç',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _submitted = false;
                    _currentStep = 0;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Başvuruyu Görüntüle'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class IhizSitePage extends StatefulWidget {
  const IhizSitePage({
    super.key,
    required this.onExit,
    this.applicationData,
    required this.pricingConfig,
    this.onApplicationDataChanged,
    this.onPricingConfigChanged,
  });

  final VoidCallback onExit;
  final CourierApplicationData? applicationData;
  final IhizPricingConfig pricingConfig;
  final ValueChanged<CourierApplicationData>? onApplicationDataChanged;
  final ValueChanged<IhizPricingConfig>? onPricingConfigChanged;

  @override
  State<IhizSitePage> createState() => _IhizSitePageState();
}

class _IhizSitePageState extends State<IhizSitePage> {
  static const LatLng _turkiyeCenter = LatLng(39.0, 35.0);
  static const String _activeOrderStorageKey = 'ihiz_active_order_item_id';
  static const String _activeStageStorageKey = 'ihiz_active_delivery_stage';
  double _earningBaseFee = 28;
  double _earningPerKmFee = 7;
  double _earningPlatformFee = 10;
  double _earningMinutePrice = 4;
  double _earningNightBonus = 12;
  double _earningRainBonus = 15;
  double _etaPerKmMinute = 5;
  double _etaBaseMinute = 6;
  double _deliveryGeoFenceMeters = 150;
  bool _otpRequiredForDelivery = true;
  bool _rainBonusEnabled = true;
  int _selectedOrderIndex = 0;
  int _selectedTabIndex = 0;
  int? _activeDeliveryOrderIndex;
  String? _activeDeliveryOrderItemId;
  int? _mapPopupOrderIndex;
  bool _mapPopupCardExpanded = true;
  _DeliveryStage _deliveryStage = _DeliveryStage.idle;
  bool _mapDeliveryPanelExpanded = true;
  bool _courierOnline = false;
  DateTime? _workStartedAt;
  Duration _workedToday = Duration.zero;
  Timer? _workTicker;
  final ValueNotifier<Duration> _workedDurationNotifier = ValueNotifier(
    Duration.zero,
  );
  DateTime? _lastActiveRouteRefreshAt;
  final MapController _mobileMapController = MapController();
  final TextEditingController _mapSearchController = TextEditingController();
  StreamSubscription<List<Map<String, dynamic>>>? _storesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _orderItemsSubscription;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _storesRefreshTimer;
  Timer? _webLocationTimer;
  List<_LiveStoreMarker> _liveStores = const [];
  List<_CourierPoolOrder> _courierPoolOrders = const [];
  String _storeSearchQuery = '';
  String? _highlightedStoreId;
  bool _storesLoading = true;
  bool _locationTrackingStarted = false;
  LatLng? _courierLocation;
  String? _locationStatus;
  String? _lastDeliverySyncError;
  List<LatLng> _activeRoutePoints = const [];
  List<LatLng> _previewRoutePoints = const [];
  bool _routeLoading = false;
  LatLng? _lastRouteOrigin;
  LatLng? _lastRouteDestination;
  CourierApplicationData? _applicationData;
  bool _taskNotificationsEnabled = true;
  bool _soundAlertsEnabled = true;
  bool _nightModeEnabled = false;
  bool _faceIdEnabled = true;
  Set<String> _activeRegionKeys = <String>{};
  final Map<String, _ActiveRegionOption> _manualActiveRegions =
      <String, _ActiveRegionOption>{};
  Set<String> _knownPoolOrderIds = <String>{};
  static const List<String> _deliveryIssueReasons = [
    'Kullanıcı evde değil',
    'Telefonu açmıyor',
    'Lokasyon değiştirmiş',
    'Hatalı konum girmiş',
    'Diğer sebepler',
  ];

  @override
  void didUpdateWidget(covariant IhizSitePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pricingConfig != widget.pricingConfig) {
      _applyPricingConfig(widget.pricingConfig);
      unawaited(_fetchCourierPoolOrders(force: true));
    }
    if (oldWidget.applicationData != widget.applicationData &&
        widget.applicationData != null) {
      _applicationData = widget.applicationData;
      _syncUiPreferencesFromApplicationData(widget.applicationData);
    }
  }

  static const List<_MapNodeLayout> _mapLayouts = [
    _MapNodeLayout(
      storeAlignment: Alignment(-0.66, -0.30),
      courierAlignment: Alignment(-0.10, -0.12),
      customerAlignment: Alignment(0.64, 0.52),
      zoneLabel: 'Gökmeydan hattı',
      demandLabel: '2 dk önce çağrı açtı',
      storePoint: LatLng(39.7623, 30.5097),
      courierPoint: LatLng(39.7606, 30.5162),
      customerPoint: LatLng(39.7718, 30.5314),
    ),
    _MapNodeLayout(
      storeAlignment: Alignment(-0.12, -0.62),
      courierAlignment: Alignment(0.12, -0.16),
      customerAlignment: Alignment(0.72, 0.18),
      zoneLabel: 'Hoşnudiye hattı',
      demandLabel: 'Yoğun saat çağrısı',
      storePoint: LatLng(39.7827, 30.5149),
      courierPoint: LatLng(39.7774, 30.5208),
      customerPoint: LatLng(39.7866, 30.5332),
    ),
    _MapNodeLayout(
      storeAlignment: Alignment(0.30, -0.14),
      courierAlignment: Alignment(0.12, 0.12),
      customerAlignment: Alignment(0.78, 0.66),
      zoneLabel: 'Cassaba hattı',
      demandLabel: 'Elektronik teslim bekliyor',
      storePoint: LatLng(39.7761, 30.4892),
      courierPoint: LatLng(39.7728, 30.5008),
      customerPoint: LatLng(39.7894, 30.5257),
    ),
  ];

  static const List<_RegisteredStoreData> _demoStores = [
    _RegisteredStoreData(
      id: 'demo-a101',
      name: 'A101 Gökmeydan',
      address: 'Gökmeydan Mah. Nazım Hikmet Cad. No:45',
      cityLabel: 'Eskişehir / Gökmeydan',
      point: LatLng(39.7623, 30.5097),
      accent: Color(0xFF3563E9),
      taskTitle: 'Yakın market teslimatı',
      customerName: 'Elif T.',
      customerAddress: 'Şirintepe Mah. Yalçın Sk. No:8',
      storePhone: '0222 220 11 01',
      customerPhone: '0532 120 10 08',
      deliveryCode: '1408',
      earning: '₺96',
      earningBreakdown: _CourierEarningBreakdown(
        distanceKm: 1.8,
        baseFee: 28,
        perKmFee: 7,
        distanceFee: 12.6,
        distanceBasedFee: 40.6,
        etaMinutes: 15,
        minutePrice: 4,
        etaBasedFee: 60,
        nightBonus: 0,
        rainBonus: 0,
        platformFee: 10,
        deliveryTotal: 50.6,
        total: 40.6,
      ),
      eta: '11 dk',
      route: '1.8 km',
      label: '10 dk hedef',
      tags: ['Tek paket', 'Yakın müşteri', 'Hafif ürün'],
      isRequestingCourier: true,
    ),
    _RegisteredStoreData(
      id: 'demo-macro',
      name: 'MacroCenter Eskişehir',
      address: 'Hoşnudiye Mah. İsmet İnönü 1 Cad. No:18',
      cityLabel: 'Eskişehir / Hoşnudiye',
      point: LatLng(39.7827, 30.5149),
      accent: Color(0xFF1E88E5),
      taskTitle: 'Sıcak teslim',
      customerName: 'Sena A.',
      customerAddress: 'Cumhuriyet Mah. Fabrikalar Sok. No:14',
      storePhone: '0222 220 11 02',
      customerPhone: '0532 120 10 14',
      deliveryCode: '2714',
      earning: '₺118',
      earningBreakdown: _CourierEarningBreakdown(
        distanceKm: 2.6,
        baseFee: 28,
        perKmFee: 7,
        distanceFee: 18.2,
        distanceBasedFee: 46.2,
        etaMinutes: 19,
        minutePrice: 4,
        etaBasedFee: 76,
        nightBonus: 0,
        rainBonus: 0,
        platformFee: 10,
        deliveryTotal: 56.2,
        total: 46.2,
      ),
      eta: '14 dk',
      route: '2.6 km',
      label: 'Öncelikli rota',
      tags: ['Motor uygun', 'Temassız teslim', 'Bonus açık'],
      isRequestingCourier: true,
    ),
    _RegisteredStoreData(
      id: 'demo-teknosa',
      name: 'Teknosa Cassaba Modern',
      address: 'Büyükdere Cad. Cassaba Modern AVM Zemin Kat',
      cityLabel: 'Eskişehir / Cassaba',
      point: LatLng(39.7761, 30.4892),
      accent: Color(0xFFE17055),
      taskTitle: 'Elektronik teslim',
      customerName: 'Mert K.',
      customerAddress: 'Vişnelik Mah. Öğretmenler Cad. No:32',
      storePhone: '0222 220 11 03',
      customerPhone: '0532 120 10 32',
      deliveryCode: '4432',
      earning: '₺164',
      earningBreakdown: _CourierEarningBreakdown(
        distanceKm: 4.0,
        baseFee: 28,
        perKmFee: 7,
        distanceFee: 28,
        distanceBasedFee: 56,
        etaMinutes: 26,
        minutePrice: 4,
        etaBasedFee: 104,
        nightBonus: 0,
        rainBonus: 0,
        platformFee: 10,
        deliveryTotal: 66,
        total: 56,
      ),
      eta: '21 dk',
      route: '4.0 km',
      label: 'Kimlik kontrolü',
      tags: ['4 paket', 'Kimlik doğrulama', 'Yoğun saat bonusu'],
      isRequestingCourier: true,
    ),
    _RegisteredStoreData(
      id: 'demo-migros',
      name: 'Migros Doktorlar',
      address: 'İsmet İnönü 1 Cad. No:102',
      cityLabel: 'Eskişehir / Doktorlar',
      point: LatLng(39.7804, 30.5202),
      accent: Color(0xFF7A4DFF),
      taskTitle: 'Ekspres market görevi',
      customerName: 'Berke A.',
      customerAddress: 'Bahçelievler Mah. Ertaş Cad. No:17',
      storePhone: '0222 220 11 04',
      customerPhone: '0532 120 10 17',
      deliveryCode: '8917',
      earning: '₺132',
      earningBreakdown: _CourierEarningBreakdown(
        distanceKm: 2.2,
        baseFee: 28,
        perKmFee: 7,
        distanceFee: 15.4,
        distanceBasedFee: 43.4,
        etaMinutes: 17,
        minutePrice: 4,
        etaBasedFee: 68,
        nightBonus: 0,
        rainBonus: 0,
        platformFee: 10,
        deliveryTotal: 53.4,
        total: 43.4,
      ),
      eta: '15 dk',
      route: '2.2 km',
      label: 'Hızlı teslim',
      tags: ['2 paket', 'Kampanya aktif', 'Yakın rota'],
      isRequestingCourier: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _applyPricingConfig(widget.pricingConfig);
    _applicationData = widget.applicationData;
    _syncUiPreferencesFromApplicationData(_applicationData);
    _subscribeToStores();
    _checkLocationPermissionAndStart();
    unawaited(_restorePersistedActiveDeliveryState());
    unawaited(_loadSavedActiveRegions());
  }

  @override
  void dispose() {
    _workTicker?.cancel();
    _workedDurationNotifier.dispose();
    _storesSubscription?.cancel();
    _orderItemsSubscription?.cancel();
    _storesRefreshTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _webLocationTimer?.cancel();
    _mapSearchController.dispose();
    super.dispose();
  }

  Future<void> _restorePersistedActiveDeliveryState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeOrderKey = _scopedDeliveryStorageKey(_activeOrderStorageKey);
      final activeStageKey = _scopedDeliveryStorageKey(_activeStageStorageKey);
      final persistedOrderItemId =
          (prefs.getString(activeOrderKey) ??
                  prefs.getString(_activeOrderStorageKey) ??
                  '')
              .trim();
      if (persistedOrderItemId.isEmpty) return;
      final stageRaw =
          (prefs.getString(activeStageKey) ??
                  prefs.getString(_activeStageStorageKey) ??
                  '')
              .trim();
      final restoredStage = _deliveryStageFromStorage(stageRaw);

      if (!mounted) return;
      setState(() {
        _activeDeliveryOrderItemId = persistedOrderItemId;
        _deliveryStage = restoredStage;
        _mapDeliveryPanelExpanded = false;
        _selectedTabIndex = 1;
      });

      await _fetchCourierPoolOrders(force: true);
      if (!mounted) return;

      if (_activeDeliveryOrder == null) {
        await _clearPersistedActiveDeliveryState();
        if (!mounted) return;
        setState(() {
          _deliveryStage = _DeliveryStage.idle;
          _activeDeliveryOrderIndex = null;
          _activeDeliveryOrderItemId = null;
          _selectedTabIndex = 0;
          _mapDeliveryPanelExpanded = true;
        });
        return;
      }

      _focusActiveDeliveryRoute();
      _refreshActiveRoute();
    } catch (_) {
      // Local storage restore optionaldir; hata olursa normal akis devam eder.
    }
  }

  _DeliveryStage _deliveryStageFromStorage(String raw) {
    switch (raw) {
      case 'headingToStore':
        return _DeliveryStage.headingToStore;
      case 'onTheWay':
        return _DeliveryStage.onTheWay;
      default:
        return _DeliveryStage.onTheWay;
    }
  }

  Future<void> _persistActiveDeliveryState() async {
    final orderItemId = (_activeDeliveryOrderItemId ?? '').trim();
    if (orderItemId.isEmpty ||
        _deliveryStage == _DeliveryStage.idle ||
        _deliveryStage == _DeliveryStage.delivered) {
      await _clearPersistedActiveDeliveryState();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeOrderKey = _scopedDeliveryStorageKey(_activeOrderStorageKey);
      final activeStageKey = _scopedDeliveryStorageKey(_activeStageStorageKey);
      await prefs.setString(activeOrderKey, orderItemId);
      await prefs.setString(activeStageKey, _deliveryStage.name);
      await prefs.remove(_activeOrderStorageKey);
      await prefs.remove(_activeStageStorageKey);
    } catch (_) {
      // Local storage save optionaldir; akisi bozmasin.
    }
  }

  Future<void> _clearPersistedActiveDeliveryState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeOrderKey = _scopedDeliveryStorageKey(_activeOrderStorageKey);
      final activeStageKey = _scopedDeliveryStorageKey(_activeStageStorageKey);
      await prefs.remove(activeOrderKey);
      await prefs.remove(activeStageKey);
      await prefs.remove(_activeOrderStorageKey);
      await prefs.remove(_activeStageStorageKey);
    } catch (_) {
      // Local storage clear optionaldir; akisi bozmasin.
    }
  }

  String _scopedDeliveryStorageKey(String baseKey) {
    final userId = Supabase.instance.client.auth.currentUser?.id.trim() ?? '';
    if (userId.isEmpty) return baseKey;
    return '$baseKey:$userId';
  }

  bool _isTerminalOrderItemStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'delivered' ||
        normalized == 'cancelled' ||
        normalized == 'return_requested' ||
        normalized == 'return_received' ||
        normalized == 'refunded' ||
        normalized == 'returned';
  }

  bool _isReturnFlowOrderItemStatus(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'return_requested' ||
        normalized == 'return_approved' ||
        normalized == 'return_shipped_back' ||
        normalized == 'return_received' ||
        normalized == 'returned' ||
        normalized == 'refunded';
  }

  void _toggleWorkStatus() {
    setState(() {
      if (_courierOnline) {
        if (_workStartedAt != null) {
          _workedToday += DateTime.now().difference(_workStartedAt!);
        }
        _courierOnline = false;
        _workStartedAt = null;
        _workedDurationNotifier.value = _workedToday;
        _workTicker?.cancel();
      } else {
        _courierOnline = true;
        _workStartedAt = DateTime.now();
        _workTicker?.cancel();
        _workedDurationNotifier.value = _workedToday;
        _workTicker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || !_courierOnline || _workStartedAt == null) return;
          _workedDurationNotifier.value =
              _workedToday + DateTime.now().difference(_workStartedAt!);
        });
      }
    });
  }

  void _syncUiPreferencesFromApplicationData(CourierApplicationData? data) {
    if (data == null) return;
    _taskNotificationsEnabled = data.pushNotificationsEnabled;
    _soundAlertsEnabled = data.soundAlertsEnabled;
    _nightModeEnabled = data.nightModeEnabled;
    _faceIdEnabled = data.faceIdEnabled;
  }

  void _applyPricingConfig(IhizPricingConfig config) {
    // Kurye popup kazancı admindeki ana fiyat motoru ile birebir ilerlesin.
    _earningBaseFee = config.baseFee;
    _earningPerKmFee = config.perKmFee;
    _earningPlatformFee = config.platformFee;
    _earningMinutePrice = config.courierMinutePrice;
    _earningNightBonus = config.courierNightBonus;
    _earningRainBonus = config.courierRainBonus;
    _etaPerKmMinute = config.etaPerKmMinute;
    _etaBaseMinute = config.etaBaseMinute;
    _deliveryGeoFenceMeters = config.deliveryGeoFenceMeters;
    _otpRequiredForDelivery = config.otpRequired;
    _rainBonusEnabled = config.courierRainBonus > 0;
  }

  void _emitCourierAlert({
    required String message,
    bool forceSoundAndVibration = false,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    final shouldPlay = forceSoundAndVibration || _soundAlertsEnabled;
    if (!shouldPlay) return;
    SystemSound.play(SystemSoundType.alert);
    if (!kIsWeb) {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;
        final orders = _orders;
        final selectedOrder = orders.isEmpty
            ? null
            : orders[_selectedOrderIndex.clamp(0, orders.length - 1)];
        final isMapTabMobile = isMobile && _selectedTabIndex == 1;

        return Scaffold(
          bottomNavigationBar: isMobile ? _buildBottomBar() : null,
          body: Stack(
            children: [
              isMapTabMobile
                  ? SafeArea(
                      bottom: false,
                      child: _buildMapOnlyScreen(selectedOrder),
                    )
                  : SafeArea(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          isMobile ? 16 : 28,
                          18,
                          isMobile ? 16 : 28,
                          isMobile ? 110 : 28,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isMobile ? 560 : 1280,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ..._buildDashboardContent(
                                  isMobile,
                                  selectedOrder,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
              if (_nightModeEnabled)
                IgnorePointer(
                  child: Container(
                    color: const Color(0xFF020617).withValues(alpha: 0.24),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _subscribeToStores() {
    _fetchStores();
    _fetchCourierPoolOrders();

    final storeStream = Supabase.instance.client
        .from('stores')
        .stream(primaryKey: const ['seller_id'])
        .order('business_name');

    _storesSubscription = storeStream.listen(
      (rows) {
        _applyStoreRows(rows);
      },
      onError: (_) {
        if (!mounted) return;
        _fetchStores();
        _fetchCourierPoolOrders();
      },
    );

    final orderItemsStream = Supabase.instance.client
        .from('order_items')
        .stream(primaryKey: const ['id'])
        .order('created_at');
    _orderItemsSubscription = orderItemsStream.listen(
      (_) {
        _fetchCourierPoolOrders();
      },
      onError: (_) {
        if (!mounted) return;
        _fetchCourierPoolOrders();
      },
    );

    _storesRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _fetchStores();
      _fetchCourierPoolOrders();
    });
  }

  Future<void> _checkLocationPermissionAndStart() async {
    if (_locationTrackingStarted) return;
    _locationTrackingStarted = true;
    var trackingReady = false;

    try {
      if (!kIsWeb) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            setState(() {
              _locationStatus = 'Konum servisi kapalı';
            });
          }
          return;
        }
      }

      if (kIsWeb) {
        try {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.denied) {
            if (mounted) {
              setState(() {
                _locationStatus = 'Tarayici konum izni reddedildi';
              });
            }
            return;
          }
          if (permission == LocationPermission.deniedForever) {
            if (mounted) {
              setState(() {
                _locationStatus = 'Tarayici konum izni kalici kapali';
              });
            }
            return;
          }
        } catch (_) {
          // Bazı tarayıcılarda Permissions API desteklenmez;
          // asıl izin/hata getCurrentPosition çağrısında yakalanır.
        }
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _locationStatus = 'Konum izni reddedildi';
            });
          }
          return;
        }
        if (permission == LocationPermission.deniedForever) {
          if (mounted) {
            setState(() {
              _locationStatus = 'Konum izni kalici kapali';
            });
          }
          return;
        }
      }

      Position? position;
      Object? locationError;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (error) {
        locationError = error;
        try {
          position = await Geolocator.getCurrentPosition();
        } catch (fallbackError) {
          locationError = fallbackError;
          if (!kIsWeb) {
            try {
              position = await Geolocator.getLastKnownPosition();
            } catch (lastKnownError) {
              locationError = lastKnownError;
            }
          }
        }
      }

      if (position == null) {
        if (mounted) {
          setState(() {
            _locationStatus = _locationErrorMessage(locationError);
          });
        }
        return;
      }

      _updateCourierLocation(
        location: LatLng(position.latitude, position.longitude),
        statusMessage: 'Canlı konum izleniyor',
        forceRouteRefresh: true,
      );
      _startLiveLocationUpdates();
      trackingReady = true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _locationStatus = _locationErrorMessage(error);
        });
      }
    } finally {
      if (!trackingReady) {
        _locationTrackingStarted = false;
      }
    }
  }

  String _locationErrorMessage(Object? error) {
    final details = (error ?? '').toString().toLowerCase();
    if (details.contains('secure origin') || details.contains('https')) {
      return 'Konum icin HTTPS veya localhost gerekli';
    }
    if (details.contains('permission api')) {
      return 'Tarayici bu izin API ozelligini desteklemiyor';
    }
    if (details.contains('denied')) {
      return 'Tarayici konum izni reddedildi';
    }
    if (details.contains('timeout')) {
      return 'Konum istegi zaman asimina ugradi';
    }
    if (details.contains('position unavailable') ||
        details.contains('location information is unavailable') ||
        details.contains('not available')) {
      return 'Cihaz konumu su an alinamiyor';
    }
    if (details.contains('unsupported')) {
      return 'Tarayici konum ozelligini desteklemiyor';
    }
    if (details.contains('service')) {
      return 'Konum servisi kapali olabilir';
    }
    return 'Konum alinamadi, tekrar deneyin';
  }

  void _updateCourierLocation({
    required LatLng location,
    required String statusMessage,
    bool forceRouteRefresh = false,
  }) {
    if (!mounted) return;

    final previousLocation = _courierLocation;
    final now = DateTime.now();
    final movedMeters = previousLocation == null
        ? double.infinity
        : Geolocator.distanceBetween(
            previousLocation.latitude,
            previousLocation.longitude,
            location.latitude,
            location.longitude,
          );
    final shouldUpdateUi = previousLocation == null || movedMeters >= 4;
    final shouldRefreshRoute =
        forceRouteRefresh ||
        (_hasActiveDelivery &&
            (previousLocation == null ||
                movedMeters >= 15 ||
                _lastActiveRouteRefreshAt == null ||
                now.difference(_lastActiveRouteRefreshAt!) >=
                    const Duration(seconds: 8)));

    _courierLocation = location;
    if (shouldUpdateUi) {
      setState(() {
        _locationStatus = statusMessage;
      });
    }

    if (!_hasActiveDelivery) return;

    if (shouldRefreshRoute) {
      _lastActiveRouteRefreshAt = now;
      _refreshActiveRoute();
    }
    if (shouldUpdateUi) {
      _focusActiveDeliveryRoute();
    }
  }

  void _startLiveLocationUpdates() {
    if (kIsWeb) {
      _webLocationTimer?.cancel();
      _webLocationTimer = Timer.periodic(const Duration(seconds: 5), (
        timer,
      ) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 4),
            ),
          );

          _updateCourierLocation(
            location: LatLng(position.latitude, position.longitude),
            statusMessage: 'Canlı konum güncellendi',
          );
        } catch (_) {}
      });
      return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionStreamSubscription?.cancel();
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            _updateCourierLocation(
              location: LatLng(position.latitude, position.longitude),
              statusMessage: 'Canlı konum güncellendi',
            );
          },
        );
  }

  double? _courierToStoreDistanceMeters(LatLng storePoint) {
    final courierLocation = _courierLocation;
    if (courierLocation == null) return null;

    return Geolocator.distanceBetween(
      courierLocation.latitude,
      courierLocation.longitude,
      storePoint.latitude,
      storePoint.longitude,
    );
  }

  double _storeToCustomerDistanceMeters(
    LatLng storePoint,
    LatLng customerPoint,
  ) {
    return Geolocator.distanceBetween(
      storePoint.latitude,
      storePoint.longitude,
      customerPoint.latitude,
      customerPoint.longitude,
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  _CourierEarningBreakdown _calculateCourierEarningBreakdown({
    required double distanceKm,
    required DateTime orderCreatedAt,
    required Map<String, dynamic> deliveryAddress,
  }) {
    final safeDistance = distanceKm.isFinite
        ? distanceKm.clamp(0.3, 50.0).toDouble()
        : 2.2;
    final distanceFee = safeDistance * _earningPerKmFee;
    final etaMinutes = ((_etaBaseMinute) + (safeDistance * _etaPerKmMinute))
        .clamp(1.0, 180.0)
        .toDouble();
    final distanceBasedFee = _earningBaseFee + distanceFee;
    final etaBasedFee = etaMinutes * _earningMinutePrice;
    final coreFee = distanceBasedFee >= etaBasedFee
        ? distanceBasedFee
        : etaBasedFee;
    final isNight = orderCreatedAt.hour >= 22 || orderCreatedAt.hour < 6;
    final isRain =
        _rainBonusEnabled &&
        (deliveryAddress['is_raining'] == true ||
            deliveryAddress['weather_rain'] == true);
    final nightBonus = isNight ? _earningNightBonus : 0.0;
    final rainBonus = isRain ? _earningRainBonus : 0.0;
    final total = _roundMoney(coreFee + nightBonus + rainBonus);
    final deliveryTotal = _roundMoney(total + _earningPlatformFee);

    return _CourierEarningBreakdown(
      distanceKm: _roundMoney(safeDistance),
      baseFee: _earningBaseFee,
      perKmFee: _earningPerKmFee,
      distanceFee: _roundMoney(distanceFee),
      distanceBasedFee: _roundMoney(distanceBasedFee),
      etaMinutes: _roundMoney(etaMinutes),
      minutePrice: _earningMinutePrice,
      etaBasedFee: _roundMoney(etaBasedFee),
      nightBonus: nightBonus,
      rainBonus: rainBonus,
      platformFee: _earningPlatformFee,
      deliveryTotal: deliveryTotal,
      total: total,
    );
  }

  String _formatTryCurrency(double amount, {bool withDecimals = false}) {
    final normalized = withDecimals
        ? _roundMoney(amount).toStringAsFixed(2)
        : amount.round().toString();
    final parts = normalized.split('.');
    final integerPart = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    if (withDecimals && parts.length > 1) {
      return '₺$integerPart,${parts[1]}';
    }
    return '₺$integerPart';
  }

  double _roundMoney(double value) => (value * 100).round() / 100;

  Future<void> _refreshActiveRoute() async {
    if (!_hasActiveDelivery) {
      if (mounted && _activeRoutePoints.isNotEmpty) {
        setState(() {
          _activeRoutePoints = const [];
          _lastRouteOrigin = null;
          _lastRouteDestination = null;
          _routeLoading = false;
        });
      }
      return;
    }

    final activeIndex = _activeDeliveryOrderIndex!;
    final activeOrder = _activeDeliveryOrder;
    final isExternalOrder = _isExternalOrder(activeOrder);
    final origin = isExternalOrder
        ? (_courierLocation ?? _fallbackCourierPointForIndex(activeIndex))
        : (_deliveryStage == _DeliveryStage.headingToStore
              ? (_courierLocation ?? _fallbackCourierPointForIndex(activeIndex))
              : _storePointForIndex(activeIndex));
    final destination = isExternalOrder
        ? _storePointForIndex(activeIndex)
        : (_deliveryStage == _DeliveryStage.headingToStore
              ? _storePointForIndex(activeIndex)
              : _customerPointForIndex(activeIndex));

    final shouldSkip =
        _lastRouteOrigin != null &&
        _lastRouteDestination != null &&
        Geolocator.distanceBetween(
              _lastRouteOrigin!.latitude,
              _lastRouteOrigin!.longitude,
              origin.latitude,
              origin.longitude,
            ) <
            35 &&
        Geolocator.distanceBetween(
              _lastRouteDestination!.latitude,
              _lastRouteDestination!.longitude,
              destination.latitude,
              destination.longitude,
            ) <
            10;

    if (shouldSkip || _routeLoading) return;

    setState(() {
      _routeLoading = true;
    });

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return;
      final geometry = routes.first['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List<dynamic>?;
      if (coordinates == null || coordinates.isEmpty) return;

      final points = coordinates
          .whereType<List<dynamic>>()
          .where((pair) => pair.length >= 2)
          .map(
            (pair) => LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            ),
          )
          .toList(growable: false);

      if (!mounted || points.isEmpty) return;

      setState(() {
        _activeRoutePoints = points;
        _lastRouteOrigin = origin;
        _lastRouteDestination = destination;
      });
    } catch (_) {
      // Keep straight-line fallback if the routing service fails.
    } finally {
      if (mounted) {
        setState(() {
          _routeLoading = false;
        });
      }
    }
  }

  Future<List<LatLng>> _fetchRoutePoints(
    LatLng origin,
    LatLng destination,
  ) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};'
      '${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson',
    );

    final response = await http.get(url);
    if (response.statusCode != 200) return const [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return const [];

    final geometry = routes.first['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'] as List<dynamic>?;
    if (coordinates == null || coordinates.isEmpty) return const [];

    return coordinates
        .whereType<List<dynamic>>()
        .where((pair) => pair.length >= 2)
        .map(
          (pair) =>
              LatLng((pair[1] as num).toDouble(), (pair[0] as num).toDouble()),
        )
        .toList(growable: false);
  }

  void _focusPointsOnMap(LatLng first, LatLng second, {double maxZoom = 14.4}) {
    final center = LatLng(
      (first.latitude + second.latitude) / 2,
      (first.longitude + second.longitude) / 2,
    );
    final distanceMeters = Geolocator.distanceBetween(
      first.latitude,
      first.longitude,
      second.latitude,
      second.longitude,
    );
    final zoom = distanceMeters > 24000
        ? 9.8
        : distanceMeters > 12000
        ? 10.8
        : distanceMeters > 6000
        ? 11.6
        : distanceMeters > 3000
        ? 12.3
        : distanceMeters > 1700
        ? 13.0
        : maxZoom;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mobileMapController.move(center, zoom);
    });
  }

  Future<void> _showPreviewRouteFor(int index) async {
    if (index < 0 || index >= _orders.length) return;

    final isExternalOrder = _isExternalOrder(_orders[index]);
    final storePoint = _storePointForIndex(index);
    final customerPoint = _customerPointForIndex(index);
    final routeOrigin = isExternalOrder
        ? (_courierLocation ?? _fallbackCourierPointForIndex(index))
        : storePoint;
    final routeDestination = isExternalOrder ? storePoint : customerPoint;

    setState(() {
      _previewRoutePoints = const [];
    });
    _focusPointsOnMap(routeOrigin, routeDestination);

    try {
      final points = await _fetchRoutePoints(routeOrigin, routeDestination);
      if (!mounted || _mapPopupOrderIndex != index || points.isEmpty) return;

      setState(() {
        _previewRoutePoints = points;
      });
      _focusPointsOnMap(routeOrigin, routeDestination, maxZoom: 13.8);
    } catch (_) {
      // Keep straight-line fallback if preview routing fails.
    }
  }

  _MapNodeLayout _layoutForIndex(int index) {
    return _mapLayouts[index % _mapLayouts.length];
  }

  LatLng _storePointForIndex(int index) {
    return _registeredStores[index].point;
  }

  LatLng _customerPointForIndex(int index) {
    final customerPoint = _registeredStores[index].customerPoint;
    if (customerPoint != null) return customerPoint;
    final layout = _layoutForIndex(index);
    final storePoint = _storePointForIndex(index);
    return LatLng(
      storePoint.latitude +
          (layout.customerPoint.latitude - layout.storePoint.latitude),
      storePoint.longitude +
          (layout.customerPoint.longitude - layout.storePoint.longitude),
    );
  }

  LatLng _fallbackCourierPointForIndex(int index) {
    final layout = _layoutForIndex(index);
    final storePoint = _storePointForIndex(index);
    final latitudeDelta =
        layout.courierPoint.latitude - layout.storePoint.latitude;
    final longitudeDelta =
        layout.courierPoint.longitude - layout.storePoint.longitude;
    return LatLng(
      storePoint.latitude + latitudeDelta,
      storePoint.longitude + longitudeDelta,
    );
  }

  void _centerOnCourierLocation() {
    final courierLocation = _courierLocation;
    if (courierLocation == null) {
      _checkLocationPermissionAndStart();
      return;
    }

    _mobileMapController.move(courierLocation, 15.2);
  }

  void _focusActiveDeliveryRoute() {
    if (!_hasActiveDelivery) return;

    final activeIndex = _activeDeliveryOrderIndex!;
    final activeOrder = _activeDeliveryOrder;
    final isExternalOrder = _isExternalOrder(activeOrder);
    final courierPoint =
        _courierLocation ?? _fallbackCourierPointForIndex(activeIndex);
    final targetPoint = isExternalOrder
        ? _storePointForIndex(activeIndex)
        : (_deliveryStage == _DeliveryStage.headingToStore
              ? _storePointForIndex(activeIndex)
              : _customerPointForIndex(activeIndex));
    final center = LatLng(
      (courierPoint.latitude + targetPoint.latitude) / 2,
      (courierPoint.longitude + targetPoint.longitude) / 2,
    );
    final distanceMeters = Geolocator.distanceBetween(
      courierPoint.latitude,
      courierPoint.longitude,
      targetPoint.latitude,
      targetPoint.longitude,
    );
    final zoom = distanceMeters > 12000
        ? 10.8
        : distanceMeters > 6000
        ? 11.6
        : distanceMeters > 2500
        ? 12.6
        : 13.8;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mobileMapController.move(center, zoom);
    });
  }

  Future<void> _fetchStores() async {
    try {
      final response = await Supabase.instance.client
          .from('stores')
          .select(
            'seller_id, business_name, store_lat, store_lng, is_store_open',
          )
          .not('store_lat', 'is', null)
          .not('store_lng', 'is', null)
          .order('business_name');

      _applyStoreRows(List<Map<String, dynamic>>.from(response));
    } catch (error) {
      debugPrint('IHIZ stores fetch error: $error');
      if (!mounted) return;
      setState(() {
        _storesLoading = false;
      });
    }
  }

  Future<void> _fetchCourierPoolOrders({bool force = false}) async {
    if (_hasActiveDelivery && !force) return;

    try {
      final activeOrderItemId = _activeDeliveryOrderItemId?.trim() ?? '';
      var shouldClearPersistedDeliveryState = false;
      _CourierPoolOrder? retainedActiveOrder;
      if (activeOrderItemId.isNotEmpty) {
        for (final task in _courierPoolOrders) {
          if (task.orderItemId == activeOrderItemId) {
            retainedActiveOrder = task;
            break;
          }
        }
      }

      final client = Supabase.instance.client;
      final itemResponse = await client
          .from('order_items')
          .select(
            'id, order_id, seller_id, status, shipment_step, product_name, product_image_url, store_name, tracking_number, cargo_company, created_at',
          )
          .inFilter('status', const ['ready_to_ship', 'return_approved'])
          .order('created_at', ascending: true);
      final itemRows = List<Map<String, dynamic>>.from(itemResponse as List);

      if (activeOrderItemId.isNotEmpty &&
          itemRows.every(
            (row) => (row['id']?.toString() ?? '') != activeOrderItemId,
          )) {
        try {
          final activeRowRaw = await client
              .from('order_items')
              .select(
                'id, order_id, seller_id, status, shipment_step, product_name, product_image_url, store_name, tracking_number, cargo_company, created_at',
              )
              .eq('id', activeOrderItemId)
              .maybeSingle();
          if (activeRowRaw != null) {
            final activeRow = Map<String, dynamic>.from(activeRowRaw as Map);
            final activeStatus = (activeRow['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();
            if (_isTerminalOrderItemStatus(activeStatus)) {
              shouldClearPersistedDeliveryState = true;
            } else {
              itemRows.insert(0, activeRow);
            }
          } else {
            shouldClearPersistedDeliveryState = true;
          }
        } catch (_) {
          // Active row okunamazsa havuz akışını bozma.
        }
      }

      final dueReturnSignals = await _fetchDueReturnPickupSignals(
        client: client,
      );
      if (dueReturnSignals.isNotEmpty) {
        final returnItemIds = dueReturnSignals.keys
            .where((id) => id.trim().isNotEmpty)
            .toSet()
            .toList(growable: false);
        if (returnItemIds.isNotEmpty) {
          try {
            final returnItemResponse = await client
                .from('order_items')
                .select(
                  'id, order_id, seller_id, status, shipment_step, product_name, product_image_url, store_name, tracking_number, cargo_company, created_at',
                )
                .inFilter('id', returnItemIds);
            final returnRows = List<Map<String, dynamic>>.from(
              returnItemResponse as List,
            );
            final rowIndexById = <String, int>{
              for (var i = 0; i < itemRows.length; i++)
                (itemRows[i]['id']?.toString() ?? ''): i,
            };
            for (final returnRow in returnRows) {
              final itemId = returnRow['id']?.toString() ?? '';
              if (itemId.isEmpty) continue;
              final signal = dueReturnSignals[itemId];
              if (signal == null) continue;
              final enriched = {
                ...returnRow,
                'is_return_pickup': true,
                'return_request_id': signal['return_request_id']?.toString(),
                'buyer_user_id': signal['buyer_user_id']?.toString(),
                'pickup_window_start': signal['pickup_window_start']
                    ?.toString(),
                'pickup_window_end': signal['pickup_window_end']?.toString(),
                'buyer_pickup_note': signal['buyer_pickup_note']?.toString(),
                'pickup_address': signal['pickup_address'],
                'return_signal_created_at': signal['created_at']?.toString(),
              };
              final existingIndex = rowIndexById[itemId];
              if (existingIndex != null) {
                itemRows[existingIndex] = {
                  ...itemRows[existingIndex],
                  ...enriched,
                };
                continue;
              }
              rowIndexById[itemId] = itemRows.length;
              itemRows.add(enriched);
            }
          } catch (e) {
            debugPrint('IHIZ due return pickup order_items fetch warn: $e');
          }
        }
      }

      if (itemRows.isEmpty) {
        if (!mounted) return;
        setState(() {
          if (shouldClearPersistedDeliveryState) {
            _deliveryStage = _DeliveryStage.idle;
            _activeDeliveryOrderIndex = null;
            _activeDeliveryOrderItemId = null;
            _selectedTabIndex = 0;
            _mapDeliveryPanelExpanded = true;
          }
          if (retainedActiveOrder == null) {
            _courierPoolOrders = const [];
          } else {
            _courierPoolOrders = [retainedActiveOrder];
          }
          _knownPoolOrderIds = <String>{};
          _storesLoading = false;
          if (_courierPoolOrders.isNotEmpty) {
            _activeDeliveryOrderIndex = 0;
            _selectedOrderIndex = 0;
          }
        });
        if (shouldClearPersistedDeliveryState) {
          unawaited(_clearPersistedActiveDeliveryState());
        }
        return;
      }

      final orderIds = itemRows
          .map((row) => row['order_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final sellerIds = itemRows
          .map((row) => row['seller_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final Map<String, Map<String, dynamic>> orderById = {};
      if (orderIds.isNotEmpty) {
        final orderResponse = await client
            .from('orders')
            .select('id, order_number, user_id, delivery_address, created_at')
            .inFilter('id', orderIds);
        for (final raw in (orderResponse as List<dynamic>)) {
          final map = Map<String, dynamic>.from(raw as Map);
          orderById[map['id']?.toString() ?? ''] = map;
        }
      }

      final Map<String, Map<String, dynamic>> storeBySellerId = {};
      if (sellerIds.isNotEmpty) {
        final storeResponse = await client
            .from('stores')
            .select(
              'seller_id, business_name, address, phone, support_phone, store_lat, store_lng',
            )
            .inFilter('seller_id', sellerIds);
        for (final raw in (storeResponse as List<dynamic>)) {
          final map = Map<String, dynamic>.from(raw as Map);
          final sellerId = map['seller_id']?.toString();
          if (sellerId == null || sellerId.isEmpty) continue;
          storeBySellerId[sellerId] = map;
        }
      }

      final customerIds = orderById.values
          .map((row) => row['user_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);
      final Map<String, Map<String, dynamic>> userById = {};
      if (customerIds.isNotEmpty) {
        try {
          final userResponse = await client
              .from('users')
              .select('id, display_name, phone')
              .inFilter('id', customerIds);
          for (final raw in (userResponse as List<dynamic>)) {
            final map = Map<String, dynamic>.from(raw as Map);
            userById[map['id']?.toString() ?? ''] = map;
          }
        } catch (_) {
          // Kullanıcı lookup izni olmayabilir; adres telefonu fallback kullanılır.
        }
      }

      final List<_CourierPoolOrder> mapped = [];
      for (var index = 0; index < itemRows.length; index++) {
        final item = itemRows[index];
        final itemId = item['id']?.toString() ?? '';
        if (itemId.isEmpty) continue;

        final orderId = item['order_id']?.toString() ?? '';
        final sellerId = item['seller_id']?.toString() ?? '';
        final order = orderById[orderId];
        final store = storeBySellerId[sellerId];
        final itemStatus = (item['status']?.toString() ?? '')
            .trim()
            .toLowerCase();
        final itemShipmentStep = (item['shipment_step']?.toString() ?? '')
            .trim()
            .toLowerCase();
        final isReturnPickup =
            item['is_return_pickup'] == true ||
            itemShipmentStep == 'return_pickup_scheduled' ||
            itemStatus == 'return_shipped_back' ||
            itemStatus == 'return_received';
        if (itemStatus == 'return_approved' && !isReturnPickup) {
          continue;
        }
        final deliveryAddress = _jsonMap(
          isReturnPickup ? item['pickup_address'] : order?['delivery_address'],
        );
        final userId =
            item['buyer_user_id']?.toString().trim().isNotEmpty == true
            ? item['buyer_user_id'].toString().trim()
            : order?['user_id']?.toString() ?? '';
        final user = userById[userId];

        final storeName = _firstFilled(
          isReturnPickup
              ? [
                  _joinText([
                    deliveryAddress['name']?.toString(),
                    deliveryAddress['surname']?.toString(),
                  ]),
                  deliveryAddress['fullName']?.toString(),
                  user?['display_name']?.toString(),
                  'İade Alım Noktası',
                ]
              : [
                  item['store_name']?.toString(),
                  store?['business_name']?.toString(),
                  'Mağaza',
                ],
        );
        final productName = _firstFilled([
          item['product_name']?.toString(),
          'Ürün',
        ]);
        final storeAddress = _firstFilled(
          isReturnPickup
              ? [
                  _joinText([
                    deliveryAddress['address']?.toString(),
                    deliveryAddress['detail']?.toString(),
                    deliveryAddress['district']?.toString(),
                    deliveryAddress['city']?.toString(),
                  ]),
                  'Adres bilgisi yok',
                ]
              : [store?['address']?.toString(), 'Adres bilgisi yok'],
        );
        final customerName = _firstFilled(
          isReturnPickup
              ? [
                  item['store_name']?.toString(),
                  store?['business_name']?.toString(),
                  'Satıcı',
                ]
              : [
                  deliveryAddress['fullName']?.toString(),
                  _joinText([
                    deliveryAddress['name']?.toString(),
                    deliveryAddress['surname']?.toString(),
                  ]),
                  user?['display_name']?.toString(),
                  'Müşteri',
                ],
        );
        final customerAddress = _firstFilled(
          isReturnPickup
              ? [store?['address']?.toString(), 'Adres bilgisi yok']
              : [
                  _joinText([
                    deliveryAddress['address']?.toString(),
                    deliveryAddress['detail']?.toString(),
                    deliveryAddress['district']?.toString(),
                    deliveryAddress['city']?.toString(),
                  ]),
                  'Adres bilgisi yok',
                ],
        );
        final regionLabel = _normalizeRegionLabel(
          _firstFilled([
            deliveryAddress['district']?.toString(),
            deliveryAddress['neighborhood']?.toString(),
            deliveryAddress['town']?.toString(),
            deliveryAddress['city']?.toString(),
            'Genel',
          ]),
        );
        final regionCity = _normalizeRegionLabel(
          _firstFilled([
            deliveryAddress['city']?.toString(),
            deliveryAddress['province']?.toString(),
            deliveryAddress['state']?.toString(),
            _applicationData?.city,
            'Türkiye',
          ]),
        );
        final regionKey = _regionKeyFor(regionLabel);
        final storePhone = _firstFilled(
          isReturnPickup
              ? [
                  deliveryAddress['phone']?.toString(),
                  deliveryAddress['phoneNumber']?.toString(),
                  deliveryAddress['gsm']?.toString(),
                  user?['phone']?.toString(),
                  '-',
                ]
              : [
                  store?['phone']?.toString(),
                  store?['support_phone']?.toString(),
                  '-',
                ],
        );
        final customerPhone = _firstFilled(
          isReturnPickup
              ? [
                  store?['phone']?.toString(),
                  store?['support_phone']?.toString(),
                  '-',
                ]
              : [
                  deliveryAddress['phone']?.toString(),
                  deliveryAddress['phoneNumber']?.toString(),
                  deliveryAddress['gsm']?.toString(),
                  user?['phone']?.toString(),
                  '-',
                ],
        );

        final layout = _mapLayouts[index % _mapLayouts.length];
        final storeLat = _asDouble(store?['store_lat'] ?? store?['latitude']);
        final storeLng = _asDouble(store?['store_lng'] ?? store?['longitude']);
        final pickupLat = _asDouble(
          deliveryAddress['lat'] ?? deliveryAddress['latitude'],
        );
        final pickupLng = _asDouble(
          deliveryAddress['lng'] ?? deliveryAddress['longitude'],
        );
        final storePoint =
            isReturnPickup && pickupLat != null && pickupLng != null
            ? LatLng(pickupLat, pickupLng)
            : (storeLat != null && storeLng != null)
            ? LatLng(storeLat, storeLng)
            : layout.storePoint;
        final customerPoint =
            isReturnPickup && storeLat != null && storeLng != null
            ? LatLng(storeLat, storeLng)
            : (pickupLat != null && pickupLng != null)
            ? LatLng(pickupLat, pickupLng)
            : LatLng(
                storePoint.latitude +
                    (layout.customerPoint.latitude -
                        layout.storePoint.latitude),
                storePoint.longitude +
                    (layout.customerPoint.longitude -
                        layout.storePoint.longitude),
              );
        final distanceKm =
            Geolocator.distanceBetween(
              storePoint.latitude,
              storePoint.longitude,
              customerPoint.latitude,
              customerPoint.longitude,
            ) /
            1000;
        final orderCreatedAt =
            DateTime.tryParse(order?['created_at']?.toString() ?? '') ??
            DateTime.now();
        final earningBreakdown = _calculateCourierEarningBreakdown(
          distanceKm: distanceKm,
          orderCreatedAt: orderCreatedAt,
          deliveryAddress: deliveryAddress,
        );
        final etaRaw = (distanceKm * _etaPerKmMinute) + _etaBaseMinute;
        final etaMin = etaRaw.round().clamp(8, 180);
        final trackingCode = _resolveTrackingCode(
          existing: item['tracking_number']?.toString(),
          orderNumber: order?['order_number']?.toString() ?? '',
          orderItemId: itemId,
        );
        final deliveryCode = _buildDeliveryCode(itemId);
        mapped.add(
          _CourierPoolOrder(
            orderItemId: itemId,
            orderId: orderId,
            sellerId: sellerId,
            customerId: userId,
            orderNumber: order?['order_number']?.toString() ?? '-',
            productName: productName,
            productImageUrl: item['product_image_url']?.toString() ?? '',
            storeName: storeName,
            storeAddress: storeAddress,
            storePhone: storePhone,
            storePoint: storePoint,
            customerName: customerName,
            customerAddress: customerAddress,
            customerPhone: customerPhone,
            customerPoint: customerPoint,
            regionLabel: regionLabel,
            regionCity: regionCity,
            regionKey: regionKey,
            trackingCode: trackingCode,
            deliveryCode: deliveryCode,
            earning: _formatTryCurrency(earningBreakdown.total),
            earningBreakdown: earningBreakdown,
            eta: '$etaMin dk',
            route: '${distanceKm.toStringAsFixed(1)} km',
            createdAt:
                DateTime.tryParse(item['created_at']?.toString() ?? '') ??
                DateTime.now(),
            returnRequestId: item['return_request_id']?.toString(),
            buyerPickupNote: item['buyer_pickup_note']?.toString(),
            pickupWindowStart: DateTime.tryParse(
              item['pickup_window_start']?.toString() ?? '',
            ),
            pickupWindowEnd: DateTime.tryParse(
              item['pickup_window_end']?.toString() ?? '',
            ),
            isReturnPickup: isReturnPickup,
          ),
        );
      }

      if (_deliveryStage != _DeliveryStage.idle &&
          activeOrderItemId.isNotEmpty &&
          retainedActiveOrder != null &&
          mapped.every((item) => item.orderItemId != activeOrderItemId)) {
        mapped.insert(0, retainedActiveOrder);
      }

      final visibleMapped = _activeRegionKeys.isEmpty
          ? mapped
          : mapped
                .where((item) => _activeRegionKeys.contains(item.regionKey))
                .toList(growable: false);
      final incomingOrderIds = visibleMapped
          .map((item) => item.orderItemId)
          .where((id) => id.isNotEmpty)
          .toSet();
      final hasInitializedBefore = _knownPoolOrderIds.isNotEmpty;
      final newOrderCount = hasInitializedBefore
          ? incomingOrderIds.difference(_knownPoolOrderIds).length
          : 0;

      if (!mounted) return;
      setState(() {
        _courierPoolOrders = mapped;
        _knownPoolOrderIds = incomingOrderIds;
        _storesLoading = false;
        if (activeOrderItemId.isNotEmpty) {
          final activeIndex = _registeredStores.indexWhere(
            (store) => (store.orderItemId ?? '').trim() == activeOrderItemId,
          );
          if (activeIndex >= 0) {
            _activeDeliveryOrderIndex = activeIndex;
            _selectedOrderIndex = activeIndex;
          } else if (_deliveryStage != _DeliveryStage.idle) {
            shouldClearPersistedDeliveryState = true;
            _deliveryStage = _DeliveryStage.idle;
            _activeDeliveryOrderIndex = null;
            _activeDeliveryOrderItemId = null;
            _selectedTabIndex = 0;
            _mapDeliveryPanelExpanded = true;
          }
        }
        if (_registeredStores.isEmpty) {
          _selectedOrderIndex = 0;
          _mapPopupOrderIndex = null;
        } else if (_selectedOrderIndex >= _registeredStores.length) {
          _selectedOrderIndex = 0;
        }
      });
      if (shouldClearPersistedDeliveryState) {
        unawaited(_clearPersistedActiveDeliveryState());
      }
      if (_taskNotificationsEnabled && newOrderCount > 0) {
        _emitCourierAlert(message: '$newOrderCount yeni sipariş havuza düştü.');
      }
    } catch (error) {
      debugPrint('IHIZ courier pool fetch error: $error');
      if (!mounted) return;
      setState(() {
        _storesLoading = false;
      });
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchDueReturnPickupSignals({
    required SupabaseClient client,
  }) async {
    final signals = <String, Map<String, dynamic>>{};
    final nowUtc = DateTime.now().toUtc();
    final nowIso = nowUtc.toIso8601String();

    try {
      final taskRows = await client
          .from('ihiz_return_pickup_tasks')
          .select(
            'id, return_request_id, order_id, order_item_id, buyer_user_id, seller_id, pickup_window_start, pickup_window_end, pickup_address, note, status, created_at',
          )
          .inFilter('status', const ['queued', 'assigned'])
          .order('pickup_window_start', ascending: true);
      for (final raw in (taskRows as List<dynamic>)) {
        final row = Map<String, dynamic>.from(raw as Map);
        final orderItemId = row['order_item_id']?.toString().trim() ?? '';
        if (orderItemId.isEmpty) continue;
        signals[orderItemId] = {
          'source': 'task',
          'return_request_id': row['return_request_id']?.toString(),
          'order_id': row['order_id']?.toString(),
          'order_item_id': orderItemId,
          'buyer_user_id': row['buyer_user_id']?.toString(),
          'seller_id': row['seller_id']?.toString(),
          'pickup_window_start': row['pickup_window_start']?.toString(),
          'pickup_window_end': row['pickup_window_end']?.toString(),
          'pickup_address': row['pickup_address'],
          'buyer_pickup_note': row['note']?.toString(),
          'created_at': row['created_at']?.toString(),
        };
      }
    } catch (e) {
      debugPrint('IHIZ return pickup tasks query warn: $e');
    }

    final currentUserId = client.auth.currentUser?.id.trim() ?? '';
    if (currentUserId.isEmpty) return signals;

    try {
      final notificationRows = await client
          .from('user_notifications')
          .select('id, created_at, data')
          .eq('user_id', currentUserId)
          .lte('created_at', nowIso)
          .order('created_at', ascending: false)
          .limit(300);
      for (final raw in (notificationRows as List<dynamic>)) {
        final row = Map<String, dynamic>.from(raw as Map);
        final data = _jsonMap(row['data']);
        final type = data['type']?.toString().trim().toLowerCase() ?? '';
        if (type != 'ihiz_return_pickup_due') continue;
        final orderItemId = data['order_item_id']?.toString().trim() ?? '';
        if (orderItemId.isEmpty) continue;
        final existing = signals[orderItemId];
        if (existing != null && existing['source']?.toString() == 'task') {
          continue;
        }
        signals[orderItemId] = {
          'source': 'notification',
          'return_request_id': data['return_request_id']?.toString(),
          'order_id': data['order_id']?.toString(),
          'order_item_id': orderItemId,
          'buyer_user_id': data['buyer_user_id']?.toString(),
          'seller_id': data['seller_id']?.toString(),
          'pickup_window_start': data['pickup_window_start']?.toString(),
          'pickup_window_end': data['pickup_window_end']?.toString(),
          'pickup_address': data['pickup_address'],
          'buyer_pickup_note': data['buyer_pickup_note']?.toString(),
          'created_at': row['created_at']?.toString(),
        };
      }
    } catch (e) {
      debugPrint('IHIZ return pickup notifications query warn: $e');
    }

    return signals;
  }

  Map<String, dynamic> _jsonMap(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map((key, val) => MapEntry(key.toString(), val));
        }
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  String _joinText(List<String?> parts) {
    return parts
        .map((part) => part?.trim() ?? '')
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim();
  }

  String _firstFilled(List<String?> values) {
    for (final value in values) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _resolveTrackingCode({
    required String? existing,
    required String orderNumber,
    required String orderItemId,
  }) {
    final trimmedExisting = existing?.trim() ?? '';
    if (trimmedExisting.isNotEmpty) return trimmedExisting;
    final orderDigits = orderNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final itemDigits = orderItemId.replaceAll(RegExp(r'[^0-9]'), '');
    final merged = (orderDigits + itemDigits).padRight(12, '4');
    return '7330${merged.substring(0, 12)}';
  }

  String _buildDeliveryCode(String orderItemId) {
    final digits = orderItemId.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 4) {
      return digits.substring(digits.length - 4);
    }
    final seed = orderItemId.codeUnits.fold<int>(
      0,
      (acc, code) => (acc + code) % 9000,
    );
    return (1000 + seed).toString().padLeft(4, '0');
  }

  bool _isExternalOrderNumber(String? orderNumber) {
    final normalized = (orderNumber ?? '').trim().toUpperCase();
    return normalized.startsWith('IBUL-EXT-');
  }

  bool _isExternalOrder(_OrderCardData? order) {
    return _isExternalOrderNumber(order?.orderNumber);
  }

  void _applyStoreRows(List<Map<String, dynamic>> rows) {
    if (!mounted) return;

    final stores = rows
        .map(_storeFromRow)
        .whereType<_LiveStoreMarker>()
        .toList(growable: false);

    setState(() {
      _liveStores = stores;
      _storesLoading = false;
      if (_highlightedStoreId != null &&
          stores.every((store) => store.id != _highlightedStoreId)) {
        _highlightedStoreId = null;
      }
    });

    if (stores.isNotEmpty &&
        _mapSearchController.text.trim().isEmpty &&
        _highlightedStoreId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || stores.isEmpty) return;
        _mobileMapController.move(stores.first.point, 11.8);
      });
    }
  }

  _LiveStoreMarker? _storeFromRow(Map<String, dynamic> row) {
    final lat = row['latitude'] ?? row['store_lat'];
    final lng = row['longitude'] ?? row['store_lng'];

    if (lat == null || lng == null) return null;

    return _LiveStoreMarker(
      id: (row['seller_id'] ?? row['id'] ?? '').toString(),
      name: (row['business_name'] ?? 'Mağaza').toString(),
      point: LatLng(double.parse(lat.toString()), double.parse(lng.toString())),
      isOpen: row['is_store_open'] == true,
    );
  }

  void _handleMapSearchChanged(String value) {
    setState(() {
      _storeSearchQuery = value;
      if (value.trim().isEmpty) {
        _highlightedStoreId = null;
        _mapPopupOrderIndex = null;
        _previewRoutePoints = const [];
      }
    });

    final trimmed = value.trim().toLowerCase();
    if (trimmed.isEmpty) {
      _mobileMapController.move(_turkiyeCenter, 6.2);
      return;
    }

    if (_orders.isEmpty) {
      final matches = _searchableLiveStores;
      if (matches.isEmpty) return;
      final firstMatch = matches.first;
      setState(() {
        _highlightedStoreId = firstMatch.id;
      });
      _mobileMapController.move(firstMatch.point, 13.8);
      return;
    }

    final matches = _searchableStores;
    if (matches.isEmpty) return;

    final firstMatch = matches.first;
    final selectedIndex = _registeredStores.indexWhere(
      (store) => store.id == firstMatch.id,
    );
    setState(() {
      _highlightedStoreId = firstMatch.id;
      if (selectedIndex >= 0) {
        _selectedOrderIndex = selectedIndex;
      }
    });
    _mobileMapController.move(firstMatch.point, 13.8);
  }

  List<_LiveStoreMarker> get _searchableLiveStores {
    final regionFilteredStores = _activeRegionKeys.isEmpty
        ? _liveStores
        : _liveStores
              .where((store) => _isStoreInActiveRegions(store))
              .toList(growable: false);
    final query = _storeSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return regionFilteredStores;
    return regionFilteredStores
        .where((store) => store.name.toLowerCase().contains(query))
        .toList(growable: false);
  }

  List<_ActiveRegionOption> _selectedActiveRegionsForFilter() {
    if (_activeRegionKeys.isEmpty) return const <_ActiveRegionOption>[];
    return _availableActiveRegionOptions()
        .where((option) => _activeRegionKeys.contains(option.key))
        .toList(growable: false);
  }

  bool _isStoreInActiveRegions(_LiveStoreMarker store) {
    final selectedRegions = _selectedActiveRegionsForFilter();
    if (selectedRegions.isEmpty) return true;

    for (final region in selectedRegions) {
      if (_pointInsideRegion(store.point, region)) {
        return true;
      }
    }
    return false;
  }

  bool _pointInsideRegion(LatLng point, _ActiveRegionOption region) {
    for (final ring in region.boundaryRings) {
      if (_isPointInPolygon(point, ring)) {
        return true;
      }
    }
    final distanceMeters = Geolocator.distanceBetween(
      point.latitude,
      point.longitude,
      region.point.latitude,
      region.point.longitude,
    );
    return distanceMeters <= 22000;
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;
    final testX = point.longitude;
    final testY = point.latitude;
    var inside = false;
    var j = polygon.length - 1;
    for (var i = 0; i < polygon.length; i++) {
      final xi = polygon[i].longitude;
      final yi = polygon[i].latitude;
      final xj = polygon[j].longitude;
      final yj = polygon[j].latitude;
      final intersects =
          ((yi > testY) != (yj > testY)) &&
          (testX < ((xj - xi) * (testY - yi)) / ((yj - yi) + 1e-12) + xi);
      if (intersects) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  List<_RegisteredStoreData> get _registeredStores {
    if (_courierPoolOrders.isNotEmpty) {
      final visiblePoolOrders = _activeRegionKeys.isEmpty
          ? _courierPoolOrders
          : _courierPoolOrders
                .where((task) => _activeRegionKeys.contains(task.regionKey))
                .toList(growable: false);
      return List.generate(visiblePoolOrders.length, (index) {
        final task = visiblePoolOrders[index];
        final seed = _demoStores[index % _demoStores.length];
        final isExternalOrder = task.orderNumber.toUpperCase().startsWith(
          'IBUL-EXT-',
        );
        final isReturnPickup = task.isReturnPickup;
        final normalizedProductName = task.productName.trim();
        final baseTaskTitle = normalizedProductName.isNotEmpty
            ? normalizedProductName
            : 'Ürün';
        final taskTitle = isReturnPickup
            ? '$baseTaskTitle (İade alımı)'
            : baseTaskTitle;
        final taskTags = <String>[
          isReturnPickup ? 'İade alımı' : 'Canlı sipariş',
          task.regionLabel,
          if (isReturnPickup)
            'Müşteriden satıcıya'
          else if (isExternalOrder)
            'Ayrı Sipariş'
          else
            'Hızlı teslim',
        ];
        return _RegisteredStoreData(
          id: task.orderItemId,
          orderItemId: task.orderItemId,
          orderId: task.orderId,
          sellerId: task.sellerId,
          customerId: task.customerId,
          trackingCode: task.trackingCode,
          productName: task.productName,
          orderNumber: task.orderNumber,
          returnRequestId: task.returnRequestId,
          buyerPickupNote: task.buyerPickupNote,
          pickupWindowStart: task.pickupWindowStart,
          pickupWindowEnd: task.pickupWindowEnd,
          isReturnPickup: isReturnPickup,
          name: task.storeName,
          address: task.storeAddress,
          cityLabel: isReturnPickup ? 'İade görevi' : 'Canlı sipariş',
          point: task.storePoint,
          customerPoint: task.customerPoint,
          accent: seed.accent,
          taskTitle: taskTitle,
          customerName: task.customerName,
          customerAddress: task.customerAddress,
          regionLabel: task.regionLabel,
          regionKey: task.regionKey,
          storePhone: task.storePhone,
          customerPhone: task.customerPhone,
          deliveryCode: task.deliveryCode,
          earning: task.earning,
          earningBreakdown: task.earningBreakdown,
          eta: task.eta,
          route: task.route,
          label: isReturnPickup ? 'İade havuzu' : 'İHız havuzu',
          tags: taskTags,
          isRequestingCourier: true,
        );
      });
    }
    return const [];
  }

  List<_OrderCardData> get _orders => _registeredStores
      .map(
        (store) => _OrderCardData(
          title: store.taskTitle,
          storeName: store.name,
          storeAddress: store.address,
          storePhone: store.storePhone,
          customerName: store.customerName,
          customerAddress: store.customerAddress,
          regionLabel: store.regionLabel,
          regionKey: store.regionKey,
          customerPhone: store.customerPhone,
          deliveryCode: store.deliveryCode,
          orderItemId: store.orderItemId,
          orderId: store.orderId,
          sellerId: store.sellerId,
          customerId: store.customerId,
          trackingCode: store.trackingCode,
          productName: store.productName,
          orderNumber: store.orderNumber,
          returnRequestId: store.returnRequestId,
          buyerPickupNote: store.buyerPickupNote,
          pickupWindowStart: store.pickupWindowStart,
          pickupWindowEnd: store.pickupWindowEnd,
          isReturnPickup: store.isReturnPickup,
          earning: store.earning,
          earningBreakdown: store.earningBreakdown,
          eta: store.eta,
          route: store.route,
          label: store.label,
          accent: store.accent,
          tags: store.tags,
        ),
      )
      .toList(growable: false);

  bool get _hasActiveDelivery =>
      _deliveryStage != _DeliveryStage.idle && _activeDeliveryOrder != null;

  _OrderCardData? get _activeDeliveryOrder {
    final activeOrderItemId = _activeDeliveryOrderItemId?.trim() ?? '';
    if (activeOrderItemId.isNotEmpty) {
      for (final order in _orders) {
        if ((order.orderItemId?.trim() ?? '') == activeOrderItemId) {
          return order;
        }
      }
    }
    final activeIndex = _activeDeliveryOrderIndex;
    if (activeIndex == null ||
        activeIndex < 0 ||
        activeIndex >= _orders.length) {
      return null;
    }
    return _orders[activeIndex];
  }

  bool _isCurrentActiveOrder(int index) {
    if (index < 0 || index >= _orders.length) return false;
    final activeOrderItemId = _activeDeliveryOrderItemId?.trim() ?? '';
    if (activeOrderItemId.isNotEmpty) {
      return (_orders[index].orderItemId?.trim() ?? '') == activeOrderItemId;
    }
    return _activeDeliveryOrderIndex == index;
  }

  Map<String, dynamic> _courierNotificationData() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final courierUserId = currentUser?.id.toString().trim() ?? '';
    final courierName = _firstFilled([
      _applicationData?.fullName,
      currentUser?.userMetadata?['display_name']?.toString(),
    ]);
    final courierPhone = _firstFilled([
      _applicationData?.phone,
      currentUser?.phone?.toString(),
    ]);
    final courierVehicle = _firstFilled([_applicationData?.motorType]);

    return {
      if (courierUserId.isNotEmpty) 'courier_user_id': courierUserId,
      if (courierName.isNotEmpty) 'courier_name': courierName,
      if (courierPhone.isNotEmpty) 'courier_phone': courierPhone,
      if (courierVehicle.isNotEmpty) 'courier_vehicle': courierVehicle,
    };
  }

  Future<String> _findUserIdByPhone(String phone) async {
    final raw = phone.trim();
    if (raw.isEmpty || raw == '-') return '';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    final candidates = <String>{raw};
    if (digits.length == 10) {
      candidates.add('0$digits');
      candidates.add('90$digits');
      candidates.add('+90$digits');
    } else if (digits.length == 11 && digits.startsWith('0')) {
      final rest = digits.substring(1);
      candidates.add('90$rest');
      candidates.add('+90$rest');
      candidates.add(digits);
    } else if (digits.length == 12 && digits.startsWith('90')) {
      final rest = digits.substring(2);
      candidates.add('0$rest');
      candidates.add('+$digits');
      candidates.add(digits);
    } else {
      candidates.add(digits);
      candidates.add('+$digits');
    }

    try {
      final rows = await Supabase.instance.client
          .from('users')
          .select('id, phone')
          .inFilter('phone', candidates.toList())
          .limit(1);
      for (final rawRow in (rows as List<dynamic>)) {
        final row = Map<String, dynamic>.from(rawRow as Map);
        final userId = row['id']?.toString().trim() ?? '';
        if (userId.isNotEmpty) return userId;
      }
    } catch (e) {
      debugPrint('IHIZ resolve user by phone warn: $e');
    }
    return '';
  }

  Future<String> _resolveCustomerNotificationUserId(
    _OrderCardData order,
  ) async {
    final direct = order.customerId?.trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final orderId = order.orderId?.trim() ?? '';
    if (orderId.isNotEmpty) {
      try {
        final rowRaw = await Supabase.instance.client
            .from('orders')
            .select('user_id, delivery_address')
            .eq('id', orderId)
            .maybeSingle();
        if (rowRaw != null) {
          final row = Map<String, dynamic>.from(rowRaw as Map);
          final userId = row['user_id']?.toString().trim() ?? '';
          if (userId.isNotEmpty) return userId;
          final address = _jsonMap(row['delivery_address']);
          final addressPhone = _firstFilled([
            address['phone']?.toString(),
            address['phoneNumber']?.toString(),
            address['gsm']?.toString(),
          ]);
          final fromAddress = await _findUserIdByPhone(addressPhone);
          if (fromAddress.isNotEmpty) return fromAddress;
        }
      } catch (e) {
        debugPrint('IHIZ resolve customer from order warn: $e');
      }
    }

    return _findUserIdByPhone(order.customerPhone);
  }

  Future<void> _pickupPackage(int index) async {
    if (index < 0 || index >= _orders.length) return;
    final selectedOrder = _orders[index];
    final selectedOrderItemId = selectedOrder.orderItemId?.trim() ?? '';
    final isExternalOrder = _isExternalOrder(selectedOrder);
    final displayName = _mapDisplayNameForStore(_registeredStores[index]);
    setState(() {
      _selectedOrderIndex = index;
      _activeDeliveryOrderIndex = index;
      _activeDeliveryOrderItemId = selectedOrderItemId.isEmpty
          ? null
          : selectedOrderItemId;
      _mapPopupOrderIndex = null;
      _deliveryStage = _DeliveryStage.headingToStore;
      _mapDeliveryPanelExpanded = false;
      _highlightedStoreId = _registeredStores[index].id;
      _mapSearchController.text = displayName;
      _storeSearchQuery = displayName;
      _selectedTabIndex = 1;
      _previewRoutePoints = const [];
    });
    _checkLocationPermissionAndStart();
    _focusActiveDeliveryRoute();
    _refreshActiveRoute();
    if (isExternalOrder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mobileMapController.move(_storePointForIndex(index), 15.4);
      });
    }
    await _markOrderAsPickedUp(selectedOrder);
  }

  Future<void> _markOrderAsPickedUp(_OrderCardData order) async {
    final orderItemId = order.orderItemId?.trim() ?? '';
    final orderId = order.orderId?.trim() ?? '';
    if (orderItemId.isEmpty || orderId.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final trackingCode = _resolveTrackingCode(
      existing: order.trackingCode,
      orderNumber: order.orderNumber ?? '',
      orderItemId: orderItemId,
    );
    final deliveryCode = order.deliveryCode;
    final courierData = _courierNotificationData();
    final courierName = courierData['courier_name']?.toString().trim() ?? '';
    final returnRequestId = order.returnRequestId?.trim() ?? '';
    final isReturnPickup = order.isReturnPickup;
    try {
      if (isReturnPickup) {
        final updatedOrderItem = await Supabase.instance.client
            .from('order_items')
            .update({
              'status': 'return_shipped_back',
              'shipment_step': 'return_shipped_back',
              'cargo_company': 'İHız',
              'tracking_number': trackingCode,
              'updated_at': now,
            })
            .eq('id', orderItemId)
            .select('id')
            .maybeSingle();
        if (updatedOrderItem == null) {
          throw Exception(
            'İade alımı için order_items güncellenemedi. Kurye RLS yetkisi kontrol edilmeli.',
          );
        }
        unawaited(_persistActiveDeliveryState());

        try {
          await Supabase.instance.client.from('order_item_status_history').insert({
            'order_item_id': orderItemId,
            'status': 'return_shipped_back',
            'title': 'İHız iade kuryesi ürünü teslim aldı',
            'description': courierName.isEmpty
                ? 'İade ürünü müşteriden teslim alındı ve satıcıya götürülüyor.'
                : '$courierName iade ürününü müşteriden teslim aldı ve satıcıya götürüyor.',
            'tracking_number': trackingCode,
            'cargo_company': 'İHız',
            'created_at': now,
            'extra_data': {
              if (returnRequestId.isNotEmpty)
                'return_request_id': returnRequestId,
              if ((order.buyerPickupNote ?? '').trim().isNotEmpty)
                'buyer_pickup_note': order.buyerPickupNote!.trim(),
            },
          });
        } catch (historyError) {
          debugPrint('IHIZ return pickup history insert warn: $historyError');
        }

        try {
          await Supabase.instance.client
              .from('ihiz_return_pickup_tasks')
              .update({
                'status': 'picked_up',
                'picked_up_at': now,
                'assigned_courier_id':
                    Supabase.instance.client.auth.currentUser?.id,
                'updated_at': now,
              })
              .eq('order_item_id', orderItemId)
              .inFilter('status', const ['queued', 'assigned']);
        } catch (taskError) {
          debugPrint('IHIZ return pickup task update warn: $taskError');
        }

        final customerId = await _resolveCustomerNotificationUserId(order);
        if (customerId.isNotEmpty) {
          final body =
              "İade talebiniz için İHız kuryesi ürünü teslim aldı. ${order.productName ?? 'Ürün'} satıcıya götürülüyor.";
          await Supabase.instance.client.from('user_notifications').insert({
            'user_id': customerId,
            'title': order.storeName,
            'body': body,
            'data': {
              'type': 'order_tracking',
              'order_id': orderId,
              'order_item_id': orderItemId,
              'return_request_id': returnRequestId,
              'status': 'return_shipped_back',
              'store_name': order.storeName,
              'product_name': order.productName,
              'tracking_number': trackingCode,
              'delivery_code': deliveryCode,
              'cargo_company': 'İHız',
              'delivery_mode': 'courier',
              'open_tab': 'tracking',
              ...courierData,
            },
            'created_at': now,
          });
        }

        try {
          await _syncParentOrderStatusFromItems(orderId, now: now);
        } catch (syncError) {
          debugPrint('IHIZ return pickup parent status sync warn: $syncError');
        }
        return;
      }

      final updatedOrderItem = await Supabase.instance.client
          .from('order_items')
          .update({
            'status': 'out_for_delivery',
            'shipment_step': 'out_for_delivery',
            'cargo_company': 'İHız',
            'tracking_number': trackingCode,
            'updated_at': now,
          })
          .eq('id', orderItemId)
          .select('id')
          .maybeSingle();
      if (updatedOrderItem == null) {
        throw Exception(
          'order_items güncellenemedi. Kurye hesabı yetkisi (RLS) kontrol edilmeli.',
        );
      }
      unawaited(_persistActiveDeliveryState());

      await Supabase.instance.client.from('order_item_status_history').insert({
        'order_item_id': orderItemId,
        'status': 'out_for_delivery',
        'title': 'İHız kuryesi paketi teslim aldı',
        'description': courierName.isEmpty
            ? 'Kurye mağazadan paketi teslim aldı ve müşteriye teslimata başladı.'
            : '$courierName mağazadan paketi teslim aldı ve müşteriye teslimata başladı.',
        'tracking_number': trackingCode,
        'cargo_company': 'İHız',
        'created_at': now,
      });

      final customerId = await _resolveCustomerNotificationUserId(order);
      if (customerId.isNotEmpty) {
        final body =
            "${order.storeName} mağazamızdan aldığınız ${order.productName ?? 'ürün'} ürünü İHız kuryemiz teslim almıştır, $deliveryCode ile takip edebilirsiniz, $trackingCode ile ürünün detaylı bilgilerini görebilirsiniz.";
        await Supabase.instance.client.from('user_notifications').insert({
          'user_id': customerId,
          'title': order.storeName,
          'body': body,
          'data': {
            'type': 'order_tracking',
            'order_id': orderId,
            'order_item_id': orderItemId,
            'status': 'out_for_delivery',
            'store_name': order.storeName,
            'product_name': order.productName,
            'tracking_number': trackingCode,
            'delivery_code': deliveryCode,
            'cargo_company': 'İHız',
            'delivery_mode': 'courier',
            'open_tab': 'tracking',
            ...courierData,
          },
          'created_at': now,
        });
      } else {
        debugPrint(
          'IHIZ pickup notification skipped: customer user_id bulunamadi. orderId=$orderId',
        );
      }

      await Supabase.instance.client
          .from('orders')
          .update({'status': 'shipped', 'updated_at': now})
          .eq('id', orderId);

      final sellerId = order.sellerId?.trim() ?? '';
      if (sellerId.isNotEmpty) {
        try {
          await Supabase.instance.client.rpc(
            'wallet_capture_seller_delivery_by_reference',
            params: {
              'p_seller_id': sellerId,
              'p_reference_id': orderId,
              'p_idempotency_key':
                  'capture-$orderItemId-${DateTime.now().microsecondsSinceEpoch}',
              'p_reason': 'courier_picked_up',
            },
          );
        } catch (walletError) {
          debugPrint('IHIZ wallet capture warn: $walletError');
        }
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sipariş havuzu güncellenemedi: $error')),
      );
    }
  }

  Future<void> _syncParentOrderStatusFromItems(
    String orderId, {
    required String now,
  }) async {
    final rows = await Supabase.instance.client
        .from('order_items')
        .select('status')
        .eq('order_id', orderId);
    final statuses = List<Map<String, dynamic>>.from(rows as List)
        .map((row) => (row['status'] ?? '').toString().toLowerCase())
        .where((status) => status.isNotEmpty)
        .toList(growable: false);
    if (statuses.isEmpty) {
      throw Exception('Sipariş durumları okunamadı.');
    }

    var orderStatus = 'confirmed';
    if (statuses.every((status) => status == 'delivered')) {
      orderStatus = 'delivered';
    } else if (statuses.every((status) {
      return status == 'returned' ||
          status == 'return_received' ||
          status == 'refunded';
    })) {
      orderStatus = 'returned';
    } else if (statuses.any(_isReturnFlowOrderItemStatus)) {
      orderStatus = 'return_requested';
    } else if (statuses.any((status) {
      return status == 'shipped' ||
          status == 'transfer' ||
          status == 'branch' ||
          status == 'out_for_delivery';
    })) {
      orderStatus = 'shipped';
    } else if (statuses.any((status) {
      return status == 'preparing' || status == 'ready_to_ship';
    })) {
      orderStatus = 'preparing';
    } else if (statuses.any((status) {
      return status == 'new' || status == 'confirmed';
    })) {
      orderStatus = 'confirmed';
    } else if (statuses.any((status) => status == 'cancelled')) {
      orderStatus = 'cancelled';
    }

    await Supabase.instance.client
        .from('orders')
        .update({'status': orderStatus, 'updated_at': now})
        .eq('id', orderId);
  }

  Future<bool> _markOrderDelivered(_OrderCardData order) async {
    final orderItemId = order.orderItemId?.trim() ?? '';
    final orderId = order.orderId?.trim() ?? '';
    _lastDeliverySyncError = null;
    if (orderItemId.isEmpty || orderId.isEmpty) {
      _lastDeliverySyncError =
          'Teslim kaydi icin orderItemId/orderId eksik geldi.';
      return false;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final courierData = _courierNotificationData();
    final courierName = courierData['courier_name']?.toString().trim() ?? '';
    final returnRequestId = order.returnRequestId?.trim() ?? '';
    final isReturnPickup = order.isReturnPickup;
    try {
      if (isReturnPickup) {
        final updatedOrderItem = await Supabase.instance.client
            .from('order_items')
            .update({
              'status': 'return_received',
              'shipment_step': 'return_received',
              'updated_at': now,
            })
            .eq('id', orderItemId)
            .select('id')
            .maybeSingle();
        if (updatedOrderItem == null) {
          throw Exception(
            'İade teslimi için order_items güncellemesi uygulanmadı.',
          );
        }

        try {
          await _syncParentOrderStatusFromItems(orderId, now: now);
        } catch (syncError) {
          debugPrint(
            'IHIZ return delivered parent status sync warn: $syncError',
          );
        }

        try {
          await Supabase.instance.client
              .from('order_item_status_history')
              .insert({
                'order_item_id': orderItemId,
                'status': 'return_received',
                'title': 'İade ürünü satıcıya teslim edildi',
                'description': courierName.isEmpty
                    ? 'İHız iade kuryesi ürünü satıcıya teslim etti.'
                    : '$courierName iade ürününü satıcıya teslim etti.',
                'tracking_number': order.trackingCode,
                'cargo_company': 'İHız',
                'created_at': now,
              });
        } catch (historyError) {
          debugPrint(
            'IHIZ return delivered history insert warn: $historyError',
          );
        }

        try {
          await Supabase.instance.client
              .from('ihiz_return_pickup_tasks')
              .update({
                'status': 'delivered',
                'delivered_at': now,
                'updated_at': now,
              })
              .eq('order_item_id', orderItemId)
              .inFilter('status', const ['picked_up', 'queued', 'assigned']);
        } catch (taskError) {
          debugPrint('IHIZ return delivered task update warn: $taskError');
        }

        final customerId = await _resolveCustomerNotificationUserId(order);
        if (customerId.isNotEmpty) {
          try {
            await Supabase.instance.client.from('user_notifications').insert({
              'user_id': customerId,
              'title': order.storeName,
              'body':
                  '${order.productName ?? 'Ürün'} için iade alımı tamamlandı. Ürün satıcıya teslim edildi.',
              'data': {
                'type': 'order_tracking',
                'order_id': orderId,
                'order_item_id': orderItemId,
                'return_request_id': returnRequestId,
                'status': 'return_received',
                'store_name': order.storeName,
                'product_name': order.productName,
                'tracking_number': order.trackingCode,
                'cargo_company': 'İHız',
                'delivery_mode': 'courier',
                'open_tab': 'tracking',
                ...courierData,
              },
              'created_at': now,
            });
          } catch (notificationError) {
            debugPrint(
              'IHIZ return delivered notification warn: $notificationError',
            );
          }
        }
        if (!mounted) return true;
        _emitCourierAlert(
          message: 'İade teslimi tamamlandı: ${order.productName ?? 'Ürün'}',
          forceSoundAndVibration: _soundAlertsEnabled,
        );
        _lastDeliverySyncError = null;
        return true;
      }

      final updatedOrderItem = await Supabase.instance.client
          .from('order_items')
          .update({
            'status': 'delivered',
            'shipment_step': 'delivered',
            'updated_at': now,
          })
          .eq('id', orderItemId)
          .select('id')
          .maybeSingle();
      if (updatedOrderItem == null) {
        throw Exception(
          'order_items delivered güncellemesi uygulanmadı. Kurye RLS yetkisi eksik olabilir.',
        );
      }

      try {
        await _syncParentOrderStatusFromItems(orderId, now: now);
      } catch (syncError) {
        debugPrint('IHIZ parent status sync warn: $syncError');
        try {
          await Supabase.instance.client
              .from('orders')
              .update({'status': 'delivered', 'updated_at': now})
              .eq('id', orderId);
        } catch (orderSyncError) {
          // Item durumu delivered olarak yazildiktan sonra parent order update
          // policy/RLS sebebiyle basarisiz olabilir. Bu durumda teslimi fail
          // saymak yerine sadece loglayip akisi devam ettiriyoruz.
          debugPrint('IHIZ order fallback sync warn: $orderSyncError');
        }
      }

      try {
        await Supabase.instance.client
            .from('order_item_status_history')
            .insert({
              'order_item_id': orderItemId,
              'status': 'delivered',
              'title': 'Sipariş teslim edildi',
              'description': courierName.isEmpty
                  ? 'İHız kuryesi siparişi müşteriye teslim etti.'
                  : '$courierName siparişi müşteriye teslim etti.',
              'tracking_number': order.trackingCode,
              'cargo_company': 'İHız',
              'created_at': now,
            });
      } catch (historyError) {
        debugPrint('IHIZ delivered history insert warn: $historyError');
      }

      final customerId = await _resolveCustomerNotificationUserId(order);
      if (customerId.isNotEmpty) {
        try {
          await Supabase.instance.client.from('user_notifications').insert({
            'user_id': customerId,
            'title': order.storeName,
            'body':
                "${order.storeName} mağazamızdan aldığınız ${order.productName ?? 'ürün'} ürünü İHız tarafından teslim edilmiştir.",
            'data': {
              'type': 'order_tracking',
              'order_id': orderId,
              'order_item_id': orderItemId,
              'status': 'delivered',
              'store_name': order.storeName,
              'product_name': order.productName,
              'tracking_number': order.trackingCode,
              'cargo_company': 'İHız',
              'delivery_mode': 'courier',
              'open_tab': 'tracking',
              ...courierData,
            },
            'created_at': now,
          });
        } catch (notificationError) {
          debugPrint('IHIZ delivered notification warn: $notificationError');
        }
      } else {
        debugPrint(
          'IHIZ delivered notification skipped: customer user_id bulunamadi. orderId=$orderId',
        );
      }
      if (!mounted) return true;
      _emitCourierAlert(
        message: 'Teslimat tamamlandı: ${order.storeName}',
        forceSoundAndVibration: _soundAlertsEnabled,
      );
      _lastDeliverySyncError = null;
      return true;
    } catch (error) {
      final compact = _compactSupabaseError(error);
      _lastDeliverySyncError = compact.isEmpty
          ? 'unknown_delivery_error'
          : compact;
      debugPrint('IHIZ mark delivered error: $error');
      return false;
    }
  }

  String _compactSupabaseError(Object error) {
    if (error is PostgrestException) {
      final message = error.message.toString().trim();
      final details = (error.details ?? '').toString().trim();
      final hint = (error.hint ?? '').toString().trim();
      final parts = <String>[
        if ((error.code ?? '').trim().isNotEmpty) 'code=${error.code}',
        if (message.isNotEmpty) message,
        if (details.isNotEmpty) details,
        if (hint.isNotEmpty) hint,
      ];
      return parts.join(' | ').trim();
    }
    return error.toString().replaceFirst('Exception:', '').trim();
  }

  String _deliverySyncFailureHint() {
    final raw = (_lastDeliverySyncError ?? '').trim();
    if (raw.isEmpty) {
      return 'Kurye yetkisi/policy veya baglanti ayarini kontrol edin.';
    }
    final normalized = raw.toLowerCase();
    if (normalized.contains('row-level security') ||
        normalized.contains('permission') ||
        normalized.contains('policy')) {
      if (normalized.contains('order_items')) {
        return 'Kurye hesabının order_items UPDATE yetkisi yok. RLS courier policy eksik.';
      }
      if (normalized.contains('orders')) {
        return 'Kurye hesabının orders UPDATE yetkisi yok. RLS courier policy eksik.';
      }
      return 'Kurye hesabı policy (RLS) yetkisine takıldı. order_items/orders courier policylerini kontrol edin.';
    }
    if (normalized.contains('failed host lookup') ||
        normalized.contains('socket') ||
        normalized.contains('network') ||
        normalized.contains('timeout')) {
      return 'Sunucuya baglanti saglanamadi. Ag ve internet baglantisini kontrol edin.';
    }
    final compactRaw = raw.length > 180 ? '${raw.substring(0, 180)}...' : raw;
    return 'Teknik hata: $compactRaw';
  }

  void _startCustomerRoute() {
    if (!_hasActiveDelivery) return;
    setState(() {
      _deliveryStage = _DeliveryStage.onTheWay;
      _mapDeliveryPanelExpanded = false;
      _selectedTabIndex = 1;
    });
    unawaited(_persistActiveDeliveryState());
    _focusActiveDeliveryRoute();
    _refreshActiveRoute();
  }

  Future<void> _completeDelivery({bool codeVerified = false}) async {
    if (!_hasActiveDelivery) return;
    final activeOrder = _activeDeliveryOrder;
    if (activeOrder == null) return;

    final synced = await _markOrderDelivered(activeOrder);
    if (!mounted) return;
    if (!synced) {
      final baseText = codeVerified
          ? 'Kod dogrulandi ancak teslim durumu yazilamadi.'
          : 'Teslim durumu yazilamadi.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$baseText ${_deliverySyncFailureHint()}')),
      );
      return;
    }
    unawaited(_clearPersistedActiveDeliveryState());

    setState(() {
      _deliveryStage = _DeliveryStage.delivered;
      _mapDeliveryPanelExpanded = true;
      _activeRoutePoints = const [];
      _lastRouteOrigin = null;
      _lastRouteDestination = null;
    });
  }

  Future<void> _completeDeliveryWithVerification() async {
    if (!_hasActiveDelivery || _deliveryStage != _DeliveryStage.onTheWay) {
      return;
    }

    final activeOrder = _activeDeliveryOrder;
    if (activeOrder == null) return;
    final activeIndex = _activeDeliveryOrderIndex;
    if (activeIndex != null &&
        _courierLocation != null &&
        _deliveryGeoFenceMeters > 0) {
      final targetPoint = _isExternalOrder(activeOrder)
          ? _storePointForIndex(activeIndex)
          : _customerPointForIndex(activeIndex);
      final distanceToTarget = Geolocator.distanceBetween(
        _courierLocation!.latitude,
        _courierLocation!.longitude,
        targetPoint.latitude,
        targetPoint.longitude,
      );
      if (distanceToTarget > _deliveryGeoFenceMeters) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Teslim onayi icin hedef noktaya daha yakin olmaniz gerekiyor '
              '(limit: ${_deliveryGeoFenceMeters.round()} m, kalan: ${distanceToTarget.round()} m).',
            ),
          ),
        );
        return;
      }
    }

    if (_isExternalOrder(activeOrder)) {
      await _completeDelivery();
      return;
    }

    if (activeOrder.isReturnPickup) {
      await _completeDelivery();
      return;
    }

    if (!_otpRequiredForDelivery) {
      await _completeDelivery();
      return;
    }

    final expectedCode = activeOrder.deliveryCode.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    if (expectedCode.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Teslim kodu doğrulanamadı. Sipariş kodu eksik görünüyor.',
          ),
        ),
      );
      return;
    }

    final enteredCode = await _askDeliveryCode(expectedCode: expectedCode);
    if (!mounted || enteredCode == null) return;

    await _completeDelivery(codeVerified: true);
  }

  Future<String?> _askDeliveryCode({required String expectedCode}) async {
    final controller = TextEditingController();
    String? validationMessage;

    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Teslim kodu'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Musterinin telefonuna giden 4 haneli teslim kodunu girin.',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: InputDecoration(
                        hintText: 'Ornek: 1234',
                        counterText: '',
                        errorText: validationMessage,
                      ),
                      onChanged: (_) {
                        if (validationMessage == null) {
                          return;
                        }
                        setDialogState(() {
                          validationMessage = null;
                        });
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Iptal'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final digits = controller.text.replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );
                      if (digits.length != 4) {
                        setDialogState(() {
                          validationMessage = 'Lutfen 4 haneli kod girin.';
                        });
                        return;
                      }
                      if (digits != expectedCode) {
                        setDialogState(() {
                          validationMessage = 'Kod hatalı.';
                        });
                        return;
                      }
                      Navigator.of(context).pop(digits);
                    },
                    child: const Text('Onayla'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _reportActiveDeliveryIssue() async {
    if (!_hasActiveDelivery || _deliveryStage == _DeliveryStage.delivered) {
      return;
    }

    final selectedReason = await _pickDeliveryIssueReason();
    if (!mounted || selectedReason == null) return;

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Paketi iptal et'),
          content: Text(
            'Bildirilen sebep:\n$selectedReason\n\nBu teslimat iptal edilsin mi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('İptal et'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldCancel != true) return;
    await _cancelActiveDelivery(selectedReason);
  }

  Future<String?> _pickDeliveryIssueReason() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bildir',
                  style: TextStyle(
                    color: Color(0xFF163B73),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Teslimat sorunu sebebini seçin',
                  style: TextStyle(
                    color: Color(0xFF5B6B86),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ..._deliveryIssueReasons.map((item) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item,
                      style: const TextStyle(
                        color: Color(0xFF163B73),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(item),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (reason == null) return null;
    if (reason != 'Diğer sebepler') return reason;

    final other = await _askOtherIssueReason();
    if (other == null) return null;
    if (other.trim().isEmpty) return reason;
    return 'Diğer: ${other.trim()}';
  }

  Future<String?> _askOtherIssueReason() async {
    final controller = TextEditingController();

    try {
      return await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Diğer sebep'),
            content: TextField(
              controller: controller,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Sebebi yazın',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Vazgeç'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Onayla'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _cancelActiveDelivery(String reason) async {
    if (!_hasActiveDelivery) return;
    final shouldStayOnMap = _selectedTabIndex == 1;
    final activeOrder = _activeDeliveryOrder;
    final orderItemId = activeOrder?.orderItemId?.trim() ?? '';
    final orderId = activeOrder?.orderId?.trim() ?? '';
    final reasonText = reason.trim().isEmpty
        ? 'operasyonel sebepler'
        : reason.trim();
    String? syncError;

    if (orderItemId.isNotEmpty && orderId.isNotEmpty) {
      final now = DateTime.now().toUtc().toIso8601String();
      try {
        if (activeOrder?.isReturnPickup == true) {
          final updatedOrderItem = await Supabase.instance.client
              .from('order_items')
              .update({
                'status': 'return_approved',
                'shipment_step': 'return_approved',
                'updated_at': now,
              })
              .eq('id', orderItemId)
              .select('id')
              .maybeSingle();
          if (updatedOrderItem == null) {
            throw Exception(
              'İade görevi iptalinde order_items güncellemesi uygulanmadı.',
            );
          }

          try {
            await _syncParentOrderStatusFromItems(orderId, now: now);
          } catch (syncParentError) {
            debugPrint(
              'IHIZ return cancel parent status sync warn: $syncParentError',
            );
          }

          try {
            await Supabase.instance.client
                .from('order_item_status_history')
                .insert({
                  'order_item_id': orderItemId,
                  'status': 'return_approved',
                  'title': 'İade kurye görevi iptal edildi',
                  'description': 'İptal nedeni: $reasonText',
                  'tracking_number': activeOrder?.trackingCode,
                  'cargo_company': 'İHız',
                  'created_at': now,
                });
          } catch (historyError) {
            debugPrint('IHIZ return cancel history insert warn: $historyError');
          }

          try {
            await Supabase.instance.client
                .from('ihiz_return_pickup_tasks')
                .update({'status': 'cancelled', 'updated_at': now})
                .eq('order_item_id', orderItemId)
                .inFilter('status', const ['queued', 'assigned', 'picked_up']);
          } catch (taskError) {
            debugPrint('IHIZ return cancel task update warn: $taskError');
          }

          final customerId = activeOrder == null
              ? ''
              : await _resolveCustomerNotificationUserId(activeOrder);
          if (customerId.isNotEmpty) {
            try {
              await Supabase.instance.client.from('user_notifications').insert({
                'user_id': customerId,
                'title': activeOrder?.storeName ?? 'İHız',
                'body':
                    "İade kurye alımı '$reasonText' sebebiyle iptal edildi. Tekrar saat planlayabilirsiniz.",
                'data': {
                  'type': 'order_tracking',
                  'order_id': orderId,
                  'order_item_id': orderItemId,
                  'return_request_id': activeOrder?.returnRequestId,
                  'status': 'return_approved',
                  'store_name': activeOrder?.storeName,
                  'product_name': activeOrder?.productName,
                  'tracking_number': activeOrder?.trackingCode,
                  'cargo_company': 'İHız',
                  'delivery_mode': 'courier',
                  'cancel_reason': reasonText,
                  'open_tab': 'tracking',
                },
                'created_at': now,
              });
            } catch (notificationError) {
              debugPrint(
                'IHIZ return cancel notification warn: $notificationError',
              );
            }
          }
          _lastDeliverySyncError = null;
          _resetDeliveryFlow();
          if (mounted && shouldStayOnMap) {
            setState(() {
              _selectedTabIndex = 1;
            });
          }
          return;
        }

        final updatedOrderItem = await Supabase.instance.client
            .from('order_items')
            .update({
              'status': 'cancelled',
              'shipment_step': 'cancelled',
              'updated_at': now,
            })
            .eq('id', orderItemId)
            .select('id')
            .maybeSingle();
        if (updatedOrderItem == null) {
          throw Exception(
            'order_items cancelled güncellemesi uygulanmadı. Kurye RLS yetkisi eksik olabilir.',
          );
        }

        try {
          await _syncParentOrderStatusFromItems(orderId, now: now);
        } catch (syncParentError) {
          debugPrint('IHIZ parent status cancel sync warn: $syncParentError');
          await Supabase.instance.client
              .from('orders')
              .update({'status': 'cancelled', 'updated_at': now})
              .eq('id', orderId);
        }

        try {
          await Supabase.instance.client
              .from('order_item_status_history')
              .insert({
                'order_item_id': orderItemId,
                'status': 'cancelled',
                'title': 'Kurye teslimatı iptal etti',
                'description': 'İptal nedeni: $reasonText',
                'tracking_number': activeOrder?.trackingCode,
                'cargo_company': 'İHız',
                'created_at': now,
              });
        } catch (historyError) {
          debugPrint('IHIZ cancel history insert warn: $historyError');
        }

        final customerId = activeOrder == null
            ? ''
            : await _resolveCustomerNotificationUserId(activeOrder);
        if (customerId.isNotEmpty) {
          try {
            await Supabase.instance.client.from('user_notifications').insert({
              'user_id': customerId,
              'title': activeOrder?.storeName ?? 'İHız',
              'body':
                  "'$reasonText' sebepten dolayı siparişiniz iptal edilmiştir.",
              'data': {
                'type': 'order_tracking',
                'order_id': orderId,
                'order_item_id': orderItemId,
                'status': 'cancelled',
                'store_name': activeOrder?.storeName,
                'product_name': activeOrder?.productName,
                'tracking_number': activeOrder?.trackingCode,
                'cargo_company': 'İHız',
                'delivery_mode': 'courier',
                'cancel_reason': reasonText,
                'open_tab': 'tracking',
              },
              'created_at': now,
            });
          } catch (notificationError) {
            debugPrint('IHIZ cancel notification warn: $notificationError');
          }
        } else {
          debugPrint(
            'IHIZ cancel notification skipped: customer user_id bulunamadi. orderId=$orderId',
          );
        }
      } catch (error) {
        syncError = _compactSupabaseError(error);
        debugPrint('IHIZ cancel delivery sync error: $error');
      }
    } else {
      syncError = 'Sipariş kimliği bulunamadı (order_id/order_item_id).';
    }

    if (syncError != null && syncError.trim().isNotEmpty) {
      _lastDeliverySyncError = syncError;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Teslimat iptal edilemedi. ${_deliverySyncFailureHint()}',
          ),
        ),
      );
      return;
    }

    _resetDeliveryFlow();
    if (!mounted) return;

    if (shouldStayOnMap) {
      setState(() {
        _selectedTabIndex = 1;
      });
    }

    _lastDeliverySyncError = null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Teslimat iptal edildi: $reasonText')),
    );
  }

  void _resetDeliveryFlow() {
    unawaited(_clearPersistedActiveDeliveryState());
    setState(() {
      _deliveryStage = _DeliveryStage.idle;
      _activeDeliveryOrderIndex = null;
      _activeDeliveryOrderItemId = null;
      _highlightedStoreId = null;
      _mapDeliveryPanelExpanded = true;
      _activeRoutePoints = const [];
      _previewRoutePoints = const [];
      _lastRouteOrigin = null;
      _lastRouteDestination = null;
      _mapSearchController.clear();
      _storeSearchQuery = '';
      _selectedTabIndex = 0;
    });
    _fetchCourierPoolOrders();
  }

  String _deliveryStageLabel(_DeliveryStage stage) {
    final isReturnPickup = _activeDeliveryOrder?.isReturnPickup == true;
    switch (stage) {
      case _DeliveryStage.idle:
        return 'Görev havuzunda';
      case _DeliveryStage.headingToStore:
        return isReturnPickup
            ? 'Müşteriden iade alınıyor'
            : 'Mağazaya gidiliyor';
      case _DeliveryStage.onTheWay:
        return isReturnPickup
            ? 'Satıcıya iade götürülüyor'
            : 'Müşteriye gidiliyor';
      case _DeliveryStage.delivered:
        return isReturnPickup ? 'İade teslim edildi' : 'Teslim edildi';
    }
  }

  List<_RegisteredStoreData> get _searchableStores {
    final query = _storeSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return _registeredStores;

    return _registeredStores
        .where(
          (store) =>
              store.name.toLowerCase().contains(query) ||
              _mapDisplayNameForStore(store).toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  List<_RegisteredStoreData> get _demandStores => _registeredStores
      .where((store) => store.isRequestingCourier)
      .toList(growable: false);

  String _mapDisplayNameForStore(_RegisteredStoreData store) {
    if (store.isReturnPickup) return 'İade Ürün';
    return store.name;
  }

  void _openMapOrderPopup(int index) {
    if (index < 0 || index >= _orders.length) return;

    final selectedStore = _registeredStores[index];
    final displayName = _mapDisplayNameForStore(selectedStore);
    setState(() {
      _selectedOrderIndex = index;
      _mapPopupOrderIndex = index;
      _mapPopupCardExpanded = true;
      _highlightedStoreId = selectedStore.id;
      _mapSearchController.text = displayName;
      _storeSearchQuery = displayName;
    });
    _showPreviewRouteFor(index);
  }

  void _closeMapOrderPopup() {
    setState(() {
      _mapPopupOrderIndex = null;
      _mapPopupCardExpanded = true;
      _previewRoutePoints = const [];
    });
  }

  Future<void> _openAccountSettingsPage() async {
    final seededApplicationData =
        _applicationData ?? _defaultCourierApplicationData();
    final updated = await Navigator.of(context).push<_AccountSettingsResult>(
      MaterialPageRoute<_AccountSettingsResult>(
        builder: (context) => _AccountSettingsPage(
          applicationData: seededApplicationData,
          initialPushEnabled: _taskNotificationsEnabled,
          initialSoundEnabled: _soundAlertsEnabled,
          initialNightModeEnabled: _nightModeEnabled,
          initialFaceIdEnabled: _faceIdEnabled,
        ),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() {
      _applicationData = updated.applicationData;
      _taskNotificationsEnabled = updated.pushEnabled;
      _soundAlertsEnabled = updated.soundEnabled;
      _nightModeEnabled = updated.nightModeEnabled;
      _faceIdEnabled = updated.faceIdEnabled;
    });
    widget.onApplicationDataChanged?.call(updated.applicationData);
  }

  CourierApplicationData _defaultCourierApplicationData() {
    return const CourierApplicationData(
      fullName: 'Baran Yılmaz',
      phone: '05xx xxx xx xx',
      tcNumber: '',
      birthDate: '',
      licenseType: '',
      motorType: '',
      criminalRecord: '',
      companyType: '',
      city: 'Eskişehir',
      district: 'Tepebaşı',
      availability: 'Tam zamanlı / Yarı zamanlı',
      email: 'ornek@ihiz.com',
      note: '',
    );
  }

  List<_CourierDailyEarning> _mockDailyEarnings() {
    final today = DateTime.now();
    return List.generate(120, (index) {
      final amount = 540 + ((index * 73) % 460) + ((index % 5) * 22);
      final deliveries = 1 + (index % 5);
      final date = DateTime(today.year, today.month, today.day - index);
      return _CourierDailyEarning(
        date: date,
        amount: amount.toDouble(),
        completedDeliveries: deliveries,
      );
    });
  }

  Future<void> _openEarningsPage() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            _CourierEarningsPage(dailyEarnings: _mockDailyEarnings()),
      ),
    );
  }

  Map<String, dynamic> _activeRegionOptionToJson(_ActiveRegionOption option) {
    final boundaryRings = option.boundaryRings
        .map(
          (ring) => ring
              .map((point) => <double>[point.latitude, point.longitude])
              .toList(growable: false),
        )
        .where((ring) => ring.length >= 3)
        .toList(growable: false);
    return {
      'key': option.key,
      'district': option.district,
      'city': option.city,
      'lat': option.point.latitude,
      'lng': option.point.longitude,
      if (boundaryRings.isNotEmpty) 'boundary_rings': boundaryRings,
    };
  }

  List<List<LatLng>> _boundaryRingsFromDynamic(dynamic raw) {
    if (raw is! List) return const [];
    final rings = <List<LatLng>>[];
    for (final ringRaw in raw) {
      if (ringRaw is! List) continue;
      final ring = <LatLng>[];
      for (final pointRaw in ringRaw) {
        double? lat;
        double? lng;
        if (pointRaw is List && pointRaw.length >= 2) {
          lat = _asDouble(pointRaw[0]);
          lng = _asDouble(pointRaw[1]);
        } else if (pointRaw is Map) {
          final map = Map<String, dynamic>.from(pointRaw);
          lat = _asDouble(map['lat'] ?? map['latitude']);
          lng = _asDouble(map['lng'] ?? map['longitude']);
        }
        if (lat != null && lng != null) {
          ring.add(LatLng(lat, lng));
        }
      }
      if (ring.length >= 3) {
        rings.add(ring);
      }
    }
    return rings;
  }

  _ActiveRegionOption? _activeRegionOptionFromMap(Map<String, dynamic> raw) {
    final district = _normalizeRegionLabel((raw['district'] ?? '').toString());
    if (district == 'Genel') return null;
    final city = _normalizeRegionLabel((raw['city'] ?? 'Türkiye').toString());
    final keyValue = (raw['key'] ?? '').toString().trim();
    final key = keyValue.isEmpty
        ? _regionKeyFor(district)
        : _regionKeyFor(keyValue);
    final lat = _asDouble(raw['lat'] ?? raw['latitude']);
    final lng = _asDouble(raw['lng'] ?? raw['longitude']);
    if (lat == null || lng == null) return null;
    return _ActiveRegionOption(
      key: key,
      district: district,
      city: city,
      point: LatLng(lat, lng),
      boundaryRings: _boundaryRingsFromDynamic(raw['boundary_rings']),
    );
  }

  List<_ActiveRegionOption> _activeRegionOptionsFromDynamic(dynamic raw) {
    dynamic decoded = raw;
    if (decoded is String && decoded.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        return const [];
      }
    }
    if (decoded is! List) return const [];
    final optionsByKey = <String, _ActiveRegionOption>{};
    for (final row in decoded) {
      if (row is! Map) continue;
      final option = _activeRegionOptionFromMap(
        row.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (option == null) continue;
      optionsByKey[option.key] = option;
    }
    return optionsByKey.values.toList(growable: false);
  }

  Set<String> _activeRegionKeysFromDynamic(dynamic raw) {
    dynamic decoded = raw;
    if (decoded is String && decoded.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(decoded);
      } catch (_) {
        decoded = decoded.split(',');
      }
    }
    if (decoded is! List) return <String>{};
    return decoded
        .map((value) => _regionKeyFor((value ?? '').toString()))
        .where((value) => value.isNotEmpty)
        .toSet();
  }

  Future<void> _loadSavedActiveRegions() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    try {
      final row = await Supabase.instance.client
          .from('ihiz_courier_applications')
          .select('active_region_keys, active_region_options')
          .eq('user_id', currentUser.id)
          .maybeSingle();
      if (row is! Map) return;
      final data = Map<String, dynamic>.from(row as Map);
      final selectedKeys = _activeRegionKeysFromDynamic(
        data['active_region_keys'],
      );
      final savedOptions = _activeRegionOptionsFromDynamic(
        data['active_region_options'],
      );
      if (!mounted) return;
      setState(() {
        _activeRegionKeys = selectedKeys;
        for (final option in savedOptions) {
          final normalizedKey = _regionKeyFor(
            option.key.isNotEmpty ? option.key : option.district,
          );
          _manualActiveRegions[normalizedKey] = option.copyWith(
            key: normalizedKey,
          );
        }
      });
    } catch (error) {
      debugPrint('IHIZ active region load error: $error');
    }
  }

  Future<void> _persistActiveRegions() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    final selectedKeys = _activeRegionKeys.toList(growable: false)..sort();
    final options = _manualActiveRegions.values
        .map(_activeRegionOptionToJson)
        .toList(growable: false);
    try {
      await Supabase.instance.client
          .from('ihiz_courier_applications')
          .update({
            'active_region_keys': selectedKeys,
            'active_region_options': options,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', currentUser.id);
    } catch (error) {
      debugPrint('IHIZ active region save error: $error');
    }
  }

  String _normalizeRegionLabel(String raw) {
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized.isEmpty ? 'Genel' : normalized;
  }

  String _extractRegionDistrictPart(String raw) {
    var normalized = _normalizeRegionLabel(raw);
    for (final separator in const ['/', ',', '|', '\\']) {
      if (normalized.contains(separator)) {
        normalized = normalized.split(separator).first.trim();
      }
    }
    return _normalizeRegionLabel(normalized);
  }

  String _normalizeRegionKeyToken(String raw) {
    return raw
        .trim()
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u');
  }

  String _regionKeyFor(String raw) {
    final districtPart = _extractRegionDistrictPart(raw);
    return _normalizeRegionKeyToken(districtPart);
  }

  LatLng _resolveRegionPoint({
    required String district,
    required String city,
    String? key,
  }) {
    final normalizedDistrict = _normalizeRegionLabel(district);
    final normalizedCity = _normalizeRegionLabel(city);
    final regionKey = key ?? _regionKeyFor(normalizedDistrict);

    final manual = _manualActiveRegions[regionKey];
    if (manual != null) return manual.point;

    for (final task in _courierPoolOrders) {
      if (task.regionKey == regionKey) return task.customerPoint;
    }

    String normalizedText(String text) {
      return text
          .toLowerCase()
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ş', 's')
          .replaceAll('ç', 'c')
          .replaceAll('ö', 'o')
          .replaceAll('ü', 'u');
    }

    final districtAscii = normalizedText(normalizedDistrict);
    if (districtAscii.contains('hosnudiye')) {
      return _mapLayouts[1].customerPoint;
    }
    if (districtAscii.contains('cassaba')) return _mapLayouts[2].customerPoint;
    if (districtAscii.contains('doktorlar')) return _demoStores.last.point;
    if (districtAscii.contains('tepebasi')) return _mapLayouts[0].storePoint;
    if (districtAscii.contains('gokmeydan')) {
      return _mapLayouts[0].customerPoint;
    }
    if (districtAscii.contains('antakya')) {
      return const LatLng(36.2021, 36.1606);
    }

    final cityAscii = normalizedText(normalizedCity);
    if (cityAscii.contains('eskisehir')) return _mapLayouts[0].storePoint;
    if (cityAscii.contains('hatay')) return const LatLng(36.2021, 36.1606);

    return const LatLng(39.0, 35.0);
  }

  _ActiveRegionOption _profileActiveRegionOption() {
    final base = _applicationData ?? _defaultCourierApplicationData();
    final district = _normalizeRegionLabel(base.district);
    final city = _normalizeRegionLabel(base.city);
    final key = _regionKeyFor(district);
    return _ActiveRegionOption(
      key: key,
      district: district,
      city: city,
      point: _resolveRegionPoint(district: district, city: city, key: key),
    );
  }

  List<_ActiveRegionOption> _availableActiveRegionOptions() {
    final optionsByKey = <String, _ActiveRegionOption>{};

    void register(_ActiveRegionOption option) {
      optionsByKey[option.key] = option;
    }

    register(_profileActiveRegionOption());

    for (final option in _manualActiveRegions.values) {
      register(option);
    }

    for (final task in _courierPoolOrders) {
      final district = _normalizeRegionLabel(task.regionLabel);
      final city = _normalizeRegionLabel(task.regionCity);
      final key = _regionKeyFor(district);
      register(
        _ActiveRegionOption(
          key: key,
          district: district,
          city: city,
          point: task.customerPoint,
        ),
      );
    }

    final options = optionsByKey.values.toList(growable: false)
      ..sort((a, b) => a.label.compareTo(b.label));
    return options;
  }

  String _activeRegionMetricValue() {
    if (_activeRegionKeys.isEmpty) return 'Tümü';
    return _activeRegionKeys.length.toString();
  }

  String _activeRegionMetricCaption() {
    if (_activeRegionKeys.isEmpty) {
      return 'Bölge filtresi kapalı';
    }
    final options = _availableActiveRegionOptions();
    final labels = options
        .where((option) => _activeRegionKeys.contains(option.key))
        .map((option) => option.label)
        .toList(growable: false);
    if (labels.isEmpty) {
      return '${_activeRegionKeys.length} bölge seçili';
    }
    if (labels.length == 1) return labels.first;
    return '${labels.first} +${labels.length - 1} bölge';
  }

  Future<void> _openActiveRegionsPage() async {
    final options = _availableActiveRegionOptions();
    final profileRegion = _profileActiveRegionOption();
    final initialSelected = _activeRegionKeys.isEmpty
        ? <String>{profileRegion.key}
        : <String>{..._activeRegionKeys};
    final result = await Navigator.of(context)
        .push<_ActiveRegionSelectionResult>(
          MaterialPageRoute<_ActiveRegionSelectionResult>(
            builder: (context) => _ActiveRegionsPage(
              options: options,
              initialSelectedKeys: initialSelected,
            ),
          ),
        );
    if (!mounted || result == null) return;
    final selectedKeysRaw = result.selectedKeys.isEmpty
        ? <String>{profileRegion.key}
        : result.selectedKeys;
    final selectedKeys = selectedKeysRaw
        .map((key) => _regionKeyFor(key))
        .where((key) => key.isNotEmpty)
        .toSet();
    setState(() {
      _activeRegionKeys = selectedKeys;
      for (final option in result.allOptions) {
        final normalizedKey = _regionKeyFor(
          option.key.isNotEmpty ? option.key : option.district,
        );
        _manualActiveRegions[normalizedKey] = option.copyWith(
          key: normalizedKey,
        );
      }
      _selectedOrderIndex = 0;
      _mapPopupOrderIndex = null;
      _previewRoutePoints = const [];
      if (_orders.isEmpty) {
        _highlightedStoreId = null;
      }
    });
    unawaited(_persistActiveRegions());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _activeRegionKeys.isEmpty
              ? 'Tüm bölgeler için sipariş alımı açıldı.'
              : '${_activeRegionKeys.length} bölge aktif edildi.',
        ),
      ),
    );
  }

  Future<void> _createSupportTicket({
    required String category,
    required String subject,
    required String description,
    required String priority,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('Destek talebi için önce giriş yapmalısınız.');
    }

    final scopedCategory = category.toLowerCase().startsWith('kurye /')
        ? category
        : 'Kurye / $category';
    final scopedSubject = subject.toLowerCase().startsWith('[kurye]')
        ? subject
        : '[KURYE] $subject';
    final nowIso = DateTime.now().toIso8601String();
    await Supabase.instance.client.from('support_tickets').insert({
      'user_id': user.id,
      'user_type': 'user',
      'category': scopedCategory,
      'subject': scopedSubject,
      'description': description,
      'status': 'open',
      'priority': priority,
      'created_at': nowIso,
      'updated_at': nowIso,
    });
  }

  Future<void> _openSupportCenterSheet() async {
    final noteController = TextEditingController();
    final templates = <Map<String, String>>[
      {
        'title': 'Teslimat Gecikmesi',
        'category': 'Teslimat',
        'subject': 'Teslimat gecikmesi bildirimi',
        'description': 'Teslimat sırasında gecikme yaşıyorum.',
        'priority': 'high',
      },
      {
        'title': 'Adres Sorunu',
        'category': 'Adres',
        'subject': 'Adres doğrulama sorunu',
        'description': 'Müşteri adresine ulaşırken sorun yaşadım.',
        'priority': 'medium',
      },
      {
        'title': 'Ödeme Sorunu',
        'category': 'Ödeme',
        'subject': 'Ödeme/dekont sorunu',
        'description': 'Kazanç veya dekont kısmında uyuşmazlık var.',
        'priority': 'high',
      },
      {
        'title': 'Uygulama Hatası',
        'category': 'Teknik',
        'subject': 'Uygulama teknik hata bildirimi',
        'description': 'Uygulamada teknik bir hata ile karşılaştım.',
        'priority': 'medium',
      },
    ];

    var selectedIndex = 0;
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final selected = templates[selectedIndex];
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Destek Merkezi',
                    style: TextStyle(
                      color: Color(0xFF163B73),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Hazır kutulardan konuyu seçip bildirim bırakın veya canlı sohbet başlatın.',
                    style: TextStyle(color: Color(0xFF5B6B86), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(templates.length, (index) {
                      final item = templates[index];
                      final isActive = selectedIndex == index;
                      return InkWell(
                        onTap: () {
                          setSheetState(() {
                            selectedIndex = index;
                          });
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF163B73)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF163B73)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Text(
                            item['title'] ?? '-',
                            style: TextStyle(
                              color: isActive
                                  ? Colors.white
                                  : const Color(0xFF374151),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  _ApplyField(
                    label: 'Ek not',
                    hint: 'İsterseniz kısa açıklama yazın',
                    controller: noteController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setSheetState(() {
                                    isSubmitting = true;
                                  });
                                  try {
                                    final note = noteController.text.trim();
                                    final baseDescription =
                                        selected['description'] ?? '';
                                    final description = note.isEmpty
                                        ? baseDescription
                                        : '$baseDescription\n\nKurye notu: $note';
                                    await _createSupportTicket(
                                      category: selected['category'] ?? 'Genel',
                                      subject:
                                          selected['subject'] ??
                                          'Destek talebi',
                                      description: description,
                                      priority:
                                          selected['priority'] ?? 'medium',
                                    );
                                    if (!mounted) return;
                                    Navigator.of(this.context).pop();
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Destek bildirimi gönderildi. Admin panelde görünecek.',
                                        ),
                                      ),
                                    );
                                  } catch (error) {
                                    setSheetState(() {
                                      isSubmitting = false;
                                    });
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Destek bildirimi gönderilemedi: $error',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.report_gmailerrorred_outlined),
                          label: Text(
                            isSubmitting
                                ? 'Gönderiliyor...'
                                : 'Bildirimi Gönder',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setSheetState(() {
                                    isSubmitting = true;
                                  });
                                  try {
                                    final note = noteController.text.trim();
                                    final description = note.isEmpty
                                        ? 'Kurye canlı sohbet talebi başlattı.'
                                        : 'Kurye canlı sohbet talebi başlattı.\n\nİlk mesaj: $note';
                                    await _createSupportTicket(
                                      category: 'Canlı Sohbet',
                                      subject: 'Canlı sohbet talebi',
                                      description: description,
                                      priority: 'high',
                                    );
                                    if (!mounted) return;
                                    Navigator.of(this.context).pop();
                                    await Future<void>.delayed(
                                      const Duration(milliseconds: 120),
                                    );
                                    if (!mounted) return;
                                    await _openLiveChatSheet(
                                      initialMessage: note,
                                    );
                                  } catch (error) {
                                    setSheetState(() {
                                      isSubmitting = false;
                                    });
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Canlı sohbet başlatılamadı: $error',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('Canlı Sohbet'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
  }

  Future<void> _openLiveChatSheet({String? initialMessage}) async {
    final trimmedMessage = initialMessage?.trim() ?? '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Canlı Sohbet',
                style: TextStyle(
                  color: Color(0xFF163B73),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Canlı sohbete bağlanıyorsunuz...',
                        style: const TextStyle(
                          color: Color(0xFF163B73),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (trimmedMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF163B73),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      trimmedMessage,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Yakında operatör bağlanacak. Şimdilik hazırlık ekranı aktif.',
                style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Kapat'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildDashboardContent(
    bool isMobile,
    _OrderCardData? selectedOrder,
  ) {
    if (!isMobile) {
      return [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 10,
              child: Column(children: [_buildOrderPool(false)]),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 8,
              child: Column(children: [_buildAccountCard(false)]),
            ),
          ],
        ),
      ];
    }

    switch (_selectedTabIndex) {
      case 0:
        return [
          _buildOrderPool(true),
          if (_hasActiveDelivery) ...[
            const SizedBox(height: 18),
            _buildDeliveryControlCard(true),
          ],
        ];
      case 1:
        return [_buildMapOnlyScreen(selectedOrder)];
      case 2:
        return [_buildAccountCard(true)];
      default:
        return [_buildOrderPool(true)];
    }
  }

  Widget _buildBottomBar() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDDE6F4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: NavigationBar(
          height: 74,
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFF163B73).withValues(alpha: 0.1),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          selectedIndex: _selectedTabIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedTabIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Ana Sayfa',
            ),
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Harita',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Hesabım',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapOnlyScreen(_OrderCardData? selectedOrder) {
    final hasTaskContext = selectedOrder != null && _orders.isNotEmpty;
    final isExternalTask = _isExternalOrder(selectedOrder);
    final visibleOrderStores = _searchableStores;
    final visibleLiveStores = _searchableLiveStores;
    final showActiveRoute =
        hasTaskContext &&
        _hasActiveDelivery &&
        _isCurrentActiveOrder(_selectedOrderIndex);
    final activeDeliveryOrder = showActiveRoute ? selectedOrder : null;
    final popupOrderIndex = hasTaskContext ? _mapPopupOrderIndex : null;
    final popupOrder = popupOrderIndex != null
        ? _orders[popupOrderIndex]
        : null;
    final isPopupExternalOrder = _isExternalOrder(popupOrder);
    final showPreviewRoute = popupOrder != null && !showActiveRoute;
    final activeAccent = selectedOrder?.accent ?? const Color(0xFF163B73);
    final storePoint = hasTaskContext
        ? _storePointForIndex(_selectedOrderIndex)
        : (visibleLiveStores.isNotEmpty
              ? visibleLiveStores.first.point
              : _turkiyeCenter);
    final customerPoint = hasTaskContext
        ? _customerPointForIndex(_selectedOrderIndex)
        : storePoint;
    final courierPoint =
        _courierLocation ??
        (hasTaskContext
            ? _fallbackCourierPointForIndex(_selectedOrderIndex)
            : storePoint);
    final courierToStoreMeters = hasTaskContext
        ? _courierToStoreDistanceMeters(storePoint)
        : null;
    final storeToCustomerMeters = hasTaskContext
        ? (isExternalTask
              ? null
              : _storeToCustomerDistanceMeters(storePoint, customerPoint))
        : null;
    final compactPrimaryDistanceLabel =
        _deliveryStage == _DeliveryStage.onTheWay
        ? (storeToCustomerMeters == null
              ? 'Müşteri konumu bekleniyor'
              : 'Müşteri: ${_formatDistance(storeToCustomerMeters)}')
        : (courierToStoreMeters == null
              ? 'Konum bekleniyor'
              : 'Mağaza: ${_formatDistance(courierToStoreMeters)}');
    final compactStatusText = _deliveryStage == _DeliveryStage.headingToStore
        ? (courierToStoreMeters == null
              ? 'Konum alınıyor, mağazaya ilerleyin.'
              : 'Mağazaya ${_formatDistance(courierToStoreMeters)} kaldı.')
        : _deliveryStage == _DeliveryStage.onTheWay
        ? (isExternalTask
              ? 'Paket alındı, teslimi onaylayın.'
              : (storeToCustomerMeters == null
                    ? 'Müşteri konumu bekleniyor.'
                    : 'Müşteriye ${_formatDistance(storeToCustomerMeters)} kaldı.'))
        : 'Teslimat tamamlandı.';
    final String compactPrimaryActionLabel;
    VoidCallback? compactPrimaryAction;
    if (_deliveryStage == _DeliveryStage.headingToStore) {
      compactPrimaryActionLabel = 'Yola çık';
      compactPrimaryAction = _startCustomerRoute;
    } else if (_deliveryStage == _DeliveryStage.onTheWay) {
      compactPrimaryActionLabel = 'Teslim et';
      compactPrimaryAction = _completeDeliveryWithVerification;
    } else {
      compactPrimaryActionLabel = 'Bitir';
      compactPrimaryAction = _resetDeliveryFlow;
    }
    final fallbackRoutePoints = hasTaskContext
        ? ((isExternalTask || _deliveryStage == _DeliveryStage.headingToStore)
              ? [courierPoint, storePoint]
              : [storePoint, customerPoint])
        : const <LatLng>[];
    final visibleRoutePoints = _activeRoutePoints.isNotEmpty
        ? _activeRoutePoints
        : fallbackRoutePoints;
    final previewRoutePoints = _previewRoutePoints.isNotEmpty
        ? _previewRoutePoints
        : (hasTaskContext
              ? (isPopupExternalOrder
                    ? [courierPoint, storePoint]
                    : [storePoint, customerPoint])
              : const <LatLng>[]);
    final showCustomerMarker =
        (showActiveRoute && !isExternalTask) ||
        (popupOrder != null && !isPopupExternalOrder);
    final showFloatingLocationButton = popupOrder == null;
    final locationButtonBottom = showActiveRoute
        ? (_mapDeliveryPanelExpanded ? 210.0 : 108.0)
        : 18.0;

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mobileMapController,
            options: const MapOptions(
              initialCenter: _turkiyeCenter,
              initialZoom: 6.2,
              minZoom: 5,
              maxZoom: 18,
              initialRotation: 0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.ihiz_web',
              ),
              PolylineLayer(
                polylines: !(showActiveRoute || showPreviewRoute)
                    ? <Polyline<Object>>[]
                    : <Polyline<Object>>[
                        Polyline(
                          points: showActiveRoute
                              ? visibleRoutePoints
                              : previewRoutePoints,
                          strokeWidth: 5,
                          color: activeAccent.withValues(
                            alpha: showActiveRoute ? 0.88 : 0.62,
                          ),
                        ),
                      ],
              ),
              MarkerLayer(
                markers: [
                  if (hasTaskContext)
                    ...visibleOrderStores.map((store) {
                      final isHighlighted = store.id == _highlightedStoreId;
                      return Marker(
                        point: store.point,
                        width: isHighlighted ? 62 : 52,
                        height: isHighlighted ? 62 : 52,
                        child: _MapStoreMarker(
                          color: store.accent,
                          isSelected: isHighlighted,
                          onTap: () {
                            final orderIndex = _registeredStores.indexWhere(
                              (registeredStore) =>
                                  registeredStore.id == store.id,
                            );
                            if (orderIndex != -1) {
                              _openMapOrderPopup(orderIndex);
                            }
                          },
                        ),
                      );
                    }),
                  if (!hasTaskContext)
                    ...visibleLiveStores.map((store) {
                      final isHighlighted = store.id == _highlightedStoreId;
                      return Marker(
                        point: store.point,
                        width: isHighlighted ? 62 : 52,
                        height: isHighlighted ? 62 : 52,
                        child: _MapStoreMarker(
                          color: const Color(0xFF163B73),
                          isSelected: isHighlighted,
                          showPackageBadge: false,
                          onTap: () {
                            setState(() {
                              _highlightedStoreId = store.id;
                            });
                            _mobileMapController.move(store.point, 13.8);
                          },
                        ),
                      );
                    }),
                  if (showCustomerMarker)
                    Marker(
                      point: customerPoint,
                      width: 56,
                      height: 56,
                      child: const _MapPinMarker(
                        color: Color(0xFF163B73),
                        icon: Icons.person_pin_circle_outlined,
                      ),
                    ),
                  Marker(
                    point: courierPoint,
                    width: 74,
                    height: 74,
                    child: const _CourierPulse(),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFF5B6B86)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _mapSearchController,
                      onChanged: _handleMapSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Mağaza ara',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_storesLoading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_mapSearchController.text.isNotEmpty)
                    IconButton(
                      onPressed: () {
                        _mapSearchController.clear();
                        setState(() {
                          _storeSearchQuery = '';
                          _highlightedStoreId = null;
                        });
                        _mobileMapController.move(_turkiyeCenter, 6.2);
                      },
                      icon: const Icon(Icons.close, color: Color(0xFF5B6B86)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: 82,
          left: 14,
          right: 14,
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 48,
              child: hasTaskContext
                  ? ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _demandStores.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final store = _demandStores[index];
                        final mapDisplayName = _mapDisplayNameForStore(store);
                        final isActive =
                            _mapSearchController.text == mapDisplayName ||
                            popupOrderIndex == index;

                        return InkWell(
                          onTap: () => _openMapOrderPopup(index),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF163B73)
                                  : Colors.white.withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notifications_active_outlined,
                                  size: 16,
                                  color: isActive
                                      ? Colors.white
                                      : const Color(0xFF163B73),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  mapDisplayName,
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF163B73),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: visibleLiveStores.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final store = visibleLiveStores[index];
                        final isActive = _highlightedStoreId == store.id;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _highlightedStoreId = store.id;
                            });
                            _mobileMapController.move(store.point, 13.8);
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF163B73)
                                  : Colors.white.withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.storefront_outlined,
                                  size: 16,
                                  color: isActive
                                      ? Colors.white
                                      : const Color(0xFF163B73),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  store.name,
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF163B73),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
        if (popupOrder != null)
          Positioned(
            left: 14,
            right: 14,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: _buildMapPopupCard(popupOrderIndex!, popupOrder),
            ),
          ),
        if (!hasTaskContext && !_storesLoading && visibleLiveStores.isEmpty)
          Positioned(
            left: 14,
            right: 14,
            bottom: 20,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDDE6F4)),
                ),
                child: const Text(
                  'Canli magazaya ait konum bulunamadi.',
                  style: TextStyle(
                    color: Color(0xFF5B6B86),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        if (showFloatingLocationButton)
          Positioned(
            right: 14,
            bottom: locationButtonBottom,
            child: SafeArea(
              top: false,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _centerOnCourierLocation,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFF163B73),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.14),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (showActiveRoute && popupOrder == null)
          Positioned(
            left: 14,
            right: 14,
            bottom: 18,
            child: SafeArea(
              top: false,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  _mapDeliveryPanelExpanded ? 16 : 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _deliveryStageLabel(_deliveryStage),
                            style: const TextStyle(
                              color: Color(0xFF163B73),
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _mapDeliveryPanelExpanded =
                                  !_mapDeliveryPanelExpanded;
                            });
                          },
                          icon: Icon(
                            _mapDeliveryPanelExpanded
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            color: const Color(0xFF163B73),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    if (_mapDeliveryPanelExpanded)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _poolPill(
                            Icons.navigation_outlined,
                            courierToStoreMeters == null
                                ? 'Konum bekleniyor'
                                : 'Mağaza: ${_formatDistance(courierToStoreMeters)}',
                          ),
                          if (!isExternalTask && storeToCustomerMeters != null)
                            _poolPill(
                              Icons.route_outlined,
                              'Müşteri: ${_formatDistance(storeToCustomerMeters)}',
                            ),
                        ],
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _poolPill(
                            Icons.navigation_outlined,
                            compactPrimaryDistanceLabel,
                          ),
                        ],
                      ),
                    if (_mapDeliveryPanelExpanded) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F9FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDDE6F4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Teslimat bilgisi',
                              style: TextStyle(
                                color: Color(0xFF5B6B86),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Mağaza',
                              style: TextStyle(
                                color: Color(0xFF5B6B86),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeDeliveryOrder!.storeAddress,
                              style: const TextStyle(
                                color: Color(0xFF163B73),
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _phoneLink(
                              activeDeliveryOrder.storePhone,
                              icon: Icons.phone_in_talk_outlined,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              activeDeliveryOrder.customerName,
                              style: const TextStyle(
                                color: Color(0xFF163B73),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeDeliveryOrder.customerAddress,
                              style: const TextStyle(
                                color: Color(0xFF5B6B86),
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _phoneLink(
                              activeDeliveryOrder.customerPhone,
                              icon: Icons.phone_in_talk_outlined,
                            ),
                          ],
                        ),
                      ),
                      if (courierToStoreMeters == null) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Konum alinamasa bile bu adres ve telefon bilgileriyle teslimata devam edebilirsiniz.',
                          style: TextStyle(
                            color: Color(0xFF5B6B86),
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        _deliveryStage == _DeliveryStage.headingToStore
                            ? (isExternalTask
                                  ? 'Canlı konumunuza göre mağazaya kalan mesafe gösteriliyor.'
                                  : 'Canlı konumunuza göre mağazaya kalan mesafe gösteriliyor. Mağazadan sonra müşteri rotası hazır.')
                            : _deliveryStage == _DeliveryStage.onTheWay
                            ? (isExternalTask
                                  ? 'Paket alındı. Teslim durumunu onaylayarak görevi tamamlayın.'
                                  : 'Paket alındı. Şimdi mağazadan müşteriye kalan mesafeyi takip ederek teslimata devam edin.')
                            : 'Teslimat tamamlandı.',
                        style: const TextStyle(
                          color: Color(0xFF163B73),
                          fontWeight: FontWeight.w800,
                          height: 1.45,
                        ),
                      ),
                      if (_locationStatus != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _routeLoading
                              ? 'Yol rotasi sokaklara gore hazirlaniyor...'
                              : _locationStatus!,
                          style: const TextStyle(
                            color: Color(0xFF5B6B86),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (_deliveryStage == _DeliveryStage.onTheWay)
                        Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: ElevatedButton(
                                onPressed: _completeDeliveryWithVerification,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: activeDeliveryOrder.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Teslim edildi',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 4,
                              child: OutlinedButton(
                                onPressed: _reportActiveDeliveryIssue,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF163B73),
                                  side: const BorderSide(
                                    color: Color(0xFF163B73),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Bildir',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_deliveryStage ==
                                  _DeliveryStage.headingToStore) {
                                _startCustomerRoute();
                                return;
                              }
                              _resetDeliveryFlow();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: activeDeliveryOrder.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _deliveryStage == _DeliveryStage.headingToStore
                                  ? (isExternalTask
                                        ? 'Paketi teslim aldım'
                                        : 'Paketi aldım, müşteriye gidiyorum')
                                  : 'Yeni görev havuzuna dön',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        compactStatusText,
                        style: const TextStyle(
                          color: Color(0xFF163B73),
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isExternalTask
                                  ? (activeDeliveryOrder?.storeName ?? 'Mağaza')
                                  : '${activeDeliveryOrder?.storeName ?? 'Mağaza'} → ${activeDeliveryOrder?.customerName ?? 'Müşteri'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF5B6B86),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: compactPrimaryAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  activeDeliveryOrder?.accent ?? activeAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              compactPrimaryActionLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMapPopupCard(int orderIndex, _OrderCardData order) {
    final layout = _layoutForIndex(orderIndex);
    final isExternalOrder = _isExternalOrder(order);
    final isActiveOrder = _isCurrentActiveOrder(orderIndex);
    final isAnotherOrderLocked = _hasActiveDelivery && !isActiveOrder;
    final isDelivered =
        isActiveOrder && _deliveryStage == _DeliveryStage.delivered;

    final String actionLabel;
    VoidCallback? onPrimaryAction;

    if (isAnotherOrderLocked) {
      actionLabel = 'Aktif teslimat var';
      onPrimaryAction = null;
    } else if (isActiveOrder &&
        _deliveryStage == _DeliveryStage.headingToStore) {
      actionLabel = isExternalOrder
          ? 'Paketi teslim aldım'
          : 'Paketi aldım, müşteriye gidiyorum';
      onPrimaryAction = () {
        _closeMapOrderPopup();
        _startCustomerRoute();
      };
    } else if (isActiveOrder && _deliveryStage == _DeliveryStage.onTheWay) {
      actionLabel = 'Teslim edildi';
      onPrimaryAction = () {
        _closeMapOrderPopup();
        _completeDeliveryWithVerification();
      };
    } else if (isDelivered) {
      actionLabel = 'Yeni göreve dön';
      onPrimaryAction = () {
        _closeMapOrderPopup();
        _resetDeliveryFlow();
      };
    } else {
      actionLabel = 'Paketi teslim al';
      onPrimaryAction = () {
        _closeMapOrderPopup();
        _pickupPackage(orderIndex);
      };
    }

    final normalizedStoreName = _normalizeMapPopupValue(
      order.storeName,
      fallback: 'Mağaza bilgisi yok',
    );
    final normalizedProduct = _normalizeMapPopupValue(
      order.title,
      fallback: 'Ürün bilgisi yok',
    );
    final normalizedStoreAddress = _normalizeMapPopupValue(
      order.storeAddress,
      fallback: 'Adres bilgisi yok',
    );
    final normalizedStorePhone = _normalizeMapPopupValue(
      order.storePhone,
      fallback: 'Telefon bilgisi yok',
    );
    final normalizedCustomerName = _normalizeMapPopupValue(
      order.customerName,
      fallback: 'Müşteri bilgisi yok',
    );
    final normalizedCustomerAddress = _normalizeMapPopupValue(
      order.customerAddress,
      fallback: 'Adres bilgisi yok',
    );
    final normalizedCustomerPhone = _normalizeMapPopupValue(
      order.customerPhone,
      fallback: 'Telefon bilgisi yok',
    );
    final routeValue = isExternalOrder ? 'Mağaza rotası' : order.route;

    if (!_mapPopupCardExpanded) {
      return InkWell(
        onTap: () {
          setState(() {
            _mapPopupCardExpanded = true;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: order.accent.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _mapPopupCardExpanded = true;
                    });
                  },
                  icon: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Color(0xFF5B6B86),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _popupSummaryChip('Mağaza', normalizedStoreName),
                  _popupSummaryChip('Ürün', normalizedProduct),
                  _popupSummaryChip('Fiyat', order.earning),
                  _popupSummaryChip('Süre', order.eta),
                  _popupSummaryChip('Rota', routeValue),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: order.accent.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: order.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.inventory_2_outlined, color: order.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.storeName,
                      style: const TextStyle(
                        color: Color(0xFF163B73),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      normalizedProduct,
                      style: const TextStyle(
                        color: Color(0xFF5B6B86),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _mapPopupCardExpanded = false;
                  });
                },
                icon: const Icon(Icons.close_rounded, color: Color(0xFF5B6B86)),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _earningInfoPill(order),
              _poolPill(Icons.schedule_outlined, order.eta),
              _poolPill(Icons.route_outlined, routeValue),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F9FF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDDE6F4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mağaza bilgileri',
                  style: TextStyle(
                    color: Color(0xFF5B6B86),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      color: order.accent,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            normalizedStoreName,
                            style: const TextStyle(
                              color: Color(0xFF163B73),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            normalizedStoreAddress,
                            style: const TextStyle(
                              color: Color(0xFF5B6B86),
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _phoneLink(
                            normalizedStorePhone,
                            icon: Icons.phone_in_talk_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: const Color(0xFFDDE6F4).withValues(alpha: 0.9),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Müşteri bilgileri',
                  style: TextStyle(
                    color: Color(0xFF5B6B86),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.person_pin_circle_outlined,
                      color: Color(0xFF163B73),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            normalizedCustomerName,
                            style: const TextStyle(
                              color: Color(0xFF163B73),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            normalizedCustomerAddress,
                            style: const TextStyle(
                              color: Color(0xFF5B6B86),
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _phoneLink(
                            normalizedCustomerPhone,
                            icon: Icons.phone_in_talk_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isExternalOrder
                ? 'Bu ayri sipariste haritada sadece magazaya gidis rotasi gosterilir.'
                : '${layout.zoneLabel} bolgesine teslim edilecek',
            style: const TextStyle(
              color: Color(0xFF5B6B86),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF163B73),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _centerOnCourierLocation,
                    icon: const Icon(Icons.my_location, color: Colors.white),
                    iconSize: 18,
                    tooltip: 'Konum',
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    _mobileMapController.move(
                      _storePointForIndex(orderIndex),
                      15,
                    );
                  },
                  child: const Text('Yaklastir'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPrimaryAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: onPrimaryAction == null
                    ? const Color(0xFFB7C4BD)
                    : order.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeMapPopupValue(String value, {required String fallback}) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized == '-') return fallback;
    return normalized;
  }

  Widget _popupSummaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F9FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDE6F4)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Color(0xFF5B6B86),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Color(0xFF163B73),
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _phoneLink(String phone, {required IconData icon}) {
    final canDial = phone.replaceAll(RegExp(r'[^0-9+]'), '').isNotEmpty;
    return InkWell(
      onTap: canDial ? () => _openPhoneDialer(phone) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: canDial
                  ? const Color(0xFF163B73)
                  : const Color(0xFF5B6B86),
            ),
            const SizedBox(width: 6),
            Text(
              phone,
              style: TextStyle(
                color: canDial
                    ? const Color(0xFF163B73)
                    : const Color(0xFF5B6B86),
                fontWeight: FontWeight.w800,
                decoration: canDial
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPhoneDialer(String phone) async {
    final sanitizedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (sanitizedPhone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: sanitizedPhone);
    await launchUrl(uri);
  }

  // ignore: unused_element
  Widget _buildMapCard(_OrderCardData selectedOrder, bool isMobile) {
    final selectedLayout = _layoutForIndex(_selectedOrderIndex);

    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Harita ve canlı kurye çağrıları',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF163B73),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2D8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  selectedOrder.label,
                  style: const TextStyle(
                    color: Color(0xFF8B5E00),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Kurye canlı konumunu, kurye isteyen mağazaları ve seçili teslim noktasını aynı haritada görür. Siparişler hem ana sayfadaki havuzdan hem bu harita ekranından seçilebilir.',
            style: TextStyle(color: Color(0xFF5B6B86), height: 1.5),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _poolPill(
                Icons.my_location_outlined,
                'Canlı kurye: ${selectedLayout.zoneLabel}',
              ),
              _poolPill(
                Icons.store_mall_directory_outlined,
                '${_orders.length} mağaza kurye istiyor',
              ),
              _poolPill(
                Icons.flash_on_outlined,
                '${selectedOrder.eta} içinde teslim hedefi',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: isMobile ? 420 : 390,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: const Color(0xFFE7F2EA),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildMapCanvas(
              selectedOrder,
              isMobile: isMobile,
              plainMode: false,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Haritadaki kurye çağrıları',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF163B73),
            ),
          ),
          const SizedBox(height: 10),
          if (isMobile)
            Column(
              children: List.generate(_orders.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _orders.length - 1 ? 0 : 10,
                  ),
                  child: _buildMapOrderSelector(index, true),
                );
              }),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                _orders.length,
                (index) => SizedBox(
                  width: 252,
                  child: _buildMapOrderSelector(index, false),
                ),
              ),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _addressCard(
                'Mağaza adresi',
                selectedOrder.storeAddress,
                selectedOrder.accent,
                Icons.storefront_outlined,
              ),
              _addressCard(
                'Müşteri adresi',
                selectedOrder.customerAddress,
                const Color(0xFF163B73),
                Icons.location_on_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapCanvas(
    _OrderCardData selectedOrder, {
    required bool isMobile,
    required bool plainMode,
  }) {
    final selectedLayout = _layoutForIndex(_selectedOrderIndex);

    return Stack(
      children: [
        const Positioned.fill(child: _MapBackdrop()),
        if (!plainMode)
          Align(
            alignment: const Alignment(-0.92, -0.88),
            child: _mapBubble(
              title: 'Canlı kurye',
              value: 'Baran Yılmaz • ${selectedLayout.zoneLabel}',
              color: const Color(0xFF163B73),
              icon: Icons.two_wheeler_outlined,
            ),
          ),
        if (!plainMode)
          Align(
            alignment: const Alignment(0.90, -0.86),
            child: _mapBubble(
              title: 'Kurye isteyen mağaza',
              value: selectedOrder.storeName,
              color: selectedOrder.accent,
              icon: Icons.notifications_active_outlined,
            ),
          ),
        for (var index = 0; index < _orders.length; index++)
          Align(
            alignment: _mapLayouts[index % _mapLayouts.length].storeAlignment,
            child: plainMode
                ? _MapStoreMarker(
                    color: _orders[index].accent,
                    isSelected: index == _selectedOrderIndex,
                    onTap: () {
                      setState(() {
                        _selectedOrderIndex = index;
                      });
                    },
                  )
                : _StoreDemandNode(
                    order: _orders[index],
                    info: _mapLayouts[index % _mapLayouts.length],
                    isSelected: index == _selectedOrderIndex,
                    onTap: () {
                      setState(() {
                        _selectedOrderIndex = index;
                      });
                    },
                  ),
          ),
        Align(
          alignment: selectedLayout.customerAlignment,
          child: _Pin(
            label: selectedOrder.customerName,
            color: const Color(0xFF163B73),
            icon: Icons.person_pin_circle_outlined,
            showLabel: !plainMode,
          ),
        ),
        Align(
          alignment: selectedLayout.courierAlignment,
          child: const _CourierPulse(),
        ),
        if (!plainMode)
          Align(
            alignment: const Alignment(0.88, 0.88),
            child: Container(
              constraints: BoxConstraints(maxWidth: isMobile ? 170 : 220),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Seçili teslimat',
                    style: TextStyle(
                      color: const Color(0xFF7B879C),
                      fontWeight: FontWeight.w700,
                      fontSize: isMobile ? 11 : 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedOrder.customerName,
                    style: const TextStyle(
                      color: Color(0xFF163B73),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    selectedOrder.route,
                    style: const TextStyle(
                      color: Color(0xFF5B6B86),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _earningBadge(_OrderCardData order, {required Color accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            order.earning,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _showEarningBreakdownSheet(order),
            borderRadius: BorderRadius.circular(999),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: accent.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }

  Widget _earningInfoPill(_OrderCardData order) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.payments_outlined,
            size: 16,
            color: Color(0xFF163B73),
          ),
          const SizedBox(width: 8),
          Text(
            order.earning,
            style: const TextStyle(
              color: Color(0xFF163B73),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _showEarningBreakdownSheet(order),
            borderRadius: BorderRadius.circular(999),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: Color(0xFF163B73),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEarningBreakdownSheet(_OrderCardData order) async {
    final breakdown = order.earningBreakdown;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kurye kazanç hesabı',
                style: TextStyle(
                  color: Color(0xFF163B73),
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                order.title,
                style: const TextStyle(
                  color: Color(0xFF5B6B86),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              _breakdownRow(
                'Taban ücret',
                _formatTryCurrency(breakdown.baseFee),
              ),
              _breakdownRow(
                'ETA',
                '${breakdown.etaMinutes.toStringAsFixed(1)} dk',
              ),
              _breakdownRow(
                'Dakika fiyatı',
                _formatTryCurrency(breakdown.minutePrice, withDecimals: true),
              ),
              _breakdownRow(
                'Mesafe ücreti (${breakdown.distanceKm.toStringAsFixed(1)} km)',
                _formatTryCurrency(breakdown.distanceFee, withDecimals: true),
              ),
              _breakdownRow(
                'Km birim fiyatı',
                _formatTryCurrency(breakdown.perKmFee, withDecimals: true),
              ),
              _breakdownRow(
                'Mesafe bazlı çekirdek',
                _formatTryCurrency(
                  breakdown.distanceBasedFee,
                  withDecimals: true,
                ),
              ),
              _breakdownRow(
                'ETA bazlı çekirdek',
                _formatTryCurrency(breakdown.etaBasedFee, withDecimals: true),
              ),
              _breakdownRow(
                'Gece bonusu',
                _formatTryCurrency(breakdown.nightBonus, withDecimals: true),
              ),
              _breakdownRow(
                'Yağmur bonusu',
                _formatTryCurrency(breakdown.rainBonus, withDecimals: true),
              ),
              _breakdownRow(
                'Uygulama komisyonu',
                _formatTryCurrency(breakdown.platformFee, withDecimals: true),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _breakdownRow(
                'Kurye kazancı',
                _formatTryCurrency(breakdown.total, withDecimals: true),
                emphasize: true,
              ),
              _breakdownRow(
                'Teslimat toplamı',
                _formatTryCurrency(breakdown.deliveryTotal, withDecimals: true),
                emphasize: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _breakdownRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFF5B6B86),
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: const Color(0xFF163B73),
              fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapOrderSelector(int index, bool isMobile) {
    final order = _orders[index];
    final layout = _mapLayouts[index % _mapLayouts.length];
    final isSelected = index == _selectedOrderIndex;
    final isActiveOrder = _isCurrentActiveOrder(index);
    final isAnotherOrderLocked = _hasActiveDelivery && !isActiveOrder;
    final isDelivered =
        isActiveOrder && _deliveryStage == _DeliveryStage.delivered;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedOrderIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF2F7FF) : const Color(0xFFF6F9FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? order.accent : const Color(0xFFDDE6F4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.storeName,
                    style: const TextStyle(
                      color: Color(0xFF163B73),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _earningBadge(order, accent: order.accent),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              layout.demandLabel,
              style: const TextStyle(
                color: Color(0xFF5B6B86),
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _poolPill(Icons.route_outlined, order.route),
                _poolPill(Icons.schedule_outlined, order.eta),
                _poolPill(Icons.place_outlined, layout.zoneLabel),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: isMobile ? double.infinity : null,
              child: ElevatedButton(
                onPressed: isAnotherOrderLocked
                    ? null
                    : () {
                        if (isDelivered) {
                          _resetDeliveryFlow();
                          return;
                        }
                        _pickupPackage(index);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected
                      ? order.accent
                      : const Color(0xFF163B73),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isAnotherOrderLocked
                      ? 'Aktif teslimat var'
                      : isDelivered
                      ? 'Yeni göreve dön'
                      : isActiveOrder
                      ? 'Paket teslim alındı'
                      : 'Paketi teslim al',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderPool(bool isMobile) {
    final isWebReadOnly = !isMobile;
    final emptyPoolText = _activeRegionKeys.isNotEmpty
        ? 'Seçili bölgede sipariş yok'
        : 'Henüz Sipariş Yok';

    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sipariş havuzu',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Color(0xFF163B73),
            ),
          ),
          const SizedBox(height: 14),
          if (_orders.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDDE6F4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emptyPoolText,
                    style: const TextStyle(
                      color: Color(0xFF5B6B86),
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ...List.generate(_orders.length, (index) {
            final order = _orders[index];
            final isSelected = index == _selectedOrderIndex;
            final isActiveOrder = _isCurrentActiveOrder(index);
            final isAnotherOrderLocked = _hasActiveDelivery && !isActiveOrder;
            final isDelivered =
                isActiveOrder && _deliveryStage == _DeliveryStage.delivered;

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _orders.length - 1 ? 0 : 12,
              ),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedOrderIndex = index;
                  });
                },
                borderRadius: BorderRadius.circular(22),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFF2F7FF)
                        : const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected
                          ? order.accent
                          : const Color(0xFFDDE6F4),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: order.accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: order.accent,
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: isMobile ? 260 : 220,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.title,
                                  style: const TextStyle(
                                    color: Color(0xFF163B73),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  order.storeName,
                                  style: const TextStyle(
                                    color: Color(0xFF5B6B86),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _earningBadge(order, accent: const Color(0xFF163B73)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _poolPill(Icons.route_outlined, order.route),
                          _poolPill(Icons.schedule_outlined, order.eta),
                          ...order.tags.map(
                            (tag) => _poolPill(Icons.circle, tag, dot: true),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isWebReadOnly
                              ? null
                              : isAnotherOrderLocked
                              ? null
                              : () {
                                  if (isDelivered) {
                                    _resetDeliveryFlow();
                                    return;
                                  }
                                  _pickupPackage(index);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isWebReadOnly
                                ? const Color(0xFFB7C4BD)
                                : isSelected
                                ? order.accent
                                : const Color(0xFF163B73),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            isWebReadOnly
                                ? 'Sadece görüntüleme'
                                : isAnotherOrderLocked
                                ? 'Aktif teslimat var'
                                : isDelivered
                                ? 'Yeni göreve dön'
                                : isActiveOrder
                                ? 'Paket teslim alındı'
                                : 'Paketi teslim al',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDeliveryControlCard(bool isMobile) {
    final activeOrder = _activeDeliveryOrder;
    if (activeOrder == null) return const SizedBox.shrink();
    final isExternalOrder = _isExternalOrder(activeOrder);
    final isReturnPickup = activeOrder.isReturnPickup;
    final activeIndex = _activeDeliveryOrderIndex!;
    final storePoint = _storePointForIndex(activeIndex);
    final customerPoint = _customerPointForIndex(activeIndex);
    final courierToStoreMeters = _courierToStoreDistanceMeters(storePoint);
    final storeToCustomerMeters = isExternalOrder
        ? null
        : _storeToCustomerDistanceMeters(storePoint, customerPoint);

    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Teslimat akışı',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Color(0xFF163B73),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  activeOrder.accent.withValues(alpha: 0.14),
                  activeOrder.accent.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _poolPill(
                      Icons.inventory_2_outlined,
                      _deliveryStageLabel(_deliveryStage),
                    ),
                    _poolPill(
                      isReturnPickup
                          ? Icons.person_pin_circle_outlined
                          : Icons.storefront_outlined,
                      courierToStoreMeters == null
                          ? '${activeOrder.storeName} • ${_locationStatus ?? 'konum bekleniyor'}'
                          : isReturnPickup
                          ? 'Müşteri ${_formatDistance(courierToStoreMeters)}'
                          : 'Mağaza ${_formatDistance(courierToStoreMeters)}',
                    ),
                    if (storeToCustomerMeters != null)
                      _poolPill(
                        isReturnPickup
                            ? Icons.storefront_outlined
                            : Icons.person_pin_circle_outlined,
                        isReturnPickup
                            ? 'Satıcı ${_formatDistance(storeToCustomerMeters)}'
                            : 'Müşteri ${_formatDistance(storeToCustomerMeters)}',
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _deliveryStage == _DeliveryStage.headingToStore
                      ? (isReturnPickup
                            ? 'Canlı konumunuza göre müşteriye kalan mesafe izleniyor. Müşteriden iade ürünü aldığınızda onaylayın.'
                            : 'Canlı konumunuza göre mağazaya kalan mesafe izleniyor. Mağazaya vardığınızda paketi aldığınızı onaylayın.')
                      : _deliveryStage == _DeliveryStage.onTheWay
                      ? (isReturnPickup
                            ? 'İade ürün araçta. Şimdi müşteriden satıcıya olan mesafeyi takip ederek teslimatı tamamlayın.'
                            : isExternalOrder
                            ? 'Paket alındı. Teslim durumunu onaylayarak görevi tamamlayın.'
                            : 'Paket araçta. Şimdi mağazadan müşteriye olan mesafeyi takip ederek teslimatı tamamlayın.')
                      : 'Teslimat tamamlandı. Yeni paket almak için havuza dönebilirsiniz.',
                  style: const TextStyle(
                    color: Color(0xFF163B73),
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                if (_locationStatus != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _locationStatus!,
                    style: const TextStyle(
                      color: Color(0xFF5B6B86),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (isMobile)
                  Column(children: _buildDeliveryActions(activeOrder, true))
                else
                  Row(children: _buildDeliveryActions(activeOrder, false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDeliveryActions(
    _OrderCardData activeOrder,
    bool isMobile,
  ) {
    final isExternalActiveOrder = _isExternalOrder(activeOrder);
    final isReturnPickup = activeOrder.isReturnPickup;
    final primaryButton = ElevatedButton(
      onPressed: () {
        if (_deliveryStage == _DeliveryStage.headingToStore) {
          _startCustomerRoute();
          return;
        }
        if (_deliveryStage == _DeliveryStage.onTheWay) {
          _completeDeliveryWithVerification();
          return;
        }
        _resetDeliveryFlow();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: activeOrder.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        _deliveryStage == _DeliveryStage.headingToStore
            ? (isReturnPickup
                  ? 'Ürünü aldım, satıcıya gidiyorum'
                  : isExternalActiveOrder
                  ? 'Paketi teslim aldım'
                  : 'Paketi aldım, müşteriye gidiyorum')
            : _deliveryStage == _DeliveryStage.onTheWay
            ? (isReturnPickup ? 'Satıcıya teslim edildi' : 'Teslim edildi')
            : 'Yeni görev al',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );

    final mapButton = OutlinedButton(
      onPressed: () {
        setState(() {
          _selectedTabIndex = 1;
        });
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: const Text(
        'Haritayı aç',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );

    if (isMobile) {
      return [
        SizedBox(width: double.infinity, child: primaryButton),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: mapButton),
      ];
    }

    return [
      Expanded(child: primaryButton),
      const SizedBox(width: 10),
      Expanded(child: mapButton),
    ];
  }

  Widget _buildAccountCard(bool isMobile) {
    const supportSetting = _AccountSetting(
      'Destek merkezi',
      'Canlı destek ekibine hızlı ulaş',
      Icons.support_agent_outlined,
    );
    final metrics = [
      _Metric(
        'Bugünkü kazanç',
        '₺842',
        'Bugün 3 teslimat',
        icon: Icons.wallet_outlined,
        accent: Color(0xFF1E88E5),
        onTap: _openEarningsPage,
      ),
      const _Metric(
        'Tamamlanan görev',
        '18',
        'Bugün teslim edildi',
        icon: Icons.inventory_2_outlined,
        accent: Color(0xFF3563E9),
      ),
      const _Metric(
        'Teslimat puanı',
        '4.9',
        'Son 30 görev',
        icon: Icons.star_outline_rounded,
        accent: Color(0xFFE17055),
      ),
      _Metric(
        'Aktif bölge',
        _activeRegionMetricValue(),
        _activeRegionMetricCaption(),
        icon: Icons.map_outlined,
        accent: Color(0xFF7A4DFF),
        onTap: _openActiveRegionsPage,
      ),
    ];

    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hesabım',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Color(0xFF163B73),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Profil ve teslimat özeti',
            style: TextStyle(
              color: Color(0xFF5B6B86),
              height: 1.4,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDCE7F7)),
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAccountProfileAvatar(),
                      const SizedBox(height: 12),
                      _buildAccountProfileDetails(),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAccountProfileAvatar(),
                      const SizedBox(width: 14),
                      Expanded(child: _buildAccountProfileDetails()),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _accountQuickPill(
                Icons.flash_on_outlined,
                _courierOnline ? 'Müsait' : 'Durduruldu',
                _courierOnline
                    ? const Color(0xFF1E88E5)
                    : const Color(0xFF6B7280),
              ),
              _accountQuickPill(
                Icons.star_outline,
                'Puan 4.9',
                const Color(0xFF163B73),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Günlük özet',
            style: TextStyle(
              color: Color(0xFF163B73),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: List.generate(metrics.length, (index) {
              final metric = metrics[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == metrics.length - 1 ? 0 : 10,
                ),
                child: _accountMetricCard(metric),
              );
            }),
          ),
          const SizedBox(height: 14),
          _accountSettingTile(supportSetting, onTap: _openSupportCenterSheet),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onExit,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Çıkış Yap',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountProfileAvatar() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF163B73), Color(0xFF2559A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF163B73).withValues(alpha: 0.14),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 28),
    );
  }

  Widget _buildAccountProfileDetails() {
    final profileName = _applicationData?.fullName.trim();
    final profileLocation = _applicationData?.locationLabel.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kurye Profili',
          style: TextStyle(
            color: Color(0xFF5B6B86),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            Text(
              profileName == null || profileName.isEmpty
                  ? 'Baran Yılmaz'
                  : profileName,
              style: const TextStyle(
                color: Color(0xFF163B73),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _openAccountSettingsPage,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF163B73),
                side: const BorderSide(color: Color(0xFFD2DED6)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                backgroundColor: Colors.white.withValues(alpha: 0.85),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text(
                'Profil Düzenle',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          profileLocation == null || profileLocation.isEmpty
              ? 'Tepebaşı / Eskişehir'
              : profileLocation,
          style: const TextStyle(
            color: Color(0xFF5B6B86),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _accountBadge(
              label: 'Kurye',
              icon: Icons.local_shipping_outlined,
              color: const Color(0xFF163B73),
            ),
            _accountBadge(
              label: _courierOnline ? 'Durdur' : 'İşe Başla',
              icon: _courierOnline
                  ? Icons.pause_circle_outline
                  : Icons.play_arrow_rounded,
              color: _courierOnline
                  ? const Color(0xFF1E88E5)
                  : const Color(0xFFE17055),
              onTap: _toggleWorkStatus,
            ),
          ],
        ),
      ],
    );
  }

  Widget _accountBadge({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountQuickPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDDE6F4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _accountMetricCard(_Metric metric) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            metric.accent.withValues(alpha: 0.12),
            metric.accent.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: metric.accent.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: metric.accent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(metric.icon, color: metric.accent, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        metric.title,
                        style: const TextStyle(
                          color: Color(0xFF5B6B86),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                metric.value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF163B73),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            metric.caption,
            style: const TextStyle(
              color: Color(0xFF7B879C),
              height: 1.35,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );

    if (metric.onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: metric.onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }

  Widget _accountSettingTile(_AccountSetting setting, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F9FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF163B73).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  setting.icon,
                  color: const Color(0xFF163B73),
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      setting.title,
                      style: const TextStyle(
                        color: Color(0xFF163B73),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      setting.caption,
                      style: const TextStyle(
                        color: Color(0xFF5B6B86),
                        height: 1.4,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF5B6B86)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mapBubble({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7B879C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF163B73),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressCard(
    String title,
    String address,
    Color color,
    IconData icon,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F9FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF7B879C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address,
                    style: const TextStyle(
                      color: Color(0xFF163B73),
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _poolPill(IconData icon, String text, {bool dot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot
              ? Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF163B73),
                    shape: BoxShape.circle,
                  ),
                )
              : Icon(icon, size: 16, color: const Color(0xFF163B73)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF163B73),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapBackdrop extends StatelessWidget {
  const _MapBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MapPainter(), child: const SizedBox.expand());
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFFC8D9CE)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final thinPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final routePaint = Paint()
      ..color = const Color(0xFF163B73)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final mainRoad = Path()
      ..moveTo(size.width * 0.08, size.height * 0.22)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.08,
        size.width * 0.56,
        size.height * 0.34,
      )
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.56,
        size.width * 0.92,
        size.height * 0.84,
      );

    final sideRoad = Path()
      ..moveTo(size.width * 0.12, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.58,
        size.width * 0.48,
        size.height * 0.48,
      )
      ..quadraticBezierTo(
        size.width * 0.68,
        size.height * 0.34,
        size.width * 0.86,
        size.height * 0.28,
      );

    canvas.drawPath(mainRoad, roadPaint);
    canvas.drawPath(sideRoad, roadPaint);
    canvas.drawPath(mainRoad, thinPaint);
    canvas.drawPath(sideRoad, thinPaint);

    final route = Path()
      ..moveTo(size.width * 0.24, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.38,
        size.width * 0.48,
        size.height * 0.46,
      )
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.58,
        size.width * 0.74,
        size.height * 0.66,
      );

    canvas.drawPath(route, routePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.label,
    required this.color,
    required this.icon,
    this.showLabel = true,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white),
        ),
        if (showLabel) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF163B73),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _MapStoreMarker extends StatelessWidget {
  const _MapStoreMarker({
    required this.color,
    required this.isSelected,
    this.showPackageBadge = true,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final bool showPackageBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: isSelected ? 62 : 54,
          height: isSelected ? 62 : 54,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Container(
                  width: isSelected ? 58 : 48,
                  height: isSelected ? 58 : 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.95),
                      width: isSelected ? 4 : 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.30),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.store_mall_directory_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              if (showPackageBadge)
                Positioned(
                  top: isSelected ? 1 : 2,
                  right: isSelected ? 0 : 1,
                  child: Container(
                    width: isSelected ? 22 : 20,
                    height: isSelected ? 22 : 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD24D),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.inventory_2_rounded,
                      size: 11,
                      color: Color(0xFF5E4300),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPinMarker extends StatelessWidget {
  const _MapPinMarker({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 26),
    );
  }
}

class _StoreDemandNode extends StatelessWidget {
  const _StoreDemandNode({
    required this.order,
    required this.info,
    required this.isSelected,
    required this.onTap,
  });

  final _OrderCardData order;
  final _MapNodeLayout info;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? order.accent : Colors.white,
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: order.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.store_mall_directory_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isSelected ? 'Seçili çağrı' : 'Kurye istiyor',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: order.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.storeName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF163B73),
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                info.demandLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF5B6B86),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourierPulse extends StatelessWidget {
  const _CourierPulse();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF60A5FA).withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFF60A5FA).withValues(alpha: 0.65),
              width: 1.8,
            ),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            color: Color(0xFF3B82F6),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

class _IhizAdminPricingPage extends StatefulWidget {
  const _IhizAdminPricingPage({
    required this.initialConfig,
    required this.onBack,
    required this.onConfigApplied,
  });

  final IhizPricingConfig initialConfig;
  final VoidCallback onBack;
  final ValueChanged<IhizPricingConfig> onConfigApplied;

  @override
  State<_IhizAdminPricingPage> createState() => _IhizAdminPricingPageState();
}

class _IhizAdminPricingPageState extends State<_IhizAdminPricingPage> {
  late IhizPricingConfig _config;
  final TextEditingController _versionNoteController = TextEditingController();
  bool _loadingHistory = false;
  bool _savingVersion = false;
  String? _storageWarning;
  List<_PricingRuleVersion> _history = const [];

  String _simOrderType = 'ibul_internal';
  double _simDistanceKm = 2.2;
  bool _simNight = false;
  bool _simRain = false;
  bool _simSurge = false;
  bool _simMultiOrder = false;
  bool _simForceFreeDelivery = false;
  String _simCancelStage = 'before_assign';

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _loadPricingVersionHistory();
  }

  @override
  void dispose() {
    _versionNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadPricingVersionHistory() async {
    setState(() {
      _loadingHistory = true;
      _storageWarning = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('ihiz_pricing_rule_versions')
          .select('version, config, active_from, is_active, created_at, note')
          .order('version', ascending: false)
          .limit(30);
      final mapped = List<Map<String, dynamic>>.from(rows as List)
          .map((row) {
            final configMap = Map<String, dynamic>.from(
              (row['config'] as Map?) ?? const <String, dynamic>{},
            );
            return _PricingRuleVersion(
              version: _toInt(row['version'], 0),
              activeFrom:
                  DateTime.tryParse(row['active_from']?.toString() ?? '') ??
                  DateTime.now(),
              isActive: row['is_active'] == true,
              createdAt:
                  DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                  DateTime.now(),
              note: row['note']?.toString() ?? '',
              config: IhizPricingConfig.fromJson(configMap),
            );
          })
          .toList(growable: false);
      if (mapped.isNotEmpty) {
        _config = mapped.first.config;
        widget.onConfigApplied(_config);
      }
      setState(() {
        _history = mapped;
      });
    } catch (error) {
      setState(() {
        _storageWarning =
            'Versiyon kaydi okunamadi. Önce SUPABASE_IHIZ_PRICING_ADMIN.sql scriptini calistirin. Hata: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingHistory = false;
        });
      }
    }
  }

  Future<void> _saveNewVersion() async {
    if (_savingVersion) return;
    setState(() {
      _savingVersion = true;
      _storageWarning = null;
    });
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      final nowIso = DateTime.now().toIso8601String();
      final rows = await client
          .from('ihiz_pricing_rule_versions')
          .select('version')
          .order('version', ascending: false)
          .limit(1);
      final currentVersion = rows.isNotEmpty
          ? _toInt((rows.first as Map)['version'], 0)
          : 0;
      final nextVersion = currentVersion + 1;

      await client
          .from('ihiz_pricing_rule_versions')
          .update({'is_active': false, 'active_to': nowIso})
          .eq('is_active', true);

      await client.from('ihiz_pricing_rule_versions').insert({
        'version': nextVersion,
        'config': _config.toJson(),
        'active_from': nowIso,
        'active_to': null,
        'is_active': true,
        'created_by': userId,
        'created_at': nowIso,
        'note': _versionNoteController.text.trim(),
      });

      widget.onConfigApplied(_config);
      _versionNoteController.clear();
      await _loadPricingVersionHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fiyat kurali v$nextVersion olarak kaydedildi.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _storageWarning =
            'Versiyon kaydi yazilamadi. Önce SUPABASE_IHIZ_PRICING_ADMIN.sql scriptini calistirin. Hata: $error';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kayit basarisiz: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _savingVersion = false;
        });
      }
    }
  }

  int _toInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _round2(double value) => (value * 100).round() / 100;

  String _try(double value, {bool decimal = false}) {
    final normalized = decimal
        ? _round2(value).toStringAsFixed(2)
        : value.round().toString();
    final parts = normalized.split('.');
    final integerPart = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    if (decimal && parts.length > 1) {
      return '₺$integerPart,${parts[1]}';
    }
    return '₺$integerPart';
  }

  double _internalCustomerContribution(double distanceKm) {
    if (_config.freeDeliveryCampaignEnabled || _simForceFreeDelivery) {
      return 0;
    }
    if (distanceKm <= 3) return _config.customerFee0To3Km;
    if (distanceKm <= 6) return _config.customerFee3To6Km;
    return _config.customerFee6PlusKm;
  }

  _PricingSimulatorResult _simulate() {
    final dynamicFactor = _config.dynamicPricingEnabled;
    var total = _config.baseFee + (_simDistanceKm * _config.perKmFee);
    if (dynamicFactor && _simNight) total += _config.nightBonus;
    if (dynamicFactor && _simRain) total += _config.rainBonus;
    if (dynamicFactor && _simSurge) total += _config.surgeBonus;
    if (dynamicFactor && _simMultiOrder && _config.multiOrderEnabled) {
      total += _config.multiOrderExtraFee;
    }
    total = total
        .clamp(_config.minDeliveryFee, _config.maxDeliveryFee)
        .toDouble();

    double customerFee = 0;
    double sellerFee = 0;
    if (_simOrderType == 'external') {
      final externalBase = (total + _config.externalServiceFee)
          .clamp(_config.externalMinFee, 999999)
          .toDouble();
      sellerFee = externalBase;
      customerFee = 0;
    } else {
      customerFee = _internalCustomerContribution(_simDistanceKm);
      if (_config.sellerContributionMode == 'fixed_50_percent') {
        sellerFee = total * 0.5;
        customerFee = total - sellerFee;
      } else {
        sellerFee = (total - customerFee).clamp(0, 999999).toDouble();
      }
    }

    var courierEarning =
        _config.courierBaseEarning +
        (_simDistanceKm * _config.courierPerKmEarning);
    if (_simNight) courierEarning += _config.courierNightBonus;
    if (_simRain) courierEarning += _config.courierRainBonus;
    if (_simSurge) courierEarning += _config.courierSurgeBonus;
    if (_simMultiOrder && _config.multiOrderEnabled) {
      courierEarning += _config.courierMultiOrderBonus;
    }

    final revenue = customerFee + sellerFee;
    final platformMargin = (revenue - courierEarning)
        .clamp(0, 999999)
        .toDouble();
    final reserveAmount = sellerFee;
    final refundPct = switch (_simCancelStage) {
      'before_assign' => _config.cancelBeforeAssignRefundPct,
      'after_assign' => _config.cancelAfterAssignRefundPct,
      'after_pickup' => _config.cancelAfterPickupRefundPct,
      _ => _config.cancelBeforeAssignRefundPct,
    };
    final refundAmount = reserveAmount * (refundPct / 100);
    final penaltyAmount = reserveAmount * (_config.cancelPenaltyPct / 100);

    return _PricingSimulatorResult(
      totalDeliveryFee: _round2(total),
      customerFee: _round2(customerFee),
      sellerFee: _round2(sellerFee),
      courierEarning: _round2(courierEarning),
      platformMargin: _round2(platformMargin),
      reserveAmount: _round2(reserveAmount),
      refundAmount: _round2(refundAmount),
      penaltyAmount: _round2(penaltyAmount),
      refundRate: _round2(refundPct),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sim = _simulate();
    final isMobile = MediaQuery.sizeOf(context).width < 950;
    final activeVersion = _history.cast<_PricingRuleVersion?>().firstWhere(
      (item) => item?.isActive == true,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Fiyatlandırma ve Hakediş Yönetimi',
          style: TextStyle(
            color: Color(0xFF163B73),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _loadingHistory ? null : _loadPricingVersionHistory,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Yenile'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFDDE6F4)),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _adminPill(
                          Icons.new_releases_outlined,
                          activeVersion == null
                              ? 'Aktif versiyon yok'
                              : 'Aktif sürüm: v${activeVersion.version}',
                        ),
                        _adminPill(
                          Icons.calendar_today_outlined,
                          activeVersion == null
                              ? 'Aktivasyon tarihi yok'
                              : 'Aktiflik: ${activeVersion.activeFrom.day.toString().padLeft(2, '0')}.${activeVersion.activeFrom.month.toString().padLeft(2, '0')}.${activeVersion.activeFrom.year}',
                        ),
                        _adminPill(
                          Icons.account_balance_wallet_outlined,
                          'Min wallet ${_try(_config.minWalletBalance)}',
                        ),
                      ],
                    ),
                  ),
                  if ((_storageWarning ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _adminWarningBox(_storageWarning!),
                  ],
                  const SizedBox(height: 14),
                  if (isMobile) ...[
                    _buildPricingEditor(sim),
                    const SizedBox(height: 14),
                    _buildVersionPanel(),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 8, child: _buildPricingEditor(sim)),
                        const SizedBox(width: 14),
                        Expanded(flex: 5, child: _buildVersionPanel()),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPricingEditor(_PricingSimulatorResult sim) {
    return Column(
      children: [
        _adminSectionCard(
          title: '1. Genel fiyat motoru ayarları',
          subtitle:
              'Taban, km, min/max ücret ve dinamik fiyat anahtarları burada yönetilir.',
          child: Column(
            children: [
              _adminSlider(
                title: 'Taban ücret',
                value: _config.baseFee,
                min: 0,
                max: 150,
                divisions: 150,
                label: _try(_config.baseFee),
                onChanged: (value) {
                  final normalized = _round2(value);
                  setState(() {
                    _config = _config.copyWith(
                      baseFee: normalized,
                      courierBaseEarning: normalized,
                    );
                  });
                },
              ),
              _adminSlider(
                title: 'Km başı ücret',
                value: _config.perKmFee,
                min: 0,
                max: 40,
                divisions: 400,
                label: _try(_config.perKmFee, decimal: true),
                onChanged: (value) {
                  final normalized = _round2(value);
                  setState(() {
                    _config = _config.copyWith(
                      perKmFee: normalized,
                      courierPerKmEarning: normalized,
                    );
                  });
                },
              ),
              _adminSlider(
                title: 'Minimum teslimat ücreti',
                value: _config.minDeliveryFee,
                min: 0,
                max: 300,
                divisions: 300,
                label: _try(_config.minDeliveryFee),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(minDeliveryFee: _round2(value));
                  });
                },
              ),
              _adminSlider(
                title: 'Maksimum teslimat ücreti',
                value: _config.maxDeliveryFee,
                min: 50,
                max: 800,
                divisions: 750,
                label: _try(_config.maxDeliveryFee),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(maxDeliveryFee: _round2(value));
                  });
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dinamik fiyat aktif'),
                value: _config.dynamicPricingEnabled,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(dynamicPricingEnabled: value);
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _adminSectionCard(
          title: '2. İBUL içi sipariş fiyat yönetimi',
          subtitle: 'Müşteri katkı kademeleri, satıcı katkı modu ve kampanya.',
          child: Column(
            children: [
              _adminSlider(
                title: '0-3 km müşteri katkısı',
                value: _config.customerFee0To3Km,
                min: 0,
                max: 200,
                divisions: 200,
                label: _try(_config.customerFee0To3Km),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      customerFee0To3Km: _round2(value),
                    );
                  });
                },
              ),
              _adminSlider(
                title: '3-6 km müşteri katkısı',
                value: _config.customerFee3To6Km,
                min: 0,
                max: 250,
                divisions: 250,
                label: _try(_config.customerFee3To6Km),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      customerFee3To6Km: _round2(value),
                    );
                  });
                },
              ),
              _adminSlider(
                title: '6+ km müşteri katkısı',
                value: _config.customerFee6PlusKm,
                min: 0,
                max: 350,
                divisions: 350,
                label: _try(_config.customerFee6PlusKm),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      customerFee6PlusKm: _round2(value),
                    );
                  });
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _config.sellerContributionMode,
                decoration: const InputDecoration(
                  labelText: 'Satıcı katkısı hesaplama modu',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'remaining_after_customer',
                    child: Text('Müşteri katkısı sonrası kalan tutar'),
                  ),
                  DropdownMenuItem(
                    value: 'fixed_50_percent',
                    child: Text('Sabit %50 satıcı katkısı'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _config = _config.copyWith(sellerContributionMode: value);
                  });
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ücretsiz teslimat kampanyası aktif'),
                value: _config.freeDeliveryCampaignEnabled,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      freeDeliveryCampaignEnabled: value,
                    );
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _adminSectionCard(
          title: '3. Dış sipariş fiyat yönetimi',
          subtitle:
              'Dış siparişte satıcı yansımaları, servis bedeli ve alt limit.',
          child: Column(
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dış siparişte tüm ücreti satıcı öder'),
                value: _config.externalSellerPaysAll,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(externalSellerPaysAll: value);
                  });
                },
              ),
              _adminSlider(
                title: 'Servis bedeli',
                value: _config.externalServiceFee,
                min: 0,
                max: 120,
                divisions: 120,
                label: _try(_config.externalServiceFee),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      externalServiceFee: _round2(value),
                    );
                  });
                },
              ),
              _adminSlider(
                title: 'Minimum dış sipariş ücreti',
                value: _config.externalMinFee,
                min: 0,
                max: 400,
                divisions: 400,
                label: _try(_config.externalMinFee),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(externalMinFee: _round2(value));
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _adminSectionCard(
          title: '4. Bonus yönetimi',
          subtitle:
              'Gece, yağmur, yoğunluk ve multi-order fiyat etkileri bu bölümde.',
          child: Column(
            children: [
              _adminSlider(
                title: 'Gece bonusu',
                value: _config.nightBonus,
                min: 0,
                max: 80,
                divisions: 80,
                label: _try(_config.nightBonus),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(nightBonus: _round2(value));
                  });
                },
              ),
              _adminSlider(
                title: 'Yağmur bonusu',
                value: _config.rainBonus,
                min: 0,
                max: 80,
                divisions: 80,
                label: _try(_config.rainBonus),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(rainBonus: _round2(value));
                  });
                },
              ),
              _adminSlider(
                title: 'Yoğunluk bonusu',
                value: _config.surgeBonus,
                min: 0,
                max: 100,
                divisions: 100,
                label: _try(_config.surgeBonus),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(surgeBonus: _round2(value));
                  });
                },
              ),
              _adminSlider(
                title: 'Yol üstü sipariş ek ücreti',
                value: _config.multiOrderExtraFee,
                min: 0,
                max: 120,
                divisions: 120,
                label: _try(_config.multiOrderExtraFee),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      multiOrderExtraFee: _round2(value),
                    );
                  });
                },
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Multi-order aktif'),
                value: _config.multiOrderEnabled,
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(multiOrderEnabled: value);
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _adminSectionCard(
          title: '5. Wallet kuralları',
          subtitle:
              'Minimum bakiye, reserve/capture/release akışı ve düşük bakiye alarmı.',
          child: Column(
            children: [
              _adminSlider(
                title: 'Minimum wallet bakiyesi',
                value: _config.minWalletBalance,
                min: 0,
                max: 5000,
                divisions: 500,
                label: _try(_config.minWalletBalance),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      minWalletBalance: _round2(value),
                    );
                  });
                },
              ),
              _adminSlider(
                title: 'Düşük bakiye uyarı seviyesi',
                value: _config.lowBalanceWarningLevel,
                min: 0,
                max: 5000,
                divisions: 500,
                label: _try(_config.lowBalanceWarningLevel),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      lowBalanceWarningLevel: _round2(value),
                    );
                  });
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _config.walletFlowMode,
                decoration: const InputDecoration(
                  labelText: 'Wallet akış modeli',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'reserve_capture_release',
                    child: Text('reserve → capture/release'),
                  ),
                  DropdownMenuItem(
                    value: 'direct_capture',
                    child: Text('direkt capture'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _config = _config.copyWith(walletFlowMode: value);
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _adminSectionCard(
          title: '6. İptal / iade kuralları',
          subtitle:
              'Sipariş aşamasına göre iade oranlarını ve kesinti yüzdesini yönetin.',
          child: Column(
            children: [
              _adminSlider(
                title: 'Kurye atanmadan iptal iade oranı',
                value: _config.cancelBeforeAssignRefundPct,
                min: 0,
                max: 100,
                divisions: 100,
                label: '%${_config.cancelBeforeAssignRefundPct.round()}',
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      cancelBeforeAssignRefundPct: _round2(value),
                    );
                  });
                },
              ),
              _adminSlider(
                title: 'Kurye atandıktan sonra iade oranı',
                value: _config.cancelAfterAssignRefundPct,
                min: 0,
                max: 100,
                divisions: 100,
                label: '%${_config.cancelAfterAssignRefundPct.round()}',
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      cancelAfterAssignRefundPct: _round2(value),
                    );
                  });
                },
              ),
              _adminSlider(
                title: 'Pickup sonrası iade oranı',
                value: _config.cancelAfterPickupRefundPct,
                min: 0,
                max: 100,
                divisions: 100,
                label: '%${_config.cancelAfterPickupRefundPct.round()}',
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      cancelAfterPickupRefundPct: _round2(value),
                    );
                  });
                },
              ),
              _adminSlider(
                title: 'İptal kesinti oranı',
                value: _config.cancelPenaltyPct,
                min: 0,
                max: 100,
                divisions: 100,
                label: '%${_config.cancelPenaltyPct.round()}',
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      cancelPenaltyPct: _round2(value),
                    );
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _adminSectionCard(
          title: '7. Kurye hakediş ayarları',
          subtitle:
              'Kurye taban/km kazancı, bonus kalemleri ve haftalık ödeme günü.',
          child: Column(
            children: [
              _adminSlider(
                title: 'Kurye taban kazanç',
                value: _config.courierBaseEarning,
                min: 0,
                max: 150,
                divisions: 150,
                label: _try(_config.courierBaseEarning),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      courierBaseEarning: _round2(value),
                    );
                  });
                },
              ),
              _adminSlider(
                title: 'Kurye km başı kazanç',
                value: _config.courierPerKmEarning,
                min: 0,
                max: 40,
                divisions: 400,
                label: _try(_config.courierPerKmEarning, decimal: true),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      courierPerKmEarning: _round2(value),
                    );
                  });
                },
              ),
              _adminSlider(
                title: 'Kurye gece bonusu',
                value: _config.courierNightBonus,
                min: 0,
                max: 80,
                divisions: 80,
                label: _try(_config.courierNightBonus),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      courierNightBonus: _round2(value),
                    );
                  });
                },
              ),
              _adminSlider(
                title: 'Kurye yağmur bonusu',
                value: _config.courierRainBonus,
                min: 0,
                max: 80,
                divisions: 80,
                label: _try(_config.courierRainBonus),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      courierRainBonus: _round2(value),
                    );
                  });
                },
              ),
              _adminSlider(
                title: 'Kurye yoğunluk bonusu',
                value: _config.courierSurgeBonus,
                min: 0,
                max: 100,
                divisions: 100,
                label: _try(_config.courierSurgeBonus),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      courierSurgeBonus: _round2(value),
                    );
                  });
                },
              ),
              _adminSlider(
                title: 'Kurye multi-order bonusu',
                value: _config.courierMultiOrderBonus,
                min: 0,
                max: 120,
                divisions: 120,
                label: _try(_config.courierMultiOrderBonus),
                onChanged: (value) {
                  setState(() {
                    _config = _config.copyWith(
                      courierMultiOrderBonus: _round2(value),
                    );
                  });
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _config.weeklyPayoutDay,
                decoration: const InputDecoration(
                  labelText: 'Haftalık ödeme günü',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Pazartesi',
                    child: Text('Pazartesi'),
                  ),
                  DropdownMenuItem(value: 'Salı', child: Text('Salı')),
                  DropdownMenuItem(value: 'Çarşamba', child: Text('Çarşamba')),
                  DropdownMenuItem(value: 'Perşembe', child: Text('Perşembe')),
                  DropdownMenuItem(value: 'Cuma', child: Text('Cuma')),
                  DropdownMenuItem(
                    value: 'Cumartesi',
                    child: Text('Cumartesi'),
                  ),
                  DropdownMenuItem(value: 'Pazar', child: Text('Pazar')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _config = _config.copyWith(weeklyPayoutDay: value);
                  });
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _adminSectionCard(
          title: '8. Hesaplama simülatörü',
          subtitle:
              'Sipariş tipi ve koşulları değiştirerek tutar dağılımını anlık test edin.',
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _simOrderType,
                decoration: const InputDecoration(labelText: 'Sipariş tipi'),
                items: const [
                  DropdownMenuItem(
                    value: 'ibul_internal',
                    child: Text('İBUL iç sipariş'),
                  ),
                  DropdownMenuItem(
                    value: 'external_manual',
                    child: Text('Dış sipariş'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _simOrderType = value;
                  });
                },
              ),
              _adminSlider(
                title: 'Mesafe',
                value: _simDistanceKm,
                min: 0.3,
                max: 25,
                divisions: 247,
                label: '${_simDistanceKm.toStringAsFixed(1)} km',
                onChanged: (value) {
                  setState(() {
                    _simDistanceKm = _round2(value);
                  });
                },
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _toggleChip(
                    label: 'Gece',
                    selected: _simNight,
                    onTap: () => setState(() => _simNight = !_simNight),
                  ),
                  _toggleChip(
                    label: 'Yağmur',
                    selected: _simRain,
                    onTap: () => setState(() => _simRain = !_simRain),
                  ),
                  _toggleChip(
                    label: 'Yoğunluk',
                    selected: _simSurge,
                    onTap: () => setState(() => _simSurge = !_simSurge),
                  ),
                  _toggleChip(
                    label: 'Multi-order',
                    selected: _simMultiOrder,
                    onTap: () =>
                        setState(() => _simMultiOrder = !_simMultiOrder),
                  ),
                  _toggleChip(
                    label: 'Ücretsiz teslimat',
                    selected: _simForceFreeDelivery,
                    onTap: () => setState(
                      () => _simForceFreeDelivery = !_simForceFreeDelivery,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _simCancelStage,
                decoration: const InputDecoration(labelText: 'İptal aşaması'),
                items: const [
                  DropdownMenuItem(
                    value: 'before_assign',
                    child: Text('Kurye atanmadan iptal'),
                  ),
                  DropdownMenuItem(
                    value: 'after_assign',
                    child: Text('Kurye atandıktan sonra iptal'),
                  ),
                  DropdownMenuItem(
                    value: 'after_pickup',
                    child: Text('Pickup sonrası iptal'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _simCancelStage = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F9FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDDE6F4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _simRow(
                      'Toplam teslimat ücreti',
                      _try(sim.totalDeliveryFee),
                    ),
                    _simRow('Müşteriden alınacak tutar', _try(sim.customerFee)),
                    _simRow('Satıcıdan alınacak tutar', _try(sim.sellerFee)),
                    _simRow('Kurye hakedişi', _try(sim.courierEarning)),
                    _simRow('Platform marjı', _try(sim.platformMargin)),
                    _simRow('Reserve wallet tutarı', _try(sim.reserveAmount)),
                    _simRow(
                      'İade tutarı (${sim.refundRate.toStringAsFixed(0)}%)',
                      _try(sim.refundAmount),
                    ),
                    _simRow('Kesinti tutarı', _try(sim.penaltyAmount)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionPanel() {
    return Column(
      children: [
        _adminSectionCard(
          title: 'Versiyon kaydı',
          subtitle:
              'Yeni kural seti kaydettiğinizde tarih/sürüm logu oluşturulur ve aktif sürüm işaretlenir.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _versionNoteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Versiyon notu',
                  hintText: 'Örn: Ramazan dönemi gece bonusu güncellemesi',
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _savingVersion ? null : _saveNewVersion,
                  icon: _savingVersion
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _savingVersion
                        ? 'Kaydediliyor...'
                        : 'Aktif kuralı yeni versiyon olarak kaydet',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_loadingHistory)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              if (_history.isEmpty && !_loadingHistory)
                const Text(
                  'Henüz versiyon kaydı yok.',
                  style: TextStyle(
                    color: Color(0xFF5B6B86),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ..._history.take(12).map((item) {
                final date =
                    '${item.activeFrom.day.toString().padLeft(2, '0')}.${item.activeFrom.month.toString().padLeft(2, '0')}.${item.activeFrom.year}';
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.isActive
                        ? const Color(0xFFE8F0FF)
                        : const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: item.isActive
                          ? const Color(0xFF3563E9)
                          : const Color(0xFFDDE6F4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'v${item.version} • $date',
                              style: const TextStyle(
                                color: Color(0xFF163B73),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (item.note.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.note,
                                style: const TextStyle(
                                  color: Color(0xFF5B6B86),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (item.isActive)
                        const Chip(
                          label: Text('Aktif'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _adminSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE6F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF163B73),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF5B6B86),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _adminSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF163B73),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF163B73),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _simRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5B6B86),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF163B73),
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF163B73) : const Color(0xFFF1F5FF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF163B73),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _adminPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F9FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF163B73)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF163B73),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminWarningBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF991B1B),
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

class _PricingSimulatorResult {
  const _PricingSimulatorResult({
    required this.totalDeliveryFee,
    required this.customerFee,
    required this.sellerFee,
    required this.courierEarning,
    required this.platformMargin,
    required this.reserveAmount,
    required this.refundAmount,
    required this.penaltyAmount,
    required this.refundRate,
  });

  final double totalDeliveryFee;
  final double customerFee;
  final double sellerFee;
  final double courierEarning;
  final double platformMargin;
  final double reserveAmount;
  final double refundAmount;
  final double penaltyAmount;
  final double refundRate;
}

class _AccountSettingsPage extends StatefulWidget {
  const _AccountSettingsPage({
    this.applicationData,
    required this.initialPushEnabled,
    required this.initialSoundEnabled,
    required this.initialNightModeEnabled,
    required this.initialFaceIdEnabled,
  });

  final CourierApplicationData? applicationData;
  final bool initialPushEnabled;
  final bool initialSoundEnabled;
  final bool initialNightModeEnabled;
  final bool initialFaceIdEnabled;

  @override
  State<_AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsResult {
  const _AccountSettingsResult({
    required this.applicationData,
    required this.pushEnabled,
    required this.soundEnabled,
    required this.nightModeEnabled,
    required this.faceIdEnabled,
  });

  final CourierApplicationData applicationData;
  final bool pushEnabled;
  final bool soundEnabled;
  final bool nightModeEnabled;
  final bool faceIdEnabled;
}

class _AccountSettingsPageState extends State<_AccountSettingsPage> {
  bool _pushEnabled = true;
  bool _soundEnabled = true;
  bool _nightMode = false;
  bool _faceIdEnabled = true;
  bool _isSaving = false;
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _tcController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _cityController;
  late final TextEditingController _districtController;
  late final TextEditingController _availabilityController;
  late final TextEditingController _emailController;
  late final TextEditingController _noteController;
  late final TextEditingController _paymentAccountHolderController;
  late final TextEditingController _paymentBankNameController;
  late final TextEditingController _paymentIbanController;
  String? _licenseType;
  String? _motorType;
  String? _criminalRecord;
  String? _companyType;

  static const List<String> _licenseOptions = ['A1', 'A2', 'B', 'Diğer'];
  static const List<String> _motorOptions = [
    '110 CC ve üzeri',
    '50 CC',
    'Motorum yok',
  ];
  static const List<String> _criminalRecordOptions = ['Var', 'Yok'];
  static const List<String> _companyOptions = [
    'Şahıs Şirketi',
    'Limited Şirket',
    'Şirketim yok',
  ];

  String _safeValue(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String _initialValue(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String? _normalizeOption(String? value, List<String> options) {
    if (value == null) return null;
    final trimmed = value.trim();
    return options.contains(trimmed) ? trimmed : null;
  }

  @override
  void initState() {
    super.initState();
    final application = widget.applicationData;
    _fullNameController = TextEditingController(
      text: _initialValue(application?.fullName, 'Baran Yılmaz'),
    );
    _phoneController = TextEditingController(
      text: _initialValue(application?.phone, '05xx xxx xx xx'),
    );
    _tcController = TextEditingController(
      text: _initialValue(application?.tcNumber, ''),
    );
    _birthDateController = TextEditingController(
      text: _initialValue(application?.birthDate, ''),
    );
    _cityController = TextEditingController(
      text: _initialValue(application?.city, 'Eskişehir'),
    );
    _districtController = TextEditingController(
      text: _initialValue(application?.district, 'Tepebaşı'),
    );
    _availabilityController = TextEditingController(
      text: _initialValue(
        application?.availability,
        'Tam zamanlı / Yarı zamanlı',
      ),
    );
    _emailController = TextEditingController(
      text: _initialValue(application?.email, 'ornek@ihiz.com'),
    );
    _noteController = TextEditingController(
      text: _initialValue(application?.note, ''),
    );
    _paymentAccountHolderController = TextEditingController(
      text: _initialValue(application?.paymentAccountHolder, ''),
    );
    _paymentBankNameController = TextEditingController(
      text: _initialValue(application?.paymentBankName, ''),
    );
    _paymentIbanController = TextEditingController(
      text: _initialValue(application?.paymentIban, ''),
    );
    _licenseType = _normalizeOption(application?.licenseType, _licenseOptions);
    _motorType = _normalizeOption(application?.motorType, _motorOptions);
    _criminalRecord = _normalizeOption(
      application?.criminalRecord,
      _criminalRecordOptions,
    );
    _companyType = _normalizeOption(application?.companyType, _companyOptions);
    _pushEnabled =
        application?.pushNotificationsEnabled ?? widget.initialPushEnabled;
    _soundEnabled =
        application?.soundAlertsEnabled ?? widget.initialSoundEnabled;
    _nightMode =
        application?.nightModeEnabled ?? widget.initialNightModeEnabled;
    _faceIdEnabled = application?.faceIdEnabled ?? widget.initialFaceIdEnabled;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _tcController.dispose();
    _birthDateController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _availabilityController.dispose();
    _emailController.dispose();
    _noteController.dispose();
    _paymentAccountHolderController.dispose();
    _paymentBankNameController.dispose();
    _paymentIbanController.dispose();
    super.dispose();
  }

  CourierApplicationData _updatedApplicationData() {
    final base =
        widget.applicationData ??
        const CourierApplicationData(
          fullName: 'Baran Yılmaz',
          phone: '05xx xxx xx xx',
          tcNumber: '',
          birthDate: '',
          licenseType: '',
          motorType: '',
          criminalRecord: '',
          companyType: '',
          city: 'Eskişehir',
          district: 'Tepebaşı',
          availability: 'Tam zamanlı / Yarı zamanlı',
          email: 'ornek@ihiz.com',
          note: '',
        );

    return base.copyWith(
      fullName: _safeValue(_fullNameController.text, base.fullName),
      phone: _safeValue(_phoneController.text, base.phone),
      tcNumber: _safeValue(_tcController.text, base.tcNumber),
      birthDate: _safeValue(_birthDateController.text, base.birthDate),
      licenseType: _safeValue(_licenseType, base.licenseType),
      motorType: _safeValue(_motorType, base.motorType),
      criminalRecord: _safeValue(_criminalRecord, base.criminalRecord),
      companyType: _safeValue(_companyType, base.companyType),
      city: _safeValue(_cityController.text, base.city),
      district: _safeValue(_districtController.text, base.district),
      availability: _safeValue(_availabilityController.text, base.availability),
      email: _safeValue(_emailController.text, base.email),
      note: _safeValue(_noteController.text, base.note),
      pushNotificationsEnabled: _pushEnabled,
      soundAlertsEnabled: _soundEnabled,
      nightModeEnabled: _nightMode,
      faceIdEnabled: _faceIdEnabled,
      paymentAccountHolder: _safeValue(
        _paymentAccountHolderController.text,
        base.paymentAccountHolder,
      ),
      paymentBankName: _safeValue(
        _paymentBankNameController.text,
        base.paymentBankName,
      ),
      paymentIban: _safeValue(_paymentIbanController.text, base.paymentIban),
    );
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    final updatedData = _updatedApplicationData();
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;
    final nowIso = DateTime.now().toIso8601String();

    try {
      if (currentUser != null) {
        await client
            .from('ihiz_courier_applications')
            .update({
              'full_name': updatedData.fullName,
              'phone': updatedData.phone,
              'tc_number': updatedData.tcNumber,
              'birth_date': updatedData.birthDate,
              'license_type': updatedData.licenseType,
              'motor_type': updatedData.motorType,
              'criminal_record': updatedData.criminalRecord,
              'company_type': updatedData.companyType,
              'city': updatedData.city,
              'district': updatedData.district,
              'availability': updatedData.availability,
              'email': updatedData.email,
              'note': updatedData.note,
              'push_notifications_enabled':
                  updatedData.pushNotificationsEnabled,
              'sound_alerts_enabled': updatedData.soundAlertsEnabled,
              'night_mode_enabled': updatedData.nightModeEnabled,
              'face_id_enabled': updatedData.faceIdEnabled,
              'payment_account_holder': updatedData.paymentAccountHolder,
              'payment_bank_name': updatedData.paymentBankName,
              'payment_iban': updatedData.paymentIban,
              'updated_at': nowIso,
            })
            .eq('user_id', currentUser.id);

        try {
          await client
              .from('users')
              .update({
                'display_name': updatedData.fullName,
                'phone': updatedData.phone,
                'updated_at': nowIso,
              })
              .eq('id', currentUser.id);
        } catch (_) {
          // users tablosu yetki/policy farkı profil kaydını bloklamasın.
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(
        _AccountSettingsResult(
          applicationData: updatedData,
          pushEnabled: _pushEnabled,
          soundEnabled: _soundEnabled,
          nightModeEnabled: _nightMode,
          faceIdEnabled: _faceIdEnabled,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ayarlar kaydedilemedi: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _normalizeIban(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  }

  String _formatIbanForView(String value) {
    final normalized = _normalizeIban(value);
    if (normalized.isEmpty) return 'TR•• •••• •••• •••• •••• •••• ••';
    final chunks = <String>[];
    for (var i = 0; i < normalized.length; i += 4) {
      chunks.add(normalized.substring(i, (i + 4).clamp(0, normalized.length)));
    }
    return chunks.join(' ');
  }

  String _maskedIbanForView(String value) {
    final normalized = _normalizeIban(value);
    if (normalized.length < 8) return 'TR•• •••• •••• •••• •••• •••• ••';
    final start = normalized.substring(0, 4);
    final end = normalized.substring(normalized.length - 2);
    return _formatIbanForView('$start${'•' * (normalized.length - 6)}$end');
  }

  Future<void> _openIbanEditor() async {
    final accountHolderController = TextEditingController(
      text: _paymentAccountHolderController.text.trim(),
    );
    final bankNameController = TextEditingController(
      text: _paymentBankNameController.text.trim(),
    );
    final ibanController = TextEditingController(
      text: _formatIbanForView(_paymentIbanController.text.trim()),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'IBAN Düzenle',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF163B73),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ödemelerin doğru hesaba yatması için bilgileri kontrol edin.',
                style: TextStyle(color: Color(0xFF5B6B86), height: 1.4),
              ),
              const SizedBox(height: 14),
              _ApplyField(
                label: 'Hesap Sahibi',
                hint: 'Ad Soyad',
                controller: accountHolderController,
              ),
              const SizedBox(height: 10),
              _ApplyField(
                label: 'Banka Adı',
                hint: 'Örn: Ziraat Bankası',
                controller: bankNameController,
              ),
              const SizedBox(height: 10),
              _ApplyField(
                label: 'IBAN',
                hint: 'TR00 0000 0000 0000 0000 0000 00',
                controller: ibanController,
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Vazgeç'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () {
                      final accountHolder = accountHolderController.text.trim();
                      final bankName = bankNameController.text.trim();
                      final iban = _normalizeIban(ibanController.text.trim());
                      final isIbanValid = RegExp(
                        r'^TR[0-9]{24}$',
                      ).hasMatch(iban);
                      if (accountHolder.isEmpty ||
                          bankName.isEmpty ||
                          !isIbanValid) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Hesap sahibi, banka adı ve geçerli TR IBAN zorunlu.',
                            ),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _paymentAccountHolderController.text = accountHolder;
                        _paymentBankNameController.text = bankName;
                        _paymentIbanController.text = iban;
                      });
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'IBAN güncellendi. Kalıcı kayıt için Kaydet butonuna basın.',
                          ),
                        ),
                      );
                    },
                    child: const Text('IBAN Bilgilerini Güncelle'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    accountHolderController.dispose();
    bankNameController.dispose();
    ibanController.dispose();
  }

  Future<void> _openPaymentReceipts() async {
    final receipts = <Map<String, String>>[
      {
        'title': 'Haftalık Ödeme',
        'amount': '₺2.840',
        'date': '03 Mar 2026',
        'status': 'Hesaba Geçti',
      },
      {
        'title': 'Haftalık Ödeme',
        'amount': '₺2.515',
        'date': '24 Şub 2026',
        'status': 'Hesaba Geçti',
      },
      {
        'title': 'Bonus + Teslim Primi',
        'amount': '₺460',
        'date': '19 Şub 2026',
        'status': 'Hesaba Geçti',
      },
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kazanç Dekontları',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF163B73),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Son ödemeleriniz ve dekont kayıtları',
                    style: TextStyle(color: Color(0xFF5B6B86)),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          color: Color(0xFF163B73),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Bu ay toplam ödeme: ₺5.355',
                          style: TextStyle(
                            color: Color(0xFF163B73),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      itemCount: receipts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final receipt = receipts[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFF),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFDDE6F4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF163B73,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.receipt_long_outlined,
                                  color: Color(0xFF163B73),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      receipt['title'] ?? '-',
                                      style: const TextStyle(
                                        color: Color(0xFF163B73),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      receipt['date'] ?? '-',
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    receipt['amount'] ?? '-',
                                    style: const TextStyle(
                                      color: Color(0xFF0F766E),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    receipt['status'] ?? '-',
                                    style: const TextStyle(
                                      color: Color(0xFF059669),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openLiveSupport() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Canlı Destek',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF163B73),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Operasyon ekibine bağlan, teslimat sorunlarını hızlıca ilet.',
                style: TextStyle(color: Color(0xFF5B6B86), height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.support_agent_outlined,
                      color: Color(0xFF163B73),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Destek sırası: Yaklaşık 2 dk',
                        style: TextStyle(
                          color: Color(0xFF163B73),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SupportQuickChip(
                    label: 'Teslimat gecikmesi',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Teslimat gecikmesi konusu destek talebine eklendi.',
                          ),
                        ),
                      );
                    },
                  ),
                  _SupportQuickChip(
                    label: 'Adres sorunu',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Adres sorunu konusu destek talebine eklendi.',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text('Destek hattı: 0850 123 44 44'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.call_outlined),
                      label: const Text('Destek Hattını Ara'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Canlı sohbet açıldı (demo tasarım).',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Canlı Sohbet'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F7FD),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Hesap Ayarları',
          style: TextStyle(
            color: Color(0xFF163B73),
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: Text(
              _isSaving ? 'Kaydediliyor...' : 'Kaydet',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF163B73), Color(0xFF2559A6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kurye hesabını buradan yönet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Profil bilgileri, bildirimler, güvenlik ve ödeme ayarları tek ekranda tutulur.',
                          style: TextStyle(color: Colors.white70, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _settingsSection(
                    title: 'Profil Düzenle',
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 760;
                        final fieldWidth = isNarrow
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 12) / 2;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: fieldWidth,
                                  child: _ApplyField(
                                    label: 'Ad Soyad',
                                    hint: 'Ad Soyad',
                                    controller: _fullNameController,
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: _ApplyField(
                                    label: 'Telefon',
                                    hint: 'Telefon',
                                    controller: _phoneController,
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: _ApplyField(
                                    label: 'TC Kimlik Numarası',
                                    hint: '11 haneli kimlik numarası',
                                    controller: _tcController,
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: _ApplyField(
                                    label: 'Doğum Tarihi',
                                    hint: 'GG / AA / YYYY',
                                    controller: _birthDateController,
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: _ApplySelectField(
                                    label: 'Ehliyet Türü',
                                    hint: 'Ehliyet türü seçin',
                                    value: _licenseType,
                                    items: _licenseOptions,
                                    onChanged: (value) {
                                      setState(() {
                                        _licenseType = value;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: _ApplySelectField(
                                    label: 'Motorsiklet Türü',
                                    hint: 'Motor türü seçin',
                                    value: _motorType,
                                    items: _motorOptions,
                                    onChanged: (value) {
                                      setState(() {
                                        _motorType = value;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: _ApplySelectField(
                                    label: 'Adli Sicil Kaydı',
                                    hint: 'Durum seçin',
                                    value: _criminalRecord,
                                    items: _criminalRecordOptions,
                                    onChanged: (value) {
                                      setState(() {
                                        _criminalRecord = value;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: _ApplySelectField(
                                    label: 'Şirket Türü',
                                    hint: 'Şirket türü seçin',
                                    value: _companyType,
                                    items: _companyOptions,
                                    onChanged: (value) {
                                      setState(() {
                                        _companyType = value;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: _ApplyField(
                                    label: 'İl',
                                    hint: 'İl',
                                    controller: _cityController,
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: _ApplyField(
                                    label: 'İlçe',
                                    hint: 'İlçe',
                                    controller: _districtController,
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: _ApplyField(
                                    label: 'Müsaitlik',
                                    hint: 'Müsaitlik',
                                    controller: _availabilityController,
                                  ),
                                ),
                                SizedBox(
                                  width: fieldWidth,
                                  child: _ApplyField(
                                    label: 'E-posta',
                                    hint: 'E-posta',
                                    controller: _emailController,
                                  ),
                                ),
                                SizedBox(
                                  width: constraints.maxWidth,
                                  child: _ApplyField(
                                    label: 'Kısa Not',
                                    hint: 'Başvuru notu',
                                    controller: _noteController,
                                    maxLines: 3,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerRight,
                              child: _ApplyPrimaryButton(
                                label: _isSaving
                                    ? 'Kaydediliyor...'
                                    : 'Profili Kaydet',
                                onPressed: _isSaving ? null : _saveProfile,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  _settingsSection(
                    title: 'Bildirimler',
                    child: Column(
                      children: [
                        _SettingsSwitchTile(
                          icon: Icons.notifications_active_outlined,
                          title: 'Anlık görev bildirimleri',
                          caption: 'Yeni sipariş havuzu düştüğünde uyar.',
                          value: _pushEnabled,
                          onChanged: (value) {
                            setState(() {
                              _pushEnabled = value;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        _SettingsSwitchTile(
                          icon: Icons.volume_up_outlined,
                          title: 'Sesli uyarılar',
                          caption: 'Görev ve teslim adımlarında ses çal.',
                          value: _soundEnabled,
                          onChanged: (value) {
                            setState(() {
                              _soundEnabled = value;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        _SettingsSwitchTile(
                          icon: Icons.dark_mode_outlined,
                          title: 'Gece modu düzeni',
                          caption:
                              'Gece sürüşlerinde daha düşük parlaklık teması.',
                          value: _nightMode,
                          onChanged: (value) {
                            setState(() {
                              _nightMode = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _settingsSection(
                    title: 'Güvenlik',
                    child: Column(
                      children: [
                        _SettingsSwitchTile(
                          icon: Icons.lock_outline,
                          title: 'Face ID / biyometrik giriş',
                          caption: 'Kurye paneline hızlı ve güvenli giriş yap.',
                          value: _faceIdEnabled,
                          onChanged: (value) {
                            setState(() {
                              _faceIdEnabled = value;
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        const _SettingsActionTile(
                          icon: Icons.password_outlined,
                          title: 'Şifreyi güncelle',
                          caption:
                              'Hesap şifresini yenile ve güvenliği arttır.',
                        ),
                        const SizedBox(height: 10),
                        const _SettingsActionTile(
                          icon: Icons.history_toggle_off_outlined,
                          title: 'Oturum geçmişi',
                          caption: 'Açık cihazları ve son girişleri görüntüle.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _settingsSection(
                    title: 'Ödeme ve destek',
                    child: Column(
                      children: [
                        _SettingsInfoTile(
                          icon: Icons.account_balance_outlined,
                          title: 'IBAN',
                          value: _maskedIbanForView(
                            _paymentIbanController.text,
                          ),
                          onTap: _openIbanEditor,
                        ),
                        const SizedBox(height: 10),
                        _SettingsActionTile(
                          icon: Icons.receipt_long_outlined,
                          title: 'Kazanç dekontları',
                          caption: 'Haftalık ve aylık ödeme dökümlerini aç.',
                          onTap: _openPaymentReceipts,
                        ),
                        const SizedBox(height: 10),
                        _SettingsActionTile(
                          icon: Icons.support_agent_outlined,
                          title: 'Canlı destek',
                          caption: 'Operasyon ekibiyle hızlı bağlantı kur.',
                          onTap: _openLiveSupport,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_nightMode)
              IgnorePointer(
                child: Container(
                  color: const Color(0xFF020617).withValues(alpha: 0.24),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _settingsSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDE6F4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF163B73),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF163B73),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _IhizInput extends StatelessWidget {
  const _IhizInput({
    required this.hint,
    this.obscure = false,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
  });

  final String hint;
  final bool obscure;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF6F9FF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _ApplyField extends StatelessWidget {
  const _ApplyField({
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
    this.obscureText = false,
    this.hasError = false,
    this.errorText,
    this.onChanged,
  });

  final String label;
  final String hint;
  final int maxLines;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool readOnly;
  final GestureTapCallback? onTap;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool hasError;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          buildCounter: maxLength == null
              ? null
              : (
                  context, {
                  required currentLength,
                  required isFocused,
                  required maxLength,
                }) => null,
          readOnly: readOnly,
          onTap: onTap,
          onChanged: onChanged,
          obscureText: obscureText,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF6F9FF),
            suffixIcon: suffixIcon,
            errorText: hasError ? errorText : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFD2DBEA),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFD2DBEA),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF163B73),
                width: 1.2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ApplySelectField extends StatelessWidget {
  const _ApplySelectField({
    required this.label,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.value,
    this.hasError = false,
    this.errorText,
  });

  final String label;
  final String hint;
  final List<String> items;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool hasError;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          onChanged: onChanged,
          hint: Text(hint, style: const TextStyle(color: Color(0xFF7B879C))),
          items: items
              .map(
                (item) =>
                    DropdownMenuItem<String>(value: item, child: Text(item)),
              )
              .toList(),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF6F9FF),
            errorText: hasError ? errorText : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFD2DBEA),
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFDC2626)
                    : const Color(0xFFD2DBEA),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF163B73),
                width: 1.2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.2,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ApplyProgressHeader extends StatelessWidget {
  const _ApplyProgressHeader({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const titles = ['Kimlik', 'Sürücü', 'Bölge', 'Belgeler', 'Ödeme'];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(titles.length, (index) {
        final stepNo = index + 1;
        final isActive = currentStep == index;
        final isDone = currentStep > index;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDone
                ? const Color(0xFFEAF3FF)
                : isActive
                ? const Color(0xFF163B73)
                : const Color(0xFFF1F5FE),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF163B73)
                  : const Color(0xFFDDE6F4),
            ),
          ),
          child: Text(
            '$stepNo. ${titles[index]}',
            style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFF163B73),
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      }),
    );
  }
}

class _ApplyStepCard extends StatelessWidget {
  const _ApplyStepCard({
    required this.step,
    required this.title,
    required this.description,
    required this.child,
    required this.actions,
    this.hasError = false,
  });

  final String step;
  final String title;
  final String description;
  final Widget child;
  final List<Widget> actions;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: hasError ? const Color(0xFFFFF7F7) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: hasError ? const Color(0xFFDC2626) : const Color(0xFFDDE6F4),
          width: hasError ? 1.3 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step,
            style: const TextStyle(
              color: Color(0xFF5B6B86),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF163B73),
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF5B6B86), height: 1.55),
          ),
          if (hasError) ...[
            const SizedBox(height: 10),
            const Text(
              'Zorunlu alanları doldurun.',
              style: TextStyle(
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ),
    );
  }
}

class _ApplyCompletedCard extends StatelessWidget {
  const _ApplyCompletedCard({
    required this.step,
    required this.title,
    required this.summary,
  });

  final String step;
  final String title;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCCE0FC)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF163B73),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$step • $title',
                  style: const TextStyle(
                    color: Color(0xFF163B73),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(summary, style: const TextStyle(color: Color(0xFF5B6B86))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyPrimaryButton extends StatelessWidget {
  const _ApplyPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF163B73),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _ApplySecondaryButton extends StatelessWidget {
  const _ApplySecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Text(label),
    );
  }
}

class _ApplyStatusChip extends StatelessWidget {
  const _ApplyStatusChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5FE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDE6F4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF163B73),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SuccessLine extends StatelessWidget {
  const _SuccessLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: const BoxDecoration(
            color: Color(0xFF163B73),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF5B6B86), height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _ApplyDriverLicenseUploadField extends StatelessWidget {
  const _ApplyDriverLicenseUploadField({
    required this.label,
    required this.caption,
    required this.onPickFront,
    required this.onPickBack,
    required this.onClearFront,
    required this.onClearBack,
    this.frontDocument,
    this.backDocument,
    this.isPickingFront = false,
    this.isPickingBack = false,
    this.hasError = false,
    this.errorText,
  });

  final String label;
  final String caption;
  final VoidCallback onPickFront;
  final VoidCallback onPickBack;
  final VoidCallback onClearFront;
  final VoidCallback onClearBack;
  final _ApplyPickedDocument? frontDocument;
  final _ApplyPickedDocument? backDocument;
  final bool isPickingFront;
  final bool isPickingBack;
  final bool hasError;
  final String? errorText;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  Widget _buildFaceLine({
    required String title,
    required _ApplyPickedDocument? document,
    required bool isPicking,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final isUploaded = document != null;
    final subtitle = isUploaded
        ? '${document.name} • ${_formatFileSize(document.sizeBytes)}'
        : 'Henüz yüklenmedi';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUploaded ? const Color(0xFF8CB7F0) : const Color(0xFFDDE6F4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF163B73),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF5B6B86), height: 1.4),
          ),
          const SizedBox(height: 8),
          if (isPicking)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(isUploaded ? 'Değiştir' : title),
                ),
                if (isUploaded)
                  TextButton(onPressed: onClear, child: const Text('Kaldır')),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyDocument = frontDocument != null || backDocument != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F9FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFDC2626)
                  : hasAnyDocument
                  ? const Color(0xFF8CB7F0)
                  : const Color(0xFFDDE6F4),
              width: hasError ? 1.3 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.upload_file_outlined,
                    color: Color(0xFF163B73),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Belge yükleme alanı',
                          style: TextStyle(
                            color: Color(0xFF163B73),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          caption,
                          style: const TextStyle(
                            color: Color(0xFF5B6B86),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFaceLine(
                title: 'Ön Yüz',
                document: frontDocument,
                isPicking: isPickingFront,
                onPick: onPickFront,
                onClear: onClearFront,
              ),
              const SizedBox(height: 10),
              _buildFaceLine(
                title: 'Arka Yüz',
                document: backDocument,
                isPicking: isPickingBack,
                onPick: onPickBack,
                onClear: onClearBack,
              ),
              if (hasError && errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ApplyUploadField extends StatelessWidget {
  const _ApplyUploadField({
    required this.label,
    required this.caption,
    required this.onPick,
    required this.onClear,
    this.document,
    this.isPicking = false,
    this.hasError = false,
    this.errorText,
  });

  final String label;
  final String caption;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final _ApplyPickedDocument? document;
  final bool isPicking;
  final bool hasError;
  final String? errorText;

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final hasDocument = document != null;
    final statusTitle = hasDocument ? 'Belge yüklendi' : 'Belge yükleme alanı';
    final statusDescription = hasDocument
        ? '${document!.name} • ${_formatFileSize(document!.sizeBytes)}'
        : caption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        const SizedBox(height: 8),
        InkWell(
          onTap: isPicking ? null : onPick,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F9FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasError
                    ? const Color(0xFFDC2626)
                    : hasDocument
                    ? const Color(0xFF8CB7F0)
                    : const Color(0xFFDDE6F4),
                width: hasError ? 1.3 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasDocument
                      ? Icons.check_circle_outline
                      : Icons.upload_file_outlined,
                  color: const Color(0xFF163B73),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: const TextStyle(
                          color: Color(0xFF163B73),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusDescription,
                        style: const TextStyle(
                          color: Color(0xFF5B6B86),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (isPicking)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (hasDocument)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: onPick,
                              icon: const Icon(Icons.upload_file_outlined),
                              label: const Text('Değiştir'),
                            ),
                            TextButton(
                              onPressed: onClear,
                              child: const Text('Kaldır'),
                            ),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: onPick,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Dosya Seç'),
                        ),
                      if (hasError && errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorText!,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsInfoTile extends StatelessWidget {
  const _SettingsInfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F9FF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF163B73).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF163B73)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF5B6B86),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF163B73),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.edit_outlined, color: Color(0xFF5B6B86)),
          ],
        ),
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.caption,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F9FF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF163B73).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF163B73)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF163B73),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    caption,
                    style: const TextStyle(
                      color: Color(0xFF5B6B86),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF5B6B86)),
          ],
        ),
      ),
    );
  }
}

class _SupportQuickChip extends StatelessWidget {
  const _SupportQuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.caption,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String caption;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F9FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF163B73).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF163B73)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF163B73),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: const TextStyle(color: Color(0xFF5B6B86), height: 1.4),
                ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _CourierEarningsPage extends StatefulWidget {
  const _CourierEarningsPage({required this.dailyEarnings});

  final List<_CourierDailyEarning> dailyEarnings;

  @override
  State<_CourierEarningsPage> createState() => _CourierEarningsPageState();
}

class _CourierEarningsPageState extends State<_CourierEarningsPage> {
  _EarningsRange _selectedRange = _EarningsRange.weekly;
  bool _requestingPayout = false;
  late DateTime _visibleMonth;

  static const List<String> _weekdayShortNames = <String>[
    'Pzt',
    'Sal',
    'Çar',
    'Per',
    'Cum',
    'Cmt',
    'Paz',
  ];

  static const List<String> _monthNames = <String>[
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  List<_CourierDailyEarning> get _sortedEarnings {
    final copied = List<_CourierDailyEarning>.from(widget.dailyEarnings);
    copied.sort((a, b) => b.date.compareTo(a.date));
    return copied;
  }

  DateTime get _minMonth {
    if (_sortedEarnings.isEmpty) return _visibleMonth;
    final oldest = _sortedEarnings.last.date;
    return DateTime(oldest.year, oldest.month);
  }

  DateTime get _maxMonth {
    if (_sortedEarnings.isEmpty) return _visibleMonth;
    final newest = _sortedEarnings.first.date;
    return DateTime(newest.year, newest.month);
  }

  int _monthKey(DateTime date) => date.year * 12 + date.month;

  bool get _canGoPreviousMonth =>
      _monthKey(_visibleMonth) > _monthKey(_minMonth);

  bool get _canGoNextMonth => _monthKey(_visibleMonth) < _monthKey(_maxMonth);

  int get _periodDays => _selectedRange == _EarningsRange.weekly ? 7 : 30;

  double _monthlyTotalFor(DateTime month) {
    return _sortedEarnings
        .where(
          (entry) =>
              entry.date.year == month.year && entry.date.month == month.month,
        )
        .fold<double>(0, (sum, entry) => sum + entry.amount);
  }

  double get _periodTotal {
    if (_selectedRange == _EarningsRange.monthly) {
      return _monthlyTotalFor(_visibleMonth);
    }
    final today = DateTime.now();
    return _sortedEarnings
        .where((entry) {
          final day = DateTime(
            entry.date.year,
            entry.date.month,
            entry.date.day,
          );
          return today.difference(day).inDays < _periodDays;
        })
        .fold<double>(0, (sum, entry) => sum + entry.amount);
  }

  Map<int, double> _monthlyDayAmounts(DateTime month) {
    final values = <int, double>{};
    for (final entry in _sortedEarnings) {
      if (entry.date.year != month.year || entry.date.month != month.month) {
        continue;
      }
      final day = entry.date.day;
      values[day] = (values[day] ?? 0) + entry.amount;
    }
    return values;
  }

  String _monthLabel(DateTime month) {
    return '${_monthNames[month.month - 1]} ${month.year}';
  }

  String _formatCurrency(double amount) {
    final normalized = amount.round().toString();
    final withDots = normalized.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return '₺$withDots';
  }

  String _formatCalendarCellAmount(double amount) {
    if (amount <= 0) return '₺0';
    if (amount >= 1000) {
      final compact = amount >= 10000
          ? (amount / 1000).toStringAsFixed(0)
          : (amount / 1000).toStringAsFixed(1);
      final normalized = compact.endsWith('.0')
          ? compact.substring(0, compact.length - 2)
          : compact;
      return '₺${normalized}K';
    }
    return _formatCurrency(amount);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String _weekdayLabel(DateTime date) {
    return _weekdayShortNames[date.weekday - 1];
  }

  void _changeMonth(int delta) {
    final nextMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    if (delta < 0 && !_canGoPreviousMonth) return;
    if (delta > 0 && !_canGoNextMonth) return;
    setState(() {
      _visibleMonth = nextMonth;
    });
  }

  Widget _buildWeeklyList(List<_CourierDailyEarning> shownEarnings) {
    return ListView.separated(
      itemCount: shownEarnings.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = shownEarnings[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE4ECF8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatDate(entry.date)} • ${_weekdayLabel(entry.date)}',
                      style: const TextStyle(
                        color: Color(0xFF163B73),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${entry.completedDeliveries} teslimat',
                      style: const TextStyle(
                        color: Color(0xFF5B6B86),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatCurrency(entry.amount),
                style: const TextStyle(
                  color: Color(0xFF163B73),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthlyCalendar() {
    final dayAmounts = _monthlyDayAmounts(_visibleMonth);
    final firstDayOfMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      1,
    );
    final leadingEmptyDays = firstDayOfMonth.weekday - 1;
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final totalSlots = leadingEmptyDays + daysInMonth;
    final trailingEmptyDays = (7 - (totalSlots % 7)) % 7;
    final itemCount = totalSlots + trailingEmptyDays;

    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: _weekdayShortNames
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              childAspectRatio: 0.86,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmptyDays ||
                  index >= leadingEmptyDays + daysInMonth) {
                return const SizedBox.shrink();
              }
              final dayNumber = index - leadingEmptyDays + 1;
              final amount = dayAmounts[dayNumber] ?? 0;
              final hasEarning = amount > 0;

              return Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 5),
                decoration: BoxDecoration(
                  color: hasEarning ? const Color(0xFFEFF5FF) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasEarning
                        ? const Color(0xFFBFD6FA)
                        : const Color(0xFFE4ECF8),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dayNumber',
                      style: const TextStyle(
                        color: Color(0xFF5B6B86),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      hasEarning ? _formatCalendarCellAmount(amount) : '₺0',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasEarning
                            ? const Color(0xFF163B73)
                            : const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _requestEarningPayout() async {
    if (_requestingPayout) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kazanç talebi için önce giriş yapmalısınız.'),
        ),
      );
      return;
    }

    setState(() {
      _requestingPayout = true;
    });

    final nowIso = DateTime.now().toIso8601String();
    final periodText = _selectedRange == _EarningsRange.weekly
        ? 'Haftalık'
        : 'Aylık';
    final totalText = _formatCurrency(_periodTotal);

    try {
      await Supabase.instance.client.from('support_tickets').insert({
        'user_id': user.id,
        'user_type': 'user',
        'category': 'Kurye / Ödeme',
        'subject': '[KURYE] Kazanç talebi',
        'description':
            '$periodText dönem için kazanç talebi oluşturuldu. Tahmini tutar: $totalText.',
        'status': 'open',
        'priority': 'high',
        'created_at': nowIso,
        'updated_at': nowIso,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kazanç talebin alındı: $totalText')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kazanç talebi gönderilemedi: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _requestingPayout = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rangeLabel = _selectedRange == _EarningsRange.weekly
        ? 'Haftalık toplam'
        : 'Aylık toplam';
    final shownEarnings = _sortedEarnings.take(30).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kazançlar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDDE6F4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Haftalık'),
                          selected: _selectedRange == _EarningsRange.weekly,
                          onSelected: (_) {
                            setState(() {
                              _selectedRange = _EarningsRange.weekly;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Aylık'),
                          selected: _selectedRange == _EarningsRange.monthly,
                          onSelected: (_) {
                            setState(() {
                              _selectedRange = _EarningsRange.monthly;
                            });
                          },
                        ),
                      ],
                    ),
                    if (_selectedRange == _EarningsRange.monthly) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _canGoPreviousMonth
                                ? () => _changeMonth(-1)
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded),
                            visualDensity: VisualDensity.compact,
                          ),
                          Expanded(
                            child: Text(
                              _monthLabel(_visibleMonth),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF163B73),
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _canGoNextMonth
                                ? () => _changeMonth(1)
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      rangeLabel,
                      style: const TextStyle(
                        color: Color(0xFF5B6B86),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCurrency(_periodTotal),
                      style: const TextStyle(
                        color: Color(0xFF163B73),
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _selectedRange == _EarningsRange.weekly
                    ? 'Günlük kazançlar'
                    : 'Aylık takvim',
                style: const TextStyle(
                  color: Color(0xFF163B73),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _selectedRange == _EarningsRange.weekly
                    ? _buildWeeklyList(shownEarnings)
                    : _buildMonthlyCalendar(),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _requestingPayout ? null : _requestEarningPayout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF163B73),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _requestingPayout
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(
                    _requestingPayout
                        ? 'Talep Gönderiliyor...'
                        : 'Kazanç Talep Et',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveRegionOption {
  const _ActiveRegionOption({
    required this.key,
    required this.district,
    required this.city,
    required this.point,
    this.boundaryRings = const <List<LatLng>>[],
  });

  final String key;
  final String district;
  final String city;
  final LatLng point;
  final List<List<LatLng>> boundaryRings;

  String get label => '$district / $city';

  _ActiveRegionOption copyWith({
    String? key,
    String? district,
    String? city,
    LatLng? point,
    List<List<LatLng>>? boundaryRings,
  }) {
    return _ActiveRegionOption(
      key: key ?? this.key,
      district: district ?? this.district,
      city: city ?? this.city,
      point: point ?? this.point,
      boundaryRings: boundaryRings ?? this.boundaryRings,
    );
  }
}

class _ActiveRegionSelectionResult {
  const _ActiveRegionSelectionResult({
    required this.selectedKeys,
    required this.allOptions,
  });

  final Set<String> selectedKeys;
  final List<_ActiveRegionOption> allOptions;

  _ActiveRegionOption? get primarySelection {
    if (selectedKeys.isEmpty) return null;
    for (final option in allOptions) {
      if (selectedKeys.contains(option.key)) return option;
    }
    return null;
  }
}

class _ActiveRegionsPage extends StatefulWidget {
  const _ActiveRegionsPage({
    required this.options,
    required this.initialSelectedKeys,
  });

  final List<_ActiveRegionOption> options;
  final Set<String> initialSelectedKeys;

  @override
  State<_ActiveRegionsPage> createState() => _ActiveRegionsPageState();
}

class _ActiveRegionsPageState extends State<_ActiveRegionsPage> {
  final MapController _mapController = MapController();
  late final TextEditingController _searchController;
  late final Map<String, _ActiveRegionOption> _optionsByKey;
  final Set<String> _boundaryLoadingKeys = <String>{};
  late Set<String> _selectedKeys;
  String? _focusedRegionKey;
  bool _searching = false;
  String? _searchInfo;

  List<_ActiveRegionOption> get _allOptions {
    final values = _optionsByKey.values.toList(growable: false)
      ..sort((a, b) => a.label.compareTo(b.label));
    return values;
  }

  List<_ActiveRegionOption> get _selectedOptions {
    return _allOptions
        .where((option) => _selectedKeys.contains(option.key))
        .toList(growable: false);
  }

  List<_ActiveRegionOption> get _markerOptions {
    final markers = <_ActiveRegionOption>[..._selectedOptions];
    final focused = _focusedOption;
    if (focused != null &&
        markers.every((option) => option.key != focused.key)) {
      markers.add(focused);
    }
    return markers;
  }

  _ActiveRegionOption? get _focusedOption {
    final all = _allOptions;
    if (_focusedRegionKey != null) {
      for (final option in all) {
        if (option.key == _focusedRegionKey) return option;
      }
    }
    for (final option in all) {
      if (_selectedKeys.contains(option.key)) return option;
    }
    return null;
  }

  String _normalizeText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _districtPartForKey(String value) {
    var normalized = _normalizeText(value);
    for (final separator in const ['/', ',', '|', '\\']) {
      if (normalized.contains(separator)) {
        normalized = normalized.split(separator).first.trim();
      }
    }
    return _normalizeText(normalized);
  }

  String _keyForDistrict(String district) {
    final districtPart = _districtPartForKey(district);
    return _normalizeMatchKey(districtPart);
  }

  String _titleCaseWords(String value) {
    final normalized = _normalizeText(value);
    if (normalized.isEmpty) return normalized;
    return normalized
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.length == 1
              ? part.toUpperCase()
              : '${part.substring(0, 1).toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String _fallbackCityForManualEntry() {
    final focused = _focusedOption;
    if (focused != null && focused.city.trim().isNotEmpty) {
      return focused.city.trim();
    }
    final selected = _selectedOptions;
    if (selected.isNotEmpty && selected.first.city.trim().isNotEmpty) {
      return selected.first.city.trim();
    }
    return 'Türkiye';
  }

  LatLng _fallbackPointForManualEntry(String district) {
    final normalizedDistrict = _normalizeMatchKey(district);
    if (normalizedDistrict.contains('arsuz')) {
      return const LatLng(36.4157, 35.8908);
    }
    if (normalizedDistrict.contains('antakya')) {
      return const LatLng(36.2021, 36.1606);
    }
    if (normalizedDistrict.contains('iskenderun')) {
      return const LatLng(36.5872, 36.1735);
    }
    if (normalizedDistrict.contains('defne')) {
      return const LatLng(36.1800, 36.1180);
    }
    final focused = _focusedOption;
    if (focused != null) {
      return focused.point;
    }
    final selected = _selectedOptions;
    if (selected.isNotEmpty) {
      return selected.first.point;
    }
    return const LatLng(39.0, 35.0);
  }

  bool _addManualDistrictFromQuery(String query) {
    final normalizedQuery = _normalizeText(query);
    if (normalizedQuery.length < 2) return false;
    final district = _titleCaseWords(normalizedQuery);
    final city = _fallbackCityForManualEntry();
    final option = _ActiveRegionOption(
      key: _keyForDistrict(district),
      district: district,
      city: city,
      point: _fallbackPointForManualEntry(district),
    );
    if (!mounted) return false;
    setState(() {
      _optionsByKey[option.key] = option;
      _selectedKeys.add(option.key);
      _focusedRegionKey = option.key;
      _searchInfo =
          '${option.label} eklendi (yaklaşık konum). Bağlantı düzelince sınır çizimi otomatik güncellenecek.';
    });
    _focusMapOnOption(option);
    unawaited(_ensureBoundaryForOption(option));
    return true;
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  String _normalizeMatchKey(String value) {
    return _normalizeText(value)
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u');
  }

  Map<String, dynamic> _addressFromRow(Map<String, dynamic> row) {
    final raw = row['address'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return <String, dynamic>{};
  }

  String _districtFromRow(Map<String, dynamic> row, {String fallback = ''}) {
    final address = _addressFromRow(row);
    return _normalizeText(
      _firstNonEmpty([
        (address['town'] ?? '').toString(),
        (address['county'] ?? '').toString(),
        (address['state_district'] ?? '').toString(),
        (address['district'] ?? '').toString(),
        (row['name'] ?? '').toString(),
        fallback,
      ]),
    );
  }

  String _cityFromRow(Map<String, dynamic> row, {String fallback = 'Türkiye'}) {
    final address = _addressFromRow(row);
    return _normalizeText(
      _firstNonEmpty([
        (address['city'] ?? '').toString(),
        (address['province'] ?? '').toString(),
        (address['state'] ?? '').toString(),
        fallback,
      ]),
    );
  }

  bool _rowHasPolygonBoundary(Map<String, dynamic> row) {
    final rawGeoJson = row['geojson'];
    if (rawGeoJson is! Map) return false;
    final geoJson = Map<String, dynamic>.from(rawGeoJson);
    final type = (geoJson['type'] ?? '').toString();
    return type == 'Polygon' || type == 'MultiPolygon';
  }

  Map<String, dynamic>? _pickBestNominatimRow(
    List rows, {
    required String districtHint,
    String cityHint = '',
  }) {
    final candidates = rows
        .whereType<Map>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .toList(growable: false);
    if (candidates.isEmpty) return null;

    final districtNeedle = _normalizeMatchKey(districtHint);
    final cityNeedle = _normalizeMatchKey(cityHint);
    var bestScore = -1;
    Map<String, dynamic> best = candidates.first;

    for (final row in candidates) {
      final district = _normalizeMatchKey(_districtFromRow(row));
      final city = _normalizeMatchKey(_cityFromRow(row));
      var score = 0;

      if (_rowHasPolygonBoundary(row)) score += 100;
      final category = (row['category'] ?? '').toString().toLowerCase();
      final type = (row['type'] ?? '').toString().toLowerCase();
      final osmType = (row['osm_type'] ?? '').toString().toLowerCase();
      if (category == 'boundary' || type == 'administrative') score += 30;
      if (osmType == 'relation') score += 14;

      if (districtNeedle.isNotEmpty) {
        if (district == districtNeedle) {
          score += 45;
        } else if (district.contains(districtNeedle) ||
            districtNeedle.contains(district)) {
          score += 20;
        }
      }

      if (cityNeedle.isNotEmpty) {
        if (city == cityNeedle) {
          score += 24;
        } else if (city.contains(cityNeedle) || cityNeedle.contains(city)) {
          score += 10;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        best = row;
      }
    }

    return best;
  }

  List<LatLng> _parseRingPoints(dynamic rawRing) {
    if (rawRing is! List) return const <LatLng>[];
    final points = <LatLng>[];
    for (final rawPoint in rawRing) {
      if (rawPoint is! List || rawPoint.length < 2) continue;
      final lon = double.tryParse(rawPoint[0].toString());
      final lat = double.tryParse(rawPoint[1].toString());
      if (lat == null || lon == null) continue;
      points.add(LatLng(lat, lon));
    }
    if (points.length < 3) return const <LatLng>[];
    return points;
  }

  List<List<LatLng>> _parseBoundaryFromGeoJson(dynamic rawGeoJson) {
    if (rawGeoJson is! Map) return const <List<LatLng>>[];
    final geoJson = Map<String, dynamic>.from(rawGeoJson);
    final type = (geoJson['type'] ?? '').toString();
    final coordinates = geoJson['coordinates'];
    final polygons = <List<LatLng>>[];

    if (type == 'Polygon' && coordinates is List) {
      final outerRing = coordinates.isNotEmpty ? coordinates.first : null;
      final parsed = _parseRingPoints(outerRing);
      if (parsed.isNotEmpty) polygons.add(parsed);
      return polygons;
    }

    if (type == 'MultiPolygon' && coordinates is List) {
      for (final rawPolygon in coordinates) {
        if (rawPolygon is! List || rawPolygon.isEmpty) continue;
        final parsed = _parseRingPoints(rawPolygon.first);
        if (parsed.isNotEmpty) polygons.add(parsed);
      }
      return polygons;
    }

    return const <List<LatLng>>[];
  }

  List<List<LatLng>> _parseBoundaryFromBoundingBox(dynamic rawBoundingBox) {
    if (rawBoundingBox is! List || rawBoundingBox.length < 4) {
      return const <List<LatLng>>[];
    }
    final south = double.tryParse(rawBoundingBox[0].toString());
    final north = double.tryParse(rawBoundingBox[1].toString());
    final west = double.tryParse(rawBoundingBox[2].toString());
    final east = double.tryParse(rawBoundingBox[3].toString());
    if (south == null || north == null || west == null || east == null) {
      return const <List<LatLng>>[];
    }
    return <List<LatLng>>[
      <LatLng>[
        LatLng(south, west),
        LatLng(south, east),
        LatLng(north, east),
        LatLng(north, west),
      ],
    ];
  }

  List<List<LatLng>> _boundaryRingsFromRow(Map<String, dynamic> row) {
    final geoJsonRings = _parseBoundaryFromGeoJson(row['geojson']);
    if (geoJsonRings.isNotEmpty) return geoJsonRings;
    return _parseBoundaryFromBoundingBox(row['boundingbox']);
  }

  void _focusMapOnOption(_ActiveRegionOption option) {
    if (option.boundaryRings.isNotEmpty) {
      final points = option.boundaryRings
          .expand((ring) => ring)
          .toList(growable: false);
      if (points.length >= 3) {
        final bounds = LatLngBounds.fromPoints(points);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(22)),
        );
        return;
      }
    }
    _mapController.move(option.point, 12.8);
  }

  Future<void> _ensureBoundaryForOption(_ActiveRegionOption option) async {
    if (option.boundaryRings.isNotEmpty) return;
    if (_boundaryLoadingKeys.contains(option.key)) return;
    _boundaryLoadingKeys.add(option.key);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': '${option.district}, ${option.city}, Turkey',
        'format': 'jsonv2',
        'addressdetails': '1',
        'polygon_geojson': '1',
        'countrycodes': 'tr',
        'limit': '8',
      });
      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ihiz-web-region-picker',
        },
      );
      if (response.statusCode != 200 || !mounted) return;
      final parsed = jsonDecode(response.body);
      final rows = parsed is List ? parsed : const [];
      if (rows.isEmpty) return;
      final row = _pickBestNominatimRow(
        rows,
        districtHint: option.district,
        cityHint: option.city,
      );
      if (row == null) return;
      final boundaryRings = _boundaryRingsFromRow(row);
      if (boundaryRings.isEmpty || !mounted) return;
      setState(() {
        final current = _optionsByKey[option.key];
        if (current != null) {
          _optionsByKey[option.key] = current.copyWith(
            boundaryRings: boundaryRings,
          );
        }
      });
      final focused = _focusedOption;
      if (focused != null && focused.key == option.key) {
        _focusMapOnOption(
          _optionsByKey[option.key] ??
              option.copyWith(boundaryRings: boundaryRings),
        );
      }
    } catch (_) {
      // Boundary fetch is best-effort; keep marker-only rendering on errors.
    } finally {
      _boundaryLoadingKeys.remove(option.key);
    }
  }

  Future<void> _searchDistrictOnMap() async {
    final query = _normalizeText(_searchController.text);
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _searchInfo = null;
    });
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': '$query, Turkey',
        'format': 'jsonv2',
        'addressdetails': '1',
        'polygon_geojson': '1',
        'countrycodes': 'tr',
        'limit': '8',
      });
      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'ihiz-web-region-picker',
        },
      );
      if (response.statusCode != 200) {
        if (_addManualDistrictFromQuery(query)) {
          return;
        }
        throw Exception('HTTP ${response.statusCode}');
      }
      final parsed = jsonDecode(response.body);
      final rows = parsed is List ? parsed : const [];
      if (rows.isEmpty) {
        if (_addManualDistrictFromQuery(query)) {
          return;
        }
        if (!mounted) return;
        setState(() {
          _searchInfo = 'İlçe bulunamadı. Farklı bir ilçe adı deneyin.';
        });
        return;
      }
      final row = _pickBestNominatimRow(rows, districtHint: query);
      if (row == null) {
        if (_addManualDistrictFromQuery(query)) {
          return;
        }
        throw Exception('Uygun ilçe sonucu yok');
      }
      final district = _districtFromRow(row, fallback: query);
      final city = _cityFromRow(row, fallback: 'Türkiye');
      final lat = double.tryParse((row['lat'] ?? '').toString());
      final lon = double.tryParse((row['lon'] ?? '').toString());
      if (lat == null || lon == null) {
        if (_addManualDistrictFromQuery(query)) {
          return;
        }
        throw Exception('Konum bilgisi yok');
      }
      final option = _ActiveRegionOption(
        key: _keyForDistrict(district),
        district: district,
        city: city,
        point: LatLng(lat, lon),
        boundaryRings: _boundaryRingsFromRow(row),
      );
      if (!mounted) return;
      setState(() {
        _optionsByKey[option.key] = option;
        _selectedKeys.add(option.key);
        _focusedRegionKey = option.key;
        _searchInfo = '${option.label} eklendi.';
      });
      _focusMapOnOption(option);
    } catch (_) {
      if (_addManualDistrictFromQuery(query)) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _searchInfo = 'İlçe araması yapılamadı. Bağlantıyı kontrol edin.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _optionsByKey = <String, _ActiveRegionOption>{};
    for (final option in widget.options) {
      final normalizedKey = _keyForDistrict(
        option.key.isNotEmpty ? option.key : option.district,
      );
      _optionsByKey[normalizedKey] = option.copyWith(key: normalizedKey);
    }
    final knownKeys = _optionsByKey.keys.toSet();
    _selectedKeys = widget.initialSelectedKeys
        .map(_keyForDistrict)
        .where((key) => knownKeys.contains(key))
        .toSet();
    _focusedRegionKey = _selectedKeys.isNotEmpty ? _selectedKeys.first : null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focused = _focusedOption;
      if (focused != null) {
        _focusMapOnOption(focused);
        unawaited(_ensureBoundaryForOption(focused));
      }
      for (final option in _selectedOptions) {
        unawaited(_ensureBoundaryForOption(option));
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleRegion(_ActiveRegionOption option) {
    var shouldLoadBoundary = false;
    setState(() {
      if (_selectedKeys.contains(option.key)) {
        _selectedKeys.remove(option.key);
        _focusedRegionKey = _selectedKeys.isEmpty ? null : _selectedKeys.first;
      } else {
        _selectedKeys.add(option.key);
        _focusedRegionKey = option.key;
        shouldLoadBoundary = true;
      }
    });
    _focusMapOnOption(option);
    if (shouldLoadBoundary) {
      unawaited(_ensureBoundaryForOption(option));
    }
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusedOption;
    final selected = _selectedOptions;
    final selectedBoundaryPolygons = <Polygon>[
      for (final option in selected)
        for (final ring in option.boundaryRings)
          if (ring.length >= 3)
            Polygon(
              points: ring,
              color: null,
              borderColor: const Color(0xFFE53935),
              borderStrokeWidth: 3,
              pattern: const StrokePattern.dotted(spacingFactor: 1.15),
            ),
    ];
    final selectedFallbackCircles = selected
        .where((option) => option.boundaryRings.isEmpty)
        .toList(growable: false);
    final selectedSummary = selected.isEmpty
        ? 'Tüm ilçeler aktif'
        : selected.length == 1
        ? selected.first.label
        : '${selected.first.label} +${selected.length - 1} ilçe';
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Aktif Bölgeler',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _selectedKeys.isEmpty
                ? null
                : () {
                    setState(() {
                      _selectedKeys.clear();
                      _focusedRegionKey = null;
                    });
                  },
            child: const Text('Sıfırla'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F9FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDE6F4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seçili il / ilçe',
                      style: TextStyle(
                        color: Color(0xFF5B6B86),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedSummary,
                      style: const TextStyle(
                        color: Color(0xFF163B73),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selected
                      .map(
                        (option) => InputChip(
                          label: Text(option.label),
                          onDeleted: () => _toggleRegion(option),
                          onPressed: () {
                            setState(() {
                              _focusedRegionKey = option.key;
                            });
                            _focusMapOnOption(option);
                            unawaited(_ensureBoundaryForOption(option));
                          },
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchDistrictOnMap(),
                      decoration: InputDecoration(
                        hintText: 'Haritadan ilçe ara (örn. Antakya)',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE6F4),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFDDE6F4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _searching ? null : _searchDistrictOnMap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF163B73),
                        foregroundColor: Colors.white,
                      ),
                      child: _searching
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.travel_explore_outlined),
                    ),
                  ),
                ],
              ),
              if ((_searchInfo ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _searchInfo!,
                    style: const TextStyle(
                      color: Color(0xFF5B6B86),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFDDE6F4)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: focused?.point ?? const LatLng(39.0, 35.0),
                      initialZoom: focused == null ? 6.2 : 12.8,
                      minZoom: 5,
                      maxZoom: 17,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.ihiz_web',
                      ),
                      if (selectedBoundaryPolygons.isNotEmpty)
                        PolygonLayer(polygons: selectedBoundaryPolygons),
                      if (selectedFallbackCircles.isNotEmpty)
                        CircleLayer(
                          circles: selectedFallbackCircles
                              .map(
                                (option) => CircleMarker(
                                  point: option.point,
                                  radius: 1500,
                                  useRadiusInMeter: true,
                                  color: const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.08),
                                  borderColor: const Color(0xFF2563EB),
                                  borderStrokeWidth: 2.2,
                                ),
                              )
                              .toList(growable: false),
                        ),
                      MarkerLayer(
                        markers: _markerOptions
                            .map((option) {
                              final isSelected = _selectedKeys.contains(
                                option.key,
                              );
                              final isFocused = option.key == _focusedRegionKey;
                              final markerColor = isFocused
                                  ? const Color(0xFFEA580C)
                                  : isSelected
                                  ? const Color(0xFF163B73)
                                  : const Color(0xFF64748B);
                              return Marker(
                                point: option.point,
                                width: 112,
                                height: 56,
                                child: GestureDetector(
                                  onTap: () => _toggleRegion(option),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.location_on_rounded,
                                        color: markerColor,
                                        size: isFocused ? 30 : 26,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.94,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: markerColor.withValues(
                                              alpha: 0.28,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          option.district,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF163B73),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(
                    _ActiveRegionSelectionResult(
                      selectedKeys: _selectedKeys.toSet(),
                      allOptions: _allOptions,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF163B73),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _selectedKeys.isEmpty
                        ? 'Tüm Bölgeleri Aktif Et'
                        : '${_selectedKeys.length} İlçeyi Kaydet',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
