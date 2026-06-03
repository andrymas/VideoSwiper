import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'ui/theme/app_colors.dart';

class VideoCollectorWindow extends StatefulWidget {
  const VideoCollectorWindow({super.key});

  @override
  State<VideoCollectorWindow> createState() => _VideoCollectorWindowState();
}

class _VideoCollectorWindowState extends State<VideoCollectorWindow> {
  String? sourceDirPath;
  String? targetDirPath;
  bool copyFiles = false;
  late int _finishedTasks;
  late int _totalTasks;
  bool _isMoving = false;

  final List<String> allowedExtensions = [
    '.mp4', '.avi', '.mov', '.mkv', '.m4v', '.webm', '.flv', '.wmv',
    '.3gp', '.3g2', '.mpeg', '.mpg', '.ts', '.jpg', '.jpeg', '.png',
    '.webp', '.gif', '.bmp', '.wbmp',
  ];

  Future<void> pickSourceFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      if (mounted) setState(() => sourceDirPath = selectedDirectory);
    }
  }

  Future<void> pickTargetFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      if (mounted) setState(() => targetDirPath = selectedDirectory);
    }
  }

  Future<void> startCollection() async {
    if (sourceDirPath == null || targetDirPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both source and destination folders.', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final sourceDir = Directory(sourceDirPath!);
    final targetDir = Directory(targetDirPath!);

    setState(() {
      _isMoving = true;
      _finishedTasks = 0;
      _totalTasks = 0;
    });

    try {
      final videos = await collectVideosRecursively(sourceDir);
      await moveVideos(videos, targetDir, copyFiles);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gathered $_finishedTasks files successfully!', style: const TextStyle(color: Colors.white)),
            backgroundColor: const Color(0xFF3ECF8E),
          ),
        );
      }
    } catch (e) {
      debugPrint('Errore durante la raccolta o spostamento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMoving = false);
      }
    }
  }

  Future<List<File>> collectVideosRecursively(Directory rootDir) async {
    List<File> videos = [];
    await for (var entity in rootDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final ext = p.extension(entity.path).toLowerCase();
        if (allowedExtensions.contains(ext)) {
          videos.add(entity);
        }
      }
    }
    if (mounted) {
      setState(() {
        _totalTasks = videos.length;
        _finishedTasks = 0;
      });
    }
    return videos;
  }

  Future<void> moveVideos(List<File> videos, Directory targetDir, bool copy) async {
    for (final video in videos) {
      final newPath = p.join(targetDir.path, p.basename(video.path));
      if (copy) {
        await video.copy(newPath);
      } else {
        await video.rename(newPath);
      }
      if (mounted) {
        setState(() => _finishedTasks += 1);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Media Gatherer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.active,
          surface: AppColors.panelBackground,
        ),
      ),
      home: Scaffold(
        body: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
              decoration: const BoxDecoration(
                color: AppColors.panelBackground,
                border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.archive_rounded, color: AppColors.textPrimary, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Media Gatherer',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Collect and centralize all your scattered media files into a single destination.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────
            Expanded(
              child: _isMoving ? _buildProgressView() : _buildConfigurationView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFolderCard(
                title: 'Source Directory',
                subtitle: 'Where are the media files currently located?',
                icon: Icons.folder_open_rounded,
                path: sourceDirPath,
                onTap: pickSourceFolder,
              ),
              const SizedBox(height: 16),
              _buildFolderCard(
                title: 'Destination Directory',
                subtitle: 'Where should they be moved to?',
                icon: Icons.drive_file_move_outline,
                path: targetDirPath,
                onTap: pickTargetFolder,
              ),
              const SizedBox(height: 32),
              
              // ── Settings ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.panelBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.copy_all_rounded, color: AppColors.textSecondary, size: 24),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Operation Mode', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(
                            copyFiles ? 'Copying files (keeps originals)' : 'Moving files (faster, removes originals)',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: copyFiles,
                      activeThumbColor: AppColors.active,
                      activeTrackColor: AppColors.active.withValues(alpha: 0.3),
                      inactiveThumbColor: AppColors.textSecondary,
                      inactiveTrackColor: Colors.black26,
                      onChanged: (val) => setState(() => copyFiles = val),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // ── Start Button ──
              GestureDetector(
                onTap: startCollection,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Start Gathering',
                        style: TextStyle(
                          color: AppColors.background,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String? path,
    required VoidCallback onTap,
  }) {
    final hasPath = path != null;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: hasPath ? AppColors.active.withValues(alpha: 0.05) : AppColors.panelBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasPath ? AppColors.active.withValues(alpha: 0.3) : AppColors.border,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasPath ? AppColors.active.withValues(alpha: 0.1) : Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: hasPath ? AppColors.active : AppColors.textSecondary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(
                      hasPath ? path : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasPath ? AppColors.textPrimary : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressView() {
    final progress = _totalTasks > 0 ? _finishedTasks / _totalTasks : 0.0;
    
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.active),
            const SizedBox(height: 32),
            Text(
              'Processing files...',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '$_finishedTasks of $_totalTasks completed',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.active),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
