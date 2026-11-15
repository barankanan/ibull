import Cocoa
import FlutterMacOS
import ServiceManagement

/// Registers the bundled print bridge as a user LaunchAgent.
/// The live label is refused unless the process environment explicitly allows it.
enum PrintBridgeAgent {
  static let channelName = "com.ibul.sellerdesktop/print_agent"
  static let livePlistName = "com.ibul.localprint.plist"

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      let plistName = stringArg(call, "plistName")
      switch call.method {
      case "status":
        result(status(plistName: plistName))
      case "register":
        result(registerAgent(plistName: plistName))
      case "unregister":
        result(unregisterAgent(plistName: plistName))
      case "openLoginItems":
        openLoginItems()
        result(["ok": true, "status": "settings_opened", "message": ""])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func stringArg(_ call: FlutterMethodCall, _ key: String) -> String {
    let args = call.arguments as? [String: Any]
    return (args?[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  private static func liveRegistrationAllowed() -> Bool {
    ProcessInfo.processInfo.environment["IBUL_ALLOW_LIVE_PRINT_AGENT"] == "1"
  }

  private static func refuseLive(_ plistName: String) -> [String: Any]? {
    guard plistName == livePlistName, !liveRegistrationAllowed() else {
      return nil
    }
    return [
      "ok": false,
      "status": "live_label_blocked",
      "message": "Canlı yazıcı servisi kaydı bu kurulumda kapalı.",
    ]
  }

  private static func unsupported() -> [String: Any] {
    [
      "ok": false,
      "status": "unsupported",
      "message": "Yazıcı servisi kaydı macOS 13 ve sonrasında kullanılabilir.",
    ]
  }

  static func status(plistName: String) -> [String: Any] {
    if let refused = refuseLive(plistName) {
      return refused
    }
    guard #available(macOS 13.0, *) else {
      return unsupported()
    }
    guard !plistName.isEmpty else {
      return ["ok": false, "status": "invalid", "message": "Servis kaydı adı boş."]
    }
    let service = SMAppService.agent(plistName: plistName)
    return payload(status: service.status, ok: true)
  }

  static func registerAgent(plistName: String) -> [String: Any] {
    if let refused = refuseLive(plistName) {
      return refused
    }
    guard #available(macOS 13.0, *) else {
      return unsupported()
    }
    guard !plistName.isEmpty else {
      return ["ok": false, "status": "invalid", "message": "Servis kaydı adı boş."]
    }
    let service = SMAppService.agent(plistName: plistName)
    if service.status == .requiresApproval {
      return payload(status: .requiresApproval, ok: false)
    }
    if service.status == .enabled {
      return payload(status: .enabled, ok: true)
    }
    do {
      try service.register()
    } catch {
      let nsError = error as NSError
      if nsError.code == 12 {
        return payload(status: service.status, ok: service.status == .enabled)
      }
      return errorPayload(nsError, status: service.status)
    }
    return payload(status: service.status, ok: service.status == .enabled)
  }

  static func unregisterAgent(plistName: String) -> [String: Any] {
    if let refused = refuseLive(plistName) {
      return refused
    }
    guard #available(macOS 13.0, *) else {
      return unsupported()
    }
    let service = SMAppService.agent(plistName: plistName)
    do {
      try service.unregister()
    } catch {
      let nsError = error as NSError
      if nsError.code == 6 {
        return ["ok": true, "status": "notRegistered", "message": "İzole yazıcı servisi kayıtlı değil."]
      }
      return errorPayload(nsError, status: service.status)
    }
    return payload(status: service.status, ok: true)
  }

  private static func openLoginItems() {
    guard #available(macOS 13.0, *) else { return }
    SMAppService.openSystemSettingsLoginItems()
  }

  @available(macOS 13.0, *)
  private static func payload(status: SMAppService.Status, ok: Bool) -> [String: Any] {
    [
      "ok": ok,
      "status": statusName(status),
      "message": message(for: status),
    ]
  }

  @available(macOS 13.0, *)
  private static func errorPayload(_ error: NSError, status: SMAppService.Status) -> [String: Any] {
    let mapped = statusForError(error.code) ?? statusName(status)
    return [
      "ok": false,
      "status": mapped,
      "code": error.code,
      "domain": error.domain,
      "message": messageForCode(error.code) ?? error.localizedDescription,
    ]
  }

  @available(macOS 13.0, *)
  private static func statusName(_ status: SMAppService.Status) -> String {
    switch status {
    case .notRegistered:
      return "notRegistered"
    case .enabled:
      return "enabled"
    case .requiresApproval:
      return "requiresApproval"
    case .notFound:
      return "notFound"
    @unknown default:
      return "unknown"
    }
  }

  private static func statusForError(_ code: Int) -> String? {
    switch code {
    case 3:
      return "invalid_signature"
    case 11:
      return "launch_denied"
    case 12:
      return "already_registered"
    case 8, 10:
      return "invalid_plist"
    default:
      return nil
    }
  }

  @available(macOS 13.0, *)
  private static func message(for status: SMAppService.Status) -> String {
    switch status {
    case .enabled:
      return "Yazıcı servisi sisteme kayıtlı."
    case .requiresApproval:
      return "Yazıcı servisinin açılışta çalışması için Sistem Ayarları’nda izin vermeniz gerekiyor. İzin verilmeden servis başlatılmaz."
    case .notRegistered:
      return "Yazıcı servisi henüz sisteme kayıtlı değil."
    case .notFound:
      return "Yazıcı servisi kaydı uygulama paketinde bulunamadı."
    @unknown default:
      return "Yazıcı servisi kaydı tamamlanamadı."
    }
  }

  private static func messageForCode(_ code: Int) -> String? {
    switch code {
    case 3:
      return "Yazıcı servisi kaydı tamamlanamadı. Uygulamanın geçerli bir imzası yok."
    case 11:
      return "Yazıcı servisi izni verilmedi. Servis başlatılmadı."
    case 4:
      return "Yazıcı servisi için sistem izni verilmedi."
    default:
      return nil
    }
  }
}
