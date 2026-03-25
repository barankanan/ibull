import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/chat_state.dart';

class ChatPage extends StatefulWidget {
  final Map<String, dynamic> seller;
  final Map<String, dynamic>? product; // Optional product
  final bool isSellerChat; // True for official seller, False for user-to-user
  final String? initialMessage; // Optional initial message to send automatically

  const ChatPage({
    super.key,
    required this.seller,
    this.product,
    this.isSellerChat = true,
    this.initialMessage,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    final sellerId = widget.seller['id']?.toString() ?? widget.seller['name'] ?? 'unknown';
    final productName = widget.product?['name'];
    
    final savedMessages = ChatState().getMessages(sellerId, productName);
    
    if (savedMessages.isNotEmpty) {
      setState(() {
        _messages.addAll(savedMessages);
      });
    } else if (widget.product == null && widget.initialMessage == null) {
      // Only add initial messages if product is null (no product context) AND no saved messages AND no initial message
      _messages.add({
        'text': 'Ne zaman elime ulaşır',
        'isSender': false,
        'time': '12:18',
      });
      _messages.add({
        'text': 'Yakın lokasyonda olduğunuz için tahmini 4 saat içersinde kurye ürününüzü size iletecektir',
        'isSender': true,
        'time': '14:58',
      });
    }

    // Handle initial message passed from navigation
    if (widget.initialMessage != null) {
      final now = DateTime.now();
      final timestamp = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      final messageMap = {
        'text': widget.initialMessage,
        'isSender': true,
        'time': timestamp,
      };
      
      setState(() {
        _messages.add(messageMap);
      });

      // Save to chat state
      ChatState().addOrUpdateChat(
        sellerId: sellerId,
        sellerName: widget.seller['name'] ?? 'Satıcı',
        sellerLogo: widget.seller['logo'] ?? 'S',
        productName: productName,
        productImage: widget.product?['image'],
        lastMessage: widget.initialMessage,
        timestamp: '${now.day}/${now.month}/${now.year} $timestamp',
        fullMessage: messageMap,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    
    final message = _messageController.text;
    final now = DateTime.now();
    final timestamp = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
    
    final messageMap = {
      'text': message,
      'isSender': true,
      'time': timestamp,
    };

    setState(() {
      _messages.add(messageMap);
    });
    
    // Save to chat state
    ChatState().addOrUpdateChat(
      sellerId: widget.seller['id']?.toString() ?? widget.seller['name'] ?? 'unknown',
      sellerName: widget.seller['name'] ?? 'Satıcı',
      sellerLogo: widget.seller['logo'] ?? 'S',
      productName: widget.product?['name'],
      productImage: widget.product?['image'],
      lastMessage: message,
      timestamp: '${now.day}/${now.month}/${now.year} $timestamp',
      fullMessage: messageMap,
    );
    
    _messageController.clear();
    
    // Auto-reply from seller after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        final replyTime = DateTime.now();
        final replyTimestamp = '${replyTime.hour}:${replyTime.minute.toString().padLeft(2, '0')}';
        final replyMap = {
          'text': 'Merhaba, size nasıl yardımcı olabilirim?',
          'isSender': false,
          'time': replyTimestamp,
        };
        
        setState(() {
          _messages.add(replyMap);
        });
        
        // Save reply to chat state
        ChatState().addOrUpdateChat(
          sellerId: widget.seller['id']?.toString() ?? widget.seller['name'] ?? 'unknown',
          sellerName: widget.seller['name'] ?? 'Satıcı',
          sellerLogo: widget.seller['logo'] ?? 'S',
          productName: widget.product?['name'],
          productImage: widget.product?['image'],
          lastMessage: replyMap['text'] as String?,
          timestamp: '${now.day}/${now.month}/${now.year} $replyTimestamp',
          fullMessage: replyMap,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // If no messages yet and product exists, show initial product question screen
    final bool showInitialScreen = _messages.isEmpty && widget.product != null;
    
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isSellerChat)
              Text(
                'Satıcı',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      widget.seller['logo'] ?? 'A',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.seller['name'] ?? 'Arçelik',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: showInitialScreen ? _buildInitialScreen() : _buildChatScreen(),
    );
  }

  Widget _buildInitialScreen() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProductCardInitial(),
                const Spacer(),
              ],
            ),
          ),
        ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildChatScreen() {
    return Column(
      children: [
        // Messages Area
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (widget.product != null ? 1 : 0),
            itemBuilder: (context, index) {
              // Show product card as first item if product exists
              if (widget.product != null && index == 0) {
                return _buildProductCard();
              }
              
              final messageIndex = widget.product != null ? index - 1 : index;
              final message = _messages[messageIndex];
              return _buildMessageBubble(
                message['text'],
                message['isSender'],
                message['time'],
              );
            },
          ),
        ),
        
        // Input Area
        _buildInputArea(),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Message Input
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Soru Sor...',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                border: InputBorder.none,
                              ),
                              maxLines: null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send Button
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProductCardInitial() {
    if (widget.product == null) return const SizedBox.shrink();
    
    final now = DateTime.now();
    final timestamp = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}\n${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final hasMessages = _messages.isNotEmpty;
    
    return GestureDetector(
      onTap: () {
        // Navigate to product page
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              width: 70,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                image: widget.product!['image'] != null
                    ? DecorationImage(
                        image: ResizeImage.resizeIfNeeded(
                          210,
                          270,
                          NetworkImage(widget.product!['image']),
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: widget.product!['image'] == null
                  ? const Icon(Icons.image, color: Colors.grey, size: 35)
                  : null,
            ),
            const SizedBox(width: 12),
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product!['name'] ?? 'Ürün',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.product!['rating'] ?? '4.8'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '62 Değerlendirme',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status and timestamp
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasMessages ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    hasMessages ? 'Yanıtlandı' : 'Yanıtlanmadı',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: hasMessages ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timestamp,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard() {
    if (widget.product == null) return const SizedBox.shrink();
    
    final now = DateTime.now();
    final timestamp = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}\n${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final hasMessages = _messages.isNotEmpty;
    
    return GestureDetector(
      onTap: () {
        // Navigate to product page
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              width: 70,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                image: widget.product!['image'] != null
                    ? DecorationImage(
                        image: ResizeImage.resizeIfNeeded(
                          210,
                          270,
                          NetworkImage(widget.product!['image']),
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: widget.product!['image'] == null
                  ? const Icon(Icons.image, color: Colors.grey, size: 35)
                  : null,
            ),
            const SizedBox(width: 12),
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product!['name'] ?? 'Ürün',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.product!['rating'] ?? '4.8'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '62 Değerlendirme',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Status and timestamp
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasMessages ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    hasMessages ? 'Yanıtlandı' : 'Yanıtlanmadı',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: hasMessages ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timestamp,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isSender, String time) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSender ? Colors.white : AppColors.primary,
              borderRadius: BorderRadius.circular(16),
              border: isSender ? Border.all(color: Colors.grey.shade200) : null,
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isSender ? Colors.black87 : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
