# iOS Motion Wallpaper Architecture

On iOS, third-party apps are prohibited from running persistent background video decoding engines on the Home Screen due to Apple's strict background task limits and power management policies.

---

## 🛠️ The Official iOS Solution: Live Photo Motion Wallpapers

iOS supports moving wallpapers on the **Lock Screen** using **Live Photos**.

A Live Photo consists of two paired files sharing an identical Asset Identifier UUID:
1. **Still Image**: A `.heic` or `.jpg` photo.
2. **Video Clip**: A paired `.mov` file containing the QuickTime metadata tag:
   `com.apple.quicktime.still-image-time`.

### Implementation Pipeline:
1. Take user's MP4/MOV video clip (up to 3 seconds).
2. Generate the paired Asset UUID (`UUID().uuidString`).
3. Write metadata tag into the QuickTime track:
   ```swift
   let metadataItem = AVMutableMetadataItem()
   metadataItem.key = "com.apple.quicktime.still-image-time" as NSString
   metadataItem.keySpace = .quickTimeMetadata
   metadataItem.value = 0 as NSNumber
   ```
4. Save to user's Photo Library using `PHPhotoLibrary.shared().performChanges`:
   ```swift
   let creationRequest = PHAssetCreationRequest.forAsset()
   creationRequest.addResource(with: .photo, fileURL: imageURL, options: nil)
   creationRequest.addResource(with: .pairedVideo, fileURL: videoURL, options: nil)
   ```
5. User can select this Live Photo in iOS **Settings ➔ Wallpaper** and tap **"Live Photo"** to enable motion when pressing or waking the lock screen!
