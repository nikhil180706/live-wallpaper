# Android Live Wallpaper Architecture

Android natively provides first-class support for live wallpapers via the **`WallpaperService`** API, allowing seamless live looping video on **both the Home Screen AND the Lock Screen**.

---

## 🛠️ How It Works

1. **Manifest Service Declaration**:
   ```xml
   <service
       android:name=".VideoLiveWallpaperService"
       android:label="@string/app_name"
       android:permission="android.permission.BIND_WALLPAPER"
       android:exported="true">
       <intent-filter>
           <action android:name="android.service.wallpaper.WallpaperService" />
       </intent-filter>
       <meta-data
           android:name="android.service.wallpaper"
           android:resource="@xml/wallpaper" />
   </service>
   ```

2. **Kotlin `WallpaperService` Implementation**:
   Uses `androidx.media3.exoplayer` (or `MediaPlayer`) attached to `surfaceHolder`:
   ```kotlin
   class VideoLiveWallpaperService : WallpaperService() {
       override fun onCreateEngine(): Engine = VideoEngine()

       inner class VideoEngine : Engine() {
           private var player: ExoPlayer? = null

           override fun onSurfaceCreated(holder: SurfaceHolder) {
               super.onSurfaceCreated(holder)
               player = ExoPlayer.Builder(applicationContext).build().apply {
                   setVideoSurfaceHolder(holder)
                   repeatMode = Player.REPEAT_MODE_ALL
                   volume = 0f // Muted for battery efficiency
                   setMediaItem(MediaItem.fromUri(videoUri))
                   prepare()
                   play()
               }
           }

           override fun onVisibilityChanged(visible: Bool) {
               if (visible) player?.play() else player?.pause()
           }

           override fun onDestroy() {
               player?.release()
               super.onDestroy()
           }
       }
   }
   ```

3. **Setting Home Screen & Lock Screen**:
   Trigger the system wallpaper picker:
   ```kotlin
   val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
       putExtra(
           WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
           ComponentName(context, VideoLiveWallpaperService::class.java)
       )
   }
   startActivity(intent)
   ```
   Users can tap **"Set for Home Screen and Lock Screen"** to apply it instantly to both!
