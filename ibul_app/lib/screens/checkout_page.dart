import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/auth/user_identity.dart';
import '../core/constants.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';
import '../widgets/address_edit_sheet.dart';
import '../services/order_service.dart';
import 'login_page.dart';
import 'order_confirmation_page.dart';

class CheckoutPage extends StatefulWidget {
  final double totalPrice;
  final List<Map<String, dynamic>> selectedProducts;
  const CheckoutPage({
    super.key,
    required this.totalPrice,
    required this.selectedProducts,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  bool _acceptTerms = false;
  String _selectedPayment = 'single';
  String _paymentTab = 'card';

  // Delivery State
  int _selectedDeliveryType = 0; // 0: Fast, 1: Standard
  late DateTime _selectedFastDate;
  String _selectedFastTime = '13:00 - 15:00';
  late DateTime _selectedStandardDate;

  // Card Form Controllers
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _cvcController = TextEditingController();
  final TextEditingController _cardHolderNameController =
      TextEditingController();
  final TextEditingController _cardNameController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();

  final List<String> _timeSlots = [
    '09:00 - 11:00',
    '11:00 - 13:00',
    '13:00 - 15:00',
    '15:00 - 17:00',
    '17:00 - 19:00',
    '19:00 - 21:00',
  ];

  int _selectedAddressIndex = 0;
  int _selectedCardIndex = 0;
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    _selectedFastDate = DateTime.now();
    _selectedStandardDate = DateTime.now().add(const Duration(days: 3));

    // Add listeners to update UI on text change
    _cardNumberController.addListener(_onCardInfoChanged);
    _expiryDateController.addListener(_onCardInfoChanged);
    _cardHolderNameController.addListener(_onCardInfoChanged);
  }

  void _onCardInfoChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvcController.dispose();
    _cardHolderNameController.dispose();
    _cardNameController.dispose();
    super.dispose();
  }

  Future<void> _addNewCard({int? editIndex}) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final existingCard =
        (editIndex != null && editIndex < appState.savedCards.length)
        ? appState.savedCards[editIndex]
        : null;
    final rawCardNumber = _cardNumberController.text.trim();
    final resolvedMaskedNumber = rawCardNumber.isEmpty
        ? (existingCard?['number'] ?? '')
        : (rawCardNumber.contains('*')
              ? rawCardNumber
              : '**** ${rawCardNumber.length >= 4 ? rawCardNumber.substring(rawCardNumber.length - 4) : rawCardNumber}');

    if (resolvedMaskedNumber.isEmpty ||
        _expiryDateController.text.isEmpty ||
        _cardHolderNameController.text.isEmpty ||
        _cardNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen tüm kart bilgilerini doldurunuz.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kart başarıyla eklendi!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );

    final cardData = <String, String>{
      'name': _cardNameController.text,
      'number': resolvedMaskedNumber,
      'type': existingCard?['type'] ?? 'Visa',
      'holder': _cardHolderNameController.text,
      'expiry': _expiryDateController.text,
    };

    if (editIndex != null) {
      await appState.updateSavedCard(editIndex, cardData);
      if (!mounted) return;
      setState(() => _selectedCardIndex = editIndex);
    } else {
      await appState.addSavedCard(cardData);
      if (!mounted) return;
      setState(() => _selectedCardIndex = 0);
    }

    _cardNumberController.clear();
    _expiryDateController.clear();
    _cvcController.clear();
    _cardHolderNameController.clear();
    _cardNameController.clear();
  }

  void _showEditAddressSheet(Map<String, String> address, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddressEditSheet(
        type: 'Adres',
        initialData: address,
        onSave: (updatedAddress) async {
          final appState = Provider.of<AppState>(context, listen: false);
          await appState.updateDeliveryAddress(index, updatedAddress);
          if (!mounted) return;
          setState(() => _selectedAddressIndex = index);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Adres güncellendi.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        },
        onDelete: () {
          final appState = Provider.of<AppState>(context, listen: false);
          appState.removeDeliveryAddress(index).then((_) {
            if (!mounted) return;
            setState(() {
              if (_selectedAddressIndex >= appState.deliveryAddresses.length) {
                _selectedAddressIndex = appState.deliveryAddresses.isEmpty
                    ? 0
                    : appState.deliveryAddresses.length - 1;
              }
            });
          });
        },
      ),
    );
  }

  void _showEditPaymentSheet(Map<String, String> card, int index) {
    _cardNumberController.text = card['number'] ?? '';
    _expiryDateController.text = card['expiry'] ?? '';
    _cvcController.clear();
    _cardHolderNameController.text = card['holder'] ?? '';
    _cardNameController.text = card['name'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kartı Düzenle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPaymentForm(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _addNewCard(editIndex: index);
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Kartı Güncelle'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddAddressSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddressEditSheet(
        type: 'Adres',
        onSave: (Map<String, String> address) async {
          final appState = Provider.of<AppState>(context, listen: false);
          await appState.addDeliveryAddress(address);
          if (!mounted) return;

          setState(() {
            _selectedAddressIndex = appState.deliveryAddresses.length - 1;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Adres başarıyla eklendi!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        },
        onDelete: () {},
      ),
    );
  }

  Future<void> _showCheckoutFeedback(
    String message, {
    bool isError = true,
    String? title,
  }) async {
    if (!mounted) return;
    final isWebLayout = MediaQuery.of(context).size.width >= 900;
    if (isWebLayout) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title ?? (isError ? 'İşlem Tamamlanamadı' : 'Bilgi')),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _completeOrder() async {
    if (_isPlacingOrder) return;
    debugPrint('Checkout CTA tapped');
    final appState = Provider.of<AppState>(context, listen: false);
    final hasAddresses = appState.deliveryAddresses.isNotEmpty;
    final hasCards = appState.savedCards.isNotEmpty;
    final userId = appState.currentUser?['uid']?.toString();
    final isGuestUser = UserIdentity.isGuest(appState.currentUser);

    if (isGuestUser) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Giriş Yapın'),
          content: const Text(
            'Siparişi tamamlamak için gerçek kullanıcı hesabıyla giriş yapmanız gerekiyor.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
              },
              child: const Text('Giriş Yap'),
            ),
          ],
        ),
      );
      return;
    }

    if (!hasAddresses ||
        !hasCards ||
        !_acceptTerms ||
        userId == null ||
        userId.isEmpty) {
      final missingItems = <String>[
        if (!hasAddresses) 'teslimat adresi',
        if (!hasCards) 'kayıtlı kart',
        if (!_acceptTerms) 'sözleşme onayı',
        if (userId == null || userId.isEmpty) 'oturum bilgisi',
      ];
      await _showCheckoutFeedback(
        'Devam etmeden önce şunları tamamlayın: ${missingItems.join(', ')}.',
      );
      return;
    }

    final safeIndex =
        (_selectedAddressIndex >= 0 &&
            _selectedAddressIndex < appState.deliveryAddresses.length)
        ? _selectedAddressIndex
        : 0;

    final selectedAddress = Map<String, dynamic>.from(
      appState.deliveryAddresses[safeIndex],
    );
    final safeCardIndex =
        (_selectedCardIndex >= 0 &&
            _selectedCardIndex < appState.savedCards.length)
        ? _selectedCardIndex
        : 0;
    final selectedCard = Map<String, dynamic>.from(
      appState.savedCards[safeCardIndex],
    );
    await appState.ensureCartProductIdsResolved();
    if (!mounted) return;
    final normalizedSelectedProducts = widget.selectedProducts
        .map((source) => Map<String, dynamic>.from(source))
        .toList(growable: false);
    for (final product in normalizedSelectedProducts) {
      final existingProductId = product['productId']?.toString().trim();
      if ((existingProductId ?? '').isNotEmpty) continue;
      final productObject = product['productObject'];
      String? name = product['name']?.toString().trim();
      String? brand;
      String? storeName = product['storeName']?.toString().trim();
      try {
        name ??= (productObject as dynamic).name?.toString().trim();
      } catch (_) {}
      try {
        brand = (productObject as dynamic).brand?.toString().trim();
      } catch (_) {}
      try {
        storeName ??= (productObject as dynamic).store?.toString().trim();
      } catch (_) {}
      if ((name ?? '').isEmpty || (brand ?? '').isEmpty) continue;
      for (final cartItem in appState.cart) {
        final cartProductId = cartItem.productId?.trim() ?? '';
        if (cartProductId.isEmpty) continue;
        final sameName =
            cartItem.name.trim().toLowerCase() == name!.trim().toLowerCase();
        final sameBrand =
            cartItem.brand.trim().toLowerCase() == brand!.trim().toLowerCase();
        if (!sameName || !sameBrand) continue;
        if ((storeName ?? '').isNotEmpty &&
            (cartItem.store ?? '').trim().toLowerCase() !=
                storeName!.trim().toLowerCase()) {
          continue;
        }
        product['productId'] = cartProductId;
        product['sellerId'] ??= cartItem.sellerId;
        try {
          product['productObject'] = (productObject as dynamic).copyWith(
            productId: cartProductId,
            sellerId: cartItem.sellerId,
            store: cartItem.store,
          );
        } catch (_) {}
        break;
      }
    }
    final hasInvalidItems = normalizedSelectedProducts.any((product) {
      final productId = product['productId']?.toString().trim();
      final productObject = product['productObject'];
      String? objectProductId;
      try {
        objectProductId = (productObject as dynamic).productId
            ?.toString()
            .trim();
      } catch (_) {}
      return (productId ?? objectProductId ?? '').isEmpty;
    });
    if (hasInvalidItems) {
      await _showCheckoutFeedback(
        'Bazi sepet urunlerinde urun kimligi eksik. Lutfen urunu sepetten silip yeniden ekleyin.',
      );
      return;
    }

    setState(() => _isPlacingOrder = true);
    try {
      final orderData = await OrderService.instance.createOrderFromCheckout(
        userId: userId,
        selectedProducts: normalizedSelectedProducts,
        totalAmount: widget.totalPrice,
        deliveryAddress: selectedAddress,
        paymentCard: selectedCard,
        deliveryType: _selectedDeliveryType == 0 ? 'fast' : 'standard',
        deliverySlot: _selectedDeliveryType == 0
            ? '${_selectedFastDate.toIso8601String()}|$_selectedFastTime'
            : _selectedStandardDate.toIso8601String(),
      );

      appState.clearCart();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderConfirmationPage(
            totalPrice: widget.totalPrice,
            orderData: orderData,
            purchasedProducts: normalizedSelectedProducts,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final normalized = e.toString().replaceFirst('Exception: ', '');
      await _showCheckoutFeedback(normalized);
    } finally {
      if (mounted) {
        setState(() => _isPlacingOrder = false);
      }
    }
  }

  void _showAddPaymentSheet() {
    _cardNumberController.clear();
    _expiryDateController.clear();
    _cvcController.clear();
    _cardHolderNameController.clear();
    _cardNameController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Yeni Kart Ekle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildPaymentForm(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _addNewCard();
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Kart Ekle',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentForm() {
    return Column(
      children: [
        TextField(
          controller: _cardNumberController,
          maxLength: 19,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CardNumberFormatter(),
          ],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Kart Numarası',
            hintText: '0000 0000 0000 0000',
            counterText: "",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.credit_card),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _expiryDateController,
                maxLength: 5,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  DateFormatter(),
                ],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Ay / Yıl',
                  hintText: 'AA/YY',
                  counterText: "",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _cvcController,
                maxLength: 3,
                decoration: InputDecoration(
                  labelText: 'CVC',
                  hintText: '***',
                  counterText: "",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: const Icon(Icons.help_outline, size: 18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _cardHolderNameController,
          maxLength: 30,
          decoration: InputDecoration(
            labelText: 'Kart Üzerindeki İsim',
            hintText: 'Ad Soyad',
            counterText: "",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _cardNameController,
          decoration: InputDecoration(
            labelText: 'Kart Adı',
            hintText: 'Örn: Bonus Kartım',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildProductImage(
    Map<String, dynamic> product, {
    BoxFit fit = BoxFit.contain,
  }) {
    final dynamic source =
        product['image'] ??
        product['image_url'] ??
        product['product_image_url'];
    final String? imagePath = source?.toString();
    if (imagePath == null || imagePath.isEmpty) {
      return const Center(
        child: Icon(Icons.image, color: Colors.grey, size: 30),
      );
    }

    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        fit: fit,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.image, color: Colors.grey, size: 30),
        ),
      );
    }

    return Image.asset(
      imagePath,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.image, color: Colors.grey, size: 30)),
    );
  }

  String _formatDate(DateTime date) {
    final List<String> months = [
      '',
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
    final List<String> days = [
      '',
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    return '${days[date.weekday]}\n${date.day} ${months[date.month]}';
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 900;
    if (isWeb) {
      return _buildWebView();
    }
    // eski mobil tasarım
    final appState = Provider.of<AppState>(context);
    final hasAddresses = appState.deliveryAddresses.isNotEmpty;
    final currentAddress = hasAddresses
        ? appState.deliveryAddresses[(_selectedAddressIndex <
                  appState.deliveryAddresses.length)
              ? _selectedAddressIndex
              : 0]
        : null;
    final hasCards = appState.savedCards.isNotEmpty;
    final currentCard = hasCards
        ? appState.savedCards[(_selectedCardIndex < appState.savedCards.length)
              ? _selectedCardIndex
              : 0]
        : null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Güvenli Alışveriş',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    title: 'Teslim Adresim',
                    trailing: TextButton(
                      onPressed: _showAddAddressSheet,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      child: const Text(
                        'Yeni Ekle',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Radio(
                              value: true,
                              groupValue: true,
                              onChanged: (value) {},
                              activeColor: AppColors.primary,
                            ),
                            const Text(
                              'Adresime Gönder',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        if (hasAddresses && currentAddress != null)
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        currentAddress['title'] ?? 'Adres',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => _showEditAddressSheet(
                                        currentAddress,
                                        _selectedAddressIndex,
                                      ),
                                      child: const Text(
                                        'Düzenle',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 26),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentAddress['detail'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        currentAddress['phone'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: _showAddAddressSheet,
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  style: BorderStyle.solid,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_location_alt_outlined,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      'Teslimat adresi eklemek için tıklayın',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (hasAddresses)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.receipt_outlined,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Fatura Bilgilerim ; ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {},
                                  child: Text(
                                    currentAddress?['title'] ?? 'Adres',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {},
                                  child: const Text(
                                    'Düzenle',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 8,
                    color: Color(0xFFF5F5F5),
                  ),
                  _buildSection(
                    title: 'Ödeme Seçenekleri',
                    trailing: TextButton(
                      onPressed: _showAddPaymentSheet,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      child: const Text(
                        'Yeni Ekle',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          if (hasCards && currentCard != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentCard['name'] ?? 'Kartım',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              currentCard['number'] ??
                                                  '**** ****',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 24,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  'M',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _showEditPaymentSheet(
                                      currentCard,
                                      _selectedCardIndex,
                                    ),
                                    child: const Text(
                                      'Düzenle',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: _showAddPaymentSheet,
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    style: BorderStyle.solid,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.credit_card,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Ödeme yöntemi eklemek için tıklayın',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _selectedPayment = 'single';
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Radio<String>(
                                    value: 'single',
                                    groupValue: _selectedPayment,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedPayment = value!;
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                  ),
                                  Expanded(
                                    child: Text(
                                      'Tek Çekim (Peşin)',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  Text(
                                    '${(widget.totalPrice >= 300 ? widget.totalPrice : widget.totalPrice + 59.99).toStringAsFixed(2)} TL',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 32, bottom: 12),
                            child: Text(
                              'Ödenecek tutarın tamamı Karttan çekilecektir',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(
                              left: 16,
                              bottom: 8,
                            ),
                            leading: const Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            title: const Text(
                              'Diğer Ödeme Seçenekleri',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            children: const [
                              Text(
                                'Anında Havale ,çoklu Kredi Kartı , Dijital Ödeme',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.credit_card,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Taksitli Alışveriş',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Ayda ${(widget.totalPrice / 12).toStringAsFixed(2)} TL den Başlayan 12 taksitle',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 8,
                    color: Color(0xFFF5F5F5),
                  ),
                  _buildSection(
                    title: 'Teslimat Seçeneklerim',
                    trailing: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      child: const Text(
                        'Sepeti Düzenle',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Seçili Ürünler (${widget.selectedProducts.length})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...widget.selectedProducts.map(
                            (product) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: _buildProductImage(
                                            product,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product['name'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Kurye Teslimat (Mesafeye Bağlı)',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const Text(
                                                      'Tahmini teslim: Bugün',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  '${product['price']} TL',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (product['services'] != null &&
                                      (product['services'] as List).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Divider(height: 1),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Ekstra Seçenekler:',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          ...((product['services'] as List)
                                                  .cast<String>())
                                              .map(
                                                (service) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 4,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        service.contains(
                                                              'Parça',
                                                            )
                                                            ? Icons.build
                                                            : service.contains(
                                                                'Kargo',
                                                              )
                                                            ? Icons
                                                                  .local_shipping
                                                            : Icons
                                                                  .check_circle,
                                                        size: 14,
                                                        color:
                                                            AppColors.primary,
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Expanded(
                                                        child: Text(
                                                          service,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 10,
                                                                color:
                                                                    Colors.grey,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 8,
                    color: Color(0xFFF5F5F5),
                  ),
                  _buildSection(
                    title: 'İndirim Kuponu',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.centerLeft,
                              child: TextField(
                                controller: _couponController,
                                decoration: const InputDecoration(
                                  hintText: 'Kupon Kodu Giriniz',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              if (_couponController.text.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${_couponController.text} uygulandı!',
                                    ),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              fixedSize: const Size(80, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text(
                              'Uygula',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 8,
                    color: Color(0xFFF5F5F5),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      children: [
                        _buildExpandableTile('Cayma Hakkı'),
                        _buildExpandableTile('Ön Bilgilendirme Formu'),
                        _buildExpandableTile('Mesafeli Satış sözleşmesi'),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _acceptTerms,
                          onChanged: (value) {
                            setState(() {
                              _acceptTerms = value!;
                            });
                          },
                          activeColor: AppColors.primary,
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Ön Bilgilendirme formunu ve mesafeli satış sözleşmesini, cayma hakkını onaylıyorum.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showPriceDetails(context),
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.keyboard_arrow_up,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Toplam:',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '${(widget.totalPrice >= 300 ? widget.totalPrice : widget.totalPrice + 59.99).toStringAsFixed(2)} TL',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '%10 İndirimli',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isPlacingOrder
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          await _completeOrder();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isPlacingOrder
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Alışverişi Tamamla',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WEB LAYOUT METHODS
  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(onSearch: (q) {}),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: 40,
                    left: 24,
                    right: 24,
                    bottom: 24,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LEFT COLUMN (Forms) - SCROLLABLE
                      Expanded(
                        flex: 7,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Stepper
                                Row(
                                  children: [
                                    _buildStepItem('Sepetim', true, true, '1'),
                                    _buildStepLine(true),
                                    _buildStepItem(
                                      'Teslimat & Ödeme',
                                      true,
                                      false,
                                      '2',
                                    ),
                                    _buildStepLine(false),
                                    _buildStepItem(
                                      'Sipariş Onayı',
                                      false,
                                      false,
                                      '3',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                const Text(
                                  'Güvenli Alışveriş',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                _buildWebAddressSection(),
                                const SizedBox(height: 24),
                                _buildWebDeliverySection(),
                                const SizedBox(height: 24),
                                _buildWebPaymentSection(),
                                const SizedBox(height: 24),
                                _buildWebBottomAgreements(),
                                const SizedBox(height: 40),
                                const WebFooter(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                      // RIGHT COLUMN (Summary) - FIXED
                      Expanded(
                        flex: 4,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              const SizedBox(height: 100),
                              _buildWebSummaryCard(),
                              const SizedBox(height: 24),
                              _buildWebAgreementSection(),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isPlacingOrder
                                      ? null
                                      : () async {
                                          FocusScope.of(context).unfocus();
                                          await _completeOrder();
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isPlacingOrder
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Siparişi Onayla ve Öde',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildStepItem(
    String title,
    bool isActive,
    bool isCompleted,
    String step,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isCompleted || isActive ? AppColors.primary : Colors.white,
            shape: BoxShape.circle,
            border: isCompleted || isActive
                ? null
                : Border.all(color: Colors.grey.shade300),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    step,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? Colors.black87 : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(bool isActive) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: isActive ? AppColors.primary : Colors.grey.shade200,
      ),
    );
  }

  Widget _buildWebBottomAgreements() {
    return Column(
      children: [
        _buildWebAgreementTile('Ön bilgilendirme formu'),
        const SizedBox(height: 12),
        _buildWebAgreementTile('Mesafeli satış sözleşmesi'),
      ],
    );
  }

  Widget _buildWebAgreementTile(String title) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        trailing: const Icon(Icons.keyboard_arrow_down, color: Colors.orange),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        childrenPadding: const EdgeInsets.all(20),
        children: const [
          Text(
            'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildWebContent() {
    // Deprecated method, kept for reference or removed if unused.
    // Logic moved directly to _buildWebView
    return const SizedBox.shrink();
  }

  Widget _buildWebAddressSection() {
    final appState = Provider.of<AppState>(context);
    final hasAddresses = appState.deliveryAddresses.isNotEmpty;
    final currentAddress = hasAddresses
        ? appState.deliveryAddresses[(_selectedAddressIndex <
                  appState.deliveryAddresses.length)
              ? _selectedAddressIndex
              : 0]
        : null;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Teslimat Adresi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _showAddAddressSheet,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Yeni Adres Ekle'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (hasAddresses && currentAddress != null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primary.withOpacity(0.02),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Radio(
                    value: true,
                    groupValue: true,
                    onChanged: (v) {},
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.home_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              currentAddress['title'] ?? 'Adres',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
                              ),
                              child: Text(
                                'Varsayılan',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          currentAddress['name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentAddress['detail'] ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          currentAddress['phone'] ?? '',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showEditAddressSheet(
                      currentAddress,
                      _selectedAddressIndex,
                    ),
                    child: const Text('Düzenle'),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade200,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz kayıtlı bir teslimat adresiniz bulunmuyor.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddAddressSheet,
                    icon: const Icon(Icons.add),
                    label: const Text('Adres Ekle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Billing Address Option
          if (hasAddresses)
            Row(
              children: [
                Checkbox(
                  value: true,
                  onChanged: (v) {},
                  activeColor: AppColors.primary,
                ),
                const Text('Fatura adresim teslimat adresimle aynı olsun'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildWebPaymentSection() {
    final appState = Provider.of<AppState>(context);

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ödeme Yöntemi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          // Payment Section Layout
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;

              Widget cardVisual = Container(
                width: 320,
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.grey.shade900, Colors.black],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Image.network(
                          'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2a/Mastercard-logo.svg/1280px-Mastercard-logo.svg.png',
                          height: 32,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.credit_card,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const Icon(Icons.wifi, color: Colors.white70, size: 24),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _cardNumberController.text.isEmpty
                            ? '**** **** **** ****'
                            : _cardNumberController.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Kart Sahibi',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _cardHolderNameController.text.isEmpty
                                      ? 'AD SOYAD'
                                      : _cardHolderNameController.text
                                            .toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'SKT',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _expiryDateController.text.isEmpty
                                  ? 'AA/YY'
                                  : _expiryDateController.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );

              Widget savedCards = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kayıtlı Kartlarım',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (appState.savedCards.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Henüz kayıtlı kartınız bulunmuyor.',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ...appState.savedCards.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildSavedCardItem(
                          entry.value['name'] ?? '',
                          entry.value['number'] ?? '',
                          entry.value['type'] ?? '',
                          index: entry.key,
                        ),
                      ),
                    ),
                ],
              );

              Widget leftColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tab moved here - fixed width aligned left
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _paymentTab = 'card'),
                          child: _buildPaymentTab(
                            Icons.credit_card,
                            'Kredi / Banka Kartı',
                            _paymentTab == 'card',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _paymentTab = 'wallet'),
                          child: _buildPaymentTab(
                            Icons.account_balance_wallet,
                            'Cüzdan',
                            _paymentTab == 'wallet',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Form
                  if (_paymentTab == 'card') ...[
                    TextField(
                      controller: _cardNumberController,
                      maxLength: 19,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        CardNumberFormatter(),
                      ],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Kart Numarası',
                        hintText: '0000 0000 0000 0000',
                        counterText: "",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.credit_card),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _expiryDateController,
                            maxLength: 5,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              DateFormatter(),
                            ],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Ay / Yıl',
                              hintText: 'AA/YY',
                              counterText: "",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: TextField(
                            controller: _cvcController,
                            maxLength: 3,
                            decoration: InputDecoration(
                              labelText: 'CVC',
                              hintText: '***',
                              counterText: "",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              suffixIcon: const Icon(
                                Icons.help_outline,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _cardHolderNameController,
                      maxLength: 30,
                      decoration: InputDecoration(
                        labelText: 'Kart Üzerindeki İsim',
                        hintText: 'Ad Soyad',
                        counterText: "",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _cardNameController,
                      decoration: InputDecoration(
                        labelText: 'Kart Adı',
                        hintText: 'Örn: Bonus Kartım',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _addNewCard,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Kart Ekle',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    savedCards,
                  ] else ...[
                    // Wallet content placeholder
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              size: 48,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Cüzdanınızda bakiye bulunmamaktadır.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: leftColumn),
                    const SizedBox(width: 48),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          const SizedBox(height: 40), // Visual moved down
                          Align(
                            alignment: Alignment.centerRight,
                            child: cardVisual,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    leftColumn,
                    const SizedBox(height: 24),
                    if (_paymentTab == 'card')
                      Center(child: SizedBox(width: 320, child: cardVisual)),
                  ],
                );
              }
            },
          ),

          const SizedBox(height: 24),
          // Installment Options
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Radio(
                      value: 'single',
                      groupValue: _selectedPayment,
                      onChanged: (v) {},
                      activeColor: AppColors.primary,
                    ),
                    const Text(
                      'Tek Çekim',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '${(widget.totalPrice * 0.90).toStringAsFixed(2)} TL',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    Radio(
                      value: 'installment',
                      groupValue: _selectedPayment,
                      onChanged: (v) {},
                      activeColor: AppColors.primary,
                    ),
                    const Text('Taksitli Ödeme Seçenekleri'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedCardItem(
    String bankName,
    String number,
    String type, {
    required int index,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(
          color: _selectedCardIndex == index
              ? AppColors.primary
              : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Radio<int>(
            value: index,
            groupValue: _selectedCardIndex,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _selectedCardIndex = v);
            },
            activeColor: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Icon(Icons.credit_card, color: Colors.grey.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bankName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  number,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: () {
              final appState = Provider.of<AppState>(context, listen: false);
              _showEditPaymentSheet(appState.savedCards[index], index);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final appState = Provider.of<AppState>(context, listen: false);
              await appState.removeSavedCard(index);
              if (!mounted) return;
              if (_selectedCardIndex >= appState.savedCards.length) {
                setState(
                  () => _selectedCardIndex = appState.savedCards.isEmpty
                      ? 0
                      : appState.savedCards.length - 1,
                );
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTab(IconData icon, String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.grey.shade50,
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: isSelected ? AppColors.primary : Colors.grey.shade600,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.primary : Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWebDeliverySection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Teslimat Seçenekleri',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hızlı Teslimat
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDeliveryType = 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedDeliveryType == 0
                          ? AppColors.primary.withOpacity(0.05)
                          : Colors.white,
                      border: Border.all(
                        color: _selectedDeliveryType == 0
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        width: _selectedDeliveryType == 0 ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.flash_on,
                              color: _selectedDeliveryType == 0
                                  ? AppColors.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hızlı Teslimat',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _selectedDeliveryType == 0
                                          ? AppColors.primary
                                          : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    'Gün ve saat seçimi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedDeliveryType == 0
                                          ? AppColors.primary
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Radio(
                              value: 0,
                              groupValue: _selectedDeliveryType,
                              onChanged: (v) =>
                                  setState(() => _selectedDeliveryType = v!),
                              activeColor: AppColors.primary,
                            ),
                          ],
                        ),
                        if (_selectedDeliveryType == 0) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          const Text(
                            'Teslimat Günü',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildDateTabSelector(
                            startDate: DateTime.now(),
                            daysCount: 7,
                            selectedDate: _selectedFastDate,
                            onSelect: (date) =>
                                setState(() => _selectedFastDate = date),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Teslimat Saati',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildTimeSelector(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Standart Kargo
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDeliveryType = 1),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedDeliveryType == 1
                          ? AppColors.primary.withOpacity(0.05)
                          : Colors.white,
                      border: Border.all(
                        color: _selectedDeliveryType == 1
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        width: _selectedDeliveryType == 1 ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_shipping_outlined,
                              color: _selectedDeliveryType == 1
                                  ? AppColors.primary
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Standart Kargo',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _selectedDeliveryType == 1
                                          ? AppColors.primary
                                          : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '3+ gün sonrası',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _selectedDeliveryType == 1
                                          ? AppColors.primary
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Radio(
                              value: 1,
                              groupValue: _selectedDeliveryType,
                              onChanged: (v) =>
                                  setState(() => _selectedDeliveryType = v!),
                              activeColor: AppColors.primary,
                            ),
                          ],
                        ),
                        if (_selectedDeliveryType == 1) ...[
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 12),
                          const Text(
                            'Teslimat Günü',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildDateTabSelector(
                            startDate: DateTime.now().add(
                              const Duration(days: 3),
                            ),
                            daysCount: 14,
                            selectedDate: _selectedStandardDate,
                            onSelect: (date) =>
                                setState(() => _selectedStandardDate = date),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateTabSelector({
    required DateTime startDate,
    required int daysCount,
    required DateTime selectedDate,
    required Function(DateTime) onSelect,
  }) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: daysCount,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = startDate.add(Duration(days: index));
          final isSelected =
              date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;

          return GestureDetector(
            onTap: () => onSelect(date),
            child: Container(
              width: 80,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _formatDate(date).split('\n')[0],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(date).split('\n')[1],
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _timeSlots.map((time) {
        final isSelected = time == _selectedFastTime;
        return GestureDetector(
          onTap: () => setState(() => _selectedFastTime = time),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.white,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.primary : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWebSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sipariş Özeti',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Düzenle',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Products List (Mini)
          ...widget.selectedProducts
              .take(3)
              .map(
                (product) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildProductImage(product, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${product['quantity'] ?? 1} Adet',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${product['price']} TL',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),

          if (widget.selectedProducts.length > 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '+ ${widget.selectedProducts.length - 3} ürün daha',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),

          // Coupon Code Section
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    decoration: const InputDecoration(
                      hintText: 'İndirim Kodu',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (_couponController.text.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${_couponController.text} kodu uygulandı!',
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Uygula',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Dashed Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boxWidth = constraints.constrainWidth();
                const dashWidth = 8.0;
                final dashHeight = 1.0;
                final dashCount = (boxWidth / (2 * dashWidth)).floor();
                return Flex(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  direction: Axis.horizontal,
                  children: List.generate(dashCount, (_) {
                    return SizedBox(
                      width: dashWidth,
                      height: dashHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.grey.shade300),
                      ),
                    );
                  }),
                );
              },
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ara Toplam', style: TextStyle(color: Colors.grey)),
              Text(
                '${widget.totalPrice.toStringAsFixed(2)} TL',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kargo', style: TextStyle(color: Colors.grey)),
              const Text(
                'Bedava',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('İndirim', style: TextStyle(color: Colors.grey)),
              Text(
                '-${(widget.totalPrice * 0.10).toStringAsFixed(2)} TL',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Toplam Tutar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${(widget.totalPrice * 0.90).toStringAsFixed(2)} TL',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  'Güvenli Ödeme - 256 Bit SSL',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebAgreementSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acceptTerms,
                onChanged: (v) => setState(() => _acceptTerms = v!),
                activeColor: AppColors.primary,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Ön Bilgilendirme Formu',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(text: ' ve '),
                        TextSpan(
                          text: 'Mesafeli Satış Sözleşmesi',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(text: '\'ni okudum ve onaylıyorum.'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (trailing != null) ...[const Spacer(), trailing],
              ],
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildExpandableTile(String title) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.keyboard_arrow_down, size: 20),
      children: const [
        Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'İçerik burada görünecek...',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  void _showPriceDetails(BuildContext context) {
    const double shippingCost = 59.99;
    final bool isFreeShipping = widget.totalPrice >= 300;
    final double finalTotal = isFreeShipping
        ? widget.totalPrice
        : widget.totalPrice + shippingCost;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ara Toplam
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ara Toplam',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  Text(
                    '${widget.totalPrice.toStringAsFixed(2)} TL',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Kargo
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Kargo',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  Text(
                    '${shippingCost.toStringAsFixed(2)} TL',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Kargo İndirimi
              if (isFreeShipping)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '300 TL ve Üzeri Kargo Bedava (Satıcı Karşılar)',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    Text(
                      '-${shippingCost.toStringAsFixed(2)} TL',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              // Toplam
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Toplam:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${finalTotal.toStringAsFixed(2)} TL',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (newText.length > 16) {
      newText = newText.substring(0, 16);
    }

    var buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      buffer.write(newText[i]);
      var index = i + 1;
      if (index % 4 == 0 && index != newText.length) {
        buffer.write(' ');
      }
    }

    String result = buffer.toString();

    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

class DateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (newText.length > 4) {
      newText = newText.substring(0, 4);
    }

    var buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      buffer.write(newText[i]);
      var index = i + 1;
      if (index == 2 && index != newText.length) {
        buffer.write('/');
      }
    }

    String result = buffer.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}
