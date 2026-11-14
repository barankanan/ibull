/// Which system may create the order for this send.
///
/// LAN pilot and the Supabase RPC are never both authorities. The pilot is
/// off unless the isolated test build sets `IBUL_LAN_PILOT`.
enum OrderAuthority { cloud, lanPilot }

OrderAuthority orderAuthority({required bool lanPilotEnabled}) {
  return lanPilotEnabled ? OrderAuthority.lanPilot : OrderAuthority.cloud;
}

bool lanPilotMayCallSupabase(OrderAuthority authority) {
  return authority == OrderAuthority.cloud;
}

/// Isolated-test switch. Production builds leave this false.
class LanPilotMode {
  static const bool fromEnvironment = bool.fromEnvironment('IBUL_LAN_PILOT');
  static bool? debugOverride;

  static bool get enabled => debugOverride ?? fromEnvironment;
}

class LanPilotContract {
  static const String bridgeClosedMessage =
      'Yerel köprü kapalı. Sipariş gönderilmedi.';
  static const String notSentMessage =
      'Sipariş gönderilmedi. Taslak duruyor.';
  static const String menuMissingMessage =
      'Yerel menü doğrulanamadı. Sipariş gönderilmedi.';

  static String? userMessage(String raw) {
    for (final message in <String>[
      bridgeClosedMessage,
      menuMissingMessage,
      notSentMessage,
    ]) {
      if (raw.contains(message)) return message;
    }
    return null;
  }
}
