import 'dart:io';

/// Rules for a seller build that must not share the production app.
///
/// The shipping bundle stays [sellerDesktopBundleId]. A test build has to
/// use a different bundle, Keychain account, LAN directory and bridge port.
/// An environment flag alone does not make the launch safe.
const sellerDesktopBundleId = 'com.ibul.sellerdesktop';
const offlineTestBundleId = 'com.ibul.sellerdesktop.offlinetest';
const sellerKeychainAccount = 'ibul.sellerdesktop';
const offlineTestKeychainAccount = 'ibul.sellerdesktop.offlinetest';
const productionSupabaseMarker = 'ihmixxzqnpamcwmrfibx';
const sellerLanDirectoryName = 'Library/Application Support/ibul-lan';

class OfflineTestLaunch {
  const OfflineTestLaunch({required this.allowed, required this.failures});

  final bool allowed;
  final List<String> failures;
}

OfflineTestLaunch evaluateOfflineTestLaunch({
  required bool testMode,
  required String bundleId,
  required String keychainAccount,
  required String supabaseUrl,
  required String lanHome,
  required String printBridgePort,
}) {
  if (!testMode) {
    return const OfflineTestLaunch(allowed: true, failures: <String>[]);
  }
  final failures = <String>[];
  if (bundleId.trim() != offlineTestBundleId) {
    failures.add('Uygulama kimliği test kimliği değil.');
  }
  if (bundleId.trim() == sellerDesktopBundleId) {
    failures.add('Production satıcı kimliği kullanılamaz.');
  }
  if (keychainAccount.trim() != offlineTestKeychainAccount) {
    failures.add('Keychain hesabı test hesabı değil.');
  }
  if (keychainAccount.trim() == sellerKeychainAccount) {
    failures.add('Production Keychain hesabı kullanılamaz.');
  }
  if (supabaseUrl.contains(productionSupabaseMarker)) {
    failures.add('Production Supabase adresiyle yazma kapalı.');
  }
  final home = lanHome.trim();
  if (home.isEmpty || home.contains(sellerLanDirectoryName)) {
    failures.add('LAN dosyaları satıcı klasörünün dışında olmalı.');
  }
  if (printBridgePort.trim() == '3001') {
    failures.add('Canlı yazıcı köprüsü kullanılamaz.');
  }
  return OfflineTestLaunch(allowed: failures.isEmpty, failures: failures);
}

/// Reads the bundle id from the app that actually launched.
/// A missing plist fails closed for the test gate.
String readMacBundleIdentifier(String executablePath) {
  final executable = File(executablePath);
  final contents = executable.parent.parent;
  final plist = File('${contents.path}/Info.plist');
  if (!plist.existsSync()) return '';
  final match = RegExp(
    r'CFBundleIdentifier</key>\s*<string>([^<]+)</string>',
  ).firstMatch(plist.readAsStringSync());
  return match?.group(1)?.trim() ?? '';
}
