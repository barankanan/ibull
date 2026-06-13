import '../../utils/dynamic_value_helpers.dart';
import 'package:flutter/material.dart';

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
    final normalizedProfile = normalizeUserProfileForApp(
      profile == null ? null : Map<String, dynamic>.from(profile),
    );
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
    final resolvedPhotoUrl = resolveProfilePhotoUrl(normalizedProfile) ??
        readNullableString(
          normalizedMetadata['avatar_url'] ?? normalizedMetadata['picture'],
        );

    return {
      ...normalizedProfile,
      'uid': uid,
      'email': resolvedEmail,
      'name': resolvedName,
      'displayName': resolvedName,
      'display_name': resolvedName,
      if (resolvedPhotoUrl != null) ...{
        'photo_url': resolvedPhotoUrl,
        'photoURL': resolvedPhotoUrl,
      },
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

  static String? resolveProfilePhotoUrl(Map<String, dynamic>? currentUser) {
    final saved = readNullableString(currentUser?['photo_url']);
    if (saved != null) return saved;
    return readNullableString(currentUser?['photoURL']);
  }

  static String? formatHeightWeightSummary(Map<String, dynamic>? currentUser) {
    final parts = <String>[];
    final height = currentUser?['height'];
    if (height != null) {
      final value = readString(height);
      if (value.isNotEmpty) {
        parts.add('Boy: $value cm');
      }
    }
    final weight = currentUser?['weight'];
    if (weight != null) {
      final value = readString(weight);
      if (value.isNotEmpty) {
        parts.add('Kilo: $value kg');
      }
    }
    return parts.isEmpty ? null : parts.join('    ');
  }

  static Color profilePresetColor(String presetId, {Color fallback = const Color(0xFF7C3AED)}) {
    const presetColors = <String, Color>{
      'violet': Color(0xFF7C3AED),
      'blue': Color(0xFF2563EB),
      'emerald': Color(0xFF059669),
      'rose': Color(0xFFE11D48),
      'amber': Color(0xFFD97706),
      'slate': Color(0xFF475569),
    };
    return presetColors[presetId] ?? fallback;
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
