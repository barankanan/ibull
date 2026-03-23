class UserIdentity {
  static const String guestEmail = 'misafir@ibul.com';
  static const String defaultGuestDisplayName = 'Misafir Kullanıcı';
  static const String fallbackDisplayName = 'Kullanıcı';

  static Map<String, dynamic> buildAuthUserMap({
    required String uid,
    String? email,
    Map<String, dynamic>? profile,
    Map<String, dynamic>? userMetadata,
  }) {
    final normalizedProfile = Map<String, dynamic>.from(profile ?? const {});
    final normalizedMetadata = Map<String, dynamic>.from(
      userMetadata ?? const {},
    );
    final resolvedName = resolveDisplayName(
      currentUser: normalizedProfile,
      metadata: normalizedMetadata,
      email: email,
    );
    final resolvedEmail = resolveEmail(
      currentUser: normalizedProfile,
      email: email,
    );

    return {
      ...normalizedProfile,
      'uid': uid,
      'email': resolvedEmail,
      'name': resolvedName,
      'displayName': resolvedName,
      'display_name': resolvedName,
      'photoURL':
          normalizedMetadata['avatar_url'] ??
          normalizedMetadata['picture'] ??
          normalizedProfile['photoURL'] ??
          normalizedProfile['photo_url'],
      'isPremium': normalizedProfile['isPremium'] ?? false,
    };
  }

  static bool isGuest(Map<String, dynamic>? currentUser) {
    final uid = currentUser?['uid']?.toString() ?? '';
    final email = resolveEmail(currentUser: currentUser);
    return uid.startsWith('guest_') || email == guestEmail;
  }

  static String resolveDisplayName({
    Map<String, dynamic>? currentUser,
    Map<String, dynamic>? metadata,
    String? email,
    String fallback = fallbackDisplayName,
  }) {
    final candidates = [
      currentUser?['display_name'],
      currentUser?['displayName'],
      currentUser?['name'],
      metadata?['display_name'],
      metadata?['name'],
      _firstPartOfEmail(email),
      fallback,
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  static String resolveEmail({
    Map<String, dynamic>? currentUser,
    String? email,
  }) {
    final directEmail = email?.trim() ?? '';
    if (directEmail.isNotEmpty) {
      return directEmail;
    }
    return currentUser?['email']?.toString().trim() ?? '';
  }

  static String initialsOf(
    Map<String, dynamic>? currentUser, {
    String fallback = 'M',
  }) {
    final displayName = resolveDisplayName(
      currentUser: currentUser,
      fallback: fallback,
    );
    final parts = displayName
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return parts.isEmpty ? fallback : parts;
  }

  static String maskedDisplayNameOf(
    Map<String, dynamic>? currentUser, {
    String fallback = fallbackDisplayName,
  }) {
    final displayName = resolveDisplayName(
      currentUser: currentUser,
      fallback: fallback,
    );
    final parts = displayName.split(' ').where((part) => part.isNotEmpty);
    if (parts.isEmpty) {
      return fallback;
    }

    return parts
        .map((part) {
          if (part.length <= 1) {
            return '${part[0]}*';
          }
          return '${part.substring(0, 1).toUpperCase()}${part.substring(1, 2).toLowerCase()}**';
        })
        .join(' ');
  }

  static String _firstPartOfEmail(String? email) {
    final value = email?.trim() ?? '';
    if (value.isEmpty || !value.contains('@')) {
      return '';
    }
    return value.split('@').first;
  }
}
