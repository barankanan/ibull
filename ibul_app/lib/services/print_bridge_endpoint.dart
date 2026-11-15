import 'print_bridge_endpoint_stub.dart'
    if (dart.library.io) 'print_bridge_endpoint_io.dart' as endpoint;

/// Local bridge address. Defaults to 127.0.0.1:3001.
///
/// `IBUL_PRINT_BRIDGE_PORT` selects an isolated port for tests so the
/// seller app does not contact the live service.
Uri printBridgeBaseUri() => endpoint.printBridgeBaseUri();
