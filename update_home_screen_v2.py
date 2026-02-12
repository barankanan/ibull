
import os

file_path = '/Users/barankananogullari/Desktop/ibul2026/ibul_app/lib/screens/home_screen.dart'

new_method_content = r"""  // --- WEB GÖRÜNÜM (Yeni Tasarım) ---
  Widget _buildWebHomeContent() {
    final isElectronics = _selectedCategory == 'Elektronik';
    final isHomePage = _selectedCategory == 'Ana Sayfa';
    
    // Popüler ürünleri kategoriye göre filtrele
    final popularProducts = isHomePage 
        ? _dbProducts 
        : _dbProducts.where((p) => p.category == _selectedCategory || p.category.contains(_selectedCategory)).toList();

    // Banner images
    final bannerImages = [
      'assets/images/banners/sevgililer_gunu.png',
      'assets/images/banners/teknoloji_firsatlari.png',
      'assets/images/banners/ibul premium banner.png',
    ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ELEKTRONİK KATEGORİSİ SEÇİLİYSE
            if (isElectronics) ...[
              const SizedBox(height: 24),
              
              // 1. Kategoriler (En üstte)
              _buildOpportunityCards(),
              
              const SizedBox(height: 16),
              
              // 2. Teknoloji Dünyası Bölümü (Ürünlerin olduğu yer)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: _buildTechSection(),
              ),
              
              const SizedBox(height: 80),
              const WebFooter(),
              
            ] else ...[
              // NORMAL ANA SAYFA GÖRÜNÜMÜ ve DİĞER KATEGORİLER
              
              // 0. Adres Çubuğu
              Container(
                width: double.infinity,
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Teslimat Adresi:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Prefabrik ev-Gökmeydan Mah. Nazım Hikmet kültür merkezi karşısı',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton.icon(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        backgroundColor: AppColors.primary.withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                      label: const Text('Değiştir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),

              // 1. Kategoriler / Fırsat İkonları
              _buildOpportunityCards(),
              
              const SizedBox(height: 24),

              // 2. İkili Büyük Banner Alanı (SADECE ANA SAYFADA GÖSTER)
              if (isHomePage) ...[
                SizedBox(
                  height: 300,
                  child: Row(
                    children: [
                      // Sol: Kampanya Slider
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              CarouselSlider(
                                options: CarouselOptions(
                                  height: 300,
                                  viewportFraction: 1.0,
                                  autoPlay: true,
                                  autoPlayInterval: const Duration(seconds: 6),
                                  autoPlayAnimationDuration: const Duration(milliseconds: 1000),
                                ),
                                items: bannerImages.map((i) {
                                  return Builder(
                                    builder: (BuildContext context) {
                                      return Container(
                                        width: MediaQuery.of(context).size.width,
                                        decoration: const BoxDecoration(color: Color(0xFFF0F0F0)),
                                        child: Image.asset(
                                          i, 
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) => Container(
                                            color: Colors.grey.shade200,
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.image_not_supported, size: 64, color: Colors.grey.shade400),
                                                  const SizedBox(height: 16),
                                                  Text('Kampanya Görseli', style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 24),
                      
                      // Sağ: Günün Fırsatı
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Colors.orange.shade50, Colors.white],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.orange.shade100),
                                  boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.1), blurRadius: 10)],
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      top: 16,
                                      left: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)),
                                        child: const Text('Günün Fırsatı', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    Center(
                                      child: popularProducts.isNotEmpty 
                                        ? Transform.scale(
                                            scale: 0.8,
                                            child: ProductCard(
                                              product: _convertToProduct(popularProducts.first),
                                              width: 180,
                                            ),
                                          )
                                        : const CircularProgressIndicator(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(16),
                                  image: const DecorationImage(
                                    image: AssetImage('assets/images/banners/Görsel zeka banner.png'),
                                    fit: BoxFit.cover,
                                    opacity: 0.9,
                                  ),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(16),
                                  alignment: Alignment.bottomLeft,
                                  child: const Text(
                                    'Yapay Zeka ile\nAradığını Bul',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
              ],

              // 3. Popüler Ürünler Başlığı
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isHomePage ? 'Popüler Ürünler' : '$_selectedCategory Ürünleri',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Tümünü Gör', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // 4. Popüler Ürünler Listesi (Yatay Kaydırılabilir)
              popularProducts.isEmpty 
                ? SizedBox(
                    height: 200, 
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.category_outlined, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('Bu kategoride ürün bulunamadı', style: TextStyle(color: Colors.grey[600])),
                        ],
                      )
                    )
                  )
                : SizedBox(
                    height: 380,
                    child: Stack(
                      children: [
                        ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                            },
                          ),
                          child: ListView.separated(
                            controller: _popularProductsScrollController,
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: popularProducts.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 20),
                            itemBuilder: (context, index) {
                              final dbProduct = popularProducts[index];
                              return SizedBox(
                                width: 220,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ProductCard(
                                    product: _convertToProduct(dbProduct),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Sol Ok
                        Positioned(
                          left: 10,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new, size: 24, color: AppColors.primary),
                                onPressed: () {
                                  _popularProductsScrollController.animateTo(
                                    _popularProductsScrollController.offset - 300,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                tooltip: 'Sola Kaydır',
                              ),
                            ),
                          ),
                        ),
                        // Sağ Ok
                        Positioned(
                          right: 10,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.arrow_forward_ios, size: 24, color: AppColors.primary),
                                onPressed: () {
                                  _popularProductsScrollController.animateTo(
                                    _popularProductsScrollController.offset + 300,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                tooltip: 'Sağa Kaydır',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
              const SizedBox(height: 40),

              // 5. Markalar ve Bakım Bölümü
              if (isHomePage) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: _buildHairCareSection(),
                ),
                const SizedBox(height: 40),
              ],

              // 6. Teknoloji Dünyası Bölümü
              if (isHomePage) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: _buildTechSection(),
                ),
                const SizedBox(height: 80),
              ],
              
              // 7. Footer
              const WebFooter(),
            ],
          ],
        ),
      ),
    );
  }"""

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find start
start_marker = "  // --- WEB GÖRÜNÜM (Yeni Tasarım) ---"
start_idx = content.find(start_marker)

if start_idx == -1:
    print("Start marker not found")
    exit(1)

# Find end (start of _buildOpportunityCards)
end_marker = "  Widget _buildOpportunityCards() {"
end_idx = content.find(end_marker)

if end_idx == -1:
    print("End marker not found")
    exit(1)

# Construct new content
new_content = content[:start_idx] + new_method_content + "\n\n" + content[end_idx:]

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Successfully updated home_screen.dart")
