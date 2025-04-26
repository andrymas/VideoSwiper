import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:system_info/system_info.dart';

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
  int generatedThumbnails = 0; // -> aggiornato ogni volta che finisci un collage
  int currentVideoIndex = 0;   // -> aggiornato solo quando premi "Elimina" o "Mantieni"
  late int totalJobs;
  int framesNumber = 40;
  int maxJobs = 4;
  File? _scriptFile;
  List<File> videoFiles = [];
  String? selectedFolder;

  @override
  void dispose() {
    _scriptFile?.deleteSync();
    super.dispose();
  }


  @override
  void initState() {
    super.initState();
    _preparePythonScript();
  }

  Future<void> _preparePythonScript() async {
    final tempDir = await Directory.systemTemp.createTemp('video_swiper_script');
    final scriptPath = p.join(tempDir.path, 'collage_generator.py');
  final pythonScript = '''
import os
import cv2
from PIL import Image
import math
import sys

framesNumber = int(sys.argv[2]) if len(sys.argv) > 2 else 40


def estrai_frame_temporizzati(video_path, num_frame):
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
    frames = estrai_frame_temporizzati(video_path, num_frame=framesNumber)
    crea_collage(frames, output_collage)
''';

    final script = File(scriptPath);
    await script.writeAsString(pythonScript);
    _scriptFile = script;
  }


  Future<void> pickFolderAndLoadVideos() async {
    String? folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null) return;

    // Prepara la lista di file
    final videoExtensions = ['.mp4', '.avi', '.mov', '.mkv'];
    final files = Directory(folderPath)
        .listSync()
        .whereType<File>()
        .where((f) => videoExtensions.contains(p.extension(f.path).toLowerCase()))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    // Imposta i contatori
    setState(() {
      selectedFolder = folderPath;
      videoFiles = files;
      generatedThumbnails = 0;
      totalJobs = files.length;
    });

    // Variabili locali per dialog
    late StateSetter setStateDialog;
    Timer? ramTimer;
    final jobs = Queue<File>.from(videoFiles);

    // Mostra il dialog con StatefulBuilder
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: StatefulBuilder(
          builder: (context, dialogSetState) {
            setStateDialog = dialogSetState;

            // Lettura RAM (in GB)
            final totalGB  = SysInfo.getTotalPhysicalMemory() / 1073741824;
            final freeGB   = SysInfo.getFreePhysicalMemory()  / 1073741824;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    "Elaborati $generatedThumbnails /$totalJobs video",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                  Text(
                    "Memoria totale: ${totalGB.toStringAsFixed(2)} GB",
                    style: const TextStyle(color: Colors.white),
                  ),
                  Text(
                    "Memoria libera: ${freeGB.toStringAsFixed(2)} GB",
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    // Avvia il timer per aggiornare la RAM ogni secondo
    ramTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setStateDialog(() {}); // Ricostruisce il dialog per leggere la RAM fresca
    });

    // Coda e worker
    Future<void> worker() async {
      while (jobs.isNotEmpty) {
        final file = jobs.removeFirst();
        await _generateCollage(file);

        generatedThumbnails++;
        // aggiorna il dialog
        setStateDialog(() {});
      }
    }


    // 4) Lancio N worker in parallelo
    final workers = List.generate(maxJobs, (_) => worker());
    await Future.wait(workers);

    // stoppa il timer
    ramTimer?.cancel();
    // chiudi il dialog
    Navigator.of(context).pop();

    // riparti dall’inizio per la UI
    setState(() {
      currentVideoIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Elaborazione completata!'))
    );

  }



  Future<void> _generateCollage(File videoFile) async {
    if (_scriptFile == null) {
      print("❗ Script non pronto");
      return;
    }

    final result = await Process.run(
      'python3',
      [_scriptFile!.path, videoFile.path, framesNumber.toString()],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      print("Errore collage ${videoFile.path}: ${result.stderr}");
    } else {
      print("✅ Collage generato: ${videoFile.path}");
    }

    setState(() {
      // Aggiungi un controllo per non superare la lunghezza della lista
      if (generatedThumbnails  < videoFiles.length - 1) {
        generatedThumbnails ++;
      } else {
        // Se siamo all'ultimo video, non incrementiamo
        generatedThumbnails  = videoFiles.length - 1;
      }
    });
  }


  String _getCollagePath(File videoFile) {
    final base = p.basenameWithoutExtension(videoFile.path);
    final outputDir = p.dirname(videoFile.path);
    return p.join(outputDir, '${base}_collage.png');
  }

  void deleteCurrentVideo() {
    // elimina il video corrente dalla lista
    videoFiles.removeAt(currentVideoIndex );

    if (videoFiles.isEmpty) {
      setState(() {
        // non serve cambiare currentIndex, tanto mostriamo il messaggio
      });
    } else {
      setState(() {
        // Se eliminiamo l'ultimo video, rimaniamo sull'ultimo valido
        if (currentVideoIndex  >= videoFiles.length) {
          currentVideoIndex = videoFiles.length - 1;
        }
      });
    }
  }

  /// Restituisce un widget: se il PNG esiste e non è vuoto
  /// mostra l’immagine, altrimenti un piccolo loader e testo.
  Widget _buildCollageView(String path) {
    final file = File(path);
    final fileExists = file.existsSync() && file.lengthSync() > 0;

    if (!fileExists) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 200, height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          SizedBox(height: 8),
          Text(
            'Generazione collage in corso…',
            style: TextStyle(color: Colors.white),
          ),
        ],
      );
    }

    return Image.file(file, fit: BoxFit.contain);
  }

  @override
  Widget build(BuildContext context) {
    final hasVideos = videoFiles.isNotEmpty;
    final video = hasVideos && currentVideoIndex < videoFiles.length
        ? videoFiles[currentVideoIndex]
        : null;
    final collagePath = hasVideos && video != null ? _getCollagePath(video) : null;

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
      body: SingleChildScrollView(
        child: Column(
          children: [
            Column(
              children: [
                Text("Number of async processes"),
                Slider(
                  label: maxJobs.toString(),
                  value: maxJobs.toDouble(),
                  min: 1,
                  max: Platform.numberOfProcessors.toDouble(),
                  divisions: Platform.numberOfProcessors,
                  onChanged: (double value) {
                    setState(() {
                      maxJobs = value.toInt();
                      print(maxJobs);
                    });
                  },
                ),
                Text("Number of frames per collage"),
                Slider(
                  label: framesNumber.toString(),
                  value: framesNumber.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  onChanged: (double value) {
                    setState(() {
                      framesNumber = value.toInt();
                      print(framesNumber);
                    });
                  },
                )
              ],
            ),
            if (video == null && currentVideoIndex == videoFiles.length) // Quando siamo alla fine della lista
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Tutti i video completati!',
                      style: TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("Rivedi la lista"),
                      onPressed: () {
                        setState(() {
                          currentVideoIndex = 0; // Resetta l'indice per rivedere i video da capo
                        });
                      },
                    )
                  ],
                ),
              )
            else // Se ci sono ancora video da visualizzare
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(p.basename(video!.path), style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: collagePath != null
                            ? _buildCollageView(collagePath)
                            : const Text(
                                "Nessun collage da mostrare",
                                style: TextStyle(color: Colors.white),
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
                            onPressed: hasVideos ? deleteCurrentVideo : null, // Disabilita se non ci sono video
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text("Mantieni"),
                            onPressed: hasVideos
                                ? () {
                                    setState(() {
                                      if (currentVideoIndex < videoFiles.length - 1) {
                                        currentVideoIndex++;
                                      } else {
                                        // Se siamo all'ultimo video, mostriamo la schermata di fine lista
                                        currentVideoIndex = videoFiles.length; // Impostiamo un valore fuori dalla lista
                                      }
                                    });
                                  }
                                : null, // Disabilita se non ci sono video
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}