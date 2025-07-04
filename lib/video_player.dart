import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class MiniVideoPlayer extends StatefulWidget {
  final String videoPath;
  final bool beginPaused;
  final bool beginMuted;

  const MiniVideoPlayer({required this.videoPath, super.key, required this.beginPaused, required this.beginMuted});

  @override
  State<MiniVideoPlayer> createState() => _MiniVideoPlayerState();
}

class _MiniVideoPlayerState extends State<MiniVideoPlayer> {
  late final Player player;
  late final VideoController controller;
  // Aggiungi una variabile di stato per l'aspect ratio
  double _aspectRatio = 16 / 9; // Valore di default

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);

    player.open(Media(widget.videoPath));

    player.stream.width.listen((width) {
      if (player.state.height != null && player.state.height! > 0) {
        setState(() {
          _aspectRatio = width! / player.state.height!;
        });
      }
    });

    player.stream.height.listen((height) {
      if (height != null && height > 0) {
        if (player.state.width != null && player.state.width! > 0) {
          setState(() {
            _aspectRatio = player.state.width! / height;
          });
        }
      }
    });
    
    if(!widget.beginPaused){
      player.pause();
    }
    if(widget.beginMuted){
      player.setVolume(0);
    }
  }

  @override
  void dispose() {
    player.pause();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      // Usa l'aspect ratio calcolato dinamicamente
      aspectRatio: _aspectRatio,
      child: Video(controller: controller),
    );
  }
}