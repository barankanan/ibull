class ChatState {
  static final ChatState _instance = ChatState._internal();
  factory ChatState() => _instance;
  ChatState._internal();

  final List<Map<String, dynamic>> _chatHistory = [];

  List<Map<String, dynamic>> get chatHistory => List.unmodifiable(_chatHistory);

  void addOrUpdateChat({
    required String sellerId,
    required String sellerName,
    required String sellerLogo,
    String? productName,
    String? productImage,
    String? lastMessage,
    String? timestamp,
    Map<String, dynamic>? fullMessage, // New parameter for full message data
  }) {
    final existingIndex = _chatHistory.indexWhere((chat) => 
      chat['sellerId'] == sellerId && 
      chat['productName'] == productName
    );

    if (existingIndex != -1) {
      // Update existing chat
      List<Map<String, dynamic>> messages = List<Map<String, dynamic>>.from(
        _chatHistory[existingIndex]['messages'] ?? []
      );
      
      if (fullMessage != null) {
        messages.add(fullMessage);
      }

      _chatHistory[existingIndex] = {
        'sellerId': sellerId,
        'sellerName': sellerName,
        'sellerLogo': sellerLogo,
        'productName': productName,
        'productImage': productImage,
        'lastMessage': lastMessage ?? _chatHistory[existingIndex]['lastMessage'],
        'timestamp': timestamp ?? _chatHistory[existingIndex]['timestamp'],
        'messages': messages,
      };
    } else {
      // Add new chat
      List<Map<String, dynamic>> messages = [];
      if (fullMessage != null) {
        messages.add(fullMessage);
      }

      _chatHistory.insert(0, {
        'sellerId': sellerId,
        'sellerName': sellerName,
        'sellerLogo': sellerLogo,
        'productName': productName,
        'productImage': productImage,
        'lastMessage': lastMessage,
        'timestamp': timestamp,
        'messages': messages,
      });
    }
  }

  List<Map<String, dynamic>> getMessages(String sellerId, String? productName) {
    final chat = _chatHistory.firstWhere(
      (chat) => chat['sellerId'] == sellerId && chat['productName'] == productName,
      orElse: () => {},
    );
    
    if (chat.isEmpty || chat['messages'] == null) return [];
    return List<Map<String, dynamic>>.from(chat['messages']);
  }

  void clearAll() {
    _chatHistory.clear();
  }
}
