import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var windowChannel: FlutterMethodChannel?
  private var fullscreenObservers: [NSObjectProtocol] = []

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "mediapager/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setFullscreen",
            let arguments = call.arguments as? [String: Any],
            let enabled = arguments["enabled"] as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let self else {
        result(nil)
        return
      }

      if self.styleMask.contains(.fullScreen) != enabled {
        self.toggleFullScreen(nil)
      } else {
        self.notifyFullscreenChanged(enabled)
      }
      result(nil)
    }
    windowChannel = channel

    let notificationCenter = NotificationCenter.default
    fullscreenObservers = [
      notificationCenter.addObserver(
        forName: NSWindow.didEnterFullScreenNotification,
        object: self,
        queue: .main
      ) { [weak self] _ in
        self?.notifyFullscreenChanged(true)
      },
      notificationCenter.addObserver(
        forName: NSWindow.didExitFullScreenNotification,
        object: self,
        queue: .main
      ) { [weak self] _ in
        self?.notifyFullscreenChanged(false)
      },
    ]

    super.awakeFromNib()
  }

  deinit {
    fullscreenObservers.forEach { NotificationCenter.default.removeObserver($0) }
  }

  private func notifyFullscreenChanged(_ fullscreen: Bool) {
    windowChannel?.invokeMethod("fullscreenChanged", arguments: fullscreen)
  }
}
