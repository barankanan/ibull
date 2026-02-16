import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../widgets/web_header.dart';
import '../widgets/web_footer.dart';
import '../widgets/account_sidebar.dart';
import 'settings_page.dart';
import 'orders_page.dart';
import 'favorites_page.dart';
import 'reviews_page.dart';
import 'ai_chat_page.dart';
import 'followed_stores_page.dart';
import 'my_chats_page.dart';
import 'coupons_page.dart';
import 'addresses_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
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
      backgroundColor: const Color(0xFFF9FAFB), // Softer background for web
      body: Column(
        children: [
          WebHeader(
            onSearch: (q) {}, 
            activeMenu: 'account',
            // Mock callbacks as AccountPage doesn't manage full state like Home
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Sidebar (Navigation)
                            const SizedBox(
                              width: 280,
                              child: AccountSidebar(activePage: 'Hesap Özeti'),
                            ),
                            const SizedBox(width: 32),
                            // Right Content (Dashboard)
                            Expanded(
                              child: _buildWebDashboard(),
                            ),
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

  Widget _buildWebDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoş Geldin, Baran! 👋',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'İbul Premium üyesisin. Bu ay 450 TL kazanç sağladın.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Premium Üye',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Quick Stats
        Row(
          children: [
            _buildStatCard('Toplam Sipariş', '124', Icons.shopping_bag, Colors.blue),
            const SizedBox(width: 24),
            _buildStatCard('Bekleyen', '2', Icons.local_shipping, Colors.orange),
            const SizedBox(width: 24),
            _buildStatCard('İndirim Kuponu', '4', Icons.local_offer, Colors.purple),
            const SizedBox(width: 24),
            _buildStatCard('Cüzdan', '1.250 TL', Icons.account_balance_wallet, Colors.green),
          ],
        ),

        const SizedBox(height: 32),

        // Recent Orders Section
        const Text(
          'Son Siparişler',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _buildOrderRow(
                orderId: '#TR-2024-8592',
                date: 'Bugün, 14:30',
                status: 'Yolda',
                price: '450.00 TL',
                items: 'Apple iPhone 15 Kılıf, Ekran Koruyucu...',
                statusColor: Colors.orange,
              ),
              const Divider(height: 1),
              _buildOrderRow(
                orderId: '#TR-2024-8591',
                date: 'Dün, 18:15',
                status: 'Teslim Edildi',
                price: '1.250.00 TL',
                items: 'Nike Air Force 1 Spor Ayakkabı',
                statusColor: Colors.green,
              ),
              const Divider(height: 1),
              _buildOrderRow(
                orderId: '#TR-2024-8588',
                date: '10 Ekim 2024',
                status: 'Teslim Edildi',
                price: '89.90 TL',
                items: 'Logitech Mouse Pad',
                statusColor: Colors.green,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Recommended / Favorites Preview
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Favori Ürünlerin',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(onPressed: () {}, child: const Text('Tümünü Gör')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Placeholder for horizontal product list
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Center(
                      child: Text('Favori ürünler listesi buraya gelecek'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kayıtlı Adresim',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 180,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.home, color: AppColors.primary),
                            const SizedBox(width: 8),
                            const Text(
                              'Ev Adresi',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const AddressesPage()));
                              }, 
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Baran Kananoğulları',
                          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gökmeydan Mah. Nazım Hikmet Kültür Merkezi Karşısı\nPrefabrik Ev No: 5',
                          style: TextStyle(color: Colors.grey.shade600, height: 1.5),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Eskişehir / Odunpazarı',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
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

  Widget _buildOrderRow({
    required String orderId,
    required String date,
    required String status,
    required String price,
    required String items,
    required Color statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderId,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  items,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              date,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              price,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildMobileView() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Header - Profile Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Profile Image
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.grey.shade300,
                      child: const Icon(Icons.person, size: 36, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Baran Kananoğulları',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Boy: 1.67    Kilo: 75    Yaş:18',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    // Settings Button
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsPage()),
                        );
                      },
                      icon: const Icon(Icons.settings, size: 16),
                      label: const Text('Ayarlar', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Adresim
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Adresim',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Prefabrik ev-Gökmeydan Mah. Nazım Hikmet kül...',
                              style: TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AddressesPage()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.primary),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sync, size: 12, color: AppColors.primary),
                                  SizedBox(width: 4),
                                  Text(
                                    'Değiştir',
                                    style: TextStyle(fontSize: 10, color: AppColors.primary),
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
              const SizedBox(height: 16),
              
              // Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 110, // Matched with Home Screen ad banner height
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade900,
                    borderRadius: BorderRadius.circular(12),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/features/yapay-zeka.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  // If image is missing, show fallback content
                  child: Stack(
                    children: [
                      // Only show text if image fails (using errorBuilder in a real Image widget would be better, 
                      // but here we assume the asset exists or use this as placeholder background)
                      // For now, let's keep the text hidden assuming the image has text, 
                      // or we can overlay it if needed. Let's keep it clean as requested "tasarım boyutu".
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Three Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: _buildActionButton(Icons.shopping_bag_outlined, 'Siparişlerim', onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const OrdersPage()),
                      );
                    })),
                    const SizedBox(width: 8),
                    Expanded(child: _buildActionButton(Icons.favorite_border, 'Beğendiklerim', onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FavoritesPage()),
                      );
                    })),
                    const SizedBox(width: 8),
                    Expanded(child: _buildActionButton(Icons.chat_bubble_outline, 'Değerlendirmeler', onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ReviewsPage()),
                      );
                    })),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Menu Items
              _buildMenuItem(Icons.lightbulb_outline, 'Yapay Zekaya Danış', 
                subtitle: 'Ne almak istediği sor , Hızlı karşılaştırmalar yap',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AIChatPage()),
                  );
                }),
              _buildMenuItem(Icons.headset_mic_outlined, 'Müşteri Hizmetleri'),
              _buildMenuItem(Icons.access_time, 'Eski Siparişlerim / Tekrar al'),
              _buildMenuItem(Icons.credit_card_outlined, 'Kartlarım'),
              _buildMenuItem(Icons.home_outlined, 'Barana Özel İndirimler'),
              _buildMenuItem(Icons.local_offer_outlined, 'Kuponlarım', onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CouponsPage()),
                );
              }),
              _buildMenuItem(Icons.bookmark_border, 'Takip Ettiklerim', onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FollowedStoresPage()),
                );
              }),
              _buildMenuItem(Icons.chat_bubble_outline, 'Sohbetlerim', onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyChatsPage()),
                );
              }),
              _buildMenuItem(Icons.key, 'İabul Premium'),
              
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Hizmetler',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              _buildMenuItem(Icons.local_shipping_outlined, 'Hızlı Ürün Gönder'),
              _buildMenuItem(Icons.build_outlined, 'Garantili Tamir'),
              _buildMenuItem(Icons.format_list_bulleted, 'Montaj Hizmeti'),
              _buildMenuItem(Icons.add_circle_outline, 'Mağaza Başvurusu Yap'),
              _buildMenuItem(Icons.star_border, 'Uygulama Görüşün'),
              _buildMenuItem(Icons.help_outline, 'Yardım'),
              
              const SizedBox(height: 24),
              
              // Logout Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Çıkış Yap',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, {String? subtitle, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
