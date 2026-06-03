import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:system_info/system_info.dart';

import '../../customTypes.dart';
import '../src/rust/api/collage_generation.dart';

/// A centralized state controller that manages application settings, media files,
/// and backend processing tasks (e.g., Rust collage generation).
/// It uses [ChangeNotifier] to update the UI reactively without tight coupling.
class MediaController extends ChangeNotifier {
  // --- Settings ---
  int framesNumber = 40;
  int threadsUsed = (Platform.numberOfProcessors / 2).round().toInt();
  int qualitySetting = 2;
  Set<QualityLevel> selectedQuality = {QualityLevel.medium};

  bool showPlayer = false;
  bool beginPaused = false;
  bool beginMuted = true;

  // --- UI State ---
  bool isSidebarVisible = true;

  // --- State ---
  List<MediaClass> foundTotalFiles = [];
  
  /// Paths of media files marked to be kept.
  Set<String> keptPaths = {};
  
  /// The currently loaded directory path.
  String selectedFolder = "Select a folder";
  
  /// Directory used as a local trash bin for deleted media.
  late Directory trashLocation;

  int generatedThumbnails = 0;
  int totalJobs = 0;
  bool isGeneratingCollage = false;

  final videoExtensions = [
    '.mp4', '.avi', '.mov', '.mkv', '.m4v', '.webm', '.flv', '.wmv', '.3gp', '.3g2', '.mpeg', '.mpg', '.ts'
  ];

  final photoExtensions = [
    '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.wbmp'
  ];

  void setFramesNumber(int value) {
    framesNumber = value;
    notifyListeners();
  }

  void setThreadsUsed(int value) {
    threadsUsed = value;
    notifyListeners();
  }

  void setQuality(QualityLevel quality) {
    selectedQuality = {quality};
    qualitySetting = QualityLevel.values.indexOf(quality);
    notifyListeners();
  }

  void toggleSidebar() {
    isSidebarVisible = !isSidebarVisible;
    notifyListeners();
  }

  /// Prompts the user to pick a folder, scans for supported media files,
  /// and initiates collage generation for videos missing thumbnails.
  Future<void> pickFolderAndLoadVideos(BuildContext context) async {
    String? folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null) return;

    trashLocation = await Directory('$folderPath/trash').create(recursive: false);

    final allFiles = Directory(folderPath).listSync().whereType<File>().toList();

    final foundVideoFiles = allFiles
        .where((f) => videoExtensions.contains(p.extension(f.path).toLowerCase()))
        .map((f) => MediaClass(fileReference: f, isVideo: true))
        .toList()
      ..sort((a, b) => a.fileReference.path.compareTo(b.fileReference.path));

    final foundPhotoFiles = allFiles
        .where((f) => photoExtensions.contains(p.extension(f.path).toLowerCase()))
        .where((f) => !p.basename(f.path).contains('_collage'))
        .map((f) => MediaClass(fileReference: f, isVideo: false))
        .toList()
      ..sort((a, b) => a.fileReference.path.compareTo(b.fileReference.path));

    final totalFiles = [...foundVideoFiles, ...foundPhotoFiles];
    totalFiles.sort((a, b) => a.path.compareTo(b.path));

    selectedFolder = folderPath;
    foundTotalFiles = totalFiles;
    generatedThumbnails = 0;
    totalJobs = totalFiles.length;
    notifyListeners();

    final jobs = Queue<MediaClass>();
    for (var file in foundTotalFiles) {
      if (!await _collageAlreadyExists(file)) {
        jobs.add(file);
      } else {
        generatedThumbnails++;
      }
    }
    notifyListeners();

    if (jobs.isNotEmpty) {
      await _showProcessingDialogAndProcess(context, jobs);
    }
  }

  /// Displays a blocking overlay dialogue while Rust processes media files.
  /// It monitors system RAM usage to provide real-time feedback.
  Future<void> _showProcessingDialogAndProcess(BuildContext context, Queue<MediaClass> jobs) async {
    isGeneratingCollage = true;
    notifyListeners();
    late StateSetter setStateDialog;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(color: Colors.black.withOpacity(0)),
          ),
          Center(
            child: StatefulBuilder(
              builder: (context, dialogSetState) {
                setStateDialog = dialogSetState;
                final totalGB = SysInfo.getTotalPhysicalMemory() / 1073741824;
                final freeGB = SysInfo.getFreePhysicalMemory() / 1073741824;
                final usedGB = totalGB - freeGB;
                final ramRatio = usedGB / totalGB;

                Color getRamColor(double ratio) {
                  if (ratio < 0.5) return Colors.green;
                  if (ratio < 0.8) return Colors.orange;
                  return Colors.red;
                }

                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(selectedFolder, style: const TextStyle(color: Colors.white, decoration: TextDecoration.none)),
                      const SizedBox(height: 20),
                      Text(
                        "Elaborated $generatedThumbnails /$totalJobs videos",
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: totalJobs > 0 ? generatedThumbnails / totalJobs : 0.0,
                          backgroundColor: Colors.grey[800],
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text("RAM Usage", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 400,
                        child: Row(
                          children: [
                            Text("${usedGB.toStringAsFixed(1)} GB", style: const TextStyle(color: Colors.white, decoration: TextDecoration.none)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: ramRatio,
                                  minHeight: 12,
                                  backgroundColor: Colors.grey[700],
                                  valueColor: AlwaysStoppedAnimation<Color>(getRamColor(ramRatio)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text("${totalGB.toStringAsFixed(1)} GB", style: const TextStyle(color: Colors.white, decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    final stopwatch = Stopwatch()..start();
    try {
      final collageStream = generateCollage(
        paths: jobs.map((p) => p.fileReference.path).toList(),
        numFrames: framesNumber,
        quality: qualitySetting,
        threadsNum: threadsUsed,
      );

      await for (final _ in collageStream) {
        generatedThumbnails++;
        setStateDialog(() {});
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Errore Rust: $e");
    } finally {
      stopwatch.stop();
      isGeneratingCollage = false;
      notifyListeners();
      Navigator.of(context).pop();
    }
  }

  /// Resolves the expected collage thumbnail path for a given media file.
  String getCollagePath(MediaClass videoFile) {
    if (videoFile.isVideo) {
      final base = p.basenameWithoutExtension(videoFile.path);
      final outputDir = p.dirname(videoFile.path);
      return p.join(outputDir, '${base}_collage.jpg');
    }
    return videoFile.path;
  }

  Future<bool> _collageAlreadyExists(MediaClass videoFile) async {
    final collageFile = File(getCollagePath(videoFile));
    if (await collageFile.exists()) {
      return await collageFile.length() > 0;
    }
    return false;
  }

  /// Moves a media file (and its associated collage) to the local trash folder.
  void deleteVideo(MediaClass media) {
    final fileToDelete = media.fileReference;
    final trashPath = p.join(trashLocation.path, p.basename(fileToDelete.path));

    try {
      fileToDelete.renameSync(trashPath);
      if (media.isVideo) {
        final collageFile = File(getCollagePath(media));
        if (collageFile.existsSync()) {
          final collageTrashPath = p.join(trashLocation.path, p.basename(collageFile.path));
          collageFile.renameSync(collageTrashPath);
        }
      }
    } catch (e) {
      debugPrint('Errore spostamento file: $e');
    }

    foundTotalFiles.remove(media);
    notifyListeners();
  }

  /// Toggles the 'keep' status of a media file.
  /// Kept files remain in the grid but display a visual badge.
  void keepVideo(MediaClass media) {
    if (keptPaths.contains(media.path)) {
      keptPaths.remove(media.path);
    } else {
      keptPaths.add(media.path);
    }
    notifyListeners();
  }
}
