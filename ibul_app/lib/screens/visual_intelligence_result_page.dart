import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ibul_app/widgets/optimized_image.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../models/db_product.dart';
import '../services/database_helper.dart';
import '../services/visual_matcher_service.dart';
import '../widgets/product_card.dart';
import 'home_screen.dart';
import 'categories_page.dart';
import 'map_page.dart';
import 'cart_page.dart';
import '../core/app_state.dart';

enum VisualIntelligenceMode {
  parts, // Görsel Zeka (Parçalar/Aksesuarlar)
  similar, // Ürünü Arat (Benzer Ürünler)
}

class VisualIntelligenceResultPage extends StatefulWidget {
  final String detectedProduct;
  final String missingPart;
  final String? imagePath;
  final String? imageName;
  final VisualIntelligenceMode mode;

  const VisualIntelligenceResultPage({
    super.key,
    required this.detectedProduct,
    required this.missingPart,
    this.imagePath,
    this.imageName,
    this.mode = VisualIntelligenceMode
        .similar, // Default to similar for backward compatibility
  });

  @override
  State<VisualIntelligenceResultPage> createState() =>
      _VisualIntelligenceResultPageState();
}

class _VisualIntelligenceResultPageState
    extends State<VisualIntelligenceResultPage> {
  final AppState _appState = AppState();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TextEditingController _searchController = TextEditingController();
  List<Product> _relatedProducts = [];
  bool _isLoading = true;

  // Detected product info
  String _detectedName = 'Analiz Ediliyor...';
  String _detectedBrand = '';
  String _detectedSpecs = '';

  String _normalizeText(String value) {
    var t = value.toLowerCase().trim();
    t = t.replaceAll('ı', 'i').replaceAll('İ', 'i');
    t = t.replaceAll('ş', 's').replaceAll('Ş', 's');
    t = t.replaceAll('ğ', 'g').replaceAll('Ğ', 'g');
    t = t.replaceAll('ü', 'u').replaceAll('Ü', 'u');
    t = t.replaceAll('ö', 'o').replaceAll('Ö', 'o');
    t = t.replaceAll('ç', 'c').replaceAll('Ç', 'c');
    t = t.replaceAll(RegExp(r'[^a-z0-9\\s]'), ' ');
    t = t.replaceAll(RegExp(r'\\s+'), ' ');
    return t;
  }

  List<String> _tokenize(String value) {
    return _normalizeText(
      value,
    ).split(' ').where((e) => e.trim().length >= 2).toList();
  }

  List<String> _significantModelTokens(DBProduct product) {
    const ignored = {
      'hasarli',
      'hasarlı',
      'kirik',
      'kırık',
      'ikinci',
      'el',
      'urun',
      'ürün',
      'telefon',
      'mobil',
      'smart',
      'cihaz',
      'yenilenmis',
      'yenilenmiş',
      'gb',
      'ram',
      've',
      'ile',
      'icin',
      'için',
    };
    final tokens = _tokenize('${product.name} ${product.brand}');
    return tokens.where((t) {
      if (ignored.contains(t)) return false;
      if (RegExp(r'^\\d+$').hasMatch(t) && t.length < 2) return false;
      return true;
    }).toList();
  }

  List<String> _inferPartKeywords(DBProduct detected) {
    final imageHint = _normalizeText(widget.imagePath ?? '');
    final textHint = _normalizeText(
      '${widget.detectedProduct} ${widget.missingPart}',
    );
    final detectedText = _normalizeText(
      '${detected.name} ${detected.category} ${detected.subCategory ?? ''}',
    );
    final damagedPartsHint = _normalizeText(detected.damagedParts ?? '');
    final all = '$imageHint $textHint $detectedText';

    if (damagedPartsHint.isNotEmpty) {
      final inferred = _tokenize(
        damagedPartsHint,
      ).where((t) => t.length >= 3).take(6).toList();
      if (inferred.isNotEmpty) return inferred;
    }

    if (all.contains('telefon') ||
        all.contains('iphone') ||
        all.contains('samsung')) {
      if (all.contains('kirik') ||
          all.contains('crack') ||
          all.contains('screen') ||
          all.contains('ekran')) {
        return ['ekran', 'cam', 'lcd', 'display'];
      }
      return ['ekran', 'batarya', 'sarj', 'kablo', 'kilif', 'kamera'];
    }

    if (all.contains('bisiklet') || all.contains('bike')) {
      return ['zincir', 'fren', 'lastik', 'sele', 'pedal', 'vites'];
    }

    return ['parca', 'aksesuar', 'yedek', 'tamir'];
  }

  int _partsScore(
    DBProduct part,
    DBProduct detected,
    List<String> partKeywords,
  ) {
    final haystack = _normalizeText(
      '${part.name} ${part.category} ${part.subCategory ?? ''} ${part.keywords ?? ''} ${part.description ?? ''}',
    );
    final modelTokens = _significantModelTokens(detected);

    int score = 0;
    for (final t in modelTokens) {
      if (haystack.contains(t)) score += 3;
    }
    for (final t in partKeywords) {
      if (haystack.contains(_normalizeText(t))) score += 4;
    }
    if (part.brand == detected.brand) score += 2;
    if (part.isPart) score += 2;
    if ((part.category.toLowerCase().contains('aksesuar') ||
        (part.subCategory ?? '').toLowerCase().contains('aksesuar') ||
        part.category.toLowerCase().contains('parca') ||
        (part.subCategory ?? '').toLowerCase().contains('parca'))) {
      score += 2;
    }
    return score;
  }

  int _similarScore(DBProduct candidate, DBProduct detected) {
    int score = 0;
    if (candidate.category == detected.category) {
      score += 4;
    }
    if (candidate.subCategory != null &&
        candidate.subCategory == detected.subCategory) {
      score += 4;
    }
    if (candidate.brand == detected.brand) {
      score += 3;
    }

    final dTokens = _significantModelTokens(detected);
    final cText = _normalizeText(
      '${candidate.name} ${candidate.keywords ?? ''}',
    );
    for (final t in dTokens) {
      if (cText.contains(t)) score += 1;
    }
    return score;
  }

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.missingPart;
    _simulateAnalysisAndLoad();
  }

  Future<void> _simulateAnalysisAndLoad() async {
    setState(() => _isLoading = true);

    try {
      // 1. Simulate AI Analysis Delay
      await Future.delayed(const Duration(seconds: 2));

      final dbProducts = await _dbHelper.getAllProducts();

      if (dbProducts.isEmpty) {
        setState(() {
          _detectedName = "Ürün Bulunamadı";
          _isLoading = false;
        });
        return;
      }

      DBProduct detectedDbProduct;
      List<DBProduct> relatedDbProducts = [];

      // 2. DETECTED PRODUCT SELECTION
      DBProduct? bestMatch;
      List<DBProduct> topMatches = [];

      // Try Visual Matching first (Actual Image Comparison)
      if (widget.imagePath != null && !kIsWeb) {
        try {
          final file = File(widget.imagePath!);
          if (await file.exists()) {
            // Get top 5 matches
            topMatches = await VisualMatcherService().findTopMatches(
              file,
              dbProducts,
              limit: 8,
            );
            if (topMatches.isNotEmpty) {
              if (widget.mode == VisualIntelligenceMode.parts) {
                bestMatch = topMatches.firstWhere(
                  (p) => !p.isPart,
                  orElse: () => topMatches.first,
                );
              } else {
                bestMatch = topMatches.first;
              }
            }
          }
        } catch (e) {
          debugPrint('Error in visual matching: $e');
        }
      }

      if (bestMatch != null) {
        detectedDbProduct = bestMatch;
      } else {
        final hintTokens = _tokenize(
          '${widget.detectedProduct} ${widget.missingPart} ${widget.imageName ?? ''} ${(widget.imagePath ?? '').split('/').last}',
        );
        final scored = dbProducts.map((p) {
          final text = _normalizeText(
            '${p.name} ${p.brand} ${p.keywords ?? ''} ${p.category} ${p.subCategory ?? ''}',
          );
          int score = 0;
          for (final t in hintTokens) {
            if (text.contains(t)) {
              score += 2;
            }
          }
          if (widget.mode == VisualIntelligenceMode.parts && !p.isPart) {
            score += 1;
          }
          return MapEntry(p, score);
        }).toList()..sort((a, b) => b.value.compareTo(a.value));

        if (scored.isNotEmpty && scored.first.value > 0) {
          detectedDbProduct = scored.first.key;
        } else {
          if (mounted) {
            setState(() {
              _detectedName = 'Ürün tespit edilemedi';
              _detectedBrand = '';
              _detectedSpecs = 'Lütfen daha net bir görsel deneyin.';
              _relatedProducts = [];
              _isLoading = false;
            });
          }
          return;
        }
      }

      // 3. RELATED PRODUCTS (PARTS/SIMILAR) SELECTION
      if (widget.mode == VisualIntelligenceMode.parts) {
        final partKeywords = _inferPartKeywords(detectedDbProduct);
        final scoredParts =
            dbProducts
                .where((p) => p.id != detectedDbProduct.id)
                .map(
                  (p) => MapEntry(
                    p,
                    _partsScore(p, detectedDbProduct, partKeywords),
                  ),
                )
                .where((e) => e.value > 0)
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));

        relatedDbProducts = scoredParts.map((e) => e.key).take(8).toList();
      } else {
        final scoredSimilar =
            dbProducts
                .where((p) => p.id != detectedDbProduct.id)
                .map((p) => MapEntry(p, _similarScore(p, detectedDbProduct)))
                .where((e) => e.value > 0)
                .toList()
              ..sort((a, b) => b.value.compareTo(a.value));

        relatedDbProducts = scoredSimilar.map((e) => e.key).take(8).toList();
      }

      _relatedProducts = relatedDbProducts
          .map((dbProduct) => Product.fromDBProduct(dbProduct))
          .toList();

      // If we have other visual matches, add them to the TOP of the related list
      if (widget.mode == VisualIntelligenceMode.similar &&
          topMatches.length > 1) {
        final otherMatches = topMatches
            .skip(1)
            .where((p) => p.id != detectedDbProduct.id)
            .map((p) => Product.fromDBProduct(p))
            .toList();

        // Remove duplicates if any already exist in related
        for (var match in otherMatches) {
          _relatedProducts.removeWhere((p) => p.name == match.name);
        }

        _relatedProducts.insertAll(0, otherMatches);
      }

      if (mounted) {
        setState(() {
          _detectedName = detectedDbProduct.name;
          _detectedBrand = detectedDbProduct.brand;
          _detectedSpecs =
              detectedDbProduct.specifications ?? 'Özellik belirtilmemiş';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in visual intelligence simulation: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWebLayout = MediaQuery.of(context).size.width >= 800;
    const double webMaxWidth = 1100;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header - Ana sayfa gibi
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              readOnly: true,
                              decoration: InputDecoration(
                                hintText: widget.missingPart,
                                hintStyle: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 12,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isWebLayout ? webMaxWidth : double.infinity,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Detected image and info card - Horizontal layout
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 4, bottom: 8),
                                child: Text(
                                  'Tespit Edilen Ürün',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Image on left
                                      Container(
                                        width: 100,
                                        height: 100,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: widget.imagePath != null
                                            ? (kIsWeb
                                                  ? OptimizedImage(imageUrlOrPath: 
                                                      widget.imagePath!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) => Icon(
                                                            Icons
                                                                .broken_image_outlined,
                                                            size: 36,
                                                            color: Colors
                                                                .grey
                                                                .shade500,
                                                          ),
                                                    )
                                                  : Image.file(
                                                      File(widget.imagePath!),
                                                      fit: BoxFit.cover,
                                                    ))
                                            : Center(
                                                child: Icon(
                                                  Icons.directions_bike,
                                                  size: 60,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Info on right
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Ürün adı
                                            Text(
                                              _detectedName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            // Marka
                                            Text(
                                              _detectedBrand,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // Özellikler
                                            Text(
                                              _detectedSpecs,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
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

                        // Related products grid
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        else if (_relatedProducts.isEmpty)
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                32,
                                20,
                                32,
                                32,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    widget.mode == VisualIntelligenceMode.parts
                                        ? 'Parçalar Bulunamadı'
                                        : 'Benzer Ürün Bulunamadı',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 4,
                                    bottom: 8,
                                  ),
                                  child: Text(
                                    widget.mode == VisualIntelligenceMode.parts
                                        ? 'Uyumlu Parçalar ve Aksesuarlar'
                                        : 'Benzer Ürünler',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: isWebLayout ? 4 : 2,
                                        childAspectRatio: isWebLayout
                                            ? 0.74
                                            : 0.48,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                      ),
                                  itemCount: _relatedProducts.length,
                                  itemBuilder: (context, index) {
                                    return ProductCard(
                                      product: _relatedProducts[index],
                                      margin: EdgeInsets.zero,
                                      tight: true,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isWebLayout
          ? null
          : Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: BottomNavigationBar(
                currentIndex: 0,
                onTap: (index) {
                  if (index == 0) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                      (route) => false,
                    );
                  } else if (index == 1) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoriesPage(),
                      ),
                      (route) => false,
                    );
                  } else if (index == 2) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MapPage()),
                    );
                  } else if (index == 3) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CartPage()),
                    );
                  } else if (index == 4) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(initialIndex: 4),
                      ),
                      (route) => false,
                    );
                  }
                },
                selectedItemColor: AppColors.primary,
                unselectedItemColor: Colors.black,
                type: BottomNavigationBarType.fixed,
                showUnselectedLabels: true,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
                items: [
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Ana Sayfa',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.segment),
                    label: 'Kategori',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.map_outlined),
                    activeIcon: Icon(Icons.map),
                    label: 'Harita',
                  ),
                  BottomNavigationBarItem(
                    icon: _buildCartIcon(isActive: false),
                    activeIcon: _buildCartIcon(isActive: true),
                    label: 'Sepet',
                  ),
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Hesap',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCartIcon({required bool isActive}) {
    final cartItemCount = _appState.cart.length;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(isActive ? Icons.shopping_cart : Icons.shopping_cart_outlined),
        if (cartItemCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                cartItemCount > 9 ? '9+' : cartItemCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
