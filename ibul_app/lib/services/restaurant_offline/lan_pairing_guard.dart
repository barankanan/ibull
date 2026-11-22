import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// One order authority per restaurant on this computer.
///
/// The claim is an operating-system file lock held for as long as the process
/// lives, not a pid that must be probed with `kill -0`: a sandboxed app cannot
/// start `kill`, and a lock disappears by itself when a crashed process dies,
/// so a stale file never blocks the next start.
class LanAuthorityLock {
  LanAuthorityLock(this.file);

  static final Map<String, RandomAccessFile> _held = <String, RandomAccessFile>{};

  final File file;

  Future<bool> acquire() async {
    if (_held.containsKey(file.path)) return false;
    file.parent.createSync(recursive: true);
    RandomAccessFile? handle;
    try {
      handle = file.openSync(mode: FileMode.append);
      handle.lockSync(FileLock.exclusive);
    } on FileSystemException {
      handle?.closeSync();
      return false;
    }
    try {
      handle.truncateSync(0);
      handle.writeStringSync('$pid');
      handle.flushSync();
    } catch (_) {}
    _held[file.path] = handle;
    return true;
  }

  Future<void> release() async {
    final handle = _held.remove(file.path);
    if (handle == null) return;
    try {
      handle.unlockSync();
    } catch (_) {}
    try {
      handle.closeSync();
    } catch (_) {}
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}

/// Pairing and listen rules for the existing LAN host.
///
/// The one-time secret is not a password store. It is shown once to the
/// operator and is not written to logs by this type.
class PairingAttemptGuard {
  static const int maxFailures = 5;
  static const Duration lockout = Duration(seconds: 30);
  static const Duration codeTtl = Duration(minutes: 2);

  int failures = 0;
  DateTime? lockedUntil;

  bool allow(DateTime now) {
    final until = lockedUntil;
    if (until != null && now.isBefore(until)) return false;
    if (until != null && !now.isBefore(until)) {
      lockedUntil = null;
      failures = 0;
    }
    return true;
  }

  void recordFailure(DateTime now) {
    failures += 1;
    if (failures >= maxFailures) {
      lockedUntil = now.add(lockout);
      failures = 0;
    }
  }

  void recordSuccess() {
    failures = 0;
    lockedUntil = null;
  }
}

String newPairingSecret(Random random) {
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

bool pairingSecretMatches(String expected, String presented) {
  if (expected.isEmpty || expected.length != presented.length) return false;
  var difference = 0;
  for (var index = 0; index < expected.length; index++) {
    difference |= expected.codeUnitAt(index) ^ presented.codeUnitAt(index);
  }
  return difference == 0;
}

/// Commitment to a nonce that is revealed later (host-approved pairing).
String lanPairingCommit(String nonce) {
  return sha256.convert(utf8.encode(nonce.trim())).toString();
}

/// The six digits both screens show during host-approved pairing.
///
/// It binds the server certificate the device actually reached, the device's
/// certificate request and one fresh nonce from each side. The device commits
/// to its nonce before it sees the host's, and the host answers before the
/// device reveals, so a relay in the middle cannot steer both screens to the
/// same digits. Equal digits mean the phone and this computer talk to each
/// other directly.
String lanPairingMatchCode({
  required String serverFingerprint,
  required String csr,
  required String deviceNonce,
  required String hostNonce,
}) {
  final fingerprint = serverFingerprint.replaceAll(':', '').trim().toLowerCase();
  final request = sha256.convert(utf8.encode(csr.trim())).toString();
  final digest = sha256.convert(
    utf8.encode(
      <String>[fingerprint, request, deviceNonce.trim(), hostNonce.trim()]
          .join('|'),
    ),
  );
  var value = 0;
  for (final byte in digest.bytes.take(6)) {
    value = (value * 256 + byte) % 1000000;
  }
  return value.toString().padLeft(6, '0');
}

/// SHA-1 device ids from older enrollments are 40 hex characters.
/// They are not accepted. The device must pair again.
bool legacySha1DeviceId(String deviceId) {
  return RegExp(r'^[0-9a-f]{40}$').hasMatch(deviceId.trim().toLowerCase());
}

class LanListenDecision {
  const LanListenDecision({required this.allowed, this.error});

  final bool allowed;
  final String? error;
}

LanListenDecision decideLanListen(InternetAddress address) {
  if (address.type == InternetAddressType.IPv4 &&
      address.rawAddress.every((byte) => byte == 0)) {
    return const LanListenDecision(
      allowed: false,
      error: 'LAN sunucusu bütün ağ arayüzlerinde açılamaz.',
    );
  }
  if (address.isLoopback) {
    return const LanListenDecision(allowed: true);
  }
  if (address.type == InternetAddressType.IPv4 && _private(address.rawAddress)) {
    return const LanListenDecision(allowed: true);
  }
  return const LanListenDecision(
    allowed: false,
    error: 'Seçilen adres güvenilir bir yerel arayüz değil.',
  );
}

bool _private(List<int> bytes) {
  if (bytes.length != 4) return false;
  if (bytes[0] == 10) return true;
  if (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) return true;
  if (bytes[0] == 192 && bytes[1] == 168) return true;
  if (bytes[0] == 169 && bytes[1] == 254) return true;
  return false;
}

String lanMaterialDirectory({
  required String operatingSystem,
  required Map<String, String> environment,
  required String restaurantId,
}) {
  final override = (environment['IBUL_LAN_HOME'] ?? '').trim();
  if (override.isNotEmpty) {
    final id = restaurantId.trim();
    return operatingSystem.toLowerCase() == 'windows'
        ? '$override\\$id'
        : '$override/$id';
  }
  final id = restaurantId.trim();
  final system = operatingSystem.toLowerCase();
  if (system == 'windows') {
    final base = (environment['LOCALAPPDATA'] ?? '').trim();
    final root = base.isEmpty ? r'C:\Users\Default\AppData\Local' : base;
    return '$root\\IbulLan\\$id';
  }
  if (system == 'macos') {
    final home = (environment['HOME'] ?? '').trim();
    return '$home/Library/Application Support/ibul-lan/$id';
  }
  final home = (environment['HOME'] ?? '').trim();
  return '$home/.local/share/ibul-lan/$id';
}

/// Flutter Web cannot present a TLS client certificate.
enum LanClientChannel { desktop, mobileNative, webBlocked }

LanClientChannel lanClientChannel({required bool isWeb, required String operatingSystem}) {
  if (isWeb) return LanClientChannel.webBlocked;
  switch (operatingSystem.toLowerCase()) {
    case 'android':
    case 'ios':
      return LanClientChannel.mobileNative;
    default:
      return LanClientChannel.desktop;
  }
}
