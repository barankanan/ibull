import 'dart:convert';
import 'dart:io';
import 'dart:math';

class LanInterfaceChoice {
  const LanInterfaceChoice({required this.name, required this.address});

  final String name;
  final String address;
}

class LanInterfaceSelection {
  const LanInterfaceSelection({required this.name, required this.address});

  final String name;
  final String address;

  Map<String, String> toJson() => <String, String>{
        'name': name,
        'address': address,
      };

  static LanInterfaceSelection? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name']?.toString().trim() ?? '';
    final address = raw['address']?.toString().trim() ?? '';
    if (name.isEmpty || address.isEmpty) return null;
    return LanInterfaceSelection(name: name, address: address);
  }
}

enum LanSavedAddressState { missing, ready, changed }

class LanSavedAddressCheck {
  const LanSavedAddressCheck(this.state, {this.selection});

  final LanSavedAddressState state;
  final LanInterfaceChoice? selection;
}

const _skippedNames = <String>[
  'lo',
  'utun',
  'ipsec',
  'ppp',
  'tun',
  'tap',
  'wg',
  'tailscale',
  'vpn',
  'docker',
  'veth',
  'vmnet',
  'awdl',
  'llw',
  'bridge',
];

bool lanInterfaceNameIsVirtual(String name) {
  final text = name.trim().toLowerCase();
  if (text.isEmpty || text == 'lo0' || text.startsWith('lo')) return true;
  for (final prefix in _skippedNames) {
    if (text == prefix || text.startsWith(prefix)) return true;
  }
  return false;
}

/// Private LAN addresses an operator may explicitly choose.
/// Loopback, VPN-style names and public addresses are omitted.
class LanRawInterfaceAddress {
  const LanRawInterfaceAddress({required this.name, required this.address});

  final String name;
  final InternetAddress address;
}

List<LanInterfaceChoice> trustedLanInterfaces(
  Iterable<LanRawInterfaceAddress> interfaces,
) {
  final choices = <LanInterfaceChoice>[];
  for (final interface in interfaces) {
    if (lanInterfaceNameIsVirtual(interface.name)) continue;
    final address = interface.address;
    if (address.type != InternetAddressType.IPv4) continue;
    if (address.isLoopback) continue;
    if (!_private(address.rawAddress)) continue;
    choices.add(LanInterfaceChoice(name: interface.name, address: address.address));
  }
  return choices;
}

/// Prefers the Wi-Fi interface the operator already uses, then any other
/// trusted private address. Loopback is not a choice here.
LanInterfaceChoice? preferredTrustedLanInterface(
  List<LanInterfaceChoice> choices,
) {
  if (choices.isEmpty) return null;
  for (final choice in choices) {
    if (choice.name == 'en0') return choice;
  }
  return choices.first;
}

bool _private(List<int> bytes) {
  if (bytes.length != 4) return false;
  if (bytes[0] == 10) return true;
  if (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) return true;
  if (bytes[0] == 192 && bytes[1] == 168) return true;
  return false;
}

LanSavedAddressCheck checkSavedLanAddress({
  required LanInterfaceSelection? saved,
  required List<LanInterfaceChoice> current,
}) {
  if (saved == null) return const LanSavedAddressCheck(LanSavedAddressState.missing);
  for (final choice in current) {
    if (choice.name == saved.name && choice.address == saved.address) {
      return LanSavedAddressCheck(LanSavedAddressState.ready, selection: choice);
    }
  }
  for (final choice in current) {
    if (choice.name == saved.name && choice.address != saved.address) {
      return const LanSavedAddressCheck(LanSavedAddressState.changed);
    }
  }
  return const LanSavedAddressCheck(LanSavedAddressState.changed);
}

Future<String> lanMachineId(Directory directory) async {
  if (!directory.existsSync()) directory.createSync(recursive: true);
  final file = File('${directory.path}/machine.id');
  if (file.existsSync()) {
    final existing = (await file.readAsString()).trim();
    if (existing.length >= 16) return existing;
  }
  final random = Random.secure();
  final id = List<String>.generate(
    32,
    (_) => random.nextInt(16).toRadixString(16),
  ).join();
  await file.writeAsString(id);
  return id;
}

class LanBindStore {
  LanBindStore(this.directory);

  final Directory directory;

  File get _file => File('${directory.path}/lan-bind.json');

  Future<LanInterfaceSelection?> read() async {
    if (!_file.existsSync()) return null;
    try {
      final raw = jsonDecode(await _file.readAsString());
      return LanInterfaceSelection.fromJson(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(LanInterfaceSelection selection) async {
    if (!directory.existsSync()) directory.createSync(recursive: true);
    await _file.writeAsString(jsonEncode(selection.toJson()));
  }

  Future<void> clear() async {
    if (_file.existsSync()) await _file.delete();
  }
}

class AuthorityStartDecision {
  const AuthorityStartDecision({
    required this.allow,
    this.message,
    this.provesNoOtherServer = false,
  });

  final bool allow;
  final String? message;

  /// Missing discovery is not proof that this machine is alone.
  final bool provesNoOtherServer;
}

enum SellerLanCenterAction { alreadyRunning, start, blocked, needsChoice }

/// The seller app restarts a center it already owns. It does not take over
/// another machine, and it does not open a second host on this computer.
SellerLanCenterAction sellerLanCenterAction({
  required bool alreadyListening,
  required bool centerEnabled,
  required bool savedAddressReady,
  required bool otherMachineAnswers,
}) {
  if (alreadyListening) return SellerLanCenterAction.alreadyRunning;
  if (otherMachineAnswers) return SellerLanCenterAction.blocked;
  if (centerEnabled && savedAddressReady) return SellerLanCenterAction.start;
  return SellerLanCenterAction.needsChoice;
}

/// Another live server for the same restaurant blocks a second authority.
/// There is no automatic takeover.
AuthorityStartDecision decideAuthorityStart({
  required bool interfaceSelected,
  required bool operatorConfirmed,
  required String localMachineId,
  required String restaurantId,
  Map<String, dynamic>? remoteDiscover,
}) {
  if (!interfaceSelected) {
    return const AuthorityStartDecision(
      allow: false,
      message: 'Önce bir yerel ağ arayüzü seçin.',
    );
  }
  if (!operatorConfirmed) {
    return const AuthorityStartDecision(
      allow: false,
      message: 'Bu bilgisayarı tek sunucu yapmak için onay gerekli.',
    );
  }
  final remoteRestaurant = remoteDiscover?['restaurant_id']?.toString() ?? '';
  final remoteMachine = remoteDiscover?['machine_id']?.toString() ?? '';
  final remoteService = remoteDiscover?['service']?.toString() ?? '';
  if (remoteService == 'ibul-lan' &&
      remoteRestaurant == restaurantId &&
      remoteMachine.isNotEmpty &&
      remoteMachine != localMachineId) {
    return const AuthorityStartDecision(
      allow: false,
      message:
          'Bu restoranda başka bir sunucu yanıt veriyor. Otomatik devralma yok.',
    );
  }
  return const AuthorityStartDecision(
    allow: true,
    provesNoOtherServer: false,
    message: 'Keşif yanıtı yok. Başka sunucu olmadığı kanıtlanmadı.',
  );
}

String lanFirewallNote(String operatingSystem) {
  switch (operatingSystem.toLowerCase()) {
    case 'windows':
      return 'Windows Güvenlik Duvarı bu porta gelen bağlantıyı sorabilir. '
          'İzin verilmeden diğer cihaz bağlanamaz.';
    case 'macos':
      return 'macOS Güvenlik Duvarı açıksa gelen bağlantıya izin vermek gerekir. '
          'Duvar kuralı bu uygulamada değiştirilmez. '
          'MacBook uykuya geçince garson bağlantısı kesilir.';
    default:
      return 'Güvenlik duvarı gelen bağlantıyı engelliyorsa seçilen porta izin verin.';
  }
}
