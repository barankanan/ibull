import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/chat_state.dart';
import '../core/store_logo_helper.dart';
import 'courier_info_page.dart';
import 'chat_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _codeController = TextEditingController();
  bool _isTrackingActive = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Dummy Data
    final List<Map<String, dynamic>> notifications = [
      {
        'badgeLabel': '',
        'badgeColor': Colors.transparent, // Arka plan rengini şeffaf yapıyoruz ki logo temiz görünsün
        'badgeIcon': null, // İkonu kaldırıyoruz
        'badgeImage': 'assets/store_logos/Arçelik-Logo.wine.png', // Asset logo kullanıyoruz
        'title': 'Arçelik',
        'description': 'Arçelik mağazamızdan aldığınız (MacBook Air 13\' 8C 256GB Silverlaptop) ürün kuryeye teslim edilmiştir. 1714 kodu ile takip edebilirsiniz.',
        'time': '02:13',
        'showButton': true,
        'trackingCode': '1714',
      },
      {
        'badgeLabel': 'iGaranti',
        'badgeColor': AppColors.primary,
        'badgeIcon': Icons.build_circle, // Service/Maintenance icon similar to the user's image (gear + wrench)
        'badgeImage': null, // Using icon instead as we can't upload user's image
        'title': 'iGaranti',
        'description': 'iGaranti Kapsamında Satın Aldığınız Cihazınızın, "İphone 11" Tamir Aşaması Tamamlanmıştır. İzleme Kodunuz "1439" dur.',
        'time': '07/30/2024',
        'showButton': true,
        'trackingCode': '1439',
      },
    ];

    final List<Map<String, dynamic>> messages = ChatState().chatHistory.map((chat) => {
      'productImage': chat['productImage'] ?? 'https://via.placeholder.com/60x60.png?text=Chat',
      'productTitle': chat['productName'] ?? 'Genel Sohbet',
      'sellerName': chat['sellerName'],
      'sellerBadge': chat['sellerLogo'],
      'status': 'Yanıt Bekleniyor',
      'statusColor': AppColors.primary,
      'question': chat['lastMessage'] ?? '',
      'timestamp': chat['timestamp'] ?? '',
      'sellerId': chat['sellerId'],
      'sellerLogo': chat['sellerLogo'],
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTabButton(0, 'Bildirim', Icons.notifications),
              const SizedBox(width: 8),
              _buildTabButton(1, 'İzleme', Icons.play_arrow),
              const SizedBox(width: 8),
              _buildTabButton(2, 'Mesaj', Icons.message),
            ],
          ),
        ),
        toolbarHeight: 70,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationsTab(notifications),
          _buildTrackingTab(),
          _buildMessagesTab(messages),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _tabController.animateTo(index);
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: _tabController.index == index ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _tabController.index == index ? AppColors.primary : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: _tabController.index == index ? Colors.white : Colors.grey,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: _tabController.index == index ? Colors.white : Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsTab(List<Map<String, dynamic>> notifications) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notif = notifications[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: notif['badgeColor'] == Colors.transparent 
                            ? Colors.transparent 
                            : notif['badgeColor'].withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: notif['badgeColor'] == Colors.transparent
                            ? null
                            : Border.all(color: notif['badgeColor'].withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (notif['badgeImage'] != null)
                            notif['badgeImage'].toString().startsWith('http') 
                              ? Image.network(
                                  notif['badgeImage'],
                                  height: 40, // Logo boyutu artırıldı
                                  width: 90, // Genişlik artırıldı
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => notif['badgeIcon'] != null 
                                      ? Icon(notif['badgeIcon'], size: 14, color: notif['badgeColor'])
                                      : const SizedBox(width: 24, height: 24), // İkon yoksa yer tutucu
                                )
                              : Image.asset(
                                  notif['badgeImage'],
                                  height: 40, // Logo boyutu artırıldı
                                  width: 90, // Genişlik artırıldı
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => notif['badgeIcon'] != null 
                                      ? Icon(notif['badgeIcon'], size: 14, color: notif['badgeColor'])
                                      : const SizedBox(width: 24, height: 24), // İkon yoksa yer tutucu
                                )
                          else if (notif['badgeIcon'] != null)
                            Icon(notif['badgeIcon'], size: 14, color: notif['badgeColor']),
                          if (notif['badgeLabel'].toString().isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text(
                            notif['badgeLabel'],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: notif['badgeColor'],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notif['title'],
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          notif['description'],
                          style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (notif['showButton'] == true)
                              GestureDetector(
                                onTap: () {
                                  if (notif['trackingCode'] != null) {
                                      _codeController.text = notif['trackingCode'];
                                      _tabController.animateTo(1);
                                      setState(() {
                                        _isTrackingActive = true;
                                      });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.primary, width: 1.5),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.play_arrow, size: 14, color: AppColors.primary),
                                      SizedBox(width: 4),
                                      Text(
                                        'İzleme',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(notif['time'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrackingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text('KOD', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey[800])),
          const SizedBox(height: 12),
          Container(
            height: 45,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        hintText: 'Kod yazınız',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => setState(() => _isTrackingActive = true),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isTrackingActive = true;
                    });
                  },
                  icon: const Icon(Icons.send, color: AppColors.primary, size: 20),
                ),
              ],
            ),
          ),
          
          if (_isTrackingActive) ...[
            const SizedBox(height: 24),
            const Text('ÜRÜN VİDEOSU', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 200,
                        decoration: const BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Center(
                          child: Icon(Icons.play_circle_outline, size: 60, color: Colors.white.withOpacity(0.8)),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                          child: const Text('01:00', style: TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'MacBook Air 13" 8C 256GB SilverLaptop kargolanışı',
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.thumb_up_alt_outlined, size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Text("222", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                       border: Border.all(color: Colors.grey.shade300),
                       borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Icon(Icons.ios_share, size: 16, color: AppColors.primary),
                         SizedBox(width: 8),
                         Text("Paylaş", style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                 const SizedBox(width: 8),
                 Expanded(
                  child: Container(
                    height: 36,
                    decoration: BoxDecoration(
                       border: Border.all(color: Colors.grey.shade300),
                       borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Icon(Icons.chat_bubble_outline, size: 16, color: AppColors.primary),
                         SizedBox(width: 8),
                         Text("Soru Sor", style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text('Konum', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.blueGrey[50], // Map placeholder color
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                children: [
                  // Map Background simulation
                   const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map, size: 48, color: Colors.black12),
                          SizedBox(height: 8),
                          Text("Harita Görünümü", style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                   ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "10 dk (3,3 Km)",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Dağıtıma çıkıldı en kısa sürede adresinizdeyiz",
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const CourierInfoPage()),
                                );
                              },
                              icon: const Icon(Icons.delivery_dining, size: 18),
                              label: const Text("Kurye Bilgi"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black87,
                                side: BorderSide(color: Colors.grey.shade400),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
             const SizedBox(height: 24),

          ],
        ],
      ),
    );
  }

  Widget _buildMessagesTab(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Henüz mesaj yok',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return GestureDetector(
          onTap: () {
            // Open chat when message is tapped
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  seller: {
                    'id': msg['sellerId'],
                    'name': msg['sellerName'],
                    'logo': msg['sellerLogo'],
                  },
                  product: msg['productTitle'] != 'Genel Sohbet' ? {
                    'name': msg['productTitle'],
                    'image': msg['productImage'],
                  } : null,
                ),
              ),
            ).then((_) => setState(() {})); // Refresh when returning
          },
          child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                      image: msg['productImage'] != null && msg['productImage'] != 'https://via.placeholder.com/60x60.png?text=Chat'
                          ? DecorationImage(
                              image: NetworkImage(msg['productImage']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: msg['productImage'] == null || msg['productImage'] == 'https://via.placeholder.com/60x60.png?text=Chat'
                        ? Icon(Icons.chat, color: Colors.grey[400], size: 30)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['productTitle'],
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          msg['sellerName'],
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                   Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: msg['statusColor'].withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: msg['statusColor'].withValues(alpha: 0.3)),
                    ),
                    child: Text(msg['status'],
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: msg['statusColor'])),
                  ),
                  const SizedBox(width: 8),
                   Expanded(
                    child: Text(msg['question'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              )
            ],
          ),
        ),
        );
      },
    );
  }
}
