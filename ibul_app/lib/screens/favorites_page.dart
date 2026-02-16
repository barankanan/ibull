import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/app_state.dart';
import '../models/product_model.dart';
import 'home_screen.dart';
import 'list_detail_page.dart';
import 'product_detail_page.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';
import '../widgets/product_card.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String _selectedTab = 'Beğeniler';

  final List<String> _tabs = ['Beğeniler', 'Listelerim', 'Öneriler'];
  final AppState _appState = AppState();
  
  @override
  void initState() {
    super.initState();
    _appState.addListener(_onAppStateChanged);
  }

  @override
  void dispose() {
    _appState.removeListener(_onAppStateChanged);
    super.dispose();
  }

  void _onAppStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _showCreateListDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Liste Oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                hintText: 'Liste Adı',
                labelText: 'Liste Adı',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                hintText: 'Açıklama',
                labelText: 'Açıklama',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                _appState.createUserList(nameController.text, descController.text);
                Navigator.pop(context);
                setState(() {}); // Rebuild to show new list
              }
            },
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
  }

  final List<Product> _recommendedProducts = [
    Product(
      name: 'iPhone 15 Pro Max',
      brand: 'Apple',
      price: '54.999 TL',
      rating: 4.8,
      reviewCount: 1245,
      tags: const ['Ücretsiz Kargo', 'Yeni Sezon'],
      images: const ['assets/products/iphone15_mavi_256gb.png'],
      store: 'Apple Store',
      category: 'Elektronik',
      subCategory: 'Telefon',
    ),
    Product(
      name: 'MacBook Pro M3',
      brand: 'Apple',
      price: '84.999 TL',
      rating: 4.9,
      reviewCount: 856,
      tags: const ['Ücretsiz Kargo', 'Önerilen'],
      images: const ['assets/products/macbook_pro_m3_space_black.jpg'],
      store: 'Apple Store',
      category: 'Elektronik',
      subCategory: 'Bilgisayar',
    ),
    Product(
      name: 'Samsung Galaxy S24 Ultra',
      brand: 'Samsung',
      price: '49.999 TL',
      rating: 4.7,
      reviewCount: 923,
      tags: const ['Kısıtlı Stok', 'Önerilen'],
      images: const ['assets/products/s24_siyah_512gb.png'],
      store: 'Samsung Store',
      category: 'Elektronik',
      subCategory: 'Telefon',
    ),
    Product(
      name: 'Sony WH-1000XM5',
      brand: 'Sony',
      price: '12.499 TL',
      rating: 4.8,
      reviewCount: 645,
      tags: const ['Yeni Sezon', 'Önerilen'],
      images: const ['assets/products/sony_xm5.jpg'],
      store: 'Teknosa',
      category: 'Elektronik',
      subCategory: 'Ses Sistemi',
    ),
    Product(
      name: 'Nutella 750g',
      brand: 'Ferrero',
      price: '189,90 TL',
      rating: 4.9,
      reviewCount: 2341,
      tags: const ['Hızlı Kargo', 'İndirimli'],
      images: const ['assets/products/Nutella 750g.jpeg'],
      store: 'Migros',
      category: 'Süpermarket',
      subCategory: 'Gıda',
    ),
    Product(
      name: 'Urban Care Biotin & Kafein Tonik',
      brand: 'Urban Care',
      price: '159,90 TL',
      rating: 4.6,
      reviewCount: 789,
      tags: const ['Doğal İçerik', 'Önerilen'],
      images: const ['assets/products/Urban Care Biotin & Kafein Tonik.jpeg'],
      store: 'Rossmann',
      category: 'Kişisel Bakım',
      subCategory: 'Saç Bakımı',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width >= 800;

    if (isWeb) {
      return _buildWebView();
    }
    
    return _buildMobileView();
  }

  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          WebHeader(
            onSearch: (q) {},
            activeMenu: 'favorites',
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title & Tabs Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _selectedTab == 'Beğeniler' ? 'Favorilerim' : _selectedTab,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                // Web Tabs
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: _tabs.map((tab) {
                                      final isSelected = _selectedTab == tab;
                                      return InkWell(
                                        onTap: () => setState(() => _selectedTab = tab),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isSelected ? AppColors.primary : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            tab,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected ? Colors.white : Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Content
                            if (_selectedTab == 'Beğeniler')
                              _buildWebFavoritesGrid()
                            else if (_selectedTab == 'Listelerim')
                              _buildWebListsView()
                            else
                              _buildWebRecommendationsGrid(),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const WebFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebFavoritesGrid() {
    final favorites = _appState.favorites;
    
    if (favorites.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(60),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'Henüz favori ürünün yok',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            Text(
              'Beğendiğin ürünleri kalp ikonuna tıklayarak buraya ekleyebilirsin.',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // Go to home
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (context) => const HomeScreen()), 
                  (route) => false
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Alışverişe Başla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        childAspectRatio: 0.52, // Adjusted for ProductCard
        crossAxisSpacing: 20,
        mainAxisSpacing: 24,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final product = favorites[index];
        return ProductCard(product: product);
      },
    );
  }

  Widget _buildWebListsView() {
    // "Yeni Liste Oluştur" kartını veri listesine sanal olarak eklemek yerine
    // GridView.builder'da index yönetimi ile halledeceğiz.
    // Index 0 -> Yeni Liste Kartı
    // Index > 0 -> userLists[index - 1]
    
    final userLists = _appState.userLists;
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        childAspectRatio: 0.85, // Kart oranı
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
      ),
      itemCount: userLists.length + 1, // +1 for "Add New List" card
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildAddListCard();
        }
        final list = userLists[index - 1];
        return _buildWebListCard(list);
      },
    );
  }

  Widget _buildAddListCard() {
    return GestureDetector(
      onTap: _showCreateListDialog,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2, style: BorderStyle.solid), // Dashed border is complex in Flutter without extra package, solid is fine or custom painter
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Yeni Liste Oluştur',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ürünlerini kategorize et',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebListCard(Map<String, dynamic> list) {
    final products = list['products'] as List<Product>? ?? [];
    // İlk 3 ürün görselini al (varsa)
    final previewImages = products.take(3).map((p) => p.images.isNotEmpty ? p.images.first : '').where((img) => img.isNotEmpty).toList();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ListDetailPage(listData: list),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image Area
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Main Cover
                  list['coverImage'].toString().startsWith('assets/')
                      ? Image.asset(
                          list['coverImage'],
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          list['coverImage'],
                          fit: BoxFit.cover,
                        ),
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                  // Content over image (Bottom left)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list['name'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.person, color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${list['memberCount']} Takipçi',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.bookmark, color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${list['itemCount']} Ürün',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom Info Area (Product Previews)
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: Colors.white,
                child: Row(
                  children: [
                    // Product Thumbnails
                    if (previewImages.isNotEmpty)
                      Expanded(
                        child: SizedBox(
                          height: 40,
                          child: Stack(
                            children: List.generate(previewImages.length, (index) {
                              return Positioned(
                                left: index * 28.0,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: previewImages[index].startsWith('http')
                                        ? Image.network(previewImages[index], fit: BoxFit.cover)
                                        : Image.asset(previewImages[index], fit: BoxFit.cover),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          list['description'],
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    
                    // Go Button
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebRecommendationsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        childAspectRatio: 0.52,
        crossAxisSpacing: 20,
        mainAxisSpacing: 24,
      ),
      itemCount: _recommendedProducts.length,
      itemBuilder: (context, index) {
        final product = _recommendedProducts[index];
        return ProductCard(product: product);
      },
    );
  }

  Widget _buildMobileView() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _selectedTab == 'Beğeniler' ? 'Beğendiklerim' : _selectedTab,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search and Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Arama yap',
                          hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                          prefixIcon: Icon(Icons.search, color: AppColors.primary, size: 20),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_selectedTab == 'Listelerim') {
                      _showCreateListDialog();
                    }
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedTab == 'Listelerim' ? Icons.add : Icons.tune,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedTab == 'Listelerim' ? 'Ekle' : 'Filtre',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Horizontal Tab Bar
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final isSelected = _selectedTab == tab;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTab = tab;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        tab,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Content based on selected tab
          Expanded(
            child: _selectedTab == 'Beğeniler'
                ? _buildFavoritesGrid()
                : _selectedTab == 'Listelerim'
                    ? _buildListsView()
                    : _buildRecommendationsGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesGrid() {
    final favorites = _appState.favorites;
    
    if (favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Henüz beğenilen ürün yok',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
      ),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final product = favorites[index];
        return _buildProductCard(product);
      },
    );
  }

  Widget _buildListsView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _appState.userLists.length,
      itemBuilder: (context, index) {
        final list = _appState.userLists[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ListDetailPage(
                    listData: list,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              children: [
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    image: DecorationImage(
                      image: list['coverImage'].startsWith('http')
                          ? NetworkImage(list['coverImage'])
                          : AssetImage(list['coverImage']) as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: list['logo'].startsWith('http')
                                ? NetworkImage(list['logo'])
                                : AssetImage(list['logo']) as ImageProvider,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              list['name'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${list['memberCount']} Takipçi • ${list['itemCount']} Ürün',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
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
        );
      },
    );
  }

  Widget _buildListCardNew(Map<String, dynamic> list) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ListDetailPage(listData: list),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: list['coverImage'].toString().startsWith('assets/')
                      ? Image.asset(
                          list['coverImage'],
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.cover,
                        )
                      : Image.network(
                          list['coverImage'],
                          width: double.infinity,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                ),
                // Logo overlay
                Positioned(
                  left: 16,
                  bottom: -20,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: list['logo'].toString().startsWith('assets/')
                          ? Image.asset(
                              list['logo'],
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              list['logo'],
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 28),
            
            // List Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          list['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              '${list['memberCount']} Kişi üye',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    list['description'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.bookmark, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '${list['itemCount']} Ürün',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsGrid() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Sana Ve Tarzına Uygun öneriler Burada',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
            ),
            itemCount: _recommendedProducts.length,
            itemBuilder: (context, index) {
              final product = _recommendedProducts[index];
              return _buildProductCard(product);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    final isFavorite = _appState.isFavorite(product);
    final isInCart = _appState.isInCart(product);
    final image = product.images.isNotEmpty ? product.images.first : null;
    final primaryTag = product.tags.isNotEmpty ? product.tags.first : 'Önerilen';
    final ratingValue = product.rating;
    final int filledStars = ratingValue.isFinite ? ratingValue.clamp(0, 4).floor() : 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => ProductDetailPage(product: product),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(1.0, 0.0);
              const end = Offset.zero;
              const curve = Curves.easeOut;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              return SlideTransition(position: animation.drive(tween), child: child);
            },
            transitionDuration: const Duration(milliseconds: 250),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                      color: Colors.grey[100],
                      child: image != null && image.isNotEmpty
                          ? (image.startsWith('http')
                              ? Image.network(
                                  image,
                                  fit: BoxFit.contain,
                                  cacheWidth: 200,
                                  cacheHeight: 200,
                                  filterQuality: FilterQuality.medium,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[400],
                                    size: 30,
                                  ),
                                )
                              : Image.asset(
                                  image,
                                  fit: BoxFit.contain,
                                  cacheWidth: 200,
                                  cacheHeight: 200,
                                  filterQuality: FilterQuality.medium,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[400],
                                    size: 30,
                                  ),
                                ))
                          : Icon(
                              Icons.image_not_supported,
                              color: Colors.grey[400],
                              size: 30,
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _appState.toggleFavorite(product);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.grey.shade400,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badges
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        primaryTag,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Title
                    Text(
                      product.name,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.black87),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Rating
                    Row(
                      children: [
                        ...List.generate(
                          4,
                          (index) => Icon(
                            index < filledStars ? Icons.star : Icons.star_border,
                            color: Colors.orange,
                            size: 10,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            '(${product.reviewCount})',
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Price
                    Text(
                      product.price,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
