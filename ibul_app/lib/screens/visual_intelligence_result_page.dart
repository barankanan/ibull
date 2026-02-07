import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
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
import 'account_page.dart';
import '../core/app_state.dart';

enum VisualIntelligenceMode {
  parts,   // Görsel Zeka (Parçalar/Aksesuarlar)
  similar, // Ürünü Arat (Benzer Ürünler)
}

class VisualIntelligenceResultPage extends StatefulWidget {
  final String detectedProduct;
  final String missingPart;
  final String? imagePath;
  final VisualIntelligenceMode mode;

  const VisualIntelligenceResultPage({
    super.key,
    required this.detectedProduct,
    required this.missingPart,
    this.imagePath,
    this.mode = VisualIntelligenceMode.similar, // Default to similar for backward compatibility
  });

  @override
  State<VisualIntelligenceResultPage> createState() => _VisualIntelligenceResultPageState();
}

class _VisualIntelligenceResultPageState extends State<VisualIntelligenceResultPage> {
  final AppState _appState = AppState();
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TextEditingController _searchController = TextEditingController();
  List<Product> _relatedProducts = [];
  bool _isLoading = true;
  
  // Detected product info
  String _detectedName = 'Analiz Ediliyor...';
  String _detectedBrand = '';
  String _detectedSpecs = '';

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
      if (widget.imagePath != null) {
        try {
          final file = File(widget.imagePath!);
          if (await file.exists()) {
             // Get top 5 matches
             topMatches = await VisualMatcherService().findTopMatches(file, dbProducts, limit: 5);
             if (topMatches.isNotEmpty) {
               bestMatch = topMatches.first;
             }
          }
        } catch (e) {
          print('Error in visual matching: $e');
        }
      }

      if (bestMatch != null) {
         detectedDbProduct = bestMatch;
      } else if (widget.mode == VisualIntelligenceMode.parts) {
        // Mode: Parts - Prefer Phones/Electronics for detection simulation
        var phoneCandidates = dbProducts.where((p) {
          final name = p.name.toLowerCase();
          final brand = p.brand.toLowerCase();
          final cat = (p.category ?? '').toLowerCase();
          return name.contains('iphone') || 
                 name.contains('samsung') || 
                 name.contains('xiaomi') || 
                 name.contains('huawei') ||
                 name.contains('telefon') ||
                 brand.contains('apple') ||
                 brand.contains('samsung') ||
                 cat.contains('telefon') ||
                 cat.contains('elektronik');
        }).toList();

        if (phoneCandidates.isNotEmpty) {
          final random = Random();
          detectedDbProduct = phoneCandidates[random.nextInt(phoneCandidates.length)];
        } else {
          // Fallback to random if no phones found
          final random = Random();
          detectedDbProduct = dbProducts[random.nextInt(dbProducts.length)];
        }
      } else {
        // Mode: Similar - Prefer random but grouped by category if possible
        Map<String, List<DBProduct>> categoryGroups = {};
        for (var p in dbProducts) {
          categoryGroups.putIfAbsent(p.category, () => []).add(p);
                }
        
        var validCategories = categoryGroups.keys.where((k) => categoryGroups[k]!.length >= 3).toList();
        if (validCategories.isNotEmpty) {
          final random = Random();
          final category = validCategories[random.nextInt(validCategories.length)];
          final productsInCat = categoryGroups[category]!;
          detectedDbProduct = productsInCat[random.nextInt(productsInCat.length)];
        } else {
          final random = Random();
          detectedDbProduct = dbProducts[random.nextInt(dbProducts.length)];
        }
      }
      
      // 3. RELATED PRODUCTS (PARTS/SIMILAR) SELECTION
      if (widget.mode == VisualIntelligenceMode.parts) {
        // Mode: Parts/Accessories
        // Strategy: Look for "Kılıf", "Şarj", "Aksesuar" etc.
        
        var potentialParts = dbProducts.where((p) {
          final name = p.name.toLowerCase();
          final cat = (p.category ?? '').toLowerCase();
          return (name.contains('kılıf') || 
                 name.contains('şarj') || 
                 name.contains('aksesuar') || 
                 name.contains('kulaklık') ||
                 name.contains('cam') ||
                 name.contains('kayış') ||
                 name.contains('adaptör') ||
                 name.contains('kablo') ||
                 name.contains('ekran') ||
                 name.contains('batarya') ||
                 name.contains('pil') ||
                 name.contains('tamir') ||
                 name.contains('kasa') ||
                 name.contains('tuş') ||
                 name.contains('hoparlör') ||
                 name.contains('mikrofon') ||
                 name.contains('vida') ||
                 name.contains('flex') ||
                 name.contains('soket') ||
                 name.contains('lens') ||
                 name.contains('anakart') ||
                 cat.contains('aksesuar') ||
                 cat.contains('yedek parça') ||
                 cat.contains('elektronik parça')) &&
                 p.id != detectedDbProduct.id;
        }).toList();
        
        // Advanced matching: Match by Name similarity first (ignoring Brand strict equality)
        List<DBProduct> matchedParts = [];
        
        List<String> tokens = detectedDbProduct.name.toLowerCase().split(' ');
        // Filter out generic/status words
        List<String> ignoredWords = ['hasarlı', 'ikinci', 'el', 'telefon', 'cep', 'mobil', 'smart', 'akıllı', 'cihaz', 'yenilenmiş', 'outlet', '128gb', '64gb', '256gb', '512gb', 'ram', '32gb', '16gb'];
        List<String> significantTokens = tokens.where((t) => t.length > 1 && !ignoredWords.contains(t)).toList();
        
        if (significantTokens.isNotEmpty) {
           matchedParts = potentialParts.where((p) {
             final pName = p.name.toLowerCase();
             int matchCount = 0;
             for (var token in significantTokens) {
               if (pName.contains(token)) matchCount++;
             }
             
             // If we have specific model info (e.g. "iphone", "13"), require strong match
             if (significantTokens.length >= 2) {
               return matchCount >= 2;
             } else {
               return matchCount >= 1;
             }
           }).toList();
        }
        
        if (matchedParts.isNotEmpty) {
           relatedDbProducts = matchedParts.take(6).toList();
        } else {
           // Fallback: strict brand match if name matching failed
           var brandParts = potentialParts.where((p) => p.brand == detectedDbProduct.brand).toList();
           if (brandParts.isNotEmpty) {
              relatedDbProducts = brandParts.take(6).toList();
           } else {
              relatedDbProducts = [];
           }
        }
        
        // DO NOT FILL WITH RANDOM IF EMPTY - User wants "Parçalar Bulunamadı"

      } else {
        // Mode: Similar Products (Default)
        // Strategy: Same Category, Same Brand preferably
        
        relatedDbProducts = dbProducts
            .where((p) => p.id != detectedDbProduct.id && 
                (p.category == detectedDbProduct.category))
            .take(6)
            .toList();
            
        // If not enough, loosen constraints (same brand)
        if (relatedDbProducts.length < 4) {
          final moreProducts = dbProducts
              .where((p) => p.id != detectedDbProduct.id && 
                  !relatedDbProducts.any((rp) => rp.id == p.id) &&
                  p.brand == detectedDbProduct.brand)
              .take(6 - relatedDbProducts.length);
          relatedDbProducts.addAll(moreProducts);
        }

        // Fill with random items if still not enough (only for Similar mode)
        if (relatedDbProducts.length < 4) {
           final otherProducts = dbProducts
               .where((p) => p.id != detectedDbProduct.id && 
                             !relatedDbProducts.any((rp) => rp.id == p.id))
               .take(6 - relatedDbProducts.length);
           relatedDbProducts.addAll(otherProducts);
        }
      }
      
      _relatedProducts = relatedDbProducts
          .map((dbProduct) => Product.fromDBProduct(dbProduct))
          .toList();
      
      // If we have other visual matches, add them to the TOP of the related list
      if (topMatches.length > 1) {
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
          _detectedSpecs = detectedDbProduct.specifications ?? 'Özellik belirtilmemiş';
          _isLoading = false;
        });
      }

    } catch (e) {
      print('Error in visual intelligence simulation: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header - Ana sayfa gibi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                          const Icon(Icons.search, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              readOnly: true,
                              decoration: InputDecoration(
                                hintText: widget.missingPart,
                                hintStyle: TextStyle(color: Colors.grey[800], fontSize: 12),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Detected image and info card - Horizontal layout
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  color: Colors.grey.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Image on left
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: widget.imagePath != null
                                        ? Image.file(
                                            File(widget.imagePath!),
                                            fit: BoxFit.cover,
                                          )
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      )
                    else if (_relatedProducts.isEmpty)
                       Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
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
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.48, // Adjusted to prevent overflow
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _relatedProducts.length,
                          itemBuilder: (context, index) {
                            return ProductCard(
                              product: _relatedProducts[index],
                            );
                          },
                        ),
                      ),
                    
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Theme(
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
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            } else if (index == 1) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const CategoriesPage()),
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
                MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 4)),
                (route) => false,
              );
            }
          },
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.black,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
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
        Icon(
          isActive ? Icons.shopping_cart : Icons.shopping_cart_outlined,
        ),
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
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
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
