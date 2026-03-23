import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/core/auth/user_identity.dart';

void main() {
  test('buildAuthUserMap normalizes display name and email', () {
    final user = UserIdentity.buildAuthUserMap(
      uid: 'user-1',
      email: 'gulsen@gmail.com',
      profile: {'display_name': 'Gülşen'},
      userMetadata: {'avatar_url': 'avatar.png'},
    );

    expect(user['uid'], 'user-1');
    expect(user['name'], 'Gülşen');
    expect(user['displayName'], 'Gülşen');
    expect(user['email'], 'gulsen@gmail.com');
    expect(user['photoURL'], 'avatar.png');
    expect(UserIdentity.isGuest(user), isFalse);
  });

  test('guest identity is detected from uid and email', () {
    final guest = UserIdentity.buildAuthUserMap(
      uid: 'guest_123',
      email: UserIdentity.guestEmail,
      profile: {'name': UserIdentity.defaultGuestDisplayName},
    );

    expect(UserIdentity.isGuest(guest), isTrue);
    expect(
      UserIdentity.resolveDisplayName(currentUser: guest),
      UserIdentity.defaultGuestDisplayName,
    );
    expect(UserIdentity.initialsOf(guest), 'MK');
  });

  test('maskedDisplayNameOf masks each word consistently', () {
    expect(
      UserIdentity.maskedDisplayNameOf({'displayName': 'Gülşen Kananogullari'}),
      'Gü** Ka**',
    );
  });
}
