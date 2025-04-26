import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const VideoSwiperApp());
}

class VideoSwiperApp extends StatelessWidget {
  const VideoSwiperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VideoSwiper',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const VideoReviewPage(),
    );
  }
}

class VideoReviewPage extends StatefulWidget {
  const VideoReviewPage({super.key});

  @override
  State<VideoReviewPage> createState() => _VideoReviewPageState();
}

class _VideoReviewPageState extends State<VideoReviewPage> {
  List<File> videoFiles = [];
  int currentIndex = 0;
  String? selectedFolder;

  @override
  void initState() {
    super.initState();
  }

  Future<void> pickFolderAndLoadVideos() async {
    String? folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null) return;

    setState(() {
      selectedFolder = null;
      videoFiles = [];
      currentIndex = 0;
    });

    final videoExtensions = ['.mp4', '.avi', '.mov', '.mkv'];
    final files = Directory(folderPath)
        .listSync()
        .whereType<File>()
        .where((file) => videoExtensions.contains(p.extension(file.path).toLowerCase()))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    // Mostra caricamento temporaneo
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    for (var video in files) {
      await _generateCollage(video);
    }

    Navigator.of(context).pop(); // Chiudi il loader

    setState(() {
      selectedFolder = folderPath;
      videoFiles = files;
      currentIndex = 0;
    });
  }

  Future<void> _generateCollage(File videoFile) async {
    final tempDir = Directory.systemTemp.createTempSync();
    final scriptPath = p.join(tempDir.path, 'collage_generator.py');

    // Scrivi lo script Python nel file temporaneo
final pythonScript = '''
import os
import cv2
from PIL import Image
import math
import sys

def estrai_frame_temporizzati(video_path, num_frame=50):
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"Errore nell'apertura del video: {video_path}")
        return []

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS)
    duration_seconds = total_frames / fps if fps > 0 else 0

    if duration_seconds == 0:
        print(f"Durata video non valida: {video_path}")
        return []

    step_seconds = duration_seconds / num_frame
    frames = []

    for i in range(num_frame):
        timestamp = i * step_seconds
        cap.set(cv2.CAP_PROP_POS_MSEC, timestamp * 1000)
        ret, frame = cap.read()
        if not ret:
            continue
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        img = Image.fromarray(frame_rgb)
        frames.append(img)

    cap.release()
    return frames

def crea_collage(frames, output_path, cols=8):
    if not frames:
        print(f"Nessun frame disponibile per creare il collage: {output_path}")
        return

    rows = math.ceil(len(frames) / cols)
    thumb_size = (180, 320) if frames[0].height > frames[0].width else (320, 180)
    collage_width = cols * thumb_size[0]
    collage_height = rows * thumb_size[1]

    collage = Image.new('RGB', (collage_width, collage_height), color=(0, 0, 0))

    for index, frame in enumerate(frames):
        frame = frame.resize(thumb_size)
        x = (index % cols) * thumb_size[0]
        y = (index // cols) * thumb_size[1]
        collage.paste(frame, (x, y))

    collage.save(output_path)
    print(f"Collage salvato: {output_path}")

if __name__ == "__main__":
    video_path = sys.argv[1]
    nome_base = os.path.splitext(os.path.basename(video_path))[0]
    cartella = os.path.dirname(video_path)
    output_collage = os.path.join(cartella, f"{nome_base}_collage.png")
    frames = estrai_frame_temporizzati(video_path, num_frame=40)
    crea_collage(frames, output_collage)
''';



    await File(scriptPath).writeAsString(pythonScript);

    // Esegui lo script
    final result = await Process.run(
      'python3',
      [scriptPath, videoFile.path],
      runInShell: true,
    );

    // Cancella il file temporaneo
    await File(scriptPath).delete();

    if (result.exitCode != 0) {
      print("Errore collage ${videoFile.path}: ${result.stderr}");
    } else {
      print("✅ Collage generato: ${videoFile.path}");
    }
  }

  String _getCollagePath(File videoFile) {
    final base = p.basenameWithoutExtension(videoFile.path);
    final outputDir = p.dirname(videoFile.path); // Directory del video
    return p.join(outputDir, '${base}_collage.png');
  }

  void deleteCurrentVideo() {
    final video = videoFiles[currentIndex];
    final collage = File(_getCollagePath(video));
    if (video.existsSync()) video.deleteSync();
    if (collage.existsSync()) collage.deleteSync();

    setState(() {
      videoFiles.removeAt(currentIndex);
      if (currentIndex >= videoFiles.length) {
        currentIndex = videoFiles.isEmpty ? 0 : videoFiles.length - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasVideos = videoFiles.isNotEmpty;
    final video = hasVideos ? videoFiles[currentIndex] : null;
    final collagePath = hasVideos ? _getCollagePath(video!) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VideoSwiper'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: pickFolderAndLoadVideos,
          )
        ],
      ),
      body: hasVideos
        ? SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(p.basename(video!.path), style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Image.file(
                      File(collagePath!),
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.delete),
                        label: const Text("Elimina"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => deleteCurrentVideo(),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text("Mantieni"),
                        onPressed: () {
                          setState(() {
                            currentIndex = (currentIndex + 1) % videoFiles.length;
                          });
                        },
                      ),
                    ],
                  )
                ],
              ),
            ),
          )
        : const Center(child: Text("Nessun video selezionato")),

    );
  }
}