import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LiveWallpaperApp());
}

class LiveWallpaperApp extends StatelessWidget {
  const LiveWallpaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Wallpaper Engine',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E24),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF007AFF),
          surface: Color(0xFF2B2B36),
        ),
      ),
      home: const WallpaperSettingsScreen(),
    );
  }
}

class WallpaperSettingsScreen extends StatefulWidget {
  const WallpaperSettingsScreen({super.key});

  @override
  State<WallpaperSettingsScreen> createState() => _WallpaperSettingsScreenState();
}

class _WallpaperSettingsScreenState extends State<WallpaperSettingsScreen> {
  static const _platform = MethodChannel('com.livewallpaper.app/engine');

  String? _selectedVideoPath;
  bool _isMuted = true;
  bool _isPlaying = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString('saved_video_path');
      final savedMuted = prefs.getBool('saved_is_muted') ?? true;

      if (savedPath != null && File(savedPath).existsSync()) {
        setState(() {
          _selectedVideoPath = savedPath;
          _isMuted = savedMuted;
        });
        await _applyWallpaper(savedPath, savedMuted);
      }
    } catch (e) {
      debugPrint("Error loading preferences: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickVideoFile() async {
    const typeGroup = XTypeGroup(
      label: 'Videos',
      extensions: <String>['mp4', 'mov', 'm4v'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

    if (file != null) {
      setState(() {
        _selectedVideoPath = file.path;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_video_path', file.path);
      await _applyWallpaper(file.path, _isMuted);
    }
  }

  Future<void> _applyWallpaper(String path, bool muted) async {
    try {
      await _platform.invokeMethod('setWallpaper', {
        'path': path,
        'muted': muted,
      });
      setState(() => _isPlaying = true);
    } on PlatformException catch (e) {
      debugPrint("Error applying wallpaper: ${e.message}");
    }
  }

  Future<void> _toggleMute(bool value) async {
    setState(() => _isMuted = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('saved_is_muted', value);
    await _platform.invokeMethod('setMuted', {'muted': value});
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _platform.invokeMethod('pauseWallpaper');
      setState(() => _isPlaying = false);
    } else {
      await _platform.invokeMethod('resumeWallpaper');
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _removeWallpaper() async {
    await _platform.invokeMethod('removeWallpaper');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_video_path');
    setState(() {
      _selectedVideoPath = null;
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Desktop Live Wallpaper",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              "Hardware-accelerated Apple Silicon video playback with auto-pause power optimization.",
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.video_file_rounded, size: 40, color: Color(0xFF007AFF)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedVideoPath != null
                              ? _selectedVideoPath!.split('/').last
                              : "No video selected",
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedVideoPath ?? "Choose an MP4 or MOV file",
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _pickVideoFile,
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text("Choose Video"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Mute Audio (Recommended)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: const Text(
                  "Keeps audio off to save maximum battery and prevent unwanted sound.",
                  style: TextStyle(fontSize: 12),
                ),
                value: _isMuted,
                onChanged: _selectedVideoPath != null ? _toggleMute : null,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.blue, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Ultra-low power active: Video automatically pauses when screen is locked or sleeping (0.0% CPU usage).",
                      style: TextStyle(color: Colors.grey.shade300, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                if (_selectedVideoPath != null) ...[
                  OutlinedButton.icon(
                    onPressed: _togglePlayPause,
                    icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                    label: Text(_isPlaying ? "Pause" : "Resume"),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _removeWallpaper,
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    label: const Text("Reset", style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
                const Spacer(),
                Text(
                  "Closing window leaves wallpaper running",
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
