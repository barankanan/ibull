import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/app/account_sections.dart';
import 'package:ibul_app/app/marketplace_paths.dart';

void main() {
  test('account sections map path to sidebar label and title', () {
    expect(
      AccountSections.fromPath(MarketplacePaths.favorites),
      AccountSection.favorites,
    );
    expect(
      AccountSections.pathOf(AccountSection.favorites),
      '/favoriler',
    );
    expect(AccountSections.labelOf(AccountSection.favorites), 'Favorilerim');
    expect(
      AccountSections.documentTitleOf(AccountSection.favorites),
      'Favorilerim | İBUL',
    );
    expect(
      AccountSections.documentTitleOf(AccountSection.overview),
      'Hesabım | İBUL',
    );
    expect(
      AccountSections.fromPath(MarketplacePaths.notifications),
      AccountSection.notifications,
    );
    expect(
      AccountSections.pathOf(AccountSection.notifications),
      MarketplacePaths.notifications,
    );
    expect(
      AccountSections.fromPath(MarketplacePaths.security),
      AccountSection.security,
    );
    expect(
      AccountSections.pathOf(AccountSection.security),
      MarketplacePaths.security,
    );
    expect(
      AccountSections.pathOf(AccountSection.settings),
      MarketplacePaths.settings,
    );
    expect(AccountSections.fromPath('/hesabim/ozet'), isNull);
    expect(AccountSections.fromPath('/avm-basvurusu'), isNull);
  });
}
