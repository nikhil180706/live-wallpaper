import ScreenSaver
import AVFoundation

@objc(LiveWallpaperSaverView)
public class LiveWallpaperSaverView: ScreenSaverView {
    private var queuePlayer: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?

    public override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        self.wantsLayer = true
        self.animationTimeInterval = 1.0 / 60.0
        NSLog("🎬 [LiveWallpaperSaver] init(frame:isPreview: %d)", isPreview ? 1 : 0)
        setupPlayer()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
        self.animationTimeInterval = 1.0 / 60.0
        NSLog("🎬 [LiveWallpaperSaver] init(coder:)")
        setupPlayer()
    }

    private func findVideoPath() -> String? {
        let fm = FileManager.default
        
        // 1. Check bundle resources first (always accessible inside sandbox)
        if let bundleUrl = Bundle(for: LiveWallpaperSaverView.self).url(forResource: "current_video", withExtension: "mp4"),
           fm.fileExists(atPath: bundleUrl.path) {
            NSLog("🎬 [LiveWallpaperSaver] Found video in bundle resources: %@", bundleUrl.path)
            return bundleUrl.path
        }
        
        // 2. Check Pictures/LiveWallpaper/current_video.mp4
        if let pictures = fm.urls(for: .picturesDirectory, in: .userDomainMask).first {
            let picVideo = pictures.appendingPathComponent("LiveWallpaper/current_video.mp4")
            if fm.fileExists(atPath: picVideo.path) {
                NSLog("🎬 [LiveWallpaperSaver] Found video in Pictures: %@", picVideo.path)
                return picVideo.path
            }
        }
        
        // 3. Check Movies/LiveWallpaper/current_video.mp4
        if let movies = fm.urls(for: .moviesDirectory, in: .userDomainMask).first {
            let movVideo = movies.appendingPathComponent("LiveWallpaper/current_video.mp4")
            if fm.fileExists(atPath: movVideo.path) {
                NSLog("🎬 [LiveWallpaperSaver] Found video in Movies: %@", movVideo.path)
                return movVideo.path
            }
        }
        
        // 4. Check UserDefaults saved path
        if let saved = UserDefaults.standard.string(forKey: "lw_active_path"),
           fm.fileExists(atPath: saved) {
            NSLog("🎬 [LiveWallpaperSaver] Found video from UserDefaults: %@", saved)
            return saved
        }
        
        NSLog("❌ [LiveWallpaperSaver] No video found in any standard path")
        return nil
    }

    private func setupPlayer() {
        guard let path = findVideoPath() else { return }
        
        let url = URL(fileURLWithPath: path)
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let player = AVQueuePlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .none

        self.playerLooper = AVPlayerLooper(player: player, templateItem: item)
        self.queuePlayer = player

        let layer = AVPlayerLayer(player: player)
        layer.frame = bounds
        layer.videoGravity = .resizeAspectFill
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        self.layer?.addSublayer(layer)
        self.playerLayer = layer

        player.play()
        NSLog("🎬 [LiveWallpaperSaver] AVQueuePlayer successfully started 60 FPS playback for: %@", url.lastPathComponent)
    }

    public override func startAnimation() {
        super.startAnimation()
        NSLog("🎬 [LiveWallpaperSaver] startAnimation()")
        queuePlayer?.play()
    }

    public override func stopAnimation() {
        super.stopAnimation()
        NSLog("🎬 [LiveWallpaperSaver] stopAnimation()")
        queuePlayer?.pause()
    }
}
