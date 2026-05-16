class StoreFollowState {
  const StoreFollowState({
    this.isFollowing = false,
    this.notificationsEnabled = false,
    this.followerCount = 0,
    this.loading = false,
    this.error,
  });

  final bool isFollowing;
  final bool notificationsEnabled;
  final int followerCount;
  final bool loading;
  final String? error;

  StoreFollowState copyWith({
    bool? isFollowing,
    bool? notificationsEnabled,
    int? followerCount,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return StoreFollowState(
      isFollowing: isFollowing ?? this.isFollowing,
      notificationsEnabled:
          notificationsEnabled ?? this.notificationsEnabled,
      followerCount: followerCount ?? this.followerCount,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  factory StoreFollowState.fromJson(Map<String, dynamic> json) {
    return StoreFollowState(
      isFollowing: json['is_following'] == true,
      notificationsEnabled: json['notifications_enabled'] == true,
      followerCount: _asInt(json['follower_count']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get formattedFollowerCount {
    final count = followerCount;
    if (count >= 1000000) {
      final millions = count / 1000000;
      return '${millions >= 10 ? millions.toStringAsFixed(0) : millions.toStringAsFixed(1)}M Takipçi';
    }
    if (count >= 1000) {
      final thousands = count / 1000;
      return '${thousands >= 10 ? thousands.toStringAsFixed(0) : thousands.toStringAsFixed(1)}B Takipçi';
    }
    if (count <= 0) return '0 Takipçi';
    return '$count Takipçi';
  }
}
