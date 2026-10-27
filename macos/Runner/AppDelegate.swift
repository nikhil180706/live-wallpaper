import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    override func applicationDidFinishLaunching(_ notification: Notification) {
        let controller: FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "com.livewallpaper.app/engine",
            binaryMessenger: controller.engine.binaryMessenger
        )

        channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "setWallpaper":
                if let args = call.arguments as? [String: Any],
                   let path = args["path"] as? String,
                   let muted = args["muted"] as? Bool {
                    WallpaperManager.shared.setWallpaper(path: path, muted: muted)
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Path and muted flags are required", details: nil))
                }
            case "setMuted":
                if let args = call.arguments as? [String: Any],
                   let muted = args["muted"] as? Bool {
                    WallpaperManager.shared.setMuted(muted)
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "Muted flag required", details: nil))
                }
            case "pauseWallpaper":
                WallpaperManager.shared.pause()
                result(true)
            case "resumeWallpaper":
                WallpaperManager.shared.resume()
                result(true)
            case "removeWallpaper":
                WallpaperManager.shared.teardown()
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        super.applicationDidFinishLaunching(notification)
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Return false so wallpaper keeps running when the configuration window is closed
        return false
    }
}
