import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.ibul.app/lan_center",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "browse" else {
        result(FlutterMethodNotImplemented)
        return
      }
      LanCenterBrowse.run(result: result)
    }
  }
}

/// Finds the restaurant's own computer on the local network through its
/// Bonjour announcement (`_ibul-lan._tcp`, declared in Info.plist). It only
/// reports what is announced: host, port and the identity fields. Finding a
/// center is not trust; the app pins the server certificate and the center's
/// operator approves the device.
///
/// Discovery uses the Network framework (it reports a refused local-network
/// permission instead of staying silent); the announced host and port are
/// then read with a plain service resolve.
final class LanCenterBrowse: NSObject, NetServiceDelegate {
  private static var running: [LanCenterBrowse] = []

  private var browser: NWBrowser?
  private var services: [String: NetService] = [:]
  private var texts: [String: [String: String]] = [:]
  private var found: [[String: Any]] = []
  private var result: FlutterResult?

  static func run(result: @escaping FlutterResult) {
    let browse = LanCenterBrowse()
    browse.result = result
    running.append(browse)
    browse.start()
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { browse.finish() }
  }

  private func start() {
    let parameters = NWParameters()
    parameters.includePeerToPeer = false
    let browser = NWBrowser(
      for: .bonjourWithTXTRecord(type: "_ibul-lan._tcp", domain: "local."),
      using: parameters
    )
    self.browser = browser
    browser.stateUpdateHandler = { state in
      switch state {
      case .waiting(let error):
        // Local network access not granted (or still being asked).
        NSLog("[LanCenterBrowse] waiting: %@", error.localizedDescription)
      case .failed(let error):
        NSLog("[LanCenterBrowse] failed: %@", error.localizedDescription)
      default:
        break
      }
    }
    browser.browseResultsChangedHandler = { [weak self] results, _ in
      guard let self = self else { return }
      for item in results {
        guard case let .service(name, type, domain, _) = item.endpoint else { continue }
        if self.services[name] != nil { continue }
        var fields: [String: String] = [:]
        if case let .bonjour(record) = item.metadata {
          for key in ["svc", "rid", "mid", "fp"] {
            if let value = record[key] { fields[key] = value }
          }
        }
        self.texts[name] = fields
        let service = NetService(domain: domain, type: type, name: name)
        self.services[name] = service
        service.delegate = self
        service.resolve(withTimeout: 2.0)
      }
    }
    browser.start(queue: .main)
  }

  private func finish() {
    guard let result = result else { return }
    self.result = nil
    browser?.cancel()
    browser = nil
    for service in services.values {
      service.stop()
      service.delegate = nil
    }
    result(found)
    LanCenterBrowse.running.removeAll { $0 === self }
  }

  func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
    NSLog("[LanCenterBrowse] resolve failed: %@", errorDict.description)
  }

  func netServiceDidResolveAddress(_ sender: NetService) {
    var fields = texts[sender.name] ?? [:]
    if fields["svc"] == nil, let data = sender.txtRecordData() {
      for (key, value) in NetService.dictionary(fromTXTRecord: data) {
        fields[key] = String(data: value, encoding: .utf8) ?? ""
      }
    }
    var host = ""
    for address in sender.addresses ?? [] {
      let ipv4 = address.withUnsafeBytes { raw -> String? in
        guard let base = raw.baseAddress else { return nil }
        let generic = base.assumingMemoryBound(to: sockaddr.self)
        guard generic.pointee.sa_family == sa_family_t(AF_INET) else { return nil }
        var name = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let status = getnameinfo(
          generic, socklen_t(address.count), &name, socklen_t(name.count), nil, 0, NI_NUMERICHOST
        )
        return status == 0 ? String(cString: name) : nil
      }
      // The center listens on the private network address, never loopback.
      if let ipv4 = ipv4, !ipv4.isEmpty, !ipv4.hasPrefix("127.") {
        host = ipv4
        break
      }
    }
    if host.isEmpty, let name = sender.hostName {
      host = name.hasSuffix(".") ? String(name.dropLast()) : name
    }
    let record: [String: Any] = [
      "host": host,
      "port": sender.port,
      "restaurant_id": fields["rid"] ?? "",
      "machine_id": fields["mid"] ?? "",
      "fingerprint": fields["fp"] ?? "",
      "service": fields["svc"] ?? "",
    ]
    // The same center is announced on every interface; one row is enough.
    let known = found.contains {
      ($0["machine_id"] as? String) == (record["machine_id"] as? String)
        && ($0["host"] as? String) == host
    }
    if !known { found.append(record) }
  }
}
