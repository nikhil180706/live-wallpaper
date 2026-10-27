import Cocoa
import AVFoundation

class WallpaperManager: NSObject {
    static let shared = WallpaperManager()
    
    private var wallpaperWindows: [NSWindow] = []
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var isMuted: Bool = true
    private var currentVideoPath: String?
    private var isManuallyPaused: Bool = false

    override init() {
        super.init()
        setupPowerAndLockObservers()
    }

    private func setupPowerAndLockObservers() {
        let ws = NSWorkspace.shared.notificationCenter
        
        // 1. Pause when displays sleep, resume when waking
        ws.addObserver(self, selector: #selector(screenSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(screenWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        
        // 2. Pause when screen locks (0% CPU / 0% battery while away)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenLocked),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: NSNotification.Name("com.apple.screenIsUnlocked"),
            object: nil
        )
        
        // 3. Handle external monitors connected or unplugged
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func setWallpaper(path: String, muted: Bool) {
        self.currentVideoPath = path
        self.isMuted = muted
        self.isManuallyPaused = false
        let url = URL(fileURLWithPath: path)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.teardown()

            let asset = AVURLAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVQueuePlayer(playerItem: playerItem)
            player.isMuted = self.isMuted
            
            // Seamless infinite hardware-accelerated video loop
            self.playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
            self.queuePlayer = player

            // Setup wallpaper window for every active display
            self.createWallpaperWindows(for: player)
            player.play()
        }
    }

    private func createWallpaperWindows(for player: AVQueuePlayer) {
        for window in wallpaperWindows {
            window.orderOut(nil)
        }
        wallpaperWindows.removeAll()

        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            
            // Render directly beneath desktop icons
            window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.ignoresMouseEvents = true
            window.backgroundColor = .black
            window.canHide = false
            
            let view = NSView(frame: screen.frame)
            view.wantsLayer = true
            
            let layer = AVPlayerLayer(player: player)
            layer.frame = view.bounds
            layer.videoGravity = .resizeAspectFill
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            
            view.layer?.addSublayer(layer)
            window.contentView = view
            window.orderFront(nil)
            
            wallpaperWindows.append(window)
        }
    }

    func setMuted(_ muted: Bool) {
        self.isMuted = muted
        queuePlayer?.isMuted = muted
    }

    func pause() {
        isManuallyPaused = true
        queuePlayer?.pause()
    }

    func resume() {
        isManuallyPaused = false
        queuePlayer?.play()
    }

    @objc private func screenSleep() {
        queuePlayer?.pause()
    }

    @objc private func screenWake() {
        if !isManuallyPaused {
            queuePlayer?.play()
        }
    }

    @objc private func screenLocked() {
        queuePlayer?.pause()
    }

    @objc private func screenUnlocked() {
        if !isManuallyPaused {
            queuePlayer?.play()
        }
    }

    @objc private func screensChanged() {
        guard let player = queuePlayer else { return }
        DispatchQueue.main.async { [weak self] in
            self?.createWallpaperWindows(for: player)
        }
    }

    func teardown() {
        queuePlayer?.pause()
        queuePlayer = nil
        playerLooper = nil
        for window in wallpaperWindows {
            window.orderOut(nil)
        }
        wallpaperWindows.removeAll()
    }
}
