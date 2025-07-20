import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:system_info/system_info.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videoswiper/script.dart';
import 'package:videoswiper/video_collector.dart';
import 'package:videoswiper/video_player.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    setWindowTitle('VideoSwiper');
    setWindowMinSize(const Size(516, 600));

    WindowOptions windowOptions = const WindowOptions(
      size: Size(800, 600),
      center: true,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (e, st) {
    debugPrint('⚠️ windowManager error: $e\n$st');
  }

  if (args.firstOrNull == 'multi_window') {
    runApp(VideoCollectorWindow());
  } else {
    MediaKit.ensureInitialized();
    runApp(VideoSwiperApp());
  }
}



//drag scroll class
class SmoothScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad
  };
}

enum QualityLevel {
  lowest,
  low,
  medium,
  high,
  ultra,
}

extension QualityLevelExtension on QualityLevel {
  String toDisplayString() {
    return toString().split('.').last[0].toUpperCase() +
      toString().split('.').last.substring(1);
  }
}

//app creation class
class VideoSwiperApp extends StatelessWidget {
  const VideoSwiperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VideoSwiper',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: Colors.blueGrey,
      ),
      //home: const VideoReviewPage(),
      home: const VideoReviewPage(),
    );
  }
}

class VideoReviewPage extends StatefulWidget {
  const VideoReviewPage({super.key});

  @override
  State<VideoReviewPage> createState() => _VideoReviewPageState();
}

class _VideoReviewPageState extends State<VideoReviewPage> with TickerProviderStateMixin, WindowListener {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TransformationController _transformationController = TransformationController();
  late Directory trashLocation;
  int generatedThumbnails = 0;
  int currentVideoIndex = 0;
  late int totalJobs;
  //init variables
  int framesNumber = 40;
  int maxJobs = 4;
  File? _scriptFile;
  List<File> videoFiles = [];
  String selectedFolder = "Select a folder";
  bool _showPlayer = false;
  bool _isHovering = false;
  bool _isMenuOpen = false;
  bool _beginPaused = false;
  bool _beginMuted = true;
  Process? _collageProcess;
  double _zoom = 1.0;
  final double _minZoom = 1;
  final double _maxZoom = 3;
  final double _zoomStep = 0.5;
  bool _allowZoom = true;
  late AnimationController _controller;
  int qualitySetting = 2;

  Set<QualityLevel> _selectedQuality = {QualityLevel.medium};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _transformationController.value = Matrix4.identity() * _zoom;

    windowManager.addListener(this);
    preparePythonScript();
  }

  //removing the ordinary dispose method
  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  //new dispose method asking the user input to close the windows when processing collages
  @override
  Future<void> onWindowClose() async {
    if (getIsGeneratingCollage()) {
      final shouldClose = await showDialog<bool>(
        context: context,
        builder: (_) {
          return AlertDialog(
            backgroundColor: const Color.fromARGB(255, 22, 26, 26),
            title: const Text(
              "Are you sure you want to close VideoSwiper?",
                style: TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.none
                ),
              ),
            content: const Text(
              "The app will finish the collages it's currently processing.",
              style: TextStyle(
                color: Colors.white,
                decoration: TextDecoration.none
              ),
            ),
            actions: [
              TextButton(
                child: const Text(
                  'No',
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.none
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              TextButton(
                child: const Text(
                  'Yes',
                  style: TextStyle(
                    color: Colors.white,
                    decoration: TextDecoration.none
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          );
        },
      );

      if (shouldClose == true) {
        await stopCollageGeneration();
        await windowManager.destroy();
      }
    } else {
      await windowManager.destroy();
    }
  }

  void _changeImageSize(int action) {
    setState(() {
      if(action == 1){
        _zoom = (_zoom + _zoomStep).clamp(_minZoom, _maxZoom);
      }else if(action == 2){
        _zoom = (_zoom - _zoomStep).clamp(_minZoom, _maxZoom);
      }else if(action == 3){
        _zoom = 1;
      }
      _transformationController.value = Matrix4.identity().scaled(_zoom);
    });
  }

  void _applyQualitySetting(QualityLevel quality) {
    qualitySetting = QualityLevel.values.indexOf(quality);
    print('New qualitySetting index: $qualitySetting (${quality.toDisplayString()})');
    switch (quality) {
      case QualityLevel.lowest:
        qualitySetting = 0;
        break;
      case QualityLevel.low:
        qualitySetting = 1;
        break;
      case QualityLevel.medium:
        qualitySetting = 2;
        break;
      case QualityLevel.high:
        qualitySetting = 3;
        break;
      case QualityLevel.ultra:
        qualitySetting = 4;
        break;
    }
  }

  void toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  Future<void> preparePythonScript() async {
    final tempDir = await Directory.systemTemp.createTemp('video_swiper_script');
    final scriptPath = p.join(tempDir.path, 'collage_generator.py');
    final script = File(scriptPath);
    //pythonScript is in script.dart
    await script.writeAsString(pythonScript);
    _scriptFile = script;
  }

  bool getIsGeneratingCollage() {
    if (_collageProcess != null) {
      return true;
    } else {
      return false;
    }
  }

  Future<void> stopCollageGeneration() async {
    if (_collageProcess != null) {
      print("🛑 Terminazione processo in corso...");
      _collageProcess!.kill(ProcessSignal.sigterm);
      await _collageProcess!.exitCode;
      print("✅ Processo terminato.");
      _collageProcess = null;
    } else {
      print("ℹ️ Nessun processo attivo.");
    }
  }

  Future<void> pickFolderAndLoadVideos() async {
    print("Current settings: async ${maxJobs}, frames ${framesNumber}, quality ${qualitySetting}");
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
    final jobs = Queue<File>();
    //checks if files already have a collage and skips them
    for (var file in videoFiles) {
      if (!await _collageAlreadyExists(file)) {
        jobs.add(file);
      } else {
        print("✔️ Skipping ${file.path}, collage already exists");
        setState(() {
          generatedThumbnails++;
        });
      }
    }

    //Show the dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Stack(
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(
              color: Colors.black.withOpacity(0), // necessario per far funzionare il blur
            ),
          ),
          Center(
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
                      Text(
                        selectedFolder,
                        style: TextStyle(
                          color: Colors.white,
                          decoration: TextDecoration.none
                        ),
                      ),
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
                      SizedBox(
                        width: 800,
                        child: Row(
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
                      ),
                    ],
                  )
                );
              },
            ),
          ),
        ]
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
  }

  Future<void> _generateCollage(File videoFile) async {
    if (_scriptFile == null) {
      print("❗ Script not ready");
      return;
    }

    print("Collage doesn't exist for ${videoFile.path}, generating.");

    try {
      _collageProcess = await Process.start(
        'python3',
        [_scriptFile!.path, videoFile.path, framesNumber.toString(), qualitySetting.toString()],
        runInShell: true,
      );

      final exitCode = await _collageProcess!.exitCode;

      if (exitCode != 0) {
        print("❌ Collage error ${videoFile.path}");
      } else {
        print("✅ Collage generated: ${videoFile.path}");
      }
    } catch (e) {
      print("Error running script: $e");
    } finally {
      _collageProcess = null;
    }
  }

  //simple function to get the collage path of a video
  String _getCollagePath(File videoFile) {
    final base = p.basenameWithoutExtension(videoFile.path);
    final outputDir = p.dirname(videoFile.path);
    return p.join(outputDir, '${base}_collage.png');
  }

  //checks if a valid collage exists (size greater than 0 bytes)
  Future<bool> _collageAlreadyExists(File videoFile) async {
    final collageFile = File(_getCollagePath(videoFile));
    if (await collageFile.exists()) {
      final length = await collageFile.length();
      return length > 0;
    }
    return false;
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
        currentVideoIndex = videoFiles.length;
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
          SizedBox(height: 8),
          Text(
            'Collage not found',
            style: TextStyle(color: Colors.white),
          ),
        ],
      );
    }

    return Column(
      children: [
        if(_allowZoom)
          InteractiveViewer(
            transformationController: _transformationController,
            panEnabled: true,
            scaleEnabled: false,
            minScale: _minZoom,
            maxScale: _maxZoom,
            child: Image.file(file, fit: BoxFit.contain),
          )
        else
          Image.file(file, fit: BoxFit.contain),
        SizedBox(height: 10,),
        if (videoFiles.isNotEmpty && _showPlayer)
          SizedBox(
            height: 400,
            child: MiniVideoPlayer(
              key: ValueKey(videoFiles[currentVideoIndex].path),
              videoPath: videoFiles[currentVideoIndex].path,
              beginPaused: _beginPaused,
              beginMuted: _beginMuted,
            ),
          ),
      ],
    );
  }

  String getLastPart(String path) {
    int lastSlash = path.lastIndexOf('\\');
    if (lastSlash == -1) return path; // if / not present return whole string
    return path.substring(lastSlash + 1);
  }

  Future<String?> fetchLatestVersionFromGitHub(String owner, String repo) async {
    final url = Uri.parse('https://api.github.com/repos/$owner/$repo/releases/latest');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['tag_name'];
    } else {
      print('Failed to fetch latest version: ${response.statusCode}');
      return null;
    }
  }

  Future<void> showVersionDialog(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    final latestVersion = await fetchLatestVersionFromGitHub("andrymas", "VideoSwiper");
    final latestText = latestVersion != null
        ? latestVersion
        : 'Failed to fetch';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 12, 17, 17),
          title: const Text(
            'Info',
            style: TextStyle(
              color: Colors.white
            ),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 150, // scegli l'altezza massima che vuoi
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Latest version: $latestText",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                SizedBox(height: 10,),
                Text(
                  "Software version: v${info.version}",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
                SizedBox(height: 20,),
                if("v${info.version}" == latestText)
                  Row(
                    children: [
                      Icon(
                        Icons.check,
                        color: Colors.greenAccent,
                      ),
                      SizedBox(width: 5,),
                      Text(
                        "You have the latest version!",
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      )
                    ],
                  )
                  else
                    Row(
                      children: [
                        Icon(
                          Icons.error,
                          color: Colors.redAccent,
                        ),
                        SizedBox(width: 5,),
                        Text(
                          "You don't have the latest version!",
                          style: TextStyle(
                            color: Colors.white,
                          ),
                        )
                      ],
                    )
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white),
                ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            if("v${info.version}" != latestText)
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: const Text(
                  'Upgrade',
                  style: TextStyle(color: Colors.white),
                  ),
                onPressed: () {
                  var url = Uri.parse("https://github.com/andrymas/VideoSwiper/releases");
                  launchUrl(url);
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double drawerWidth = 500;
    final hasVideos = videoFiles.isNotEmpty;
    final video = hasVideos && currentVideoIndex < videoFiles.length
        ? videoFiles[currentVideoIndex]
        : null;
    final collagePath = hasVideos && video != null ? _getCollagePath(video) : null;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color.fromARGB(255, 12, 17, 17),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color.fromARGB(255, 22, 26, 26),
        automaticallyImplyLeading: false, // disabilita il leading automatico
        title: SizedBox(
          width: double.infinity, // prende tutta la larghezza disponibile
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Bottone a sinistra
              Align(
                alignment: Alignment.centerLeft,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isHovering = true),
                  onExit: (_) => setState(() => _isHovering = false),
                  child: InkWell(
                    splashColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: pickFolderAndLoadVideos,
                    borderRadius: BorderRadius.circular(4),
                    child: Card(
                      elevation: 0,
                      color: _isHovering
                          ? const Color.fromARGB(255, 44, 53, 59)
                          : const Color.fromARGB(255, 34, 37, 37),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.folder, color: Colors.white),
                            const SizedBox(width: 10),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(
                                getLastPart(selectedFolder),
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: const TextStyle(color: Colors.white),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Titolo centrato
              Align(
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Text(
                      '${currentVideoIndex}/${videoFiles.length}',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(
                        width: 100,
                        child: LinearProgressIndicator(
                          value: videoFiles.length > 0 ? currentVideoIndex / videoFiles.length : 0.0,
                          color: Colors.blueAccent,
                          backgroundColor: Colors.blueGrey,
                        ),
                      ),
                  ],
                ),
              ),

              // Azioni a destra
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () async {
                        final window = await DesktopMultiWindow.createWindow(jsonEncode({
                          'type': 'Sub window',
                        }));
                        window
                          ..setTitle('VideoGatherer')
                          ..show();
                      },
                      icon: const Icon(Icons.archive),
                      color: Colors.white,
                    ),
                    IconButton(
                      onPressed: () {
                        showVersionDialog(context);
                      },
                      icon: const Icon(Icons.info),
                      color: Colors.white,
                    ),
                    IconButton(
                      icon: AnimatedIcon(
                        icon: AnimatedIcons.menu_close,
                        progress: _controller,
                        color: Colors.white,
                      ),
                      onPressed: toggleMenu,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children:[
          if (video == null && currentVideoIndex == videoFiles.length)
            Container(
              width: double.infinity,
              height: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'You finished!',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh, color: Colors.black),
                    label: const Text("Go back to the start", style: TextStyle(color: Colors.black)),
                    onPressed: () {
                      setState(() {
                        currentVideoIndex = 0;
                      });
                    },
                  ),
                ],
              ),
            )
            else
              Stack(
                children: [
                  Positioned.fill(
                    child: ScrollConfiguration(
                      behavior: SmoothScrollBehavior(),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110), // Padding per lasciare spazio alla barra sotto
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (video != null) ...[
                                Text(
                                  p.basename(video.path),
                                  style: const TextStyle(fontSize: 16, color: Colors.white),
                                ),
                                Text(
                                  '${(video.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                                  style: const TextStyle(fontSize: 16, color: Colors.white),
                                ),
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
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 280,
                      height: 100,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 1),
                      margin: EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            //Semi-transparent bg
                            Container(color: Colors.black.withOpacity(0.3)),
                            //Blur filter
                            BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                              child: Container(color: Colors.transparent),
                            ),
                            //Content
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      color: Colors.white,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      iconSize: 32,
                                      onPressed: hasVideos
                                          ? () {
                                              setState(() {
                                                if (currentVideoIndex > 0) {
                                                  currentVideoIndex--;
                                                } else {
                                                  currentVideoIndex = 0;
                                                }
                                              });
                                            }
                                          : null,
                                      icon: const Icon(Icons.arrow_back),
                                    ),
                                    if(_allowZoom == true)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const SizedBox(width: 5),
                                          IconButton(
                                            color: Colors.white,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            iconSize: 32,
                                            onPressed: hasVideos
                                                ? () {_changeImageSize(1);}
                                                : null,
                                            icon: const Icon(Icons.zoom_in),
                                          ),
                                          const SizedBox(width: 5),
                                          IconButton(
                                            color: Colors.white,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            iconSize: 32,
                                            onPressed: hasVideos
                                                ? () {_changeImageSize(2);}
                                                : null,
                                            icon: const Icon(Icons.zoom_out),
                                          ),
                                          const SizedBox(width: 5),
                                        ],
                                      )
                                    else
                                      SizedBox(width: 30,),

                                    IconButton(
                                      color: Colors.white,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      iconSize: 32,
                                      onPressed: hasVideos
                                          ? () {
                                              setState(() {
                                                if (currentVideoIndex < videoFiles.length) {
                                                  currentVideoIndex++;
                                                } else {
                                                  currentVideoIndex = 0;
                                                }
                                              });
                                            }
                                          : null,
                                      icon: const Icon(Icons.arrow_forward),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.delete, color: Colors.black),
                                      label: const Text(
                                        "Delete",
                                        style: TextStyle(color: Colors.black),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                      ),
                                      onPressed: hasVideos ? deleteCurrentVideo : null,
                                    ),
                                    const SizedBox(width: 5),
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.check, color: Colors.black),
                                      label: const Text(
                                        "Keep",
                                        style: TextStyle(color: Colors.black),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                      ),
                                      onPressed: hasVideos
                                          ? () {
                                              setState(() {
                                                if (currentVideoIndex < videoFiles.length) {
                                                  currentVideoIndex++;
                                                } else {
                                                  currentVideoIndex = 0;
                                                }
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                ],
              ),
            if (_isMenuOpen)
              GestureDetector(
                onTap: toggleMenu,
                child: Container(
                  color: Colors.black54,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            // Custom drawer from right
            AnimatedPositioned(
              duration: Duration(milliseconds: 300),
              top: 0,
              right: _isMenuOpen ? 0 : -drawerWidth,
              width: drawerWidth,
              bottom: 0,
              child: Material(
                elevation: 16,
                color: Color.fromARGB(255, 22, 26, 26),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.developer_board, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              "Number of async processes",
                              style: TextStyle(
                                color: Colors.white
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          activeColor: Theme.of(context).primaryColor,
                          year2023: false,
                          label: maxJobs.toString(),
                          value: maxJobs.toDouble(),
                          min: 1,
                          max: Platform.numberOfProcessors.toDouble(),
                          divisions: Platform.numberOfProcessors-1,
                          onChanged: (double value) {
                            setState(() {
                              maxJobs = value.toInt();
                              print(maxJobs);
                            });
                          },
                        ),
                        SizedBox(height: 50,),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_library, color: Colors.white,),
                            SizedBox(width: 10),
                            Text(
                              "Number of frames per collage",
                              style: TextStyle(
                                color: Colors.white
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          activeColor: Theme.of(context).primaryColor,
                          year2023: false,
                          label: framesNumber.toString(),
                          value: framesNumber.toDouble(),
                          min: 1,
                          max: 100,
                          divisions: 100,
                          onChanged: (double value) {
                            setState(() {
                              framesNumber = value.toInt();
                              print(framesNumber);
                            });
                          },
                        ),
                        SizedBox(height: 50,),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Checkbox(
                                  activeColor: Theme.of(context).primaryColor,
                                  hoverColor: const Color.fromARGB(255, 44, 53, 59),
                                  value: _showPlayer,
                                  onChanged: (value) {
                                    setState(() {
                                      _showPlayer = value!;
                                    });
                                  },
                                ),
                                Text(
                                  "Show video player",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),

                            if(_showPlayer)
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Checkbox(
                                        activeColor: Theme.of(context).primaryColor,
                                        hoverColor: const Color.fromARGB(255, 44, 53, 59),
                                        value: _beginPaused,
                                        onChanged: (value) {
                                          setState(() {
                                            _beginPaused = value!;
                                          });
                                        },
                                      ),
                                      Text(
                                        "Autoplay",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Checkbox(
                                        activeColor: Theme.of(context).primaryColor,
                                        hoverColor: const Color.fromARGB(255, 44, 53, 59),
                                        value: _beginMuted,
                                        onChanged: (value) {
                                          setState(() {
                                            _beginMuted = value!;
                                          });
                                        },
                                      ),
                                      Text(
                                        "Start muted",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                          ],
                        ),
                        SizedBox(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Checkbox(
                              activeColor: Theme.of(context).primaryColor,
                              hoverColor: const Color.fromARGB(255, 44, 53, 59),
                              value: _allowZoom,
                              onChanged: (value) {
                                setState(() {
                                  _allowZoom = value!;
                                  _changeImageSize(3);
                                });
                              },
                            ),
                            Text(
                              "Enable image zoom",
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                        SizedBox(height: 50),
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.tune, color: Colors.white), // Appropriate icon for settings
                                SizedBox(width: 10),
                                Text(
                                  "Quality Settings",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                            SizedBox(height: 20), // Spazio tra titolo e SegmentedButton
                            SizedBox(
                              width: 490,
                              child: SegmentedButton<QualityLevel>(
                                segments: <ButtonSegment<QualityLevel>>[
                                  ButtonSegment<QualityLevel>(
                                    value: QualityLevel.lowest,
                                    label: Text(QualityLevel.lowest.toDisplayString()),
                                    icon: Icon(Icons.speed)
                                  ),
                                  ButtonSegment<QualityLevel>(
                                    value: QualityLevel.low,
                                    label: Text(QualityLevel.low.toDisplayString()),
                                    icon: Icon(Icons.flash_on)
                                  ),
                                  ButtonSegment<QualityLevel>(
                                    value: QualityLevel.medium,
                                    label: Text(QualityLevel.medium.toDisplayString()),
                                    icon: Icon(Icons.balance)
                                  ),
                                  ButtonSegment<QualityLevel>(
                                    value: QualityLevel.high,
                                    label: Text(QualityLevel.high.toDisplayString()),
                                    icon: Icon(Icons.photo_filter)
                                  ),
                                  ButtonSegment<QualityLevel>(
                                    value: QualityLevel.ultra,
                                    label: Text(QualityLevel.ultra.toDisplayString()),
                                    icon: Icon(Icons.auto_awesome)
                                  ),
                                ],
                                selected: _selectedQuality,
                                onSelectionChanged: (Set<QualityLevel> newSelection) {
                                  if (newSelection.isNotEmpty) {
                                    setState(() {
                                      _selectedQuality = newSelection;
                                      _applyQualitySetting(_selectedQuality.first); // Update and apply
                                    });
                                  }
                                },
                                style: SegmentedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Riduci padding,
                                  foregroundColor: Theme.of(context).primaryColor,
                                  selectedBackgroundColor: Theme.of(context).primaryColor,
                                  selectedForegroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                    side: BorderSide(
                                      color: Theme.of(context).colorScheme.outline,
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ]
      ),
    );
  }
}