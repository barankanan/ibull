import Cocoa
import FlutterMacOS

/// Announces the LAN center with the system Bonjour API (NetService), in
/// process. The App Sandbox cannot start the external `dns-sd` tool, and this
/// needs only the network client/server entitlements the app already has.
/// Finding the center is not trust: a device still needs the server
/// fingerprint and a pairing code.
final class LanBonjour: NSObject, NetServiceDelegate {
  static let channelName = "com.ibul.sellerdesktop/lan_bonjour"
  private static let shared = LanBonjour()

  private var service: NetService?
  private var pending: FlutterResult?

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "start":
        shared.start(call.arguments as? [String: Any] ?? [:], result: result)
      case "stop":
        shared.stop()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func start(_ args: [String: Any], result: @escaping FlutterResult) {
    stop()
    let name = (args["name"] as? String) ?? "IBUL Merkez"
    let type = (args["type"] as? String) ?? "_ibul-lan._tcp."
    let port = (args["port"] as? Int) ?? 0
    guard port > 0 && port < 65536 else {
      result(FlutterError(code: "bad_port", message: "Geçersiz port", details: nil))
      return
    }
    let service = NetService(domain: "local.", type: type, name: name, port: Int32(port))
    var record: [String: Data] = [:]
    for (key, value) in (args["txt"] as? [String: String]) ?? [:] {
      record[key] = value.data(using: .utf8)
    }
    service.setTXTRecord(NetService.data(fromTXTRecord: record))
    service.delegate = self
    self.service = service
    self.pending = result
    service.publish()
  }

  private func stop() {
    service?.stop()
    service = nil
    pending = nil
  }

  func netServiceDidPublish(_ sender: NetService) {
    pending?(true)
    pending = nil
  }

  func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
    pending?(FlutterError(code: "publish_failed", message: "\(errorDict)", details: nil))
    pending = nil
    service = nil
  }
}
