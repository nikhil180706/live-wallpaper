# Windows Live Wallpaper Engine Architecture

On Windows 10 and 11, live video desktop wallpapers are achieved using the **`WorkerW` Reparenting Technique** (the industry-standard method used by Wallpaper Engine and Lively Wallpaper).

---

## 🛠️ How It Works

1. **Find Program Manager (`Progman`)**:
   Query the desktop window using `FindWindow("Progman", null)`.
2. **Spawn `WorkerW` Layer**:
   Send the undocumented message `0x052C` to `Progman`:
   ```c
   SendMessageTimeout(progman, 0x052C, 0, 0, SMTO_NORMAL, 1000, &result);
   ```
   Windows creates a `WorkerW` window directly between the desktop background and the desktop icons.
3. **Reparent the Player Window**:
   Enum windows to locate the `WorkerW` that sits behind the icons, then call:
   ```c
   SetParent(videoPlayerHwnd, workerwHwnd);
   ```
4. **Hardware Decoding**:
   Use **Windows Media Foundation (WMF)** or **DirectShow / mpv** with DirectX 11/12 hardware acceleration for 0% CPU consumption.

---

## 🚀 Recommended Implementation
* **Language**: C# with WPF/.NET 8 or C++ with Win32 API.
* **Lock Screen**: Windows 10/11 Lock Screen allows slideshow folders via `Windows.System.UserProfile.LockScreen`.
