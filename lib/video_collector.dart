import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';

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

  Future<void> pickSourceFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        sourceDirPath = selectedDirectory;
      });
    }
  }

  Future<void> pickTargetFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        targetDirPath = selectedDirectory;
      });
    }
  }

  Future<void> startCollection() async {
    if (sourceDirPath == null || targetDirPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select both folders first')),
      );
      return;
    }

    final sourceDir = Directory(sourceDirPath!);
    final targetDir = Directory(targetDirPath!);

    setState(() {
      _isMoving = true;
      _finishedTasks = 0;
    });

    try {
      final videos = await collectVideosRecursively(sourceDir);
      await moveVideos(videos, targetDir, copyFiles);
    } catch (e) {
      debugPrint('Errore durante la raccolta o spostamento: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: $e')),
      );
    } finally {
      setState(() {
        _isMoving = false;
      });
    }
  }


  final List<String> allowedExtensions = [
    '.mp4', '.avi', '.mov', '.mkv', '.m4v', '.webm',
    '.flv', '.wmv', '.3gp', '.3g2', '.mpeg', '.mpg', '.ts'
  ];

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
    setState(() {
      _totalTasks = videos.length;
      _finishedTasks = 0;
    });
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
      setState(() {
        _finishedTasks += 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: Colors.blueGrey,
      ),
      title: 'VideoGatherer',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color.fromARGB(255, 12, 17, 17),
        appBar: AppBar(
          title: const Text(
            'VideoGatherer',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color.fromARGB(255, 22, 26, 26),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(Colors.blueGrey)
                  ),
                  onPressed: _isMoving ? null : pickSourceFolder,
                  child: Text(sourceDirPath == null
                      ? 'Select source folder'
                      : 'Source: $sourceDirPath',
                    style: TextStyle(
                      color: Colors.white
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(Colors.blueGrey)
                  ),
                  onPressed: _isMoving ? null : pickTargetFolder,
                  child: Text(targetDirPath == null
                      ? 'Select destination folder'
                      : 'Destination: $targetDirPath',
                      style: TextStyle(
                        color: Colors.white
                      ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(copyFiles 
                      ? 'Copy '
                      : 'Move (faster) ',
                    style: const TextStyle(color: Colors.white)),
                    Switch(
                      trackColor: copyFiles
                        ? MaterialStateProperty.all<Color>(Colors.blueGrey)
                        : null,
                      value: copyFiles,
                      onChanged: (val) {
                        setState(() {
                          copyFiles = val;
                        });
                      },
                    )
                  ],
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(Colors.blueGrey)
                  ),
                  onPressed: _isMoving ? null : startCollection,
                  child: Text(
                    'Start gathering',
                    style: TextStyle(
                      color: Colors.white
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                if(_isMoving)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 30),
                      SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          value: _totalTasks > 0 ? _finishedTasks / _totalTasks : 0.0,
                        ),
                      ),
                      Text(
                        "${_finishedTasks}/${_totalTasks}",
                        style: TextStyle(
                          color: Colors.white
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}