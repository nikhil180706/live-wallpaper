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
        setupPlayer()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.wantsLayer = true
        self.animationTimeInterval = 1.0 / 60.0
        setupPlayer()
    }

    private func setupPlayer() {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let dir = pictures.appendingPathComponent("LiveWallpaper")
        let videoFile = dir.appendingPathComponent("current_video.mp4")
        
        let path: String
        if FileManager.default.fileExists(atPath: videoFile.path) {
            path = videoFile.path
        } else if let saved = UserDefaults.standard.string(forKey: "lw_active_path"),
                  FileManager.default.fileExists(atPath: saved) {
            path = saved
        } else {
            return
        }

        let url = URL(fileURLWithPath: path)
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let player = AVQueuePlayer(playerItem: item)
        player.isMuted = true

        self.playerLooper = AVPlayerLooper(player: player, templateItem: item)
        self.queuePlayer = player

        let layer = AVPlayerLayer(player: player)
        layer.frame = bounds
        layer.videoGravity = .resizeAspectFill
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        self.layer?.addSublayer(layer)
        self.playerLayer = layer

        player.play()
    }

    public override func startAnimation() {
        super.startAnimation()
        queuePlayer?.play()
    }

    public override func stopAnimation() {
        super.stopAnimation()
        queuePlayer?.pause()
    }
}
