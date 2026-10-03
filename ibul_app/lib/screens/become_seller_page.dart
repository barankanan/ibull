import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../features/mall/seller/seller_mall_link_repository.dart';
import '../features/mall/seller/seller_onboarding_location.dart';
import '../features/seller/auth/seller_application_auth.dart';
import '../features/seller/onboarding/seller_onboarding_chrome.dart';
import '../services/auth_service.dart';
import '../services/store_service.dart';
import '../widgets/image_cropper_widget.dart';
import '../widgets/province_district_picker_dialog.dart';

/// Satıcı Başvuru Sayfası
/// Kullanıcıların satıcı olmak için başvuru yaptıkları sayfa
class BecomeSellerPage extends StatefulWidget {
  const BecomeSellerPage({super.key});

  @override
  State<BecomeSellerPage> createState() => _BecomeSellerPageState();
}

class _BecomeSellerPageState extends State<BecomeSellerPage> {
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();
  final _step3FormKey = GlobalKey<FormState>();
  final MapController _storeLocationMapController = MapController();

  /// Mağaza konumu (haritadan işaretlenen) – başvuru gönderilirken kullanılır
  double? _storeLat;
  double? _storeLng;

  /// İşletme logosu (başvuruda yüklenir, onay sonrası mağaza/satıcı profilinde görünür)
  XFile? _logoFile;
  Uint8List? _logoBytes;
  String? _logoFileName;

  // Document States
  // Using simple booleans for demo, but in real app would store File or Uint8List
  final Map<String, dynamic> _uploadedDocuments = {};

  bool get _taxPlateUploaded => _uploadedDocuments.containsKey('taxPlate');
  bool get _signatureCircularUploaded =>
      _uploadedDocuments.containsKey('signatureCircular');
  bool get _tradeRegistryGazetteUploaded =>
      _uploadedDocuments.containsKey('tradeRegistryGazette');
  bool get _ibanDocumentUploaded =>
      _uploadedDocuments.containsKey('ibanDocument');
  bool get _idCardUploaded => _uploadedDocuments.containsKey('idCard');

  int _currentStep = 0;

  // Form Controllers
  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _ibanController = TextEditingController();
  final _accountHolderController = TextEditingController();

  String? _selectedBusinessType;
  String? _selectedCategory;
  bool _hasPhysicalStore = false;
  bool _acceptTerms = false;
  var _obscurePassword = true;
  var _obscurePasswordConfirm = true;
  var _mapReady = false;
  SellerOnboardingLocationKind? _locationKind;
  SellerOnboardingMallDraft? _mallDraft;

  static const _stepLabels = [
    'İşletme',
    'İletişim',
    'Konum',
    'Banka',
    'Belgeler',
    'Onay',
  ];

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _businessNameController,
      _fullNameController,
      _cityController,
      _districtController,
      _bankNameController,
      _ibanController,
    ]) {
      controller.addListener(_onFormChanged);
    }
  }

  void _onFormChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _taxNumberController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _postalCodeController.dispose();
    _bankNameController.dispose();
    _ibanController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1040;
    final summary = SellerOnboardSummary(
      rows: _summaryRows(),
      missing: _missingFields().length,
      progress: _progress,
    );

    return Scaffold(
      backgroundColor: SellerOnboardTokens.bg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SellerOnboardHero(onBack: () => Navigator.maybePop(context)),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: SellerOnboardTokens.maxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(width < 700 ? 16 : 28, 24, width < 700 ? 16 : 28, 40),
                  child: Column(
                    children: [
                      SellerOnboardStepper(current: _currentStep, labels: _stepLabels),
                      const SizedBox(height: 24),
                      if (desktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildStepContent()),
                            const SizedBox(width: 20),
                            SizedBox(width: 300, child: summary),
                          ],
                        )
                      else ...[
                        _buildStepContent(),
                        const SizedBox(height: 16),
                        summary,
                      ],
                      const SizedBox(height: 20),
                      SellerOnboardNav(
                        canBack: _currentStep > 0,
                        isLast: _currentStep == 5,
                        onBack: () => setState(() => _currentStep--),
                        onNext: _currentStep == 5
                            ? (_acceptTerms ? _submitApplication : null)
                            : _nextStep,
                        nextEnabled: _currentStep != 5 || _acceptTerms,
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
  }

  double get _progress {
    const total = 12;
    return ((_filledCount()) / total).clamp(0, 1);
  }

  int _filledCount() {
    var n = 0;
    if (_businessNameController.text.trim().isNotEmpty) n++;
    if (_selectedBusinessType != null) n++;
    if (_taxNumberController.text.trim().isNotEmpty) n++;
    if (_selectedCategory != null) n++;
    if (_fullNameController.text.trim().isNotEmpty) n++;
    if (_emailController.text.trim().isNotEmpty) n++;
    if (_phoneController.text.trim().isNotEmpty) n++;
    if (_cityController.text.trim().isNotEmpty) n++;
    if (_districtController.text.trim().isNotEmpty) n++;
    if (_locationKind != null || !_hasPhysicalStore) n++;
    if (_bankNameController.text.trim().isNotEmpty) n++;
    if (_ibanController.text.trim().isNotEmpty) n++;
    return n;
  }

  List<String> _missingFields() {
    final missing = <String>[];
    if (_businessNameController.text.trim().isEmpty) missing.add('İşletme adı');
    if (_selectedBusinessType == null) missing.add('İşletme türü');
    if (_cityController.text.trim().isEmpty) missing.add('İl');
    if (_districtController.text.trim().isEmpty) missing.add('İlçe');
    if (_hasPhysicalStore && _locationKind == null) missing.add('Konum tipi');
    if (_hasPhysicalStore &&
        _locationKind == SellerOnboardingLocationKind.mall &&
        !(_mallDraft?.isReadyToSubmit ?? false)) {
      missing.add('AVM / kat / mağaza no');
    }
    if (_hasPhysicalStore &&
        _locationKind == SellerOnboardingLocationKind.standalone &&
        (_storeLat == null || _storeLng == null)) {
      missing.add('Harita konumu');
    }
    return missing;
  }

  List<(String, String)> _summaryRows() => [
        ('İşletme adı', _dash(_businessNameController.text)),
        ('İşletme türü', _selectedBusinessType ?? '—'),
        (
          'Konum tipi',
          !_hasPhysicalStore
              ? 'Fiziksel mağaza yok'
              : _locationKind == SellerOnboardingLocationKind.mall
                  ? 'AVM içerisinde'
                  : _locationKind == SellerOnboardingLocationKind.standalone
                      ? 'Bağımsız mağaza'
                      : '—',
        ),
        (
          'İl / İlçe',
          () {
            final place = [_cityController.text, _districtController.text]
                .where((e) => e.trim().isNotEmpty)
                .join(' / ');
            return place.isEmpty ? '—' : place;
          }(),
        ),
        if (_locationKind == SellerOnboardingLocationKind.mall) ...[
          ('AVM', _mallDraft?.mall.name ?? '—'),
          ('Kat', _mallDraft?.floorName ?? '—'),
          ('Mağaza No', _dash(_mallDraft?.unitCode ?? '')),
        ],
      ];

  String _dash(String value) => value.trim().isEmpty ? '—' : value.trim();

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBusinessInfoStep();
      case 1:
        return _buildContactInfoStep();
      case 2:
        return _buildStoreLocationStep();
      case 3:
        return _buildBankInfoStep();
      case 4:
        return _buildDocumentsStep();
      case 5:
        return _buildConfirmationStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBusinessInfoStep() {
    return SellerOnboardSection(
      title: '1. İşletme Bilgileri',
      subtitle: 'İşletmenizi tanıtın. Bu bilgiler mağaza profilinizde görünür.',
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _businessNameController,
              label: 'İşletme Adı *',
              hint: 'Örn: Tech Store',
              icon: Icons.store,
            ),
            const SizedBox(height: 16),
            _buildLogoField(),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'İşletme Türü *',
              value: _selectedBusinessType,
              items: [
                'Şahış Şirketi',
                'Limited Şirket',
                'Anonim Şirket',
                'Şahıs İşletmesi',
              ],
              onChanged: (value) {
                setState(() {
                  _selectedBusinessType = value;
                });
              },
              icon: Icons.business_center,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _taxNumberController,
              label: 'Vergi Numarası *',
              hint: '10 haneli vergi numarası',
              icon: Icons.receipt_long,
              keyboardType: TextInputType.number,
              maxLength: 11,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),

            _buildDropdown(
              label: 'Ana Ürün Kategorisi *',
              value: _selectedCategory,
              items: [
                'Yemek',
                'Elektronik',
                'Giyim & Aksesuar',
                'Ayakkabı & Çanta',
                'Ev & Yaşam',
                'Kozmetik & Kişisel Bakım',
                'Spor & Outdoor',
                'Anne & Bebek & Oyuncak',
                'Kitap, Müzik, Film, Hobi',
                'Süpermarket',
                'Petshop',
                'Otomotiv & Motosiklet',
                'Galerici',
                'Yapı Market & Bahçe',
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
              icon: Icons.category,
            ),
            const SizedBox(height: 16),

            CheckboxListTile(
              value: _hasPhysicalStore,
              onChanged: (value) {
                setState(() {
                  _hasPhysicalStore = value ?? false;
                });
              },
              title: const Text('Fiziksel mağazam var'),
              subtitle: const Text('Fiziksel bir mağazanız varsa işaretleyin'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'İşletme Logosu',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final xFile = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1400,
                  maxHeight: 1400,
                  imageQuality: 90,
                );
                if (xFile != null) {
                  final bytes = await xFile.readAsBytes();
                  if (!mounted) return;
                  await showDialog(
                    context: context,
                    builder: (context) => ImageCropperWidget(
                      imageData: bytes,
                      aspectRatio: 1.0,
                      suggestedWidth: 680,
                      onCropped: (croppedData) {
                        setState(() {
                          _logoFile = xFile;
                          _logoFileName = xFile.name;
                          _logoBytes = croppedData;
                        });
                      },
                    ),
                  );
                }
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _logoBytes == null
                        ? Colors.grey.shade300
                        : AppColors.primary,
                    width: _logoBytes == null ? 1 : 2,
                  ),
                ),
                child: _logoBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate,
                            size: 32,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Logo ekle',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _logoBytes!,
                          fit: BoxFit.cover,
                          width: 100,
                          height: 100,
                          // Seçilen logo tam çözünürlükte tutuluyor (yükleme
                          // için gerekli); 100pt önizlemede tam boy decode
                          // etmeye gerek yok.
                          cacheWidth:
                              (100 * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                          cacheHeight:
                              (100 * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            if (_logoFile != null)
              TextButton.icon(
                onPressed: () => setState(() {
                  _logoFile = null;
                  _logoBytes = null;
                  _logoFileName = null;
                }),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Kaldır'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Önerilen logo: 512x512 px (1:1), JPG/PNG, maksimum 1 MB.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Future<void> _useCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Konum servisleri kapalı.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Konum izni verilmedi.');
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _storeLat = pos.latitude;
        _storeLng = pos.longitude;
      });
      if (_mapReady && _locationKind == SellerOnboardingLocationKind.standalone) {
        _storeLocationMapController.move(LatLng(_storeLat!, _storeLng!), 16.0);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Konum alınamadı: $e')));
    }
  }

  Widget _buildContactInfoStep() {
    return SellerOnboardSection(
      title: '2. İletişim Bilgileri',
      subtitle: 'Başvuru ve müşteri iletişimi için güncel bilgilerinizi girin.',
      child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _buildTextField(
              controller: _fullNameController,
              label: 'Ad Soyad *',
              hint: 'Yetkili kişi adı',
              icon: Icons.person,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _emailController,
              label: 'E-posta *',
              hint: 'ornek@email.com',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bu alan zorunludur';
                }
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(value.trim())) {
                  return 'Geçerli bir e-posta adresi giriniz';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildTextField(
              key: const ValueKey('seller-onboard-password'),
              controller: _passwordController,
              label: 'Şifre *',
              hint: 'En az 6 karakter',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                key: const ValueKey('seller-onboard-password-toggle'),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Şifrenizi girin.';
                if (value.length < 6) return 'Şifre en az 6 karakter olmalıdır';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              key: const ValueKey('seller-onboard-password-confirm'),
              controller: _passwordConfirmController,
              label: 'Şifre Tekrar *',
              hint: 'Şifrenizi tekrar girin',
              icon: Icons.lock_outline,
              obscureText: _obscurePasswordConfirm,
              suffixIcon: IconButton(
                key: const ValueKey('seller-onboard-password-confirm-toggle'),
                onPressed: () =>
                    setState(() => _obscurePasswordConfirm = !_obscurePasswordConfirm),
                icon: Icon(_obscurePasswordConfirm ? Icons.visibility_off : Icons.visibility),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Şifrenizi tekrar girin.';
                if (value != _passwordController.text) return 'Şifreler eşleşmiyor.';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _phoneController,
              label: 'Telefon *',
              hint: '0555 123 45 67',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              maxLength: 11,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 24),

            const Text(
              'Adres Bilgileri',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _addressController,
              label: 'Adres *',
              hint: 'Mahalle, sokak, bina no',
              icon: Icons.location_on,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildLocationPickerField(
                    label: 'İl *',
                    valueBuilder: () => _cityController.text,
                    placeholder: 'İl seçin',
                    icon: Icons.location_city,
                    onTap: _openApplicationProvinceDistrictPicker,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLocationPickerField(
                    label: 'İlçe *',
                    valueBuilder: () => _districtController.text,
                    placeholder: 'İlçe seçin',
                    icon: Icons.map,
                    onTap: _openApplicationProvinceDistrictPicker,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _postalCodeController,
              label: 'Posta Kodu',
              hint: '34000',
              icon: Icons.markunread_mailbox,
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreLocationStep() {
    return SellerOnboardSection(
      title: '3. Mağaza Konumu',
      subtitle: 'Müşterilerin sizi haritada veya AVM içinde bulması için konumu netleştirin.',
      child: SellerOnboardingLocationStep(
        kind: _locationKind,
        onKind: (kind) => setState(() {
          _locationKind = kind;
          if (kind == SellerOnboardingLocationKind.standalone) {
            _mallDraft = null;
          } else {
            _mapReady = false;
          }
        }),
        standalone: _locationKind == SellerOnboardingLocationKind.standalone
            ? _standaloneStoreMap()
            : const SizedBox.shrink(),
        onMallDraft: (draft) => setState(() => _mallDraft = draft),
        city: _cityController.text,
        district: _districtController.text,
        onPickCityDistrict: _openApplicationProvinceDistrictPicker,
        addressField: _buildTextField(
          controller: _addressController,
          label: 'Açık adres *',
          hint: 'Mahalle, sokak, bina no',
          icon: Icons.location_on,
          maxLines: 3,
        ),
      ),
    );
  }

  Widget _standaloneStoreMap() {
    final map = Container(
      height: 340,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SellerOnboardTokens.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: _storeLocationMapController,
        options: MapOptions(
          initialCenter: LatLng(_storeLat ?? 39.0, _storeLng ?? 35.0),
          initialZoom: 12.0,
          onMapReady: () => _mapReady = true,
          onTap: (_, latLng) {
            setState(() {
              _storeLat = latLng.latitude;
              _storeLng = latLng.longitude;
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.ibul.app',
          ),
          if (_storeLat != null && _storeLng != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(_storeLat!, _storeLng!),
                  width: 48,
                  height: 48,
                  child: const Icon(Icons.location_on, color: AppColors.primary, size: 48),
                ),
              ],
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Haritada konum seçin. Onay sonrası mağazanız bu noktada görünür.',
          style: TextStyle(color: SellerOnboardTokens.muted, height: 1.4),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _useCurrentLocation,
          icon: const Icon(Icons.my_location, size: 16),
          label: const Text('Bulunduğum Konum'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 720) {
              return Column(
                children: [
                  map,
                  const SizedBox(height: 12),
                  _standaloneLocationSummary(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: map),
                const SizedBox(width: 12),
                Expanded(flex: 4, child: _standaloneLocationSummary()),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBankInfoStep() {
    return SellerOnboardSection(
      title: '4. Banka Bilgileri',
      subtitle: 'Ödemelerinizin yatacağı, işletme adına kayıtlı hesabı girin.',
      child: Form(
        key: _step3FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Banka hesabı, işletme adına kayıtlı olmalıdır.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _buildTextField(
              controller: _bankNameController,
              label: 'Banka Adı *',
              hint: 'Örn: Garanti BBVA',
              icon: Icons.account_balance,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _ibanController,
              label: 'IBAN *',
              hint: 'TR00 0000 0000 0000 0000 0000 00',
              icon: Icons.credit_card,
              keyboardType: TextInputType.text,
              maxLength: 32,
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _accountHolderController,
              label: 'Hesap Sahibi *',
              hint: 'Hesap sahibinin adı',
              icon: Icons.person_outline,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDocument(String key) async {
    // If already uploaded, remove it
    if (_uploadedDocuments.containsKey(key)) {
      setState(() {
        _uploadedDocuments.remove(key);
      });
      return;
    }

    try {
      final ImagePicker picker = ImagePicker();
      // Reduce image quality to 50% to speed up uploads and reduce size
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 1024, // Resize large images
      );

      if (image != null) {
        // Convert to Base64
        final bytes = await image.readAsBytes();
        // ignore: unused_local_variable
        final base64String = base64Encode(
          bytes,
        ); // Will use this later for storage/display

        setState(() {
          // Storing both XFile for potential upload and base64 for preview if needed
          _uploadedDocuments[key] = {
            'file': image,
            'base64':
                base64String, // Store base64 for direct saving to Firestore (demo purpose)
            'name': image.name,
          };
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Belge başarıyla yüklendi'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDocumentsStep() {
    return SellerOnboardSection(
      title: '5. Belgeler',
      subtitle: 'Onay için gerekli resmi belgeleri yükleyin. Her belge net ve okunaklı olmalı.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          _buildDocumentUploadRow(
            'Vergi Levhası *',
            _taxPlateUploaded,
            () => _pickDocument('taxPlate'),
          ),
          _buildDocumentUploadRow(
            'İmza Sirküleri *',
            _signatureCircularUploaded,
            () => _pickDocument('signatureCircular'),
          ),
          _buildDocumentUploadRow(
            'Ticaret Sicil Gazetesi *',
            _tradeRegistryGazetteUploaded,
            () => _pickDocument('tradeRegistryGazette'),
          ),
          _buildDocumentUploadRow(
            'IBAN Belgesi (Dekont/Cüzdan) *',
            _ibanDocumentUploaded,
            () => _pickDocument('ibanDocument'),
          ),
          _buildDocumentUploadRow(
            'Yetkili Kimlik Fotokopisi *',
            _idCardUploaded,
            () => _pickDocument('idCard'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentUploadRow(
    String title,
    bool isUploaded,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: isUploaded ? Colors.green.shade200 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isUploaded ? Colors.green.shade50 : Colors.white,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUploaded
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isUploaded ? Icons.check_circle : Icons.upload_file,
              color: isUploaded ? Colors.green : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  isUploaded ? 'Belge Yüklendi' : 'Henüz yüklenmedi',
                  style: TextStyle(
                    fontSize: 12,
                    color: isUploaded ? Colors.green : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: isUploaded ? Colors.red : AppColors.primary,
              side: BorderSide(
                color: isUploaded ? Colors.red : AppColors.primary,
              ),
            ),
            child: Text(isUploaded ? 'Kaldır' : 'Yükle'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationStep() {
    return SellerOnboardSection(
      title: '6. Onay',
      subtitle: 'Bilgileri kontrol edin, ardından satıcı sözleşmesini kabul ederek gönderin.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Özet Bilgiler
          _buildSummaryCard('İşletme Bilgileri', [
            {'label': 'İşletme Adı', 'value': _businessNameController.text},
            {'label': 'İşletme Türü', 'value': _selectedBusinessType ?? '-'},
            {'label': 'Vergi No', 'value': _taxNumberController.text},
            {'label': 'Kategori', 'value': _selectedCategory ?? '-'},
            if (_logoFile != null)
              {'label': 'İşletme Logosu', 'value': 'Yüklendi'},
          ]),
          const SizedBox(height: 16),

          _buildSummaryCard('İletişim Bilgileri', [
            {'label': 'Ad Soyad', 'value': _fullNameController.text},
            {'label': 'E-posta', 'value': _emailController.text},
            {'label': 'Telefon', 'value': _phoneController.text},
            {
              'label': 'Adres',
              'value':
                  '${_addressController.text}, ${_districtController.text}/${_cityController.text}',
            },
          ]),
          if (_storeLat != null && _storeLng != null) ...[
            const SizedBox(height: 16),
            _buildSummaryCard('Mağaza Konumu', [
              {
                'label': 'Enlem / Boylam',
                'value':
                    '${_storeLat!.toStringAsFixed(5)}, ${_storeLng!.toStringAsFixed(5)}',
              },
            ]),
          ],
          const SizedBox(height: 16),
          _buildSummaryCard('Banka Bilgileri', [
            {'label': 'Banka', 'value': _bankNameController.text},
            {'label': 'IBAN', 'value': _ibanController.text},
            {'label': 'Hesap Sahibi', 'value': _accountHolderController.text},
          ]),
          const SizedBox(height: 16),

          _buildSummaryCard('Yüklenen Belgeler', [
            {
              'label': 'Vergi Levhası',
              'value': _taxPlateUploaded ? 'Yüklendi' : 'Eksik',
            },
            {
              'label': 'İmza Sirküleri',
              'value': _signatureCircularUploaded ? 'Yüklendi' : 'Eksik',
            },
            {
              'label': 'Ticaret Sicil Gazetesi',
              'value': _tradeRegistryGazetteUploaded ? 'Yüklendi' : 'Eksik',
            },
            {
              'label': 'IBAN Belgesi',
              'value': _ibanDocumentUploaded ? 'Yüklendi' : 'Eksik',
            },
            {
              'label': 'Kimlik Fotokopisi',
              'value': _idCardUploaded ? 'Yüklendi' : 'Eksik',
            },
          ]),
          const SizedBox(height: 24),

          // Şartlar ve Koşullar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Satıcı Sözleşmesi',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  '• Komisyon oranı: %15\n'
                  '• Ödeme süresi: Haftalık\n'
                  '• İade süresi: 14 gün\n'
                  '• Ürün onay süresi: 24 saat\n'
                  '• Müşteri hizmetleri desteği',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          CheckboxListTile(
            value: _acceptTerms,
            onChanged: (value) {
              setState(() {
                _acceptTerms = value ?? false;
              });
            },
            title: const Text('Şartları ve koşulları kabul ediyorum'),
            subtitle: Text(
              'Satıcı sözleşmesini okudum ve kabul ediyorum',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, List<Map<String, String>> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      '${item['label']}:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item['value'] ?? '-',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      maxLines: obscureText ? 1 : maxLines,
      obscureText: obscureText,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: SellerOnboardTokens.muted),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SellerOnboardTokens.line),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
      validator: (value) {
        if (validator != null) {
          return validator(value);
        }
        if (label.contains('*') && (value == null || value.isEmpty)) {
          return 'Bu alan zorunludur';
        }
        return null;
      },
    );
  }

  Future<void> _openApplicationProvinceDistrictPicker() async {
    final selection = await showProvinceDistrictPickerDialog(
      context: context,
      initialProvince: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      initialDistrict: _districtController.text.trim().isEmpty
          ? null
          : _districtController.text.trim(),
      title: 'İl / İlçe seç',
    );
    if (selection == null || !mounted) return;
    final cityChanged = selection.province != _cityController.text.trim();
    final districtChanged = selection.district != _districtController.text.trim();
    setState(() {
      _cityController.text = selection.province;
      _districtController.text = selection.district;
      if (cityChanged || districtChanged) {
        _mallDraft = null;
      }
    });
  }

  Widget _buildLocationPickerField({
    required String label,
    required String Function() valueBuilder,
    required String placeholder,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return FormField<String>(
      initialValue: valueBuilder(),
      validator: (_) {
        if (label.contains('*') && valueBuilder().trim().isEmpty) {
          return 'Bu alan zorunludur';
        }
        return null;
      },
      builder: (field) {
        final value = valueBuilder();
        final hasValue = value.trim().isNotEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                onTap();
                field.didChange(valueBuilder());
              },
              borderRadius: BorderRadius.circular(12),
              child: Ink(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: field.hasError
                        ? Colors.red.shade400
                        : SellerOnboardTokens.line,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: Colors.grey.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              hasValue ? value : placeholder,
                              style: TextStyle(
                                color: hasValue
                                    ? const Color(0xFF111827)
                                    : const Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded),
                    ],
                  ),
                ),
              ),
            ),
            if (field.hasError) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  field.errorText ?? '',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      isDense: true,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: MediaQuery.sizeOf(context).width >= 600
            ? Icon(icon, size: 18, color: SellerOnboardTokens.muted)
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SellerOnboardTokens.line),
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Lütfen bir seçim yapın';
        }
        return null;
      },
    );
  }

  Widget _standaloneLocationSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SellerOnboardTokens.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Konum özeti', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Konum tipi: Bağımsız mağaza'),
        Text('İl / İlçe: ${_dash([_cityController.text, _districtController.text].where((e) => e.trim().isNotEmpty).join(' / '))}'),
        Text(
          _storeLat == null
              ? 'Harita: konum seçilmedi'
              : 'Harita: ${_storeLat!.toStringAsFixed(5)}, ${_storeLng!.toStringAsFixed(5)}',
        ),
      ]),
    );
  }

  void _nextStep() {
    GlobalKey<FormState>? currentFormKey;
    switch (_currentStep) {
      case 0:
        currentFormKey = _step1FormKey;
        break;
      case 1:
        currentFormKey = _step2FormKey;
        break;
      case 2:
        if (_hasPhysicalStore) {
          if (_locationKind == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mağazanızın nerede olduğunu seçin.'), backgroundColor: Colors.orange),
            );
            return;
          }
          if (_locationKind == SellerOnboardingLocationKind.standalone &&
              (_storeLat == null || _storeLng == null)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lütfen haritadan mağaza konumunu işaretleyin.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          if (_locationKind == SellerOnboardingLocationKind.mall &&
              !(_mallDraft?.isReadyToSubmit ?? false)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('AVM, kat, mağaza no ve kira/tahsis belgesi gerekli.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
        }
        break;
      case 3:
        currentFormKey = _step3FormKey;
        break;
      case 4:
        break;
    }
    if (currentFormKey?.currentState?.validate() ?? true) {
      if (_currentStep < 5) {
        setState(() {
          _currentStep++;
        });
      }
    }
  }

  Future<Map<String, Object?>> _mallPlacementPayload() async {
    final draft = _mallDraft!;
    final documents = await SellerMallLinkRepository().uploadDocuments(
      requestId: draft.requestId,
      files: draft.files,
    );
    return draft.toPlacementJson(documents);
  }

  void _submitApplication() async {
    // Show improved loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 4,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Başvuru Gönderiliyor...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Lütfen bekleyiniz, bilgileriniz işleniyor.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final authService = AuthService();
      final storeService = StoreService();

      // 1. Check/Register User First (Required for Upload)
      await SellerApplicationAuth.ensureAccount(
        auth: authService,
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _fullNameController.text,
        phone: _phoneController.text,
      );

      // 2. Upload Documents to Supabase Storage
      final Map<String, dynamic> documentsData = {};
      final List<Future<void>> uploadFutures = [];

      for (var entry in _uploadedDocuments.entries) {
        final key = entry.key; // e.g. 'taxPlate'
        final data = entry.value;
        final XFile? file = data['file'];

        if (file != null) {
          final future = Future(() async {
            try {
              final fileName = '$key.jpg';
              final Uint8List fileBytes = await file.readAsBytes();

              // Upload using StoreService with timeout
              final path = await storeService
                  .uploadDocument(fileName, fileBytes, 'image/jpeg')
                  .timeout(
                    const Duration(seconds: 60),
                    onTimeout: () =>
                        throw Exception('Dosya yükleme zaman aşımı: $key'),
                  );

              // Save Path and Status
              documentsData[key] = true;
              documentsData['${key}Path'] = path; // Store path, not URL
              documentsData['${key}Name'] = data['name'] ?? fileName;
            } catch (e) {
              debugPrint('Error uploading $key: $e');
              documentsData[key] = false;
            }
          });
          uploadFutures.add(future);
        }
      }

      // Wait for all uploads
      if (uploadFutures.isNotEmpty) {
        await Future.wait(uploadFutures);
      }

      String? logoUrl;
      if (_logoBytes != null) {
        try {
          logoUrl = await storeService
              .uploadStoreImageBytes(
                _logoBytes!,
                'logo',
                fileName: _logoFileName ?? 'store_logo.jpg',
              )
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () => throw Exception('Logo yükleme zaman aşımı'),
              );
        } catch (e) {
          debugPrint('Logo upload error: $e');
        }
      }

      final applicationData = {
        'businessName': _businessNameController.text,
        'businessType': _selectedBusinessType,
        'taxNumber': _taxNumberController.text,
        'category': _selectedCategory,
        'hasPhysicalStore': _hasPhysicalStore,
        'contactName': _fullNameController.text,
        'email': _emailController.text.trim(),
        'phone': _phoneController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'district': _districtController.text,
        'postalCode': _postalCodeController.text,
        'bankName': _bankNameController.text,
        'iban': _ibanController.text,
        'accountHolder': _accountHolderController.text,
        'documents': documentsData,
        if (_locationKind != SellerOnboardingLocationKind.mall) 'storeLat': ?_storeLat,
        if (_locationKind != SellerOnboardingLocationKind.mall) 'storeLng': ?_storeLng,
        'logoUrl': ?logoUrl,
        if (_mallDraft != null) 'mallPlacement': await _mallPlacementPayload(),
      };

      // 3. Submit Application Data
      await authService
          .submitSellerApplication(applicationData)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw Exception(
              'Başvuru gönderilirken zaman aşımı oluştu. Lütfen tekrar deneyin.',
            ),
          );

      if (!mounted) return;
      Navigator.pop(context); // Hide loading

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
          title: const Text('Başvurunuz Alındı!'),
          content: const Text(
            'Satıcı başvurusu başarıyla veritabanına kaydedildi. Admin panelinden onaylandığında satıcı paneliniz aktif olacaktır.\n\n'
            'Ortalama onay süresi: 1-2 iş günü',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Dialog'u kapat
                Navigator.pop(context); // Sayfayı kapat
              },
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Hide loading

      String errorMessage = 'Başvuru gönderilirken bir hata oluştu:\n$e';

      if (e.toString().contains('email rate limit exceeded')) {
        errorMessage =
            'Çok fazla deneme yapıldı. Lütfen FARKLI bir e-posta adresi deneyin veya 1 saat bekleyin.';
      } else if (e.toString().contains('User already registered')) {
        errorMessage =
            'Bu e-posta adresi zaten kayıtlı. Lütfen farklı bir e-posta kullanın.';
      } else if (e.toString().contains('weak_password')) {
        errorMessage =
            'Şifreniz çok zayıf. Lütfen en az 6 karakterli bir şifre girin.';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.error, color: Colors.red, size: 64),
          title: const Text('Hata Oluştu'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    }
  }
}
