part of 'home_screen.dart';

extension _HomeScreenSections on _HomeScreenState {
  Widget _buildHomeViewImpl() {
    if (_errorMessage != null) {
      return CustomErrorView(message: _errorMessage, onRetry: _loadProducts);
    }

    // Breakpoint increased to 1100 to prevent WebHeader overflow on smaller screens (tablets, small laptops)
    final isWeb = MediaQuery.of(context).size.width >= 1100;

    return SafeArea(
      child: Column(
        children: [
          // Header: Web için WebHeader, Mobil için CustomHeader
          isWeb
              ? WebHeader(
                  onSearch: _onSearch,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: _setSelectedCategory,
                )
              : CustomHeader(onSearch: _onSearch),

          Expanded(
            child: isWeb
                ? WebStickyFooterScrollView(
                    contentAlignment: Alignment.topCenter,
                    child: _buildWebHomeContent(),
                  )
                : _buildMobileHomeContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHomeContentImpl() {
    final mobileBannerImages = _resolvedBannerImages(preferMobile: true);
    final featuredProducts = _featuredHomeProducts();
    final fastDeliveryProducts = _getFastDeliveryProducts(limit: 10);
    final opportunityProducts = _getOpportunityProducts(limit: 10);
    final recentProducts = _recentHomeProducts();

    _scheduleAboveFoldImagePrecache(
      isWeb: false,
      bannerImages: mobileBannerImages,
      firstRailProducts: featuredProducts,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        const _MobileAddressBarSliver(),
        SliverToBoxAdapter(
          child: FeatureMenu(remoteCategories: _appFeatureCategories),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        _MobileBannerSliver(
          isLoadingHeroContent: _isLoadingHeroContent,
          mobileBannerImages: mobileBannerImages,
          buildHomeBannerSkeleton: _buildHomeBannerSkeleton,
          buildScaledHomeBannerImage: _buildScaledHomeBannerImage,
        ),
        if (_isLoadingHeroContent || mobileBannerImages.isNotEmpty)
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        const SliverToBoxAdapter(
          child: SponsoredProductListsSection(
            title: 'Öne Çıkan Listeler',
            subtitle: 'Ana sayfada sponsorlu olarak gösterilen ürün listeleri',
            placement: AdPlacement.homeFeed,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverToBoxAdapter(
          child: _HomeProductRailSection(
            title: const _PersonalizedProductsTitle(),
            isLoadingProducts: _isLoadingProducts,
            hasProducts: _dbProducts.isNotEmpty,
            products: featuredProducts,
            convertToProduct: _convertToProduct,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: _FastDeliverySection(
            isLoading: _isLoadingProducts || _isLoadingHomeSections,
            products: fastDeliveryProducts,
            convertToProduct: _convertToProduct,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        if (_hairCareLayoutsForHome.isNotEmpty)
          SliverToBoxAdapter(
            child: _DynamicBrandLayoutsSection(
              layouts: _hairCareLayoutsForHome,
              allProducts: _dbProducts,
            ),
          ),
        SliverToBoxAdapter(
          child: _OpportunityProductsSection(
            isLoadingProducts: _isLoadingProducts,
            products: opportunityProducts,
            convertToProduct: _convertToProduct,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: _HomeProductRailSection(
            title: Text(
              'Daha Önce Gezdiklerin',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            isLoadingProducts: _isLoadingProducts,
            hasProducts: _dbProducts.isNotEmpty,
            products: recentProducts,
            convertToProduct: _convertToProduct,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Widget _buildSubCategoryViewImpl() {
    final displayProducts = _getProductsForCurrentSubCategory();

    final sameDayProducts = displayProducts
        .where(
          (p) =>
              p.tags.contains('Hızlı Teslimat') ||
              p.tags.contains('Hızlı Kargo') ||
              p.tags.contains('Yakın Lokasyon'),
        )
        .take(10)
        .toList();

    final Map<String, List<String>> displayFilters = {};
    _standardFilters.forEach((key, value) {
      // "Telefonlar" dışındaki kategorilerde "Kategori" ve "Marka" altı boş olsun
      if ((key == 'Kategori' || key == 'Marka') &&
          _selectedSubCategory != 'Telefonlar') {
        displayFilters[key] = [];
      } else {
        displayFilters[key] = value;
      }
    });

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sidebar
        // Use ConstrainedBox or SizedBox to ensure width, but let height be determined by content
        // Since FilterSidebar now uses shrinkWrap ListView, it will take the height of its content.
        // And since it's in a Row with CrossAxisAlignment.start, it won't stretch vertically unless we tell it to.
        ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 500,
          ), // Min height to match grid roughly
          child: FilterSidebar(
            key: ValueKey(
              _selectedSubCategory,
            ), // Force rebuild when subcategory changes
            filters: displayFilters,
            onFilterChanged: (category, option, isSelected) {},
          ),
        ),

        const SizedBox(width: 24),

        // Product Grid
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_selectedSubCategory',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'Önerilen Sıralama',
                          style: TextStyle(fontSize: 14),
                        ),
                        Icon(Icons.keyboard_arrow_down, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // "Bugün Kapında" Alanı
              if (sameDayProducts.isNotEmpty &&
                  (_selectedSubCategory == 'Telefonlar' ||
                      _selectedSubCategory == 'Telefon'))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50, // Mavi arka plan
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.shade200,
                    ), // Mavi kenarlık
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_shipping,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Bugün Kapında',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue, // Mavi metin
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${sameDayProducts.length} ürün',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 290,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          cacheExtent: 500,
                          itemCount: sameDayProducts.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final dbProduct = sameDayProducts[index];
                            return SizedBox(
                              width: 160,
                              child: _wrapProductReveal(
                                scope: 'home-subcategory-same-day',
                                index: index,
                                token: _productRevealTokenFromDb(dbProduct),
                                child: ProductCard(
                                  product: _convertToProduct(dbProduct),
                                  compact: true,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              displayProducts.isEmpty
                  ? _isLoadingProducts
                        ? _buildHorizontalProductSkeletons(
                            height: 312,
                            itemWidth: 198,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                          )
                        : const Center(
                            child: Text("Bu kategoride ürün bulunamadı."),
                          )
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      cacheExtent: 800,
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent:
                            250, // Kartların aşırı genişlemesini önlemek için max genişlik
                        childAspectRatio:
                            0.65, // Oranı artırarak kart yüksekliğini azalttık (Boşlukları kapatmak için)
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: displayProducts.length > 8
                          ? 8
                          : displayProducts.length, // Limit for demo
                      itemBuilder: (context, index) {
                        final dbProduct = displayProducts[index];
                        return _wrapProductReveal(
                          scope: 'home-subcategory-grid',
                          index: index,
                          token: _productRevealTokenFromDb(dbProduct),
                          child: ProductCard(
                            product: _convertToProduct(dbProduct),
                            margin: EdgeInsets.zero,
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _wrapWebCategoryMainSlot({
    required Widget child,
    required bool expandWhenShort,
  }) {
    if (!expandWhenShort) {
      return child;
    }

    final bodyMinHeight =
        WebStickyFooterBodyScope.maybeOf(context)?.bodyMinHeight;
    if (bodyMinHeight == null) {
      return child;
    }

    const topSectionReserve = 160.0;
    final slotHeight = math.max(280.0, bodyMinHeight - topSectionReserve);

    return SizedBox(
      width: double.infinity,
      height: slotHeight,
      child: Align(
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  Widget _buildWebCategoryEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.category_outlined, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(
          'Bu kategoride henüz ürün bulunamadı',
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildWebHomeContentImpl() {
    final isElectronics = _selectedCategory == 'Elektronik';
    final isHomePage = _selectedCategory == 'Ana Sayfa';
    final isCategorySelected = !isHomePage; // Herhangi bir kategori seçili mi?
    final popularProducts = _popularProductsForSelectedCategory();
    final subCategoryProducts = _selectedSubCategory != null
        ? _getProductsForCurrentSubCategory()
        : const <DBProduct>[];
    final fastDeliveryProducts = isHomePage
        ? _getFastDeliveryProducts(limit: 10)
        : <DBProduct>[];
    final opportunityProducts = isHomePage
        ? _getOpportunityProducts(limit: 10)
        : <DBProduct>[];
    final bannerImages = _resolvedBannerImages(preferMobile: false);

    if (isHomePage) {
      _scheduleAboveFoldImagePrecache(
        isWeb: true,
        bannerImages: bannerImages,
        firstRailProducts: popularProducts,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24.0,
          ), // Increased horizontal padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KATEGORİ SEÇİLİYSE (Elektronik veya Diğerleri)
              if (isCategorySelected) ...[
                const SizedBox(height: 24),

                // 1. Kategoriler (En üstte) - Sadece seçili kategoriye özgü ikonları göster
                _buildOpportunityCards(),

                const SizedBox(height: 16),

                // 2. Alt Kategori Filtreleme veya Teknoloji Dünyası
                if (_selectedSubCategory != null)
                  _wrapWebCategoryMainSlot(
                    expandWhenShort:
                        !_isLoadingProducts && subCategoryProducts.isEmpty,
                    child: _buildSubCategoryView(),
                  )
                else if (isElectronics)
                  _wrapWebCategoryMainSlot(
                    expandWhenShort: true,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: _buildTechSection(),
                    ),
                  )
                else ...[
                  // DİĞER KATEGORİLER İÇİN SADECE ÜRÜN LİSTESİ
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_selectedCategory Ürünleri',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _wrapWebCategoryMainSlot(
                    expandWhenShort:
                        _isLoadingProducts || popularProducts.isEmpty,
                    child: _isLoadingProducts
                        ? GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            cacheExtent: 800,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  childAspectRatio: 0.58,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: 10,
                            itemBuilder: (context, index) {
                              return const ProductCardSkeleton();
                            },
                          )
                        : popularProducts.isEmpty
                        ? _buildWebCategoryEmptyState()
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            cacheExtent: 800,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  childAspectRatio: 0.58,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            itemCount: popularProducts.length,
                            itemBuilder: (context, index) {
                              final dbProduct = popularProducts[index];
                              return _wrapProductReveal(
                                scope: 'home-category-grid',
                                index: index,
                                token: _productRevealTokenFromDb(dbProduct),
                                child: ProductCard(
                                  product: _convertToProduct(dbProduct),
                                  margin: EdgeInsets.zero,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ] else ...[
                // NORMAL ANA SAYFA GÖRÜNÜMÜ

                // 0. Adres Çubuğu
                Consumer<AppState>(
                  builder: (context, appState, _) {
                    final currentAddress =
                        appState.currentDeliveryAddress ??
                        'Teslimat Adresi Seçin';
                    return Container(
                      width: double.infinity,
                      height: 50,
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Teslimat Adresi:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 16),
                          TextButton.icon(
                            onPressed: _showAddressSelectionDialog,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.08,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(
                              Icons.edit_location_alt_outlined,
                              size: 18,
                            ),
                            label: const Text(
                              'Değiştir',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // 1. Kategoriler / Fırsat İkonları
                _buildOpportunityCards(),

                const SizedBox(height: 24),

                // 2. İkili Büyük Banner Alanı
                SizedBox(
                  height: 412,
                  child: Row(
                    children: [
                      // Sol: Kampanya Slider
                      Expanded(
                        flex: 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              // Use _isLoadingHeroContent (banners+categories done) not
                              // _isLoadingHomeSections (stores+layouts done).  The banner
                              // has no dependency on stores or hair-care layouts, and those
                              // deferred queries finish 300-600 ms later — holding the
                              // biggest above-fold element as a skeleton for no reason.
                              if (_isLoadingHeroContent)
                                _buildHomeBannerSkeleton(isWeb: true)
                              else if (bannerImages.isNotEmpty)
                                CarouselSlider(
                                  options: CarouselOptions(
                                    aspectRatio:
                                        1920 /
                                        600, // Correct aspect ratio for web banners
                                    height:
                                        412, // Reduced height to align with right column (250 + 12 + 150)
                                    viewportFraction: 1.0,
                                    autoPlay: true,
                                    autoPlayInterval: const Duration(
                                      seconds: 6,
                                    ),
                                    autoPlayAnimationDuration: const Duration(
                                      milliseconds: 1000,
                                    ),
                                  ),
                                  items: bannerImages.map((i) {
                                    return Builder(
                                      builder: (BuildContext context) {
                                        return Container(
                                          width: MediaQuery.of(
                                            context,
                                          ).size.width,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFF0F0F0),
                                          ),
                                          child: _buildScaledHomeBannerImage(
                                            i,
                                            errorWidget: Container(
                                              color: Colors.grey.shade200,
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.image_not_supported,
                                                      size: 64,
                                                      color:
                                                          Colors.grey.shade400,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      'Kampanya Görseli',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        color: Colors
                                                            .grey
                                                            .shade500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                                )
                              else
                                Container(
                                  color: Colors.grey.shade100,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.campaign_outlined,
                                          size: 64,
                                          color: Colors.grey.shade300,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Henüz kampanya bulunmuyor',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade500,
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

                      const SizedBox(width: 24),

                      // Sağ: Günün Fırsatı ve Kuponlar
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            // Günün Fırsatı
                            SizedBox(
                              height: 250, // Reverted to original height
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary.withValues(alpha: 0.06),
                                      Colors.white,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Stack(
                                  children: [
                                    Center(
                                      child: _isLoadingProducts
                                          ? _buildDealOfTheDaySkeleton()
                                          : popularProducts.isNotEmpty
                                          ? DealOfTheDaySlider(
                                              products: popularProducts,
                                            )
                                          : const SizedBox(),
                                    ),
                                    Positioned(
                                      top: 16,
                                      left: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFF9800),
                                              AppColors.primary,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.flash_on,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Günün Fırsatı',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
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
                            const SizedBox(height: 12), // Consistent spacing
                            // Kuponlar
                            SizedBox(
                              height: 150, // Reduced height as requested
                              child: CouponSlider(
                                isLoading: _isLoadingHomeSections,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 2.5 Yakın Lokasyon Alanı
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDF0FF),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFB9DFFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC9E7FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.near_me_outlined,
                              color: Color(0xFF2891F1),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Yakın Lokasyon ile çevrendeki mağazalardan alışveriş yapabilirsin',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF7A8A99),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2891F1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Yakın Lokasyon',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Yatay Liste
                      (_isLoadingProducts || _isLoadingHomeSections)
                          ? _buildHorizontalProductSkeletons(
                              height: 312,
                              itemWidth: 198,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                            )
                          : fastDeliveryProducts.isNotEmpty
                          ? SizedBox(
                              height: 312,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ScrollConfiguration(
                                    behavior: ScrollConfiguration.of(context)
                                        .copyWith(
                                          dragDevices: {
                                            PointerDeviceKind.touch,
                                            PointerDeviceKind.mouse,
                                          },
                                        ),
                                    child: ListView.separated(
                                      controller:
                                          _todayProductsScrollController,
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      itemCount: fastDeliveryProducts.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(width: 20),
                                      itemBuilder: (context, index) {
                                        final dbProduct =
                                            fastDeliveryProducts[index];
                                        return SizedBox(
                                          width: 198,
                                          child: _wrapProductReveal(
                                            scope: 'home-web-fast-delivery',
                                            index: index,
                                            token: _productRevealTokenFromDb(
                                              dbProduct,
                                            ),
                                            child: ProductCard(
                                              product: _convertToProduct(
                                                dbProduct,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // Sol Ok
                                  Positioned(
                                    left: -6,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: _buildCarouselArrowButton(
                                        icon: Icons.arrow_back_ios_new,
                                        color: const Color(0xFF2891F1),
                                        onTap: () => _scrollCarousel(
                                          _todayProductsScrollController,
                                          -300,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Sağ Ok
                                  Positioned(
                                    right: -6,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: _buildCarouselArrowButton(
                                        icon: Icons.arrow_forward_ios,
                                        color: const Color(0xFF2891F1),
                                        onTap: () => _scrollCarousel(
                                          _todayProductsScrollController,
                                          300,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                const SponsoredProductListsSection(
                  title: 'Ana Sayfada Öne Çıkan Listeler',
                  subtitle:
                      'Liste reklamı verilen koleksiyonlar burada sponsorlu gösterilir.',
                  placement: AdPlacement.homeFeed,
                ),

                const SizedBox(height: 32),

                // 3. Popüler Ürünler Başlığı
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Popüler Ürünler',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: const Text(
                          'Tümünü Gör',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Popüler Ürünler Listesi (Yatay Kaydırılabilir)
                _isLoadingProducts
                    ? _buildHorizontalProductSkeletons(
                        height: 312,
                        itemWidth: 198,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      )
                    : popularProducts.isEmpty
                    ? SizedBox(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: 48,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Bu kategoride ürün bulunamadı',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 312,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context)
                                  .copyWith(
                                    dragDevices: {
                                      PointerDeviceKind.touch,
                                      PointerDeviceKind.mouse,
                                    },
                                  ),
                              child: ListView.separated(
                                controller: _popularProductsScrollController,
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                itemCount: popularProducts.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: 20),
                                itemBuilder: (context, index) {
                                  final dbProduct = popularProducts[index];
                                  return SizedBox(
                                    width: 198,
                                    child: _wrapProductReveal(
                                      scope: 'home-web-popular-products',
                                      index: index,
                                      token: _productRevealTokenFromDb(
                                        dbProduct,
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
                              left: -6,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _buildCarouselArrowButton(
                                  icon: Icons.arrow_back_ios_new,
                                  color: AppColors.primary,
                                  onTap: () => _scrollCarousel(
                                    _popularProductsScrollController,
                                    -300,
                                  ),
                                ),
                              ),
                            ),
                            // Sağ Ok
                            Positioned(
                              right: -6,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: _buildCarouselArrowButton(
                                  icon: Icons.arrow_forward_ios,
                                  color: AppColors.primary,
                                  onTap: () => _scrollCarousel(
                                    _popularProductsScrollController,
                                    300,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                const SizedBox(height: 40),

                // 4.5 Flaş Ürünler - Grid Bölümü
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFFFF0EE),
                        const Color(0xFFFFF8F7),
                        const Color(0xFFFFF0EE),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFF4D2CE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.flash_on,
                              color: Colors.red,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Flaş Ürünler',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              Text(
                                'Kaçırılmayacak fırsatlar',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Sınırlı Süre',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Grid yerine Yatay Liste
                      _isLoadingProducts
                          ? _buildHorizontalProductSkeletons(
                              height: 312,
                              itemWidth: 198,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            )
                          : opportunityProducts.isNotEmpty
                          ? SizedBox(
                              height: 312,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ScrollConfiguration(
                                    behavior: ScrollConfiguration.of(context)
                                        .copyWith(
                                          dragDevices: {
                                            PointerDeviceKind.touch,
                                            PointerDeviceKind.mouse,
                                          },
                                        ),
                                    child: ListView.separated(
                                      controller:
                                          _flashProductsScrollController,
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      itemCount: opportunityProducts.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(width: 20),
                                      itemBuilder: (context, index) {
                                        final dbProduct =
                                            opportunityProducts[index];
                                        return SizedBox(
                                          width: 198,
                                          child: _wrapProductReveal(
                                            scope: 'home-web-opportunities',
                                            index: index,
                                            token: _productRevealTokenFromDb(
                                              dbProduct,
                                            ),
                                            child: ProductCard(
                                              product: _convertToProduct(
                                                dbProduct,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // Sol Ok
                                  Positioned(
                                    left: -6,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: _buildCarouselArrowButton(
                                        icon: Icons.arrow_back_ios_new,
                                        color: AppColors.primary,
                                        onTap: () => _scrollCarousel(
                                          _flashProductsScrollController,
                                          -300,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Sağ Ok
                                  Positioned(
                                    right: -6,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: _buildCarouselArrowButton(
                                        icon: Icons.arrow_forward_ios,
                                        color: AppColors.primary,
                                        onTap: () => _scrollCarousel(
                                          _flashProductsScrollController,
                                          300,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Neden iBul? Bölümü
                _buildWhyIbulSection(),

                // Sistem Düzeni kartları: Neden iBul'un altında alt alta
                if (_hairCareLayoutsForHome.isNotEmpty) ...[
                  const SizedBox(height: 40),
                  Column(
                    children: _hairCareLayoutsForHome
                        .map(
                          (layout) => Padding(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: DynamicBrandSection(
                              layout: layout,
                              allProducts: _dbProducts,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ] else ...[
                  const SizedBox(height: 40),
                ],

                // Avantaj Çubuğu (En Alta Taşındı)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.05),
                        Colors.white,
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTrustItem(
                        Icons.local_shipping_outlined,
                        'Ücretsiz Kargo',
                        '150 TL üzeri',
                      ),
                      _buildTrustDivider(),
                      _buildTrustItem(
                        Icons.verified_user_outlined,
                        'Güvenli Ödeme',
                        '256-bit SSL',
                      ),
                      _buildTrustDivider(),
                      _buildTrustItem(
                        Icons.replay_outlined,
                        '14 Gün İade',
                        'Koşulsuz iade',
                      ),
                      _buildTrustDivider(),
                      _buildTrustItem(
                        Icons.support_agent_outlined,
                        '7/24 Destek',
                        'Canlı yardım',
                      ),
                      _buildTrustDivider(),
                      _buildTrustItem(
                        Icons.workspace_premium_outlined,
                        'Orijinal Ürün',
                        'Garantili',
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDealOfTheDaySkeleton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SkeletonLoading(
              width: double.infinity,
              height: 130,
              borderRadius: 0,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoading(
                  width: double.infinity,
                  height: 14,
                  borderRadius: 4,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonLoading(width: 80, height: 22, borderRadius: 4),
                    SkeletonLoading(width: 32, height: 32, borderRadius: 8),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

typedef _HomeBannerSkeletonBuilder = Widget Function({required bool isWeb});
typedef _HomeBannerImageBuilder =
    Widget Function(String imagePath, {required Widget errorWidget});
typedef _DbProductConverter = Product Function(DBProduct dbProduct);

class _MobileAddressBarSliver extends StatelessWidget {
  const _MobileAddressBarSliver();

  @override
  Widget build(BuildContext context) {
    final currentAddress = context.select<AppState, String>(
      (appState) => appState.currentDeliveryAddress ?? 'Adres Seçin',
    );

    return SliverToBoxAdapter(
      child: AddressBar(
        currentAddress: currentAddress,
        onAddressChanged: (newAddress) {
          context.read<AppState>().setCurrentDeliveryAddress(newAddress);
        },
      ),
    );
  }
}

class _MobileBannerSliver extends StatelessWidget {
  const _MobileBannerSliver({
    required this.isLoadingHeroContent,
    required this.mobileBannerImages,
    required this.buildHomeBannerSkeleton,
    required this.buildScaledHomeBannerImage,
  });

  final bool isLoadingHeroContent;
  final List<String> mobileBannerImages;
  final _HomeBannerSkeletonBuilder buildHomeBannerSkeleton;
  final _HomeBannerImageBuilder buildScaledHomeBannerImage;

  @override
  Widget build(BuildContext context) {
    if (isLoadingHeroContent) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: SizedBox(
            height: 130,
            child: RepaintBoundary(
              child: buildHomeBannerSkeleton(isWeb: false),
            ),
          ),
        ),
      );
    }

    if (mobileBannerImages.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: RepaintBoundary(
        child: CarouselSlider(
          options: CarouselOptions(
            aspectRatio: 1920 / 600,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            enlargeCenterPage: true,
            viewportFraction: 0.95,
          ),
          items: mobileBannerImages.map((imagePath) {
            return Builder(
              builder: (BuildContext context) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: buildScaledHomeBannerImage(
                      imagePath,
                      errorWidget: Container(
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PersonalizedProductsTitle extends StatelessWidget {
  const _PersonalizedProductsTitle();

  @override
  Widget build(BuildContext context) {
    final firstName = context.select<AppState, String>((appState) {
      final fullName = UserIdentity.resolveDisplayName(
        currentUser: appState.currentUser,
      );
      return fullName.split(' ').first;
    });

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
          fontFamily: 'Poppins',
        ),
        children: [
          TextSpan(
            text: firstName,
            style: const TextStyle(color: AppColors.primary),
          ),
          TextSpan(
            text: ', Sana Özel Ürünler',
            style: TextStyle(color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }
}

String _homeProductRevealTokenFromDb(DBProduct product) {
  final productId = product.id?.trim();
  if (productId != null && productId.isNotEmpty) {
    return productId;
  }

  final store = product.store?.trim() ?? '';
  return '${product.name.trim()}|$store';
}

Widget _wrapHomeProductReveal({
  required String scope,
  required int index,
  required String token,
  required Widget child,
}) {
  return StaggeredReveal(
    revealId: '$scope|$token',
    index: index,
    enabled: index < 8,
    child: child,
  );
}

class _HomeProductRailSection extends StatelessWidget {
  const _HomeProductRailSection({
    required this.title,
    required this.isLoadingProducts,
    required this.hasProducts,
    required this.products,
    required this.convertToProduct,
  });

  final Widget title;
  final bool isLoadingProducts;
  final bool hasProducts;
  final List<DBProduct> products;
  final _DbProductConverter convertToProduct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: 10),
          if (isLoadingProducts)
            _buildHorizontalProductRailSkeleton()
          else if (!hasProducts)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'Henüz ürün yok',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            )
          else
            RepaintBoundary(
              child: SizedBox(
                height: 312,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  cacheExtent: 500,
                  itemCount: products.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final dbProduct = products[index];
                    return SizedBox(
                      width: 198,
                      child: _wrapHomeProductReveal(
                        scope: 'home-mobile-rail',
                        index: index,
                        token: _homeProductRevealTokenFromDb(dbProduct),
                        child: ProductCard(
                          product: convertToProduct(dbProduct),
                          margin: EdgeInsets.zero,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHorizontalProductRailSkeleton() {
    return SizedBox(
      height: 312,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            const SizedBox(width: 198, child: ProductCardSkeleton()),
      ),
    );
  }
}

class _FastDeliverySection extends StatelessWidget {
  const _FastDeliverySection({
    required this.isLoading,
    required this.products,
    required this.convertToProduct,
  });

  final bool isLoading;
  final List<DBProduct> products;
  final _DbProductConverter convertToProduct;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE3F2FD),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hızlı Teslimat',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Çevrenizdeki mağazalardan hızlı alışveriş',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Hızlı Teslimat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 312,
            child: isLoading
                ? const _HorizontalProductCardSkeletonList()
                : products.isEmpty
                ? const Center(child: Text('Hızlı teslimat ürünü bulunamadı'))
                : RepaintBoundary(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      cacheExtent: 500,
                      itemCount: products.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final dbProduct = products[index];
                        return SizedBox(
                          width: 198,
                          child: _wrapHomeProductReveal(
                            scope: 'home-mobile-fast-delivery',
                            index: index,
                            token: _homeProductRevealTokenFromDb(dbProduct),
                            child: ProductCard(
                              product: convertToProduct(dbProduct),
                              margin: EdgeInsets.zero,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DynamicBrandLayoutsSection extends StatelessWidget {
  const _DynamicBrandLayoutsSection({
    required this.layouts,
    required this.allProducts,
  });

  final List<Map<String, dynamic>> layouts;
  final List<DBProduct> allProducts;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Column(
        children: layouts
            .map(
              (layout) => Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: DynamicBrandSection(
                  layout: layout,
                  allProducts: allProducts,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _OpportunityProductsSection extends StatelessWidget {
  const _OpportunityProductsSection({
    required this.isLoadingProducts,
    required this.products,
    required this.convertToProduct,
  });

  final bool isLoadingProducts;
  final List<DBProduct> products;
  final _DbProductConverter convertToProduct;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFEBEE),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fırsat Ürünler',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Kaçırılmayacak fırsatlar',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_offer, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Fırsat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 312,
            child: isLoadingProducts
                ? const _HorizontalProductCardSkeletonList()
                : products.isEmpty
                ? const Center(child: Text('Fırsat ürünü bulunamadı'))
                : RepaintBoundary(
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      cacheExtent: 500,
                      itemCount: products.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final dbProduct = products[index];
                        return SizedBox(
                          width: 198,
                          child: _wrapHomeProductReveal(
                            scope: 'home-mobile-opportunities',
                            index: index,
                            token: _homeProductRevealTokenFromDb(dbProduct),
                            child: ProductCard(
                              product: convertToProduct(dbProduct),
                              margin: EdgeInsets.zero,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalProductCardSkeletonList extends StatelessWidget {
  const _HorizontalProductCardSkeletonList();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 310,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        itemCount: 3,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) =>
            const SizedBox(width: 198, child: ProductCardSkeleton()),
      ),
    );
  }
}
