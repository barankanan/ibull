import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../features/seller/product_import/models/imported_product.dart';
import '../../../features/seller/product_import/services/product_import_service.dart';
import '../../../features/seller/product_import/services/product_quality_service.dart';

/// Gelişmiş Ürün İçe Aktarma Merkezi Ekranı / Modalı
class ProductImportCenterModal extends StatefulWidget {
  const ProductImportCenterModal({super.key});

  static Future<bool?> show(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (BuildContext context) => const ProductImportCenterModal(),
      ),
    );
  }

  @override
  State<ProductImportCenterModal> createState() => _ProductImportCenterModalState();
}

class _ProductImportCenterModalState extends State<ProductImportCenterModal> {
  final ProductImportService _service = ProductImportService();
  final ProductQualityService _qualityService = const ProductQualityService();

  late final TextEditingController _urlsController;
  late final FocusNode _urlFocusNode;

  List<ImportedProductData> _products = [];
  bool _isScanning = false;
  bool _isImporting = false;
  String _scanProgressMessage = '';
  int _currentProgress = 0;
  int _totalProgress = 0;
  String? _errorMessage;

  String _filterStatus = 'all'; // all, high, missing, selected

  @override
  void initState() {
    super.initState();
    _urlsController = TextEditingController();
    _urlFocusNode = FocusNode();
    _isScanning = false;
    _isImporting = false;

    // Modal açıldığında odağı doğrudan URL giriş alanına ver
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _urlFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _urlsController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        final currentText = _urlsController.text;
        final selection = _urlsController.selection;
        final pasteText = data.text!;
        if (selection.isValid && selection.start >= 0 && selection.end >= selection.start) {
          final newText = currentText.replaceRange(selection.start, selection.end, pasteText);
          _urlsController.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: selection.start + pasteText.length),
          );
        } else {
          _urlsController.text = currentText.isEmpty ? pasteText : '$currentText\n$pasteText';
          _urlsController.selection = TextSelection.collapsed(offset: _urlsController.text.length);
        }
        if (mounted) {
          setState(() => _errorMessage = null);
          _urlFocusNode.requestFocus();
        }
      }
    } catch (_) {}
  }

  void _selectAllText() {
    _urlsController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _urlsController.text.length,
    );
  }

  Future<void> _startScanning() async {
    final rawText = _urlsController.text.trim();
    if (rawText.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen analiz edilecek en az bir ürün URL\'si girin.';
      });
      return;
    }

    final rawUrls = rawText
        .split(RegExp(r'[\n\r\s,]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (rawUrls.isEmpty) {
      setState(() {
        _errorMessage = 'Geçerli URL bulunamadı.';
      });
      return;
    }

    setState(() {
      _isScanning = true;
      _errorMessage = null;
      _currentProgress = 0;
      _totalProgress = rawUrls.length;
      _scanProgressMessage = 'Kaynak siteler taranıyor...';
    });

    try {
      final results = await _service.scanUrls(
        rawUrls,
        onProgress: (current, total, status) {
          if (!mounted) return;
          setState(() {
            _currentProgress = current;
            _totalProgress = total;
            _scanProgressMessage = status;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _products = results;
        _isScanning = false;
        if (results.isEmpty) {
          _errorMessage =
              'Girilen adreslerden ürün bilgisi çıkarılamadı. Lütfen desteklenen bir ürün sayfası URL\'si girdiğinizden emin olun.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _toggleSelectAll(bool select) {
    setState(() {
      _products = _products.map((p) => p.copyWith(isSelected: select)).toList();
    });
  }

  void _openBatchPriceMarkupDialog() {
    final selectedCount = _products.where((p) => p.isSelected).length;
    if (selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce düzenlenecek ürünleri seçin.')),
      );
      return;
    }

    final percentController = TextEditingController();
    final fixedController = TextEditingController();
    bool roundToInteger = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Toplu Fiyat Düzenleme ($selectedCount Ürün)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Seçilen ürünlerin satış fiyatlarını kaynak fiyata göre artırabilir veya sabit tutar ekleyebilirsiniz.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: percentController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Yüzdelik Artış / İndirim (%)',
                  hintText: 'Örn: 20 (%20 artış) veya -10',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.percent, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fixedController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Sabit Tutar Ekle (₺)',
                  hintText: 'Örn: 50 veya -20',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_lira, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Fiyatları tam sayıya yuvarla', style: TextStyle(fontSize: 14)),
                value: roundToInteger,
                onChanged: (val) => setDialogState(() => roundToInteger = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final double? percent = double.tryParse(percentController.text.trim());
                final double? fixed = double.tryParse(fixedController.text.trim());
                Navigator.pop(ctx);
                setState(() {
                  _products = _service.batchApplyPriceMarkup(
                    _products,
                    percent: percent,
                    fixedAmount: fixed,
                    roundToInteger: roundToInteger,
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$selectedCount ürünün fiyatı güncellendi.')),
                );
              },
              child: const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
  }

  void _openBatchCategoryDialog() {
    final selectedCount = _products.where((p) => p.isSelected).length;
    if (selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce kategori atanacak ürünleri seçin.')),
      );
      return;
    }

    String selectedMainCategory = ProductQualityService.standardMainCategories.first;
    final subCategoryController = TextEditingController(text: 'Diğer');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Toplu Kategori Belirle ($selectedCount Ürün)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedMainCategory,
                decoration: const InputDecoration(
                  labelText: 'Ana Kategori',
                  border: OutlineInputBorder(),
                ),
                items: ProductQualityService.standardMainCategories
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedMainCategory = val);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subCategoryController,
                decoration: const InputDecoration(
                  labelText: 'Alt Kategori',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final subCat = subCategoryController.text.trim();
                Navigator.pop(ctx);
                setState(() {
                  _products = _service.batchSetCategory(
                    _products,
                    mainCategory: selectedMainCategory,
                    subCategory: subCat.isNotEmpty ? subCat : 'Diğer',
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$selectedCount ürünün kategorisi güncellendi.')),
                );
              },
              child: const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
  }

  void _openEditSingleProductDialog(ImportedProductData product) {
    final titleController = TextEditingController(text: product.name);
    final brandController = TextEditingController(text: product.brand);
    final priceController = TextEditingController(text: product.price.toStringAsFixed(2));
    final stockController = TextEditingController(text: product.stock?.toString() ?? '');
    final skuController = TextEditingController(text: product.sku);
    final barcodeController = TextEditingController(text: product.barcode ?? '');
    final descController = TextEditingController(text: product.description);
    String selectedCategory = product.mainCategory.isNotEmpty &&
            ProductQualityService.standardMainCategories.contains(product.mainCategory)
        ? product.mainCategory
        : ProductQualityService.standardMainCategories.first;
    final subCatController = TextEditingController(text: product.subCategory);

    final List<ImportedProductVariant> editableVariants =
        product.realVariants.map((v) => v.copyWith()).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
            child: DefaultTabController(
              length: editableVariants.isNotEmpty ? 2 : 1,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                appBar: AppBar(
                  elevation: 0,
                  backgroundColor: Colors.white,
                  title: const Text('Ürün Detayını Düzenle', style: TextStyle(color: Colors.black87, fontSize: 18)),
                  iconTheme: const IconThemeData(color: Colors.black87),
                  bottom: editableVariants.isNotEmpty
                      ? const TabBar(
                          labelColor: Color(0xFF0F766E),
                          unselectedLabelColor: Colors.grey,
                          indicatorColor: Color(0xFF0F766E),
                          tabs: [
                            Tab(text: 'Temel Bilgiler'),
                            Tab(text: 'Varyasyonlar'),
                          ],
                        )
                      : null,
                ),
                body: TabBarView(
                  children: [
                    // Tab 1: Temel Bilgiler
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.stock == null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 22),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Kaynak sitede kesin stok adedi bulunamadı (Bilinmiyor). Satış güvenliğiniz için gerçek stok adedini girmeniz önemle tavsiye edilir. Belirtilmezse güvenli varsayılan olarak 0 stok ile Taslak kaydedilecektir.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          TextField(
                            controller: titleController,
                            decoration: const InputDecoration(
                              labelText: 'Ürün Adı *',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: brandController,
                                  decoration: const InputDecoration(
                                    labelText: 'Marka',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    labelText: 'Fiyat (₺) *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.currency_lira, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: stockController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: product.stock == null ? 'Stok (Bilinmiyor) *' : 'Stok Adedi',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: Icon(
                                      product.stock == null ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                                      size: 18,
                                      color: product.stock == null ? const Color(0xFFD97706) : null,
                                    ),
                                    hintText: product.stock == null ? 'Stok girin (0)' : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: selectedCategory,
                                  decoration: const InputDecoration(
                                    labelText: 'Ana Kategori *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: ProductQualityService.standardMainCategories
                                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() => selectedCategory = val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: subCatController,
                                  decoration: const InputDecoration(
                                    labelText: 'Alt Kategori',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: skuController,
                                  decoration: const InputDecoration(
                                    labelText: 'SKU / Ürün Kodu',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: barcodeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Barkod (EAN/GTIN)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: descController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Açıklama',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tab 2: Varyasyonlar
                    if (editableVariants.isNotEmpty)
                      Column(
                        children: [
                          if (editableVariants.any((v) => v.stock == null))
                            Container(
                              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Bazı varyasyonların stok adedi kaynakta bulunamadı (Bilinmiyor). Lütfen stok alanını doldurunuz; boş bırakılırsa 0 olarak aktarılacaktır.',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: editableVariants.length,
                              separatorBuilder: (context, index) => const Divider(),
                              itemBuilder: (ctx, vIndex) {
                                final v = editableVariants[vIndex];
                                final isUnknownStock = v.stock == null;
                                return Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isUnknownStock ? const Color(0xFFFFFBEB) : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                        border: isUnknownStock ? Border.all(color: const Color(0xFFFDE68A)) : null,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${vIndex + 1}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isUnknownStock ? const Color(0xFFD97706) : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(v.combinationTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          if (v.sku != null && v.sku!.isNotEmpty)
                                            Text('SKU: ${v.sku}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        initialValue: v.price.toStringAsFixed(2),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(labelText: 'Fiyat', isDense: true),
                                        onChanged: (val) {
                                          final p = double.tryParse(val);
                                          if (p != null) {
                                            editableVariants[vIndex] = v.copyWith(price: p);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        initialValue: v.stock != null ? v.stock.toString() : '',
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: isUnknownStock ? 'Stok (Girin) *' : 'Stok',
                                          labelStyle: TextStyle(
                                            color: isUnknownStock ? const Color(0xFFD97706) : null,
                                            fontWeight: isUnknownStock ? FontWeight.bold : null,
                                          ),
                                          hintText: isUnknownStock ? 'Bilinmiyor (0)' : null,
                                          isDense: true,
                                          border: isUnknownStock
                                              ? const OutlineInputBorder(
                                                  borderSide: BorderSide(color: Color(0xFFD97706)),
                                                )
                                              : null,
                                        ),
                                        onChanged: (val) {
                                          final s = int.tryParse(val);
                                          editableVariants[vIndex] = v.copyWith(
                                            stock: s,
                                            inStock: s != null ? s > 0 : v.inStock,
                                          );
                                          setDialogState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                bottomNavigationBar: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('İptal'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          final double? p = double.tryParse(priceController.text.trim());
                          final int? s = int.tryParse(stockController.text.trim());
                          final updated = product.copyWith(
                            name: titleController.text.trim(),
                            brand: brandController.text.trim(),
                            price: p ?? product.price,
                            stock: s ?? product.stock,
                            inStock: s != null ? s > 0 : product.inStock,
                            mainCategory: selectedCategory,
                            subCategory: subCatController.text.trim(),
                            sku: skuController.text.trim(),
                            barcode: barcodeController.text.trim().isNotEmpty
                                ? barcodeController.text.trim()
                                : null,
                            description: descController.text.trim(),
                            realVariants: editableVariants,
                          );
                          final quality = _qualityService.evaluateQuality(updated);
                          Navigator.pop(ctx);
                          setState(() {
                            final idx = _products.indexWhere((item) => item.id == product.id);
                            if (idx != -1) {
                              _products[idx] = updated.copyWith(quality: quality);
                            }
                          });
                        },
                        child: const Text('Kaydet'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _importSelectedToIbul() async {
    final selected = _products.where((p) => p.isSelected).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen aktarılacak en az bir ürün seçin.')),
      );
      return;
    }

    // Bilinmeyen stok uyarısı ve onay kontrolü
    final unknownStockProducts = selected.where((p) => !p.isStockKnown || p.realVariants.any((v) => !v.isStockKnown)).toList();
    if (unknownStockProducts.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.inventory_2_outlined, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text('Stok Bilgisi Uyarısı'),
            ],
          ),
          content: Text(
            'Seçtiğiniz ${unknownStockProducts.length} üründe kaynak siteden kesin stok adedi alınamadı.\n\n'
            'Mağazanızı korumak adına bilinmeyen stoklar 0 olarak işlenecek ve ürünler "Taslak" olarak kaydedilecektir.\n\n'
            'Dilerseniz şimdi geri dönüp "Düzenle" butonuyla stokları girebilir veya Taslak olarak aktarıma devam edebilirsiniz.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Geri Dön ve Düzenle'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Taslak Olarak Devam Et'),
            ),
          ],
        ),
      );

      if (proceed != true) return;
    }

    setState(() {
      _isImporting = true;
      _currentProgress = 0;
      _totalProgress = selected.length;
      _scanProgressMessage = 'İçe aktarım başlatılıyor...';
    });

    try {
      final result = await _service.importSelectedProducts(
        _products,
        onProgress: (current, total, status) {
          if (!mounted) return;
          setState(() {
            _currentProgress = current;
            _totalProgress = total;
            _scanProgressMessage = status;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _products = result.products;
      });

      _showImportSummaryDialog(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isImporting = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _showImportSummaryDialog(ProductImportExecutionResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              result.isAllSuccessful ? Icons.check_circle : Icons.warning_amber_rounded,
              color: result.isAllSuccessful ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Aktarım Tamamlandı'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Toplam ${result.totalCount} ürün için içe aktarma işlemi çalıştırıldı.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow(Icons.check_circle, 'Başarılı (Taslak Oluşturuldu):', '${result.successCount}', Colors.green),
            const SizedBox(height: 8),
            _buildSummaryRow(Icons.copy, 'Mükerrer (Atlanan):', '${result.duplicateCount}', Colors.amber.shade800),
            const SizedBox(height: 8),
            _buildSummaryRow(Icons.error, 'Başarısız:', '${result.failedCount}', Colors.red),
            if (result.failures.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Hata Detayları:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: result.failures.length,
                  itemBuilder: (_, i) {
                    final f = result.failures[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${f.productName}: ${f.error}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (result.hasFailures)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _importSelectedToIbul(); // Yeniden dene
              },
              child: const Text('Hatalıları Yeniden Dene'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true); // Paneli yenile
            },
            child: const Text('Tamamla ve Ürünlerime Dön'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String val, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
      ],
    );
  }

  List<ImportedProductData> get _filteredProducts {
    switch (_filterStatus) {
      case 'high':
        return _products.where((p) => p.quality.level == ProductQualityLevel.high).toList();
      case 'missing':
        return _products.where((p) => p.quality.level != ProductQualityLevel.high).toList();
      case 'selected':
        return _products.where((p) => p.isSelected).toList();
      default:
        return _products;
    }
  }

  @override
  Widget build(BuildContext context) {
    final highQualityCount = _products.where((p) => p.quality.level == ProductQualityLevel.high).length;
    final missingCount = _products.where((p) => p.quality.level != ProductQualityLevel.high).length;
    final selectedCount = _products.where((p) => p.isSelected).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gelişmiş Ürün İçe Aktarma Merkezi',
              style: TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'Harici sitelerden URL ile ürün tara, varyasyonları ön izle ve İBUL mağazana aktar',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. URL Giriş & Desteklenen Platformlar Kartı
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Desteklenen Kaynaklar Rozetleri
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildPlatformBadge('Trendyol', Icons.check_circle_outline, Colors.orange),
                    _buildPlatformBadge('Hepsiburada', Icons.check_circle_outline, Colors.deepOrange),
                    _buildPlatformBadge('Amazon', Icons.shield_outlined, Colors.amber.shade800),
                    _buildPlatformBadge('n11', Icons.shield_outlined, Colors.deepPurple),
                    _buildPlatformBadge('ÇiçekSepeti', Icons.shield_outlined, Colors.teal),
                    _buildPlatformBadge('Shopify Mağazaları', Icons.check_circle_outline, Colors.green),
                    _buildPlatformBadge('JSON-LD / Schema.org', Icons.verified_outlined, Colors.blue),
                    _buildPlatformBadge('Open Graph / Meta', Icons.data_object, Colors.teal),
                    _buildPlatformBadge('XML / Standart HTML', Icons.code, Colors.purple),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CallbackShortcuts(
                        bindings: <ShortcutActivator, VoidCallback>{
                          const SingleActivator(LogicalKeyboardKey.keyV, meta: true): _pasteFromClipboard,
                          const SingleActivator(LogicalKeyboardKey.keyV, control: true): _pasteFromClipboard,
                          const SingleActivator(LogicalKeyboardKey.keyA, meta: true): _selectAllText,
                          const SingleActivator(LogicalKeyboardKey.keyA, control: true): _selectAllText,
                        },
                        child: TextField(
                          controller: _urlsController,
                          focusNode: _urlFocusNode,
                          autofocus: true,
                          enabled: !_isScanning,
                          readOnly: false,
                          enableInteractiveSelection: true,
                          mouseCursor: SystemMouseCursors.text,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          maxLines: 2,
                          minLines: 2,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                          cursorColor: const Color(0xFF0F766E),
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                          contextMenuBuilder: (context, editableTextState) {
                            return AdaptiveTextSelectionToolbar.editableText(
                              editableTextState: editableTextState,
                            );
                          },
                          decoration: InputDecoration(
                            hintText:
                                'Ürün sayfası URL\'lerini girin (Birden fazla URL için yeni satır veya boşluk bırakın)...',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.blueGrey.shade300),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: Colors.grey.shade200),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            prefixIcon: const Icon(Icons.link, color: Color(0xFF0F766E)),
                            suffixIcon: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _urlsController,
                              builder: (context, value, _) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (value.text.isNotEmpty)
                                      IconButton(
                                        tooltip: 'Temizle',
                                        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                        onPressed: _isScanning
                                            ? null
                                            : () {
                                                _urlsController.clear();
                                                setState(() => _errorMessage = null);
                                              },
                                      ),
                                    IconButton(
                                      tooltip: 'Panodan Yapıştır (⌘+V)',
                                      icon: const Icon(Icons.content_paste_rounded, size: 18, color: Color(0xFF0F766E)),
                                      onPressed: _isScanning ? null : _pasteFromClipboard,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isScanning || _isImporting ? null : _startScanning,
                      icon: _isScanning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.search, size: 20),
                      label: Text(_isScanning ? 'Taranıyor...' : 'Ürünleri Tara'),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() => _errorMessage = null),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_isScanning || _isImporting) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: _totalProgress > 0 ? (_currentProgress / _totalProgress) : null,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF0F766E)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_scanProgressMessage ($_currentProgress/$_totalProgress)',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),

          // 2. Metrik Kartları (KPI Özetleri)
          if (_products.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _buildKpiCard('Bulunan Ürün', '${_products.length}', Colors.blue, Icons.inventory_2_outlined),
                  const SizedBox(width: 8),
                  _buildKpiCard('Yüksek Kalite', '$highQualityCount', Colors.green, Icons.verified_outlined),
                  const SizedBox(width: 8),
                  _buildKpiCard('Eksik / Düzenlenebilir', '$missingCount', Colors.orange, Icons.edit_note),
                  const SizedBox(width: 8),
                  _buildKpiCard('Seçilen', '$selectedCount', const Color(0xFF0F766E), Icons.check_box_outlined),
                ],
              ),
            ),

          // 3. Toolbar & Filtreler
          if (_products.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: selectedCount == _products.length,
                    tristate: selectedCount > 0 && selectedCount < _products.length,
                    activeColor: const Color(0xFF0F766E),
                    onChanged: (val) => _toggleSelectAll(val == true),
                  ),
                  Text(
                    selectedCount == _products.length ? 'Tümünü Kaldır' : 'Tümünü Seç',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 16),
                  PopupMenuButton<String>(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: OutlinedButton.icon(
                      onPressed: null, // PopupMenuButton tetikler
                      icon: const Icon(Icons.tune, size: 16),
                      label: const Text('Toplu Düzenle'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'price', child: Text('Fiyat Değişimi (+% veya +₺)')),
                      const PopupMenuItem(value: 'category', child: Text('Kategori Belirle')),
                    ],
                    onSelected: (val) {
                      if (val == 'price') _openBatchPriceMarkupDialog();
                      if (val == 'category') _openBatchCategoryDialog();
                    },
                  ),
                  const Spacer(),
                  // Filtre Chip'leri
                  _buildFilterChip('all', 'Tümü (${_products.length})'),
                  const SizedBox(width: 6),
                  _buildFilterChip('high', 'Yüksek Kalite ($highQualityCount)'),
                  const SizedBox(width: 6),
                  _buildFilterChip('missing', 'Eksik Veri ($missingCount)'),
                ],
              ),
            ),

          // 4. Ürün Listesi
          Expanded(
            child: _products.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.manage_search, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'Henüz taranmış ürün yok',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Yukarıdaki alana ürün URL\'si yapıştırıp "Ürünleri Tara" butonuna tıklayın.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (ctx, index) {
                      final product = _filteredProducts[index];
                      return _buildProductCard(product);
                    },
                  ),
          ),

          // 5. Alt Sticky Aksiyon Çubuğu
          if (_products.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3)),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$selectedCount / ${_products.length} ürün seçildi',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const Text(
                        'Ürünler ilk aktarımda mağazanıza "Taslak" olarak kaydedilir.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Vazgeç'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: selectedCount == 0 || _isImporting ? null : _importSelectedToIbul,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(_isImporting ? 'İçe Aktarılıyor...' : 'İBUL\'a Aktar ($selectedCount Ürün)'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlatformBadge(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _filterStatus == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.black87)),
      selected: selected,
      selectedColor: const Color(0xFF0F766E),
      backgroundColor: Colors.white,
      onSelected: (_) => setState(() => _filterStatus = key),
    );
  }

  Widget _buildProductCard(ImportedProductData product) {
    final score = product.quality.score;
    Color qualityColor = Colors.green;
    if (score < 50) {
      qualityColor = Colors.red;
    } else if (score < 80) {
      qualityColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: product.isSelected ? const Color(0xFF0F766E).withValues(alpha: 0.5) : Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Checkbox(
              value: product.isSelected,
              activeColor: const Color(0xFF0F766E),
              onChanged: (val) {
                setState(() {
                  final idx = _products.indexWhere((p) => p.id == product.id);
                  if (idx != -1) {
                    _products[idx] = product.copyWith(isSelected: val == true);
                  }
                });
              },
            ),
            // Görsel
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 72,
                height: 72,
                color: Colors.grey.shade100,
                child: product.mainImageUrl != null
                    ? Image.network(
                        product.mainImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
                      )
                    : const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 14),
            // Bilgiler
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (product.brand.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            product.brand,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Fiyat
                      Text(
                        '${product.price.toStringAsFixed(2)} ₺',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F766E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Kategori & Varyasyon Rozetleri
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildChip(
                        product.mainCategory.isNotEmpty ? product.mainCategory : 'Kategori Eksik',
                        icon: Icons.category_outlined,
                        color: product.mainCategory.isNotEmpty ? Colors.indigo : Colors.red,
                      ),
                      if (product.hasVariants)
                        _buildChip(
                          '${product.variantCount} Varyasyon',
                          icon: Icons.alt_route,
                          color: Colors.teal,
                        ),
                      _buildChip(
                        '${product.quality.score}% Kalite',
                        icon: Icons.speed,
                        color: qualityColor,
                      ),
                      _buildChip(
                        product.isStockKnown ? '${product.stock} Stok' : 'Stok Bilinmiyor (0)',
                        icon: product.isStockKnown ? Icons.inventory_2_outlined : Icons.help_outline,
                        color: product.isStockKnown ? Colors.blueGrey : Colors.amber.shade900,
                      ),
                      _buildChip(
                        product.adapterName,
                        icon: Icons.source,
                        color: Colors.grey.shade700,
                      ),
                    ],
                  ),
                  if (product.quality.missingFields.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      children: product.quality.missingFields.map((f) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '$f Eksik',
                            style: TextStyle(fontSize: 10, color: Colors.red.shade800),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  if (product.importStatus == ProductImportStatus.success)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('✓ İBUL Mağazanıza Taslak olarak aktarıldı.',
                          style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  if (product.importStatus == ProductImportStatus.duplicate)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('⚠️ ${product.errorMessage ?? "Mükerrer ürün (zaten mevcut)."}',
                          style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  if (product.importStatus == ProductImportStatus.failed)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('❌ Hata: ${product.errorMessage}',
                          style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Düzenle butonu
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
              tooltip: 'Ürünü Düzenle',
              onPressed: () => _openEditSingleProductDialog(product),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, {required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
