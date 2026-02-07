import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'list_detail_page.dart';

/// Kullanıcının oluşturduğu listeleri gösteren sayfa
class ListsPage extends StatefulWidget {
  const ListsPage({super.key});

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> {
  // Dummy data for lists
  final List<Map<String, dynamic>> _lists = [
    {
      'id': 1,
      'name': 'Old Money Listesi',
      'coverImage': 'https://via.placeholder.com/400x200.png?text=Old+Money',
      'logo': 'https://via.placeholder.com/60x60.png?text=OM',
      'memberCount': 629,
      'description': 'Burada Eski Tarz Ürünleri Bulabilir Ve Detaylı Bilgi Alabilirsin',
      'itemCount': 12,
    },
    {
      'id': 2,
      'name': 'Teknoloji Ürünleri',
      'coverImage': 'https://via.placeholder.com/400x200.png?text=Tech',
      'logo': 'https://via.placeholder.com/60x60.png?text=T',
      'memberCount': 453,
      'description': 'En yeni teknoloji ürünleri ve akıllı cihazlar',
      'itemCount': 8,
    },
    {
      'id': 3,
      'name': 'Ev Dekorasyonu',
      'coverImage': 'https://via.placeholder.com/400x200.png?text=Home+Decor',
      'logo': 'https://via.placeholder.com/60x60.png?text=HD',
      'memberCount': 321,
      'description': 'Modern ve şık ev dekorasyon ürünleri',
      'itemCount': 15,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Listelerim',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () {
              // Yeni liste oluştur
            },
          ),
        ],
      ),
      body: _lists.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _lists.length,
              itemBuilder: (context, index) {
                return _buildListCard(_lists[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Henüz bir listeniz yok',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Beğendiğiniz ürünleri listelerinize ekleyin',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Yeni liste oluştur
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Yeni Liste Oluştur',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListCard(Map<String, dynamic> list) {
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
                  child: Image.network(
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
                      child: Image.network(
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
}
