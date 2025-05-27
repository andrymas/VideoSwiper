import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:system_info/system_info.dart';
import 'package:videoswiper/script.dart';

void main() {
  runApp(const VideoSwiperApp());
}

//app creation class
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
  late Directory trashLocation;
  int generatedThumbnails = 0;
  int currentVideoIndex = 0;
  late int totalJobs;
  //init variables
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
    //prepare the python file
    preparePythonScript();
  }


  Future<void> preparePythonScript() async {
    final tempDir = await Directory.systemTemp.createTemp('video_swiper_script');
    final scriptPath = p.join(tempDir.path, 'collage_generator.py');
    final script = File(scriptPath);
    //pythonScript is in script.dart
    await script.writeAsString(pythonScript);
    _scriptFile = script;
  }

  Future<void> pickFolderAndLoadVideos() async {
    String? folderPath = await FilePicker.platform.getDirectoryPath();
    if (folderPath == null) return;

    //File list
    trashLocation = await Directory('$folderPath/trash').create(recursive: false);
    final videoExtensions = [
      '.mp4', '.avi', '.mov', '.mkv', '.m4v', '.webm',
      '.flv', '.wmv', '.3gp', '.3g2', '.mpeg', '.mpg', '.ts'
    ];
    final files = Directory(folderPath)
        .listSync()
        .whereType<File>()
        .where((f) => videoExtensions.contains(p.extension(f.path).toLowerCase()))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    //Variable reset
    setState(() {
      selectedFolder = folderPath;
      videoFiles = files;
      generatedThumbnails = 0;
      totalJobs = files.length;
    });

    //Local variable for dialog
    late StateSetter setStateDialog;
    Timer? ramTimer;
    final jobs = Queue<File>.from(videoFiles);

    //Show the dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: StatefulBuilder(
          builder: (context, dialogSetState) {
            setStateDialog = dialogSetState;

            //RAM (in GB)
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
                    "Elaborated $generatedThumbnails /$totalJobs videos",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none
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
                    "RAM Usage",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        "${usedGB.toStringAsFixed(1)} GB",
                        style: const TextStyle(color: Colors.white, decoration: TextDecoration.none),
                      ),
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
                      Text(
                        "${totalGB.toStringAsFixed(1)} GB",
                        style: const TextStyle(color: Colors.white, decoration: TextDecoration.none),
                      ),
                    ],
                  ),
                ],
              )
            );
          },
        ),
      ),
    );

    //Refreshes the ram monitor every second
    ramTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setStateDialog((){}); //Recreates the dialog to update the ram monitor
    });

    //Thread worker
    Future<void> worker() async {
      while (jobs.isNotEmpty) {
        final file = jobs.removeFirst();
        await _generateCollage(file);

        generatedThumbnails++;
        // Update the dialog every new thumbnail
        setStateDialog((){});
      }
    }


    //Creates N paralel workers
    final workers = List.generate(maxJobs, (_) => worker());
    await Future.wait(workers);

    //Stops the timer
    ramTimer.cancel();
    //Closes the dialog
    Navigator.of(context).pop();

    //Gets the first generated video
    setState(() {
      currentVideoIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Elaboration complete!'))
    );

  }



  Future<void> _generateCollage(File videoFile) async {
    if (_scriptFile == null) {
      print("❗ Script not ready");
      return;
    }

    //runs the python script (should work only on windows)
    final result = await Process.run(
      'python3',
      [_scriptFile!.path, videoFile.path, framesNumber.toString()],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      print("Collage error ${videoFile.path}: ${result.stderr}");
    } else {
      print("✅ Collage generated: ${videoFile.path}");
    }
  }

  //simple function to get the collage path of a video
  String _getCollagePath(File videoFile) {
    final base = p.basenameWithoutExtension(videoFile.path);
    final outputDir = p.dirname(videoFile.path);
    return p.join(outputDir, '${base}_collage.png');
  }

  //creates the new file path in the trash (it seems the only way to move a file in dart)
  String uniqueTrashPath(String fileName) {
    final base = p.basenameWithoutExtension(fileName);
    final ext = p.extension(fileName);
    int count = 1;
    String newPath = p.join(trashLocation.path, '$base$ext');

    while (File(newPath).existsSync()) {
      newPath = p.join(trashLocation.path, '$base($count)$ext');
      count++;
    }

    return newPath;
  }

  void deleteCurrentVideo() {
    final file = videoFiles[currentVideoIndex];
    final collagePath = _getCollagePath(file);
    final collageFile = File(collagePath);

    try {
      // Sposta il video nel cestino
      file.renameSync(p.join(trashLocation.path, p.basename(file.path)));

      // Se il collage esiste, spostalo anche lui
      if (collageFile.existsSync()) {
        collageFile.renameSync(p.join(trashLocation.path, p.basename(collagePath)));
      }

      print('File and collage moved in: ${trashLocation.path}');
    } catch (e) {
      print('Error moving files: $e');
    }

    //remove the video from the list
    videoFiles.removeAt(currentVideoIndex);

    setState(() {
      if (videoFiles.isEmpty) {
        //no files remaining
      } else if (currentVideoIndex >= videoFiles.length) {
        //if deleting the last, go to the one before that
        currentVideoIndex = videoFiles.length - 1;
      }
    });
  }

  //if the collage does not exist or is empty
  //show the image or a loader and some text
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
            'Generating the collage...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      );
    }

    return Image.file(file, fit: BoxFit.contain);
  }

  //main ui
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
                      'You finished!',
                      style: TextStyle(fontSize: 24),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("Go back to the start"),
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
                      Text('${(video.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: collagePath != null
                            ? _buildCollageView(collagePath)
                            : const Text(
                                "No collage to show",
                                style: TextStyle(color: Colors.white),
                              ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.delete),
                            label: const Text("Delete"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: hasVideos ? deleteCurrentVideo : null, //disable if no videos available
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text("Keep"),
                            onPressed: hasVideos
                                ? () {
                                    setState(() {
                                      if (currentVideoIndex < videoFiles.length - 1) {
                                        currentVideoIndex++;
                                      } else {
                                        //if we are on the last one show a widget
                                        currentVideoIndex = videoFiles.length; //set a value outsite of the list
                                      }
                                    });
                                  }
                                : null, //disable if no videos available
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