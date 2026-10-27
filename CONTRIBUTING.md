# Contributing to Live Wallpaper Studio

Thank you for your interest in contributing to Live Wallpaper Studio! We welcome contributions across all platforms: macOS, Windows, Linux, Android, and iOS.

---

## 🛠️ Development Setup

### macOS
1. Requires macOS 12+ and Command Line Tools / Xcode.
2. Build native app & screen saver:
   ```bash
   bash build_native.sh
   ```
3. Run the app:
   ```bash
   open LiveWallpaper.app
   ```

### Flutter (Cross-Platform GUI)
1. Install Flutter SDK (`flutter doctor`).
2. Run on your platform:
   ```bash
   flutter pub get
   flutter run
   ```

---

## 📋 Pull Request Guidelines

1. Fork the repo and create a feature branch (`git checkout -b feature/awesome-feature`).
2. Ensure code compiles cleanly without compiler warnings.
3. Keep battery and memory optimization as a top priority.
4. Submit a clear Pull Request describing your changes.

---

## 📜 License
By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
