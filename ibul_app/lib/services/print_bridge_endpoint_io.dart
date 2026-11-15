import 'dart:io' show Platform;

Uri printBridgeBaseUri() {
  final raw = Platform.environment['IBUL_PRINT_BRIDGE_PORT']?.trim() ?? '';
  final port = int.tryParse(raw) ?? 3001;
  if (port < 1 || port > 65535) {
    return Uri.parse('http://127.0.0.1:3001');
  }
  return Uri.parse('http://127.0.0.1:$port');
}
