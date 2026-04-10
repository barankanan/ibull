import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
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
  final _passwordController =
      TextEditingController(); // Password controller added
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
  bool _locationPrefillTried = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryPrefillLocation();
    });
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _taxNumberController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xFFF3F4F6),
        appBar: AppBar(
          title: const Text('Satıcı Başvurusu'),
          backgroundColor: const Color(0xFF111827),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Satıcı başvurusu sadece web tarayıcısında yapılabilir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Banner
            _buildHeader(),

            // Ana İçerik
            Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Progress Steps
                  _buildProgressSteps(),
                  const SizedBox(height: 32),

                  // Form Content
                  _buildStepContent(),
                  const SizedBox(height: 24),

                  // Navigation Buttons
                  _buildNavigationButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 20),
          const Icon(Icons.store, size: 64, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            'Satıcı Olmak İçin Başvurun',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Binlerce müşteriye ulaşın, işinizi büyütün!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSteps() {
    final steps = [
      {'title': 'İşletme Bilgileri', 'icon': Icons.business},
      {'title': 'İletişim Bilgileri', 'icon': Icons.contact_mail},
      {'title': 'Mağaza Konumu', 'icon': Icons.map},
      {'title': 'Banka Bilgileri', 'icon': Icons.account_balance},
      {'title': 'Belgeler', 'icon': Icons.description},
      {'title': 'Onay', 'icon': Icons.check_circle},
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green
                              : isActive
                              ? AppColors.primary
                              : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCompleted
                              ? Icons.check
                              : steps[index]['icon'] as IconData,
                          color: isActive || isCompleted
                              ? Colors.white
                              : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        steps[index]['title'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isActive ? AppColors.primary : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isCompleted ? Colors.green : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Form(
        key: _step1FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. İşletme Bilgileri',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Lütfen işletmenizle ilgili bilgileri eksiksiz doldurun.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

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
      _storeLocationMapController.move(LatLng(_storeLat!, _storeLng!), 16.0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Konum alınamadı: $e')));
    }
  }

  Future<void> _tryPrefillLocation() async {
    if (_locationPrefillTried || _storeLat != null || _storeLng != null) return;
    _locationPrefillTried = true;
    await _useCurrentLocation();
  }

  Widget _buildContactInfoStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Form(
        key: _step2FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '2. İletişim Bilgileri',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Sizinle nasıl iletişime geçebileceğimizi belirtin.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

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

            // Password Field (Only if not logged in - check in build or make it always visible for new account creation)
            // Based on user request "add password field", we add it here.
            _buildTextField(
              controller: _passwordController,
              label: 'Şifre *',
              hint: 'En az 6 karakter',
              icon: Icons.lock,
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Şifre zorunludur';
                }
                if (value.length < 6) {
                  return 'Şifre en az 6 karakter olmalıdır';
                }
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '3. Mağaza Konumu',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Mağazanızın konumunu haritada işaretleyin. Onaylandıktan sonra uygulama haritasında bu noktada görünecektir.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.my_location, size: 16),
                label: const Text('Bulunduğum Konum'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 340,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: FlutterMap(
              mapController: _storeLocationMapController,
              options: MapOptions(
                initialCenter: LatLng(_storeLat ?? 39.0, _storeLng ?? 35.0),
                initialZoom: 12.0,
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
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 48,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_storeLat != null && _storeLng != null)
            Text(
              'Konum seçildi: ${_storeLat!.toStringAsFixed(5)}, ${_storeLng!.toStringAsFixed(5)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else
            Text(
              'Haritada mağazanızın bulunduğu yere tıklayın.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBankInfoStep() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Form(
        key: _step3FormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '4. Banka Bilgileri',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Ödemelerinizin yapılacağı banka hesabı bilgileri.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '5. Belgeler',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Başvurunuzun onaylanması için aşağıdaki belgeleri yüklemeniz gerekmektedir.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '6. Başvurunuzu Onaylayın',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

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
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool obscureText = false,
    String? Function(String?)? validator,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      obscureText: obscureText,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
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
    setState(() {
      _cityController.text = selection.province;
      _districtController.text = selection.district;
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
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: field.hasError
                        ? Colors.red.shade400
                        : Colors.grey.shade400,
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
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
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

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Geri'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _currentStep == 5
                  ? (_acceptTerms ? _submitApplication : null)
                  : _nextStep,
              icon: Icon(_currentStep == 5 ? Icons.check : Icons.arrow_forward),
              label: Text(_currentStep == 5 ? 'Başvuruyu Gönder' : 'Devam Et'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
            ),
          ),
        ],
      ),
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
        if (_hasPhysicalStore && (_storeLat == null || _storeLng == null)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lütfen haritadan mağaza konumunu işaretleyin.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
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
      if (authService.currentUser == null) {
        if (_passwordController.text.isEmpty) {
          throw Exception('Şifre alanı zorunludur');
        }
        // Sign up and login
        await authService.signUpWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
          _fullNameController.text, // displayName
          phone: _phoneController.text,
        );

        if (authService.currentUser == null) {
          throw Exception('Kullanıcı oluşturuldu fakat giriş yapılamadı.');
        }
      }

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
        'storeLat': ?_storeLat,
        'storeLng': ?_storeLng,
        'logoUrl': ?logoUrl,
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
