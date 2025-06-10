import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:system_info/system_info.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videoswiper/script.dart';
import 'package:videoswiper/videoplayer.dart';
import 'package:window_size/window_size.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  setWindowTitle('VideoSwiper');
  setWindowMinSize(const Size(500, 600));
  runApp(const VideoSwiperApp());
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

class _VideoReviewPageState extends State<VideoReviewPage> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
  late AnimationController _controller;

  @override
  void initState(){
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this
    );
    super.initState();
    preparePythonScript();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Elaboration complete!'))
    );

  }

  Future<void> _generateCollage(File videoFile) async {
    if (_scriptFile == null) {
      print("❗ Script not ready");
      return;
    }

    print("Collage doesn't exists for ${videoFile.path}, generating.");

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
        Image.file(file, fit: BoxFit.contain),
        SizedBox(height: 10,),
        if (videoFiles.isNotEmpty && _showPlayer)
          SizedBox(
            height: 400,
            child: MiniVideoPlayer(
              key: ValueKey(videoFiles[currentVideoIndex].path),
              videoPath: videoFiles[currentVideoIndex].path,
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
        leading: null,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MouseRegion(
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
                  color: _isHovering ? const Color.fromARGB(255, 44, 53, 59) : Color.fromARGB(255, 34, 37, 37), // change color on hover
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder,
                          color: Colors.white,
                        ),
                        SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 150),
                          child: Text(
                            getLastPart(selectedFolder),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: TextStyle(color: Colors.white),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              showVersionDialog(context);
            },
            icon: Icon(Icons.info),
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
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Home'),
              onTap: () {
                // azione
                Navigator.pop(context); // chiudi il drawer
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Impostazioni'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
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
            else // Se ci sono ancora video da visualizzare
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(p.basename(video!.path), style: const TextStyle(fontSize: 16, color: Colors.white)),
                      Text('${(video.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB', style: const TextStyle(fontSize: 16, color: Colors.white)),
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
                      //TODO: make these buttons float at the bottom of the screen
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                color: Colors.white,
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                iconSize: 32,
                                onPressed: hasVideos
                                  ? () {
                                      setState(() {
                                        if (currentVideoIndex > 0) {
                                          currentVideoIndex--;
                                        } else {
                                          //if we are on the last one show a widget
                                          currentVideoIndex = videoFiles.length; //set a value outsite of the list
                                        }
                                      });
                                    }
                                  : null, //disable if no videos available
                                icon: Icon(Icons.arrow_back),
                              ),
                              SizedBox(width: 30,),
                              IconButton(
                                color: Colors.white,
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                                iconSize: 32,
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
                                icon: Icon(Icons.arrow_forward),
                              ),
                            ],
                          ),
                          SizedBox(height: 10,),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.black,
                                ),
                                label: Text(
                                  "Delete",
                                  style: TextStyle(
                                    color: Colors.black,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: hasVideos ? deleteCurrentVideo : null, //disable if no videos available
                              ),
                              const SizedBox(width: 20),
                              ElevatedButton.icon(
                                icon: Icon(
                                  Icons.check,
                                  color: Colors.black,
                                ),
                                label: Text(
                                  "Keep",
                                  style: TextStyle(
                                    color: Colors.black
                                  ),
                                  ),
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
                          ),
                        ],
                      )
                    ],
                  ),
                ),
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
              // Drawer custom che scorre da destra sotto la appbar
              AnimatedPositioned(
                duration: Duration(milliseconds: 300),
                top: 0,  // cambia qui da kToolbarHeight a 0
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
                            divisions: Platform.numberOfProcessors,
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
                            divisions: 99,
                            onChanged: (double value) {
                              setState(() {
                                framesNumber = value.toInt();
                                print(framesNumber);
                              });
                            },
                          ),
                          SizedBox(height: 50,),
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
                              )
                            ],
                          ),
                          //TODO: Add quality settings
                          //modify this in python script:
                          //thumb_size = (360, 640) if frames[0].height > frames[0].width else (640, 360)
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