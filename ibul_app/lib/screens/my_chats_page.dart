import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/chat_state.dart';
import 'chat_page.dart';

class MyChatsPage extends StatefulWidget {
  const MyChatsPage({super.key});

  @override
  State<MyChatsPage> createState() => _MyChatsPageState();
}

class _MyChatsPageState extends State<MyChatsPage> {
  @override
  Widget build(BuildContext context) {
    final chats = ChatState().chatHistory;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sohbetlerim',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
      ),
      body: chats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz hiç sohbetiniz yok',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: chats.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final chat = chats[index];
                return _buildChatTile(chat);
              },
            ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    return ListTile(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              seller: {
                'id': chat['sellerId'],
                'name': chat['sellerName'],
                'logo': chat['sellerLogo'],
              },
              product: chat['productName'] != null
                  ? {
                      'name': chat['productName'],
                      'image': chat['productImage'],
                    }
                  : null,
            ),
          ),
        ).then((_) => setState(() {})); // Refresh on return
      },
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: CircleAvatar(
        backgroundColor: AppColors.primary,
        radius: 24,
        child: Text(
          chat['sellerLogo'] ?? '?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            chat['sellerName'] ?? 'İsimsiz',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          Text(
            chat['timestamp']?.toString().split(' ').last ?? '',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chat['productName'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Ürün: ${chat['productName']}',
                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            chat['lastMessage'] ?? '',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
