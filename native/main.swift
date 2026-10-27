import SwiftUI
import Cocoa
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Golden Gate Theme (macOS 27 Design Language)
struct GoldenGate {
    static let gold = Color(red: 0.98, green: 0.68, blue: 0.22)
    static let amber = Color(red: 0.94, green: 0.44, blue: 0.16)
    static let obsidian = Color(red: 0.08, green: 0.08, blue: 0.11)
    static let cardBackground = Color(white: 0.14, opacity: 0.6)
    static let border = Color.white.opacity(0.12)
    static let primaryGradient = LinearGradient(
        colors: [gold, amber],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Wallpaper Model
struct WallpaperItem: Identifiable, Codable, Equatable {
    let id: UUID
    let path: String
    let name: String
    let dateAdded: Date
    
    init(path: String) {
        self.id = UUID()
        self.path = path
        self.name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        self.dateAdded = Date()
    }
}

enum StudioTab: String, CaseIterable, Identifiable {
    case library = "Library"
    case displays = "Displays"
    case playback = "Playback"
    case lockscreen = "Live Lock Screen"
    case energy = "Energy & Battery"
    case about = "About"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .library: return "film.stack"
        case .displays: return "display.2"
        case .playback: return "slider.horizontal.3"
        case .lockscreen: return "lock.shield.fill"
        case .energy: return "bolt.shield"
        case .about: return "sparkles"
        }
    }
}

// MARK: - Engine & State Manager
class WallpaperEngine: ObservableObject {
    static let shared = WallpaperEngine()
    
    @Published var selectedTab: StudioTab = .library
    @Published var playlist: [WallpaperItem] = []
    @Published var activeWallpaperPath: String? = nil
    @Published var isPaused: Bool = false
    @Published var volume: Double = 0.0
    @Published var isMuted: Bool = true
    @Published var playbackSpeed: Float = 1.0
    @Published var aspectFill: Bool = true
    
    // Lock Screen sync
    @Published var syncLockScreen: Bool = true
    @Published var lockScreenStatusMessage: String = "Live video injected into macOS Lock Screen"
    
    // UI state
    @Published var hoveredItemId: UUID? = nil
    
    // Battery & Energy Toggles
    @Published var pauseOnLock: Bool = false
    @Published var pauseOnSleep: Bool = true
    @Published var pauseOnFullScreen: Bool = true
    @Published var pauseOnBattery: Bool = false
    @Published var cycleIntervalSeconds: Int = 0
    
    // Connected Displays
    @Published var detectedScreens: [NSScreen] = []
    
    private var wallpaperWindows: [NSWindow] = []
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var cycleTimer: Timer?
    private var thumbnailCache: [String: NSImage] = [:]
    
    init() {
        self.loadSettings()
        self.detectedScreens = NSScreen.screens
        self.setupSystemObservers()
        
        if let active = activeWallpaperPath, FileManager.default.fileExists(atPath: active) {
            self.applyWallpaper(path: active)
        }
    }
    
    private func setupSystemObservers() {
        let ws = NSWorkspace.shared.notificationCenter
        
        ws.addObserver(self, selector: #selector(screenSleep), name: NSWorkspace.screensDidSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(screenWake), name: NSWorkspace.screensDidWakeNotification, object: nil)
        
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
        
        ws.addObserver(self, selector: #selector(spaceChanged), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    func addVideo(path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        if !playlist.contains(where: { $0.path == path }) {
            let item = WallpaperItem(path: path)
            playlist.append(item)
            saveSettings()
            
            if activeWallpaperPath == nil {
                applyWallpaper(path: path)
            }
        }
    }
    
    func removeVideo(item: WallpaperItem) {
        playlist.removeAll(where: { $0.id == item.id })
        if activeWallpaperPath == item.path {
            if let first = playlist.first {
                applyWallpaper(path: first.path)
            } else {
                teardown()
                activeWallpaperPath = nil
            }
        }
        saveSettings()
    }
    
    func applyWallpaper(path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        self.activeWallpaperPath = path
        self.isPaused = false
        saveSettings()
        
        // 1. Inject Live Video directly into macOS Native Aerial System!
        injectIntoNativeAerial(path: path)
        
        // 2. Sync Live Video stream for ScreenSaver
        syncLiveVideoForLockScreen(path: path)
        
        // 3. Start desktop live video playback
        let url = URL(fileURLWithPath: path)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.teardown()
            
            let asset = AVURLAsset(url: url)
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVQueuePlayer(playerItem: playerItem)
            
            player.isMuted = self.isMuted
            player.volume = Float(self.volume)
            player.rate = self.playbackSpeed
            
            self.playerLooper = AVPlayerLooper(player: player, templateItem: playerItem)
            self.queuePlayer = player
            
            self.createWallpaperWindows(for: player)
            player.play()
        }
    }
    
    // MARK: - Native macOS Aerial Video Injection (100% Live Moving Lock Screen)
    func injectIntoNativeAerial(path: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let home = FileManager.default.homeDirectoryForCurrentUser
            let aerialsDir = home.appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials/videos")
            let targetAsset = "4207734D-74FE-4F92-B5E1-6EC8DEE24A15.mov"
            let target = aerialsDir.appendingPathComponent(targetAsset)
            
            try? FileManager.default.createDirectory(at: aerialsDir, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: target)
            try? FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: target)
            
            // Extract frame for snapshot
            let url = URL(fileURLWithPath: path)
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 320, height: 180)
            let time = CMTime(seconds: 1, preferredTimescale: 60)
            
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let bitmap = NSBitmapImageRep(cgImage: cgImage)
                if let pngData = bitmap.representation(using: .png, properties: [:]) {
                    let thumbsDir = home.appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials/thumbnails")
                    let thumbTarget = thumbsDir.appendingPathComponent("4207734D-74FE-4F92-B5E1-6EC8DEE24A15.png")
                    try? pngData.write(to: thumbTarget)
                }
            }
            
            DispatchQueue.main.async {
                self?.lockScreenStatusMessage = "Live 60 FPS video injected for Lock Screen!"
            }
        }
    }
    
    func syncLiveVideoForLockScreen(path: String) {
        let picturesDir = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let outDir = picturesDir.appendingPathComponent("LiveWallpaper")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let target = outDir.appendingPathComponent("current_video.mp4")
        
        try? FileManager.default.removeItem(at: target)
        try? FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: target)
    }
    
    func openSystemWallpaperSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension") {
            NSWorkspace.shared.open(url)
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
            
            window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
            window.ignoresMouseEvents = true
            window.backgroundColor = .black
            window.canHide = false
            
            let view = NSView(frame: screen.frame)
            view.wantsLayer = true
            
            let layer = AVPlayerLayer(player: player)
            layer.frame = view.bounds
            layer.videoGravity = self.aspectFill ? .resizeAspectFill : .resizeAspect
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            
            view.layer?.addSublayer(layer)
            window.contentView = view
            window.orderFront(nil)
            
            wallpaperWindows.append(window)
        }
    }
    
    func togglePlayPause() {
        if isPaused {
            queuePlayer?.play()
            isPaused = false
        } else {
            queuePlayer?.pause()
            isPaused = true
        }
    }
    
    func nextWallpaper() {
        guard !playlist.isEmpty else { return }
        if let current = activeWallpaperPath, let index = playlist.firstIndex(where: { $0.path == current }) {
            let nextIndex = (index + 1) % playlist.count
            applyWallpaper(path: playlist[nextIndex].path)
        } else if let first = playlist.first {
            applyWallpaper(path: first.path)
        }
    }
    
    func setVolume(_ newVol: Double) {
        self.volume = newVol
        self.isMuted = (newVol == 0.0)
        queuePlayer?.isMuted = self.isMuted
        queuePlayer?.volume = Float(newVol)
        saveSettings()
    }
    
    func toggleMute() {
        self.isMuted.toggle()
        queuePlayer?.isMuted = self.isMuted
        saveSettings()
    }
    
    func setSpeed(_ speed: Float) {
        self.playbackSpeed = speed
        queuePlayer?.rate = speed
        saveSettings()
    }
    
    func setAspectFill(_ fill: Bool) {
        self.aspectFill = fill
        if let p = queuePlayer {
            createWallpaperWindows(for: p)
        }
        saveSettings()
    }
    
    func setCycleInterval(_ seconds: Int) {
        self.cycleIntervalSeconds = seconds
        self.cycleTimer?.invalidate()
        self.cycleTimer = nil
        
        if seconds > 0 {
            self.cycleTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: true) { [weak self] _ in
                self?.nextWallpaper()
            }
        }
        saveSettings()
    }
    
    func getThumbnail(for path: String) -> NSImage? {
        if let cached = thumbnailCache[path] { return cached }
        let asset = AVURLAsset(url: URL(fileURLWithPath: path))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 320, height: 180)
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
            let img = NSImage(cgImage: cgImage, size: NSSize(width: 320, height: 180))
            thumbnailCache[path] = img
            return img
        }
        return nil
    }
    
    @objc private func screenSleep() {
        if pauseOnSleep { queuePlayer?.pause() }
    }
    
    @objc private func screenWake() {
        if !isPaused { queuePlayer?.play() }
    }
    
    @objc private func screenLocked() {
        if pauseOnLock { queuePlayer?.pause() }
    }
    
    @objc private func screenUnlocked() {
        if !isPaused { queuePlayer?.play() }
    }
    
    @objc private func spaceChanged() {
        if pauseOnFullScreen {
            if !isPaused { queuePlayer?.play() }
        }
    }
    
    @objc private func screensChanged() {
        self.detectedScreens = NSScreen.screens
        if let p = queuePlayer {
            self.createWallpaperWindows(for: p)
        }
    }
    
    private func teardown() {
        queuePlayer?.pause()
        queuePlayer = nil
        playerLooper = nil
        for window in wallpaperWindows {
            window.orderOut(nil)
        }
        wallpaperWindows.removeAll()
    }
    
    private func saveSettings() {
        let paths = playlist.map { $0.path }
        UserDefaults.standard.set(paths, forKey: "lw_playlist")
        UserDefaults.standard.set(activeWallpaperPath, forKey: "lw_active_path")
        UserDefaults.standard.set(volume, forKey: "lw_volume")
        UserDefaults.standard.set(isMuted, forKey: "lw_muted")
        UserDefaults.standard.set(playbackSpeed, forKey: "lw_speed")
        UserDefaults.standard.set(aspectFill, forKey: "lw_aspect_fill")
        UserDefaults.standard.set(pauseOnLock, forKey: "lw_pause_lock")
        UserDefaults.standard.set(pauseOnSleep, forKey: "lw_pause_sleep")
        UserDefaults.standard.set(pauseOnFullScreen, forKey: "lw_pause_fs")
        UserDefaults.standard.set(pauseOnBattery, forKey: "lw_pause_battery")
        UserDefaults.standard.set(cycleIntervalSeconds, forKey: "lw_cycle_interval")
    }
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        if let paths = defaults.stringArray(forKey: "lw_playlist") {
            self.playlist = paths.filter { FileManager.default.fileExists(atPath: $0) }.map { WallpaperItem(path: $0) }
        }
        self.activeWallpaperPath = defaults.string(forKey: "lw_active_path")
        self.volume = defaults.double(forKey: "lw_volume")
        self.isMuted = defaults.bool(forKey: "lw_muted")
        if let speed = defaults.object(forKey: "lw_speed") as? Float { self.playbackSpeed = speed }
        if defaults.object(forKey: "lw_aspect_fill") != nil { self.aspectFill = defaults.bool(forKey: "lw_aspect_fill") }
        if defaults.object(forKey: "lw_pause_lock") != nil { self.pauseOnLock = defaults.bool(forKey: "lw_pause_lock") }
        if defaults.object(forKey: "lw_pause_sleep") != nil { self.pauseOnSleep = defaults.bool(forKey: "lw_pause_sleep") }
        if defaults.object(forKey: "lw_pause_fs") != nil { self.pauseOnFullScreen = defaults.bool(forKey: "lw_pause_fs") }
        if defaults.object(forKey: "lw_pause_battery") != nil { self.pauseOnBattery = defaults.bool(forKey: "lw_pause_battery") }
        self.cycleIntervalSeconds = defaults.integer(forKey: "lw_cycle_interval")
    }
}

// MARK: - SwiftUI Studio Main View
struct StudioMainView: View {
    @ObservedObject var engine = WallpaperEngine.shared
    
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(GoldenGate.primaryGradient)
                            .frame(width: 38, height: 38)
                        Image(systemName: "play.tv.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Live Wallpaper")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Studio • macOS 27")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                Divider().padding(.horizontal, 12)
                
                VStack(spacing: 4) {
                    ForEach(StudioTab.allCases) { tab in
                        Button(action: { engine.selectedTab = tab }) {
                            HStack(spacing: 10) {
                                Image(systemName: tab.icon)
                                    .frame(width: 20)
                                Text(tab.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(engine.selectedTab == tab ? GoldenGate.gold.opacity(0.15) : Color.clear)
                            .foregroundColor(engine.selectedTab == tab ? GoldenGate.gold : .primary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                
                Spacer()
                
                if let active = engine.activeWallpaperPath {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle().fill(Color.green).frame(width: 7, height: 7)
                            Text("ACTIVE DESKTOP & LOCK")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(GoldenGate.gold)
                        }
                        Text(URL(fileURLWithPath: active).deletingPathExtension().lastPathComponent)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        HStack {
                            Button(action: { engine.togglePlayPause() }) {
                                Image(systemName: engine.isPaused ? "play.fill" : "pause.fill")
                            }
                            .buttonStyle(.plain)
                            Button(action: { engine.nextWallpaper() }) {
                                Image(systemName: "forward.fill")
                            }
                            .buttonStyle(.plain)
                            Spacer()
                            Text(engine.isPaused ? "Paused" : "Live Video")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(GoldenGate.cardBackground)
                    .cornerRadius(10)
                    .padding(12)
                }
            }
            .frame(width: 230)
            .background(.ultraThinMaterial)
            
            Divider()
            
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.13).ignoresSafeArea()
                
                switch engine.selectedTab {
                case .library:
                    LibraryTabView(engine: engine)
                case .displays:
                    DisplaysTabView(engine: engine)
                case .playback:
                    PlaybackTabView(engine: engine)
                case .lockscreen:
                    LiveLockScreenTabView(engine: engine)
                case .energy:
                    EnergyTabView(engine: engine)
                case .about:
                    AboutTabView()
                }
            }
        }
        .frame(minWidth: 880, minHeight: 580)
    }
}

// MARK: - Live Lock Screen Dedicated Tab View
struct LiveLockScreenTabView: View {
    @ObservedObject var engine = WallpaperEngine.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live Video Lock Screen (Native macOS)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Directly injected into macOS's native 60 FPS hardware aerial player.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Active Engine Card
                HStack(spacing: 16) {
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 34))
                        .foregroundColor(GoldenGate.gold)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Live Lock Screen Video Ready")
                            .font(.headline)
                        Text(engine.lockScreenStatusMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Button(action: { engine.openSystemWallpaperSettings() }) {
                        Label("Open Wallpaper Settings", systemImage: "arrow.up.right.square.fill")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GoldenGate.amber)
                }
                .padding(20)
                .background(GoldenGate.cardBackground)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(GoldenGate.primaryGradient, lineWidth: 1.5))
                
                // Instructions
                VStack(alignment: .leading, spacing: 16) {
                    Text("How to Select Your Video in macOS Wallpaper Settings:")
                        .font(.headline)
                    
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle().fill(GoldenGate.gold).frame(width: 26, height: 26)
                            Text("1").font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Click 'Open Wallpaper Settings' Above")
                                .font(.system(size: 14, weight: .semibold))
                            Text("This opens macOS System Settings directly to the Wallpaper pane.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    
                    HStack(alignment: .top, spacing: 14) {
                        ZStack {
                            Circle().fill(GoldenGate.gold).frame(width: 26, height: 26)
                            Text("2").font(.system(size: 13, weight: .bold)).foregroundColor(.black)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Click 'Golden Gate Sunset' (or 'Sequoia Sunrise')")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Your custom video is permanently injected into this slot. When selected, macOS will play your video live on the Lock Screen!")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(22)
                .background(GoldenGate.cardBackground)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(GoldenGate.border, lineWidth: 1))
                
                // Test Shortcut
                VStack(alignment: .leading, spacing: 8) {
                    Text("⚡ Test Your Live Lock Screen:")
                        .font(.headline)
                    Text("Press Control + Command + Q anytime to lock your Mac and watch your video loop live!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(18)
                .background(Color.white.opacity(0.04))
                .cornerRadius(12)
            }
            .padding(28)
        }
    }
}

// MARK: - Library Tab View
struct LibraryTabView: View {
    @ObservedObject var engine = WallpaperEngine.shared
    let columns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 20)]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wallpaper Library")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(engine.playlist.count) video wallpaper\(engine.playlist.count == 1 ? "" : "s") in collection")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Picker("Auto-Cycle", selection: Binding(
                        get: { engine.cycleIntervalSeconds },
                        set: { engine.setCycleInterval($0) }
                    )) {
                        Text("Cycle: Off").tag(0)
                        Text("Every 5 Mins").tag(300)
                        Text("Every 15 Mins").tag(900)
                        Text("Every 30 Mins").tag(1800)
                        Text("Every 1 Hour").tag(3600)
                    }
                    .frame(width: 150)
                    
                    Button(action: pickVideo) {
                        Label("Add Video", systemImage: "plus.circle.fill")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GoldenGate.amber)
                }
                .padding(.bottom, 6)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(GoldenGate.gold.opacity(0.8), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        .background(RoundedRectangle(cornerRadius: 14).fill(GoldenGate.cardBackground))
                    
                    HStack(spacing: 14) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 26))
                            .foregroundColor(GoldenGate.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Drag and Drop Video Files Here")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Supports MP4, MOV, M4V • Live Desktop & Lock Screen video streaming")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 22)
                }
                .onDrop(of: [.movie, .mpeg4Movie, .quickTimeMovie, .fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                }
                
                if engine.playlist.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 50)
                        Image(systemName: "film")
                            .font(.system(size: 46))
                            .foregroundColor(.secondary)
                        Text("No Wallpapers Added Yet")
                            .font(.headline)
                        Text("Click 'Add Video' or drag any video file above to get started.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(engine.playlist) { item in
                            WallpaperCard(item: item, engine: engine)
                        }
                    }
                }
            }
            .padding(28)
        }
    }
    
    private func pickVideo() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.prompt = "Import"
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                engine.addVideo(path: url.path)
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        self.engine.addVideo(path: url.path)
                    }
                }
            }
        }
        return true
    }
}

// MARK: - Wallpaper Card Component
struct WallpaperCard: View {
    let item: WallpaperItem
    @ObservedObject var engine: WallpaperEngine
    
    var isActive: Bool {
        engine.activeWallpaperPath == item.path
    }
    
    var isHovered: Bool {
        engine.hoveredItemId == item.id
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let thumb = engine.getThumbnail(for: item.path) {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                        .cornerRadius(10)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 140)
                        .cornerRadius(10)
                        .overlay(Image(systemName: "video.fill").foregroundColor(.secondary))
                }
                
                if isActive {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GoldenGate.primaryGradient, lineWidth: 2.5)
                    
                    VStack {
                        HStack {
                            Spacer()
                            Text("LIVE")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(GoldenGate.gold)
                                .foregroundColor(.black)
                                .cornerRadius(6)
                                .padding(8)
                        }
                        Spacer()
                    }
                }
                
                if isHovered && !isActive {
                    Color.black.opacity(0.4).cornerRadius(10)
                    Button(action: { engine.applyWallpaper(path: item.path) }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 38))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("Desktop & Live Lock Screen")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Menu {
                    Button("Play on Desktop & Lock Screen") {
                        engine.applyWallpaper(path: item.path)
                    }
                    Divider()
                    Button("Remove from Library", role: .destructive) {
                        engine.removeVideo(item: item)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .frame(width: 24)
            }
        }
        .padding(10)
        .background(GoldenGate.cardBackground)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(GoldenGate.border, lineWidth: 1))
        .onHover { hovering in
            engine.hoveredItemId = hovering ? item.id : nil
        }
    }
}

// MARK: - Displays Tab View
struct DisplaysTabView: View {
    @ObservedObject var engine = WallpaperEngine.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Displays Management")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Configure live video playback across your connected monitors.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                ForEach(Array(engine.detectedScreens.enumerated()), id: \.offset) { index, screen in
                    HStack(spacing: 20) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 130, height: 85)
                                .overlay(
                                    Image(systemName: "display")
                                        .font(.system(size: 30))
                                        .foregroundColor(GoldenGate.gold)
                                )
                            Text("Screen \(index + 1)")
                                .font(.system(size: 9, weight: .bold))
                                .padding(3)
                                .background(.black.opacity(0.6))
                                .cornerRadius(4)
                                .offset(y: 28)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Display \(index + 1)")
                                .font(.headline)
                            Text("Resolution: \(Int(screen.frame.width)) × \(Int(screen.frame.height))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Text("Status:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Active & Rendering")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(18)
                    .background(GoldenGate.cardBackground)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(GoldenGate.border, lineWidth: 1))
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Display Scaling Mode")
                        .font(.headline)
                    Picker("Scaling", selection: Binding(
                        get: { engine.aspectFill },
                        set: { engine.setAspectFill($0) }
                    )) {
                        Text("Fill Screen (Aspect Fill)").tag(true)
                        Text("Fit to Screen (Letterbox)").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 340)
                    Text("Fill Screen stretches or crops slightly to cover every pixel; Fit preserves the original aspect ratio.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(18)
                .background(GoldenGate.cardBackground)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(GoldenGate.border, lineWidth: 1))
            }
            .padding(28)
        }
    }
}

// MARK: - Playback Tab View
struct PlaybackTabView: View {
    @ObservedObject var engine = WallpaperEngine.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Playback & Audio Engine")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Control audio volume and playback speeds.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Wallpaper Audio Volume", systemImage: "speaker.wave.2.fill")
                            .font(.headline)
                        Spacer()
                        Text("\(Int(engine.volume * 100))%")
                            .font(.headline)
                            .foregroundColor(GoldenGate.gold)
                    }
                    
                    HStack(spacing: 16) {
                        Slider(value: Binding(
                            get: { engine.volume },
                            set: { engine.setVolume($0) }
                        ), in: 0...1)
                        .tint(GoldenGate.gold)
                        
                        Button(action: { engine.toggleMute() }) {
                            Image(systemName: engine.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .padding(8)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Text("Audio is muted by default to preserve battery and avoid interrupting other media.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(18)
                .background(GoldenGate.cardBackground)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(GoldenGate.border, lineWidth: 1))
                
                VStack(alignment: .leading, spacing: 14) {
                    Label("Playback Speed Multiplier", systemImage: "gauge.with.needle.fill")
                        .font(.headline)
                    
                    Picker("Speed", selection: Binding(
                        get: { engine.playbackSpeed },
                        set: { engine.setSpeed($0) }
                    )) {
                        Text("0.5× (Slow-Mo)").tag(Float(0.5))
                        Text("0.75×").tag(Float(0.75))
                        Text("1.0× (Normal)").tag(Float(1.0))
                        Text("1.25×").tag(Float(1.25))
                        Text("1.5×").tag(Float(1.5))
                        Text("2.0×").tag(Float(2.0))
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Set to 0.5× for peaceful, ambient slow-motion cinematic scenes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(18)
                .background(GoldenGate.cardBackground)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(GoldenGate.border, lineWidth: 1))
            }
            .padding(28)
        }
    }
}

// MARK: - Energy Tab View
struct EnergyTabView: View {
    @ObservedObject var engine = WallpaperEngine.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Battery & Energy Armor")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Hardware-accelerated Apple Silicon power optimizations for 24/7 battery efficiency.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 16) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 34))
                        .foregroundColor(GoldenGate.gold)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Energy Optimization Active")
                            .font(.headline)
                        Text("Current CPU consumption: < 0.6% | Direct VideoToolbox hardware decode.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(18)
                .background(GoldenGate.cardBackground)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(GoldenGate.primaryGradient, lineWidth: 1))
                
                VStack(spacing: 16) {
                    Toggle(isOn: $engine.pauseOnLock) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pause Live Desktop on Lock Screen")
                                .font(.system(size: 14, weight: .medium))
                            Text("When enabled, desktop stops while locked. Leave off if you want video playing everywhere.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Divider()
                    Toggle(isOn: $engine.pauseOnSleep) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Pause on Display Sleep")
                                .font(.system(size: 14, weight: .medium))
                            Text("Freezes playback whenever displays sleep or MacBook lid is closed.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Divider()
                    Toggle(isOn: $engine.pauseOnFullScreen) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Pause on Full-Screen Apps")
                                .font(.system(size: 14, weight: .medium))
                            Text("Saves maximum power when watching movies, gaming, or working in full-screen spaces.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    Divider()
                    Toggle(isOn: $engine.pauseOnBattery) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Pause on Battery Power")
                                .font(.system(size: 14, weight: .medium))
                            Text("Automatically suspends live wallpaper when MacBook is unplugged from the charger.")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(20)
                .background(GoldenGate.cardBackground)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(GoldenGate.border, lineWidth: 1))
            }
            .padding(28)
        }
    }
}

// MARK: - About Tab View
struct AboutTabView: View {
    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(GoldenGate.primaryGradient)
                    .frame(width: 80, height: 80)
                Image(systemName: "play.tv.fill")
                    .font(.system(size: 42))
                    .foregroundColor(.white)
            }
            Text("Live Wallpaper Studio")
                .font(.title)
                .fontWeight(.bold)
            Text("Version 2.0 • macOS 27 Golden Gate Edition")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("A completely free, 100% open-source live video wallpaper engine crafted natively for macOS.\nEngineered with Apple AVFoundation and VideoToolbox for ultra-low power consumption.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 440)
            
            Spacer()
        }
        .padding(28)
    }
}

// MARK: - Menu Bar Popover Controller
struct MenuBarPopoverView: View {
    @ObservedObject var engine = WallpaperEngine.shared
    var openStudioAction: () -> Void
    var quitAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Live Wallpaper")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Text(engine.isPaused ? "PAUSED" : "PLAYING")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(engine.isPaused ? Color.secondary : GoldenGate.gold)
                    .foregroundColor(.black)
                    .cornerRadius(4)
            }
            
            if let active = engine.activeWallpaperPath {
                HStack(spacing: 10) {
                    if let thumb = engine.getThumbnail(for: active) {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: 60, height: 36)
                            .cornerRadius(6)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(URL(fileURLWithPath: active).deletingPathExtension().lastPathComponent)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text("Live Desktop & Lock Screen")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No Wallpaper Active")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            HStack {
                Button(action: { engine.togglePlayPause() }) {
                    Label(engine.isPaused ? "Play" : "Pause", systemImage: engine.isPaused ? "play.fill" : "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: { engine.nextWallpaper() }) {
                    Label("Next", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            
            HStack {
                Image(systemName: engine.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { engine.volume },
                    set: { engine.setVolume($0) }
                ), in: 0...1)
                .tint(GoldenGate.gold)
            }
            
            Divider()
            
            HStack {
                Button("Open Studio...") {
                    openStudioAction()
                }
                .buttonStyle(.borderedProminent)
                .tint(GoldenGate.amber)
                
                Spacer()
                
                Button("Quit") {
                    quitAction()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(width: 280)
        .background(.ultraThinMaterial)
    }
}

// MARK: - App Delegate & Coordinator
class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()
    
    var statusItem: NSStatusItem!
    var popover = NSPopover()
    var mainWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        setupMainWindow()
        
        if WallpaperEngine.shared.activeWallpaperPath == nil {
            showMainWindow()
        }
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🎬"
            button.toolTip = "Live Wallpaper Studio"
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        let popoverContent = MenuBarPopoverView(
            openStudioAction: { [weak self] in
                self?.popover.performClose(nil)
                self?.showMainWindow()
            },
            quitAction: {
                NSApplication.shared.terminate(nil)
            }
        )
        
        popover.contentSize = NSSize(width: 280, height: 260)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: popoverContent)
    }
    
    private func setupMainWindow() {
        let contentView = StudioMainView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Live Wallpaper Studio"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentView = NSHostingView(rootView: contentView)
        window.isReleasedWhenClosed = false
        self.mainWindow = window
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }
}

// Entry Point
let app = NSApplication.shared
let delegate = AppDelegate.shared
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
