import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/media_controller.dart';
import '../layouts/main_layout.dart';
import '../widgets/settings_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/view_mode.dart';

/// The primary screen of the application.
/// It bridges the [MediaController] logic with the visual layout ([MainLayout]).
/// It listens for window events (like close requests) and state changes,
/// ensuring the UI always reflects the underlying data model.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WindowListener {
  /// The global state controller for media and settings.
  final MediaController _mediaController = MediaController();
  
  /// The currently active view mode (e.g., swiper or library).
  ViewMode _currentView = ViewMode.swiper;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _mediaController.dispose();
    super.dispose();
  }

  // ── Window close guard ─────────────────────────────────────────────────────
  
  /// Intercepts the window close event.
  /// If collages are still being generated in the background, it prompts
  /// the user for confirmation to prevent accidental data loss.
  @override
  Future<void> onWindowClose() async {
    if (_mediaController.isGeneratingCollage) {
      final shouldClose = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.panelBackground,
          title: const Text(
            'Close VideoSwiper?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: const Text(
            "The app is still generating collages. Are you sure you want to quit?",
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              child: const Text('No', style: TextStyle(color: AppColors.textPrimary)),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Yes', style: TextStyle(color: Colors.redAccent)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      if (shouldClose == true) await windowManager.destroy();
    } else {
      await windowManager.destroy();
    }
  }

  // ── Version dialog ─────────────────────────────────────────────────────────
  Future<String?> _fetchLatestVersion() async {
    try {
      final url = Uri.parse('https://api.github.com/repos/andrymas/VideoSwiper/releases/latest');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['tag_name'] as String?;
      }
    } catch (e) {
      debugPrint('Failed to fetch latest version: $e');
    }
    return null;
  }

  /// Displays a modal dialog comparing the local app version with the latest
  /// release fetched from GitHub. Provides a download link if outdated.
  Future<void> _showVersionDialog() async {
    final info = await PackageInfo.fromPlatform();
    final latestVersion = await _fetchLatestVersion();
    final latestText = latestVersion ?? 'Failed to fetch';
    final isLatest = 'v${info.version}' == latestText;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.panelBackground,
        title: const Text('Version Info', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Latest:   $latestText', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
            const SizedBox(height: 8),
            Text('Current:  v${info.version}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(isLatest ? Icons.check_circle : Icons.error_outline,
                    color: isLatest ? Colors.greenAccent : Colors.redAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  isLatest ? 'You are up to date.' : 'A new version is available.',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Close', style: TextStyle(color: AppColors.textPrimary)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          if (!isLatest)
            TextButton(
              child: const Text('Download', style: TextStyle(color: Colors.blueAccent)),
              onPressed: () => launchUrl(Uri.parse('https://github.com/andrymas/VideoSwiper/releases')),
            ),
        ],
      ),
    );
  }

  // ── Settings dialog ────────────────────────────────────────────────────────
  void _openSettings() {
    showDialog(
      context: context,
      builder: (_) => SettingsDialog(controller: _mediaController),
    );
  }

  // ── Media Gatherer window ──────────────────────────────────────────────────
  /// Opens a separate native window for the Media Gatherer utility.
  Future<void> _openMediaGatherer() async {
    final window = await DesktopMultiWindow.createWindow(
      jsonEncode({'type': 'Sub window'}),
    );
    window
      ..setTitle('Media Gatherer')
      ..show();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: _mediaController,
        builder: (context, _) {
          return MainLayout(
            mediaFiles: _mediaController.foundTotalFiles,
            keptPaths: _mediaController.keptPaths,
            currentView: _currentView,
            onPickFolder: () => _mediaController.pickFolderAndLoadVideos(context),
            onSettingsPressed: _openSettings,
            onShowVersionInfo: _showVersionDialog,
            onMediaGathererPressed: _openMediaGatherer,
            onViewChanged: (mode) => setState(() => _currentView = mode),
            onDelete: (media) => _mediaController.deleteVideo(media),
            onKeep: (media) => _mediaController.keepVideo(media),
            isSidebarVisible: _mediaController.isSidebarVisible,
            onToggleSidebar: _mediaController.toggleSidebar,
          );
        },
      ),
    );
  }
}
