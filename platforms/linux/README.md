# Linux Live Wallpaper Engine Architecture

Linux desktop environments are split between **X11** and **Wayland**.

---

## 1. Wayland (GNOME 40+, KDE Plasma 6, Hyprland, Sway)
On modern Wayland compositors, desktop overlays are controlled via the **`wlr-layer-shell-unstable-v1`** protocol on the `ZWLR_LAYER_SHELL_V1_LAYER_BACKGROUND` layer.

### Recommended Open-Source Engines:
* **`swww`** (Rust): Smooth Wayland animated wallpaper daemon.
  ```bash
  swww-daemon &
  swww img /path/to/animation.gif
  ```
* **`mpvpaper`**: Plays video directly onto Wayland layer-shell outputs.
  ```bash
  mpvpaper -o "no-audio loop" '*' /path/to/video.mp4
  ```

---

## 2. X11 (Xorg)
On X11, live video wallpaper runs by embedding an `mpv` player into the root desktop window (`--wid`) using **`xwinwrap`**:

```bash
xwinwrap -fs -fdt -ni -b -nf -un -argb -- \
  mpv -wid WID --loop --no-audio --vo=gpu --hwdec=auto /path/to/video.mp4
```

* **Hardware Decoding**: Utilizes `VA-API` or `VDPAU` on Intel, AMD, and NVIDIA GPUs for minimal power usage.
