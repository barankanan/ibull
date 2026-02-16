import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../models/product_model.dart';
import '../models/db_product.dart';
import '../services/database_helper.dart';
import 'search_results_page.dart';
import 'market_list_page.dart';
import 'category_products_page.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  int _selectedIndex = 0;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<DBProduct> _allProducts = [];
  bool _isLoading = true;

  final List<String> _categories = [
    "Yakın Lokasyon",
    "Elektronik",
    "Spor & Outdoor",
    "Giyim & Aksesuar",
    "Anne & Bebek & Oyuncak",
    "Kozmetik & Kişisel Bakım",
    "Ev & Yaşam",
    "Kitap & Hobi",
    "Süpermarket & Petshop",
    "2.el Ürünler",
  ];
  
  final Map<String, String> _categoryIcons = {
    "Yakın Lokasyon": "assets/category_icons/Yakın lokasyon.png",
    "Elektronik": "assets/category_icons/elektronik.png",
    "Spor & Outdoor": "assets/category_icons/spor & Outdoor.png",
    "Giyim & Aksesuar": "assets/category_icons/Giyim & Aksesuar.png",
    "Anne & Bebek & Oyuncak": "assets/category_icons/Anne & Bebek & Oyuncak.png",
    "Kozmetik & Kişisel Bakım": "assets/category_icons/kozmetik & Kişisel Bakım.png",
    "Ev & Yaşam": "assets/category_icons/Ev & Yaşam.png",
    "Kitap & Hobi": "assets/category_icons/Kitap & Hobi.png",
    "Süpermarket & Petshop": "assets/category_icons/Süpermakret & Petshop.png",
  };
  
  final Map<String, String> _subCategoryIcons = {
    // Yakın Lokasyon
    "Yemek": "assets/subcategory_icons/yemek.png",
    "Market": "assets/subcategory_icons/market.png",
    "İşletme": "assets/subcategory_icons/işletme.png",
    "Meslekler": "assets/subcategory_icons/meslekler.png",
    // Elektronik
    "Telefon & Aksesuar": "assets/subcategory_icons/telefon & aksesuar.png",
    "Bilgisayar & Tablet": "assets/subcategory_icons/bilgisayar & tablet.png",
    "TV & Ses Sistemleri": "assets/subcategory_icons/tv & ses sistemleri.png",
    "Kamera & Fotoğraf": "assets/subcategory_icons/kamera & fotoğraf.png",
    // Spor & Outdoor
    "Spor Ayakkabı": "assets/subcategory_icons/spor ayakkabı.png",
    "Spor Giyim": "assets/subcategory_icons/spor giyim.png",
    "Fitness & Kondisyon": "assets/subcategory_icons/fitness & kondisyon.png",
    "Outdoor": "assets/subcategory_icons/outdoor.png",
    // Giyim & Aksesuar
    "Kadın Giyim": "assets/subcategory_icons/Kadın giyim.png",
    "Erkek Giyim": "assets/subcategory_icons/Erkek Giyim.png",
    "Çocuk Giyim": "assets/subcategory_icons/Çocuk Giyim.png",
    "Aksesuar": "assets/subcategory_icons/aksesuar.png",
  };
  
  String _normalize(String value) {
    var t = value.toLowerCase().trim();
    t = t.replaceAll('ı', 'i').replaceAll('İ', 'i');
    t = t.replaceAll('ş', 's').replaceAll('Ş', 's');
    t = t.replaceAll('ğ', 'g').replaceAll('Ğ', 'g');
    t = t.replaceAll('ü', 'u').replaceAll('Ü', 'u');
    t = t.replaceAll('ö', 'o').replaceAll('Ö', 'o');
    t = t.replaceAll('ç', 'c').replaceAll('Ç', 'c');
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    return t;
  }
  
  @override
  void initState() {
    super.initState();
    _loadProducts();
  }
  
  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      _allProducts = await _dbHelper.getAllProducts();
    } catch (e) {
      print('Ürünler yüklenirken hata: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Product _convertToProduct(DBProduct dbProduct) {
    // Görselleri parse et
    List<String> images = [];
    
    // imageUrls JSON array ise decode et
    if (dbProduct.imageUrls != null && dbProduct.imageUrls!.isNotEmpty) {
      try {
        final decoded = json.decode(dbProduct.imageUrls!);
        if (decoded is List) {
          images = decoded.map((e) => e.toString()).toList();
        }
      } catch (e) {
        // JSON decode başarısız olursa imageUrl kullan
        if (dbProduct.imageUrl.isNotEmpty) {
          images.add(dbProduct.imageUrl);
        }
      }
    } else if (dbProduct.imageUrl.isNotEmpty) {
      images.add(dbProduct.imageUrl);
    }
    
    List<String> tags = [];
    if (dbProduct.tags.isNotEmpty) {
      tags = dbProduct.tags.split('|').map<String>((e) => e.toString().trim()).toList();
    }

    return Product(
      name: dbProduct.name,
      brand: dbProduct.brand,
      price: dbProduct.price,
      rating: dbProduct.rating,
      reviewCount: dbProduct.reviewCount,
      tags: tags,
      images: images.isEmpty ? [] : images,
      store: dbProduct.store,
      category: dbProduct.category,
      subCategory: dbProduct.subCategory,
      description: dbProduct.description,
      specifications: dbProduct.specifications,
      oldPrice: dbProduct.oldPrice,
    );
  }
  
  // Mappings for specific icons or dummy images could be added here
  // For now we will use generic icons or text avatars

  // Mock products for search
  List<Product> _getProductsForSearch() {
    return _allProducts.take(20).map((dbProduct) => _convertToProduct(dbProduct)).toList();
  }

  void _onSearch(String query) {
    final normalized = query.toLowerCase();
    final results = _getProductsForSearch().where((p) {
      return p.name.toLowerCase().contains(normalized) ||
          p.brand.toLowerCase().contains(normalized) ||
          _categories.any((cat) => cat.toLowerCase().contains(normalized));
    }).toList();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => SearchResultsPage(query: query, results: results),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onSubmitted: (value) {
                    final query = value.trim();
                    if (query.isNotEmpty) _onSearch(query);
                  },
                  decoration: const InputDecoration(
                    hintText: 'Marka, ürün veya kategori ara',
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.mic, color: AppColors.primary),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 22),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTopCategoryBar(),
          const Divider(height: 1),
          Expanded(
            child: _buildBodyContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCategoryBar() {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        cacheExtent: 300,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final isSelected = _selectedIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = index;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                    ),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: _categoryIcons.containsKey(_categories[index])
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                _categoryIcons[_categories[index]]!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      _categories[index][0],
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Text(
                                _categories[index][0],
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4), // Reduced spacing
                  Text(
                    _categories[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                      color: isSelected ? AppColors.primary : Colors.black87,
                    ),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  if (isSelected)
                    Container(
                      height: 3,
                      width: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                  if (!isSelected)
                    const SizedBox(height: 3),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBodyContent() {
    // Smooth transition
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _getContentForIndex(_selectedIndex),
    );
  }

  Widget _getContentForIndex(int index) {
    // 0: Yakın Lokasyon
    if (index == 0) {
      return _buildYakinLokasyonView();
    }
    // 1: Elektronik
    else if (index == 1) {
       return _buildGenericSubCategoryView(
        "Elektronik",
        [
          "Telefon & Aksesuar",
          "Bilgisayar & Tablet",
          "TV & Ses Sistemleri",
          "Kamera & Fotoğraf",
        ]
      );
    }
    // 2: Spor & Outdoor
    else if (index == 2) {
       return _buildGenericSubCategoryView(
        "Spor & Outdoor",
        [
          "Spor Ayakkabı",
          "Spor Giyim",
          "Fitness & Kondisyon",
          "Outdoor",
        ]
      );
    }
    // 3: Giyim & Aksesuar
    else if (index == 3) {
       return _buildGenericSubCategoryView(
        "Giyim & Aksesuar",
        [
          "Kadın Giyim",
          "Erkek Giyim",
          "Çocuk Giyim",
          "Aksesuar",
        ]
      );
    }
    // 4: Anne & Bebek & Oyuncak
    else if (index == 4) {
       return _buildGenericSubCategoryView(
        "Anne & Bebek & Oyuncak",
        [
          "Bebek Arabaları",
          "Bebek Giyim",
          "Oyuncak",
          "Anne Ürünleri",
        ]
      );
    }
    // 5: Kozmetik & Kişisel Bakım
    else if (index == 5) {
       return _buildGenericSubCategoryView(
        "Kozmetik & Kişisel Bakım",
        [
          "Parfüm & Deodorant",
          "Saç Bakımı",
          "Cilt Bakımı",
          "Makyaj",
        ]
      );
    }
    // 6: Ev & Yaşam
    else if (index == 6) {
       return _buildGenericSubCategoryView(
        "Ev & Yaşam",
        [
          "Mobilya",
          "Ev Tekstili",
          "Mutfak",
          "Banyo",
        ]
      );
    }
    // 7: Kitap & Hobi
    else if (index == 7) {
       return _buildGenericSubCategoryView(
        "Kitap & Hobi",
        [
          "Kitap",
          "Kırtasiye",
          "Müzik",
          "Hobi",
        ]
      );
    }
    // 8: Süpermarket & Petshop
    else if (index == 8) {
       return _buildGenericSubCategoryView(
        "Süpermarket & Petshop",
        [
          "Gıda & İçecek",
          "Temizlik Ürünleri",
          "Petshop",
          "Kişisel Bakım",
        ]
      );
    }
    // 9: 2.el Ürünler
    else if (index == 9) {
      return _buildSecondHandView();
    }
    // Others generic
    else {
      return _buildGenericSubCategoryView(
        _categories[index],
        ["Alt Kategori 1", "Alt Kategori 2", "Alt Kategori 3"]
      );
    }
  }

  Widget _buildYakinLokasyonView() {
    final items = [
      {'name': 'Yemek', 'icon': Icons.fastfood, 'color':Colors.red[100]},
      {'name': 'Market', 'icon': Icons.shopping_basket, 'color':Colors.green[100], 'subItems': ['Şok', 'A101', 'BIM']},
      {'name': 'İşletme', 'icon': Icons.store, 'color':Colors.blue[100]},
      {'name': 'Meslekler', 'icon': Icons.work, 'color':Colors.orange[100]},
    ];

    return _buildUnifiedGridView("Yakın Lokasyon", items.map((e) => e['name'] as String).toList());
  }

  Widget _buildSecondHandView() {
    final items = [
      '2.el Elektronik',
      '2.el Giyim',
      '2.el Mobilya',
      '2.el Beyaz Eşya',
      '2.el Kitap',
      'HEPSİ',
    ];

    return _buildUnifiedGridView("2.el Ürünler", items);
  }

  Widget _buildGenericSubCategoryView(String title, List<String> subCats) {
    return _buildUnifiedGridView(title, subCats);
  }

  Widget _buildUnifiedGridView(String title, List<String> items) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.0,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) {
             return GestureDetector(
               onTap: () {
                 // Alt kategoriye tıklayınca o kategorideki ürünleri göster
                 _showCategoryProducts(title, items[i]);
               },
               child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                           BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                        ],
                        border: Border.all(color: Colors.grey.shade100)
                      ),
                      padding: const EdgeInsets.all(8),
                      child: _subCategoryIcons.containsKey(items[i])
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                _subCategoryIcons[items[i]]!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.category, color: Colors.grey[600], size: 30);
                                },
                              ),
                            )
                          : Icon(Icons.category, color: Colors.grey[600], size: 30),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    items[i],
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: Colors.black87),
                  ),
                ],
              ),
             );
          },
        )
      ],
    );
  }
  
  void _showCategoryProducts(String category, String subCategory) {
    // Yakın Lokasyon - Market için özel sayfa
    if (category == "Yakın Lokasyon" && subCategory == "Market") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MarketListPage()),
      );
      return;
    }
    
    final selectedCategory = _normalize(category);
    final selectedSubCategory = _normalize(subCategory);

    final filteredProducts = _allProducts.where((product) {
      final productCategory = _normalize(product.category ?? '');
      final productSubCategory = _normalize(product.subCategory ?? '');

      final categoryMatch = productCategory == selectedCategory;

      if (subCategory == "HEPSİ") {
        return categoryMatch;
      }

      final subCategoryMatch = productSubCategory.isNotEmpty &&
          productSubCategory == selectedSubCategory;

      return categoryMatch && subCategoryMatch;
    }).toList();
    
    print('Kategori: $category, Alt Kategori: $subCategory');
    print('Bulunan ürün sayısı: ${filteredProducts.length}');
    
    final products = filteredProducts.map((dbProduct) => _convertToProduct(dbProduct)).toList();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryProductsPage(
          category: category,
          subCategory: subCategory,
          products: products,
        ),
      ),
    );
  }
}
