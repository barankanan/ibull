part of 'app_state.dart';

extension _AppStateProfileDomain on AppState {
  Future<void> _refreshCurrentUserProfileFromBackend() async {
    final profile = await _authService.getUserProfile();
    final uid = _currentUser?['uid']?.toString();
    if (profile == null || uid == null || uid.isEmpty) return;

    _currentUser = UserIdentity.buildAuthUserMap(
      uid: uid,
      email: _currentUser?['email']?.toString(),
      profile: profile,
      userMetadata: Map<String, dynamic>.from(
        _authService.currentUser?.userMetadata ?? const {},
      ),
    );
    notifyListeners();
  }

  Future<void> _updateUserProfileImpl({
    String? displayName,
    double? weight,
    double? height,
    String? gender,
    String? birthDate,
    String? style,
    String? phone,
    String? address,
    String? photoUrl,
  }) async {
    await _authService.updateUserProfile(
      displayName: displayName,
      weight: weight,
      height: height,
      gender: gender,
      birthDate: birthDate,
      style: style,
      phone: phone,
      address: address,
      photoUrl: photoUrl,
    );
    await _refreshCurrentUserProfileFromBackend();
  }

  Future<void> _updateUserEmailImpl(String newEmail) async {
    await _authService.updateUserEmail(newEmail);
    await _refreshCurrentUserProfileFromBackend();
  }

  Future<String> _uploadProfilePhotoBytesOnlyImpl(
    Uint8List bytes, {
    String? fileName,
  }) async {
    return _authService.uploadProfilePhotoBytes(
      bytes,
      fileName: fileName ?? 'profile.jpg',
    );
  }

  Future<void> _uploadProfilePhotoImpl(Uint8List bytes, {String? fileName}) async {
    final url = await _uploadProfilePhotoBytesOnlyImpl(bytes, fileName: fileName);
    await _updateUserProfileImpl(photoUrl: url);
  }

  Future<void> _updateUserPasswordImpl(String newPassword) async {
    await _authService.updateUserPassword(newPassword);
  }

  Future<void> _changeUserPasswordWithVerificationImpl({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _authService.changePasswordWithVerification(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> _sendPasswordResetEmailImpl({String? email}) async {
    await _authService.sendPasswordResetEmail(email: email);
  }

  bool _hasEmailPasswordProviderImpl() => _authService.hasEmailPasswordProvider();

  void _setCurrentDeliveryAddressImpl(String address) {
    _currentDeliveryAddress = address;
    unawaited(_persistCurrentDeliveryAddressLocal());
    notifyListeners();
  }
}
