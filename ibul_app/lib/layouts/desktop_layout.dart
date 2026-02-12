import 'package:flutter/material.dart';
import '../responsive/responsive_layout.dart';
import '../responsive/breakpoints.dart';

/// Desktop Layout - Geniş ekran (1200px+) için tasarlanmış layout
/// 
/// Yapısı:
/// - Header (navigation bar)
/// - Content area (sidebar + main content)
/// - Footer

class DesktopLayout extends StatefulWidget {
  final Widget? content;
  final String? title;

  const DesktopLayout({
    Key? key,
    this.content,
    this.title,
  }) : super(key: key);

  @override
  State<DesktopLayout> createState() => _DesktopLayoutState();
}

class _DesktopLayoutState extends State<DesktopLayout> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            DesktopHeader(title: widget.title),

            // Main Content Area
            SizedBox(
              width: double.infinity,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Sidebar
                  DesktopSidebar(),

                  // Main Content
                  Expanded(
                    child: widget.content ?? const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // Footer
            const DesktopFooter(),
          ],
        ),
      ),
    );
  }
}

/// Desktop Header Widget
class DesktopHeader extends StatelessWidget {
  final String? title;

  const DesktopHeader({
    Key? key,
    this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ResponsivePadding(
        desktopPadding: const EdgeInsets.symmetric(
          horizontal: ScreenBreakpoints.desktopHorizontalPadding,
          vertical: 16,
        ),
        child: Row(
          children: [
            // Logo
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'IBUL',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Search bar
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Ürün ara...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.grey),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),

            // Navigation items
            Row(
              children: [
                _NavItem('Kategoriler'),
                const SizedBox(width: 24),
                _NavItem('İşletmeler'),
                const SizedBox(width: 24),
                _NavItem('İndirimler'),
              ],
            ),
            const SizedBox(width: 24),

            // User menu
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: PopupMenuButton<String>(
                child: const Row(
                  children: [
                    Icon(Icons.person, size: 24),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_drop_down),
                  ],
                ),
                onSelected: (value) {
                  // Handle menu selection
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'profile',
                    child: Text('Profil'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'orders',
                    child: Text('Siparişlerim'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: Text('Ayarlar'),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Çıkış Yap'),
                  ),
                ],
              ),
            ),

            // Cart icon
            const SizedBox(width: 16),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: const Icon(Icons.shopping_cart, size: 24),
            ),
          ],
        ),
      ),
    );
  }
}

/// Navigation item widget
class _NavItem extends StatefulWidget {
  final String label;

  const _NavItem(this.label);

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _isHovered ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _isHovered ? Colors.blue : Colors.black,
          ),
        ),
      ),
    );
  }
}

/// Desktop Sidebar Widget
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          right: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: ListView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Kategoriler Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'KATEGORİLER',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
            ),
          ),

          // Kategori öğeleri
          ...[
            'Elektronik',
            'Giyim',
            'Ev & Bahçe',
            'Spor',
            'Kişisel Bakım',
            'Kitaplar',
            'Oyuncaklar',
            'Diğer',
          ].map((category) => _SidebarItem(category)),

          const Divider(thickness: 1, height: 16),

          // Filtreleme Başlığı
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'FİLTRELE',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
            ),
          ),

          // Fiyat filtresi
          _FilterSection(
            title: 'Fiyat Aralığı',
            content: Column(
              children: [
                RangeSlider(
                  values: const RangeValues(0, 5000),
                  min: 0,
                  max: 10000,
                  onChanged: (RangeValues values) {},
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('₺0', style: Theme.of(context).textTheme.bodySmall),
                      Text('₺10.000', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Rating filtresi
          _FilterSection(
            title: 'Değerlendirme',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(5, (index) {
                final stars = 5 - index;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: false,
                        onChanged: (value) {},
                      ),
                      Row(
                        children: List.generate(
                          stars,
                          (i) => const Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${5 - index}+ Yıldız',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sidebar kategori öğesi
class _SidebarItem extends StatefulWidget {
  final String label;

  const _SidebarItem(this.label);

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Container(
        color: _isHovered ? Colors.grey[200] : Colors.transparent,
        child: ListTile(
          title: Text(widget.label),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}

/// Filtre section widget
class _FilterSection extends StatelessWidget {
  final String title;
  final Widget content;

  const _FilterSection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: content,
        ),
      ],
    );
  }
}

/// Desktop Footer Widget
class DesktopFooter extends StatelessWidget {
  const DesktopFooter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.grey[900],
      child: ResponsivePadding(
        desktopPadding: const EdgeInsets.symmetric(
          horizontal: ScreenBreakpoints.desktopHorizontalPadding,
          vertical: 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Column 1
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hakkında',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _FooterLink('Biz Kimiz?'),
                      _FooterLink('Blog'),
                      _FooterLink('Kariyer'),
                    ],
                  ),
                ),

                // Column 2
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yardım',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _FooterLink('İletişim'),
                      _FooterLink('SSS'),
                      _FooterLink('Kargo & Ödeme'),
                    ],
                  ),
                ),

                // Column 3
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yasal',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _FooterLink('Gizlilik Politikası'),
                      _FooterLink('Kullanım Şartları'),
                      _FooterLink('Çerez Politikası'),
                    ],
                  ),
                ),

                // Column 4 - Social
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bizi Takip Edin',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _SocialIcon(Icons.facebook),
                          const SizedBox(width: 12),
                          _SocialIcon(Icons.pages),
                          const SizedBox(width: 12),
                          _SocialIcon(Icons.image),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(color: Colors.grey, height: 40),

            // Copyright
            Text(
              '© 2026 IBUL. Tüm hakları saklıdır.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Footer link widget
class _FooterLink extends StatefulWidget {
  final String label;

  const _FooterLink(this.label);

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          widget.label,
          style: TextStyle(
            color: _isHovered ? Colors.blue[300] : Colors.grey[300],
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// Social icon widget
class _SocialIcon extends StatefulWidget {
  final IconData icon;

  const _SocialIcon(this.icon);

  @override
  State<_SocialIcon> createState() => _SocialIconState();
}

class _SocialIconState extends State<_SocialIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _isHovered ? Colors.blue : Colors.grey[700],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          widget.icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
