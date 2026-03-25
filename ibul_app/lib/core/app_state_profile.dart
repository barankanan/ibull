part of 'app_state.dart';

extension _AppStateProfileDomain on AppState {
  Future<void> _updateUserProfileImpl({
    String? displayName,
    double? weight,
    double? height,
    String? gender,
    String? birthDate,
    String? style,
    String? phone,
    String? address,
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
    );
    if (_currentUser != null) {
      if (displayName != null) {
        _currentUser!['displayName'] = displayName;
        _currentUser!['name'] = displayName;
      }
      if (weight != null) _currentUser!['weight'] = weight;
      if (height != null) _currentUser!['height'] = height;
      if (gender != null) _currentUser!['gender'] = gender;
      if (birthDate != null) _currentUser!['birthDate'] = birthDate;
      if (style != null) _currentUser!['style'] = style;
      if (phone != null) _currentUser!['phone'] = phone;
      if (address != null) _currentUser!['address'] = address;
      notifyListeners();
    }
  }

  void _setCurrentDeliveryAddressImpl(String address) {
    _currentDeliveryAddress = address;
    unawaited(_persistCurrentDeliveryAddressLocal());
    notifyListeners();
  }
}
