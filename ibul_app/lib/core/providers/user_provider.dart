import 'package:flutter/foundation.dart';
import '../../services/auth_service.dart';
import '../../utils/dynamic_value_helpers.dart';

class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  int _authStateVersion = 0;
  
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // Takip edilen mağazalar
  final List<Map<String, dynamic>> _followedStores = [];
  List<Map<String, dynamic>> get followedStores => List.unmodifiable(_followedStores);

  // Kayıtlı Adresler
  final List<Map<String, String>> _deliveryAddresses = [];
  List<Map<String, String>> get deliveryAddresses => List.unmodifiable(_deliveryAddresses);

  String? _currentDeliveryAddress;
  String? get currentDeliveryAddress => _currentDeliveryAddress;

  UserProvider() {
    _initAuth();
  }

  void _initAuth() {
    _authService.authStateChanges.listen((authState) async {
      final requestVersion = ++_authStateVersion;
      final user = authState.session?.user;
      if (user != null) {
        final profile = await _authService.getUserProfile();
        if (_isStaleAuthRequest(requestVersion)) return;
        _currentUser = _buildCurrentUserMap(user, profile);
        
        if (user.id.startsWith('guest_') || user.email == 'misafir@ibul.com') {
           _loadGuestData();
        } else {
           await _loadUserData(requestVersion: requestVersion);
           if (_isStaleAuthRequest(requestVersion)) return;
        }
      } else {
        _currentUser = null;
        _clearUserData();
      }
      if (_isStaleAuthRequest(requestVersion)) return;
      notifyListeners();
    });
  }

  bool _isStaleAuthRequest(int requestVersion) {
    return requestVersion != _authStateVersion;
  }

  Map<String, dynamic> _buildCurrentUserMap(
    dynamic user,
    Map<String, dynamic>? profile,
  ) {
    final normalizedProfile = Map<String, dynamic>.from(profile ?? const {});
    final resolvedName = _resolveUserDisplayName(user, normalizedProfile);
    final resolvedEmail =
        (user.email?.toString().trim().isNotEmpty ?? false)
        ? user.email.toString().trim()
        : (normalizedProfile['email']?.toString().trim() ?? '');

    return {
      ...normalizedProfile,
      'uid': user.id,
      'email': resolvedEmail,
      'name': resolvedName,
      'displayName': resolvedName,
      'display_name': resolvedName,
      'photoURL':
          user.userMetadata?['avatar_url'] ??
          user.userMetadata?['picture'] ??
          normalizedProfile['photoURL'] ??
          normalizedProfile['photo_url'],
      'isPremium': normalizedProfile['isPremium'] ?? false,
    };
  }

  String _resolveUserDisplayName(dynamic user, Map<String, dynamic> profile) {
    final candidates = [
      profile['display_name'],
      profile['displayName'],
      profile['name'],
      user.userMetadata?['display_name'],
      user.userMetadata?['name'],
      user.email?.toString().split('@').first,
      'Kullanıcı',
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return 'Kullanıcı';
  }

  Future<void> _loadUserData({int? requestVersion}) async {
    _clearUserData();
    try {
      final addressesData = await _authService.getUserDataField('addresses');
      if (requestVersion != null && _isStaleAuthRequest(requestVersion)) return;
      if (addressesData != null && addressesData is List) {
        _deliveryAddresses.addAll(
          addressesData.map((e) => readStringMap(e)),
        );
        if (_deliveryAddresses.isNotEmpty && _currentDeliveryAddress == null) {
          _currentDeliveryAddress = _deliveryAddresses.first['detail'];
        }
      }
      
      final followedData = await _authService.getUserDataField('followedStores');
      if (requestVersion != null && _isStaleAuthRequest(requestVersion)) return;
      if (followedData != null && followedData is List) {
        _followedStores.addAll(followedData.map((e) => Map<String, dynamic>.from(e)));
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('User data loading error: $e');
    }
  }

  void _loadGuestData() {
    _deliveryAddresses.clear();
    _deliveryAddresses.addAll([
      {'title': 'Ev', 'detail': 'Prefabrik ev - Gökmeydan Mah. Nazım Hikmet Kültür Merkezi Karşısı Prefabrik Ev No: 5, Eskişehir / Odunpazarı'},
      {'title': 'İş', 'detail': 'Teknopark - Organize Sanayi Bölgesi, Eskişehir / Odunpazarı'},
    ]);
    if (_deliveryAddresses.isNotEmpty) {
      _currentDeliveryAddress = _deliveryAddresses.first['detail'];
    }
  }

  void _clearUserData() {
    _currentDeliveryAddress = null;
    _deliveryAddresses.clear();
    _followedStores.clear();
  }

  void setCurrentDeliveryAddress(String address) {
    _currentDeliveryAddress = address;
    notifyListeners();
  }
  
  // Mağaza takip işlemleri
  bool isFollowingStore(Map<String, dynamic> store) {
    return _followedStores.any((s) => s['id'] == store['id']);
  }
  
  void toggleFollowStore(Map<String, dynamic> store) {
    if (isFollowingStore(store)) {
      _followedStores.removeWhere((s) => s['id'] == store['id']);
    } else {
      _followedStores.add(store);
    }
    notifyListeners();
    _authService.updateUserDataField('followedStores', _followedStores);
  }
}
