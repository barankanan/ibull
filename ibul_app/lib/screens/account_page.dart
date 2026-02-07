import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'settings_page.dart';
import 'orders_page.dart';
import 'favorites_page.dart';
import 'reviews_page.dart';
import 'ai_chat_page.dart';
import 'followed_stores_page.dart';
import 'my_chats_page.dart';
import 'coupons_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (context) => const _AddressSelectionSheet(),
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
                      image: AssetImage('assets/images/features/yapay-zeka-banner.png'),
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

// Copy the _AddressSelectionSheet classes from address_bar.dart
class _AddressSelectionSheet extends StatefulWidget {
  const _AddressSelectionSheet();

  @override
  State<_AddressSelectionSheet> createState() => _AddressSelectionSheetState();
}

class _AddressSelectionSheetState extends State<_AddressSelectionSheet> {
  int _selectedTab = 0;
  
  final List<Map<String, String>> _deliveryAddresses = [
    {'title': 'Ev', 'detail': 'Prefabrik ev - Gökmeydan Mah..'},
    {'title': 'İş', 'detail': 'Teknopark - Organize Sanayi Bölgesi'},
  ];

  final List<Map<String, String>> _billingInfos = [
    {'title': 'Kişisel Fatura', 'detail': 'Baran Kananogullari - 1234567890'},
  ];

  void _openEditScreen({Map<String, String>? address}) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddressEditSheet(
        initialData: address,
        type: _selectedTab == 0 ? 'Adres' : 'Fatura',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 40),
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Adreslerim',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTabs(),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _selectedTab == 0 ? _deliveryAddresses.length : _billingInfos.length,
              itemBuilder: (context, index) {
                final item = _selectedTab == 0 ? _deliveryAddresses[index] : _billingInfos[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(
                      _selectedTab == 0 ? Icons.place : Icons.receipt,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(item['detail']!, style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.grey),
                    onPressed: () => _openEditScreen(address: item),
                  ),
                  onTap: () {
                     _openEditScreen(address: item);
                  },
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton.icon(
              onPressed: () => _openEditScreen(),
              icon: const Icon(Icons.add),
              label: Text(_selectedTab == 0 ? 'Yeni Adres Ekle' : 'Yeni Fatura Ekle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(
          child: _buildTabButton(
            label: 'Teslimat Adreslerim',
            isActive: _selectedTab == 0,
            onTap: () => setState(() => _selectedTab = 0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTabButton(
            label: 'Fatura Bilgilerim',
            isActive: _selectedTab == 1,
            onTap: () => setState(() => _selectedTab = 1),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({required String label, required bool isActive, required VoidCallback onTap}) {
    return SizedBox(
      height: 36,
      child: isActive
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
              ),
              child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: EdgeInsets.zero,
              ),
              child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
    );
  }
}

class _AddressEditSheet extends StatefulWidget {
  final Map<String, String>? initialData;
  final String type;

  const _AddressEditSheet({this.initialData, required this.type});

  @override
  State<_AddressEditSheet> createState() => _AddressEditSheetState();
}

class _AddressEditSheetState extends State<_AddressEditSheet> {
  late TextEditingController _titleController;
  late TextEditingController _detailController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialData?['title'] ?? '');
    _detailController = TextEditingController(text: widget.initialData?['detail'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.initialData != null;
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEditing ? '${widget.type} Düzenle' : 'Yeni ${widget.type} Ekle',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Başlık (Örn: Ev, İş)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _detailController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Detaylı Adres',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (isEditing) 
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('Sil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              if (isEditing) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.save, size: 18),
                  label: Text(isEditing ? 'Güncelle' : 'Kaydet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
