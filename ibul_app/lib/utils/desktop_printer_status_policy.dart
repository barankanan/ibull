import '../services/desktop_print_hub.dart';

/// Single rule for the top boot banner vs bottom [DesktopPrintStatusBar].
bool shouldShowDesktopPrinterBootBanner({
  required BridgeStatus bridgeStatus,
  required bool bootstrapped,
  String? bootError,
}) {
  if (bridgeStatus == BridgeStatus.online) return false;
  return !bootstrapped || (bootError != null && bootError.trim().isNotEmpty);
}

bool isDesktopPrinterBridgeReady(BridgeStatus status) =>
    status == BridgeStatus.online;
