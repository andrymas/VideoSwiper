import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart';
import 'package:videoswiper/src/rust/frb_generated.dart';
import 'package:videoswiper/video_collector.dart';

import 'ui/screens/dashboard_screen.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    await RustLib.init();
    setWindowTitle('VideoSwiper');
    setWindowMinSize(const Size(516, 600));

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800), // Ingrandito di default per la UI a pannelli
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
    runApp(const VideoSwiperApp());
  }
}

class SmoothScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

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
      scrollBehavior: SmoothScrollBehavior(),
      home: const DashboardScreen(),
    );
  }
}
