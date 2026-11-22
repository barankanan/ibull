import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // The seller window carries the visible app name; the customer app keeps
    // its own title.
    if let sellerName = Bundle.main.object(forInfoDictionaryKey: "IbulAppDisplayName") as? String,
       !sellerName.isEmpty {
      self.title = sellerName
    }

    RegisterGeneratedPlugins(registry: flutterViewController)
    LanBonjour.register(with: flutterViewController)
    PrintBridgeAgent.register(with: flutterViewController)

    super.awakeFromNib()
  }
}
