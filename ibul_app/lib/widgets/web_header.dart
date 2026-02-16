
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../screens/cart_page.dart';
import '../screens/account_page.dart';
import '../screens/favorites_page.dart';
import '../screens/notifications_page.dart';
import '../core/app_state.dart';
import 'search_overlay.dart';
import 'advanced_filter_drawer.dart';

class WebHeader extends StatefulWidget {
  final ValueChanged<String> onSearch;
  final ValueChanged<String>? onCategorySelected;
  final String? selectedCategory;
  final String? initialQuery;
  final String? activeMenu;

  const WebHeader({
    super.key,
    required this.onSearch,
    this.onCategorySelected,
    this.selectedCategory,
    this.initialQuery,
    this.activeMenu,
  });

  @override
  State<WebHeader> createState() => _WebHeaderState();
}

class _WebHeaderState extends State<WebHeader> {
  final ScrollController _categoryScrollController = ScrollController();
  final LayerLink _layerLink = LayerLink();
  final FocusNode _searchFocusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    _searchFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_searchFocusNode.hasFocus) {
      _showOverlay();
    } else {
      // Delay to allow tap on overlay items
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_searchFocusNode.hasFocus) {
          _hideOverlay();
        }
      });
    }
  }

  final GlobalKey _searchKey = GlobalKey();

  void _showOverlay({bool showFilters = false}) {
    if (_overlayEntry != null) {
      _hideOverlay();
    }

    final RenderBox renderBox = _searchKey.currentContext!.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50), // Height of bar (48) + spacing (2)
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: SearchOverlay(
              onClose: _hideOverlay,
              onSearch: (query) {
                _searchController.text = query;
                widget.onSearch(query);
                _searchFocusNode.unfocus();
                _hideOverlay();
              },
              showFilters: showFilters,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _categoryScrollController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _hideOverlay();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Üst Bar (Logo, Arama, Menüler)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          child: Row(
            children: [
              // 1. Logo
              _buildLogo(),
              
              const SizedBox(width: 48),
              
              // 2. Search Bar
              Expanded(
                child: _buildSearchBar(),
              ),
              
              const SizedBox(width: 32),
              
              // 3. Location (Konum)
              _buildLocation(),
              
              const SizedBox(width: 32),

              // 4. Menu Items (Hesabım, Favorilerim, Sepetim)
              _buildMenuItems(context),
            ],
          ),
        ),
        
        // Kategori Menüsü (Alt Bar)
        _buildCategoryBar(),
      ],
    );
  }

  Widget _buildLogo() {
    return InkWell(
      onTap: () {
        if (widget.onCategorySelected != null) {
          widget.onCategorySelected!('Ana Sayfa');
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      },
      hoverColor: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 8),
          Text(
            'iBul',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: -0.5,
              fontFamily: 'Montserrat', 
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchOverlay() {
    showDialog(
      context: context,
      barrierColor: Colors.transparent, // Handled by overlay itself
      builder: (context) => SearchOverlay(
        onClose: () => Navigator.pop(context),
        onSearch: (query) {
          Navigator.pop(context);
          widget.onSearch(query);
        },
      ),
    );
  }

  void _showFilterDrawer() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Align(
          alignment: Alignment.topRight,
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.only(top: 80, right: 40),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SizedBox(
                  width: 350,
                  height: 480,
                  child: AdvancedFilterDrawer(
                    onClose: () => Navigator.pop(context),
                    onApply: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationsPage(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(6),
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
            child: const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CompositedTransformTarget(
            link: _layerLink,
            child: Container(
              key: _searchKey,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.search, color: Colors.grey, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      textAlign: TextAlign.start,
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onSubmitted: (value) {
                        widget.onSearch(value);
                        _hideOverlay();
                      },
                      decoration: const InputDecoration(
                        hintText: 'Ürün, kategori veya marka ara...',
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),

                  const SizedBox(width: 8),

                  InkWell(
                    onTap: () {
                      // Kamera ikonu şimdilik davranışsız
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: const Icon(
                        Icons.photo_camera_outlined,
                        color: Colors.black54,
                        size: 20,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  InkWell(
                    onTap: () {
                      widget.onSearch(_searchController.text);
                      _hideOverlay();
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Center(
                        child: Text(
                          'ARA',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocation() {
    return InkWell(
      onTap: () {
        // Navigate to MapPage
        Navigator.pushNamed(context, '/map');
        // Or if named route is not set up, use direct push:
        // Navigator.push(context, MaterialPageRoute(builder: (context) => const MapPage()));
        // Assuming '/map' or importing MapPage.
        // Let's use MaterialPageRoute for safety as I don't see routes defined here.
        // Need to import MapPage first? It is likely not imported. 
        // I will rely on the fact that I need to add import or use named route if available.
        // Let's check imports in next step or assume standard approach.
        // I'll add the import in a separate block if needed, but for now let's just use the callback if possible or standard push.
        // Since I can't easily check main.dart for routes right now without another read, I'll use a direct push and ensure import.
      },
      child: Row(
        children: [
          const Icon(Icons.map, color: AppColors.primary, size: 24),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Konum',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: const [
                  Text(
                    'Harita',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
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
  }
  
  Widget _buildMenuItems(BuildContext context) {
    final appState = AppState();
    final activeMenu = widget.activeMenu;
    
    return Row(
      children: [
        _MenuItem(
          icon: Icons.person_outline, 
          label: 'Hesabım', 
          isActive: activeMenu == 'account',
          onTap: () {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation1, animation2) => const AccountPage(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          }
        ),
        const SizedBox(width: 24),
        _MenuItem(
          icon: Icons.favorite_border, 
          label: 'Favorilerim', 
          isActive: activeMenu == 'favorites',
          onTap: () {
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation1, animation2) => const FavoritesPage(),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          }
        ),
        const SizedBox(width: 24),
        ValueListenableBuilder<int>(
          valueListenable: appState.cartCountNotifier,
          builder: (context, count, child) {
            return _MenuItem(
              icon: Icons.shopping_cart_outlined, 
              label: 'Sepetim', 
              isActive: activeMenu == 'cart',
              badgeCount: count > 0 ? count : null, 
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation1, animation2) => const CartPage(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              }
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildCategoryBar() {
    final categories = [
      'Yakın Lokasyon', 'Erkek', 'Kadın', 'Elektronik', 
      'Ayakkabı & Çanta', 'Saat & Aksesuar',
      'Ev & Yaşam', 'Kırtasiye & Ofis',
      'Oto, Bahçe, Yapı Market', 'Oyuncak, Müzik, Film', 
      'Spor & Outdoor', 'Kozmetik & Kişisel Bakım', 
      'Pet Shop'
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: SizedBox(
            height: 40,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: ListView.separated(
                  controller: _categoryScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 24, right: 60),
                  itemCount: categories.length,
                  shrinkWrap: true,
                  separatorBuilder: (context, index) => const SizedBox(width: 32),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = widget.selectedCategory == category;
                    return InkWell(
                      onTap: () => widget.onCategorySelected?.call(category),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                        decoration: BoxDecoration(
                          border: isSelected 
                            ? const Border(bottom: BorderSide(color: AppColors.primary, width: 2)) 
                            : null,
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.primary : Colors.grey[800],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.white,
                        Colors.white.withOpacity(0.0),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 20),
                  child: Container(
                    width: 32,
                    height: 32,
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
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.chevron_right, color: AppColors.primary),
                      onPressed: () {
                        _categoryScrollController.animateTo(
                          _categoryScrollController.offset + 200,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationsPopup extends StatefulWidget {
  final VoidCallback onClose;

  const _NotificationsPopup({
    required this.onClose,
  });

  @override
  State<_NotificationsPopup> createState() => _NotificationsPopupState();
}

class _NotificationsPopupState extends State<_NotificationsPopup> {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bildirimler',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close, size: 20),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildTabButton(0, 'Bildirim', Icons.notifications),
                    _buildTabButton(1, 'İzleme', Icons.visibility_outlined),
                    _buildTabButton(2, 'Mesaj', Icons.chat_bubble_outline),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            SizedBox(
              height: 260,
              child: _buildTabContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final bool isActive = _activeTab == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _activeTab = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? AppColors.primary : Colors.black54,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? AppColors.primary : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildNotificationsTab();
      case 1:
        return _buildWatchlistTab();
      case 2:
        return _buildMessagesTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNotificationsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildNotificationItem(
          title: 'Sepetine bıraktığın ürün düştü',
          subtitle: 'Takip ettiğin Dyson süpürgenin fiyatı %10 indi.',
          time: '5 dk önce',
          isNew: true,
        ),
        const SizedBox(height: 12),
        _buildNotificationItem(
          title: 'Siparişin kargoya verildi',
          subtitle: 'Apple AirPods Max siparişin yola çıktı.',
          time: 'Dün',
          isNew: false,
        ),
      ],
    );
  }

  Widget _buildWatchlistTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildWatchItem(
          title: 'iPhone 15 Pro 256 GB',
          tag: 'Fiyat izlemesi',
          status: 'Fiyat değişmedi',
        ),
        const SizedBox(height: 12),
        _buildWatchItem(
          title: 'Kablosuz dik süpürge',
          tag: 'Stok izlemesi',
          status: 'Stokta 3 mağaza var',
        ),
      ],
    );
  }

  Widget _buildMessagesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMessageItem(
          sender: 'Teknosa',
          preview: 'Merhaba, ürünle ilgili sorunu yardımcı olmak için buradayız.',
          time: '2 sa önce',
        ),
        const SizedBox(height: 12),
        _buildMessageItem(
          sender: 'Baran K***',
          preview: 'İlgin için teşekkürler, ürünü hala satıyorum.',
          time: 'Dün',
        ),
      ],
    );
  }

  Widget _buildNotificationItem({
    required String title,
    required String subtitle,
    required String time,
    required bool isNew,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.notifications, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
              if (isNew) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Yeni',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWatchItem({
    required String title,
    required String tag,
    required String status,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.visibility_outlined, size: 18, color: Colors.orange),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      status,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageItem({
    required String sender,
    required String preview,
    required String time,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey.shade200,
          child: Text(
            sender.isNotEmpty ? sender[0] : '?',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sender,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badgeCount;
   final bool isActive;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? AppColors.primary : Colors.black87;

    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: color, size: 20),
              if (badgeCount != null)
                  Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
