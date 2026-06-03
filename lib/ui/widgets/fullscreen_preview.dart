import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;
import '../theme/app_colors.dart';
import '../../customTypes.dart';

/// Full-window preview.
/// - Photos  → collage/image zoomabile
/// - Videos  → prima mostra il collage; il pulsante ▶ avvia il player
///             (un solo player, senza controlli nativi sovrapposti)
class FullscreenPreview extends StatefulWidget {
  final MediaClass media;
  final bool isKept;
  final VoidCallback onDelete;
  final VoidCallback onKeep;
  final VoidCallback onClose;

  const FullscreenPreview({
    Key? key,
    required this.media,
    required this.isKept,
    required this.onDelete,
    required this.onKeep,
    required this.onClose,
  }) : super(key: key);

  @override
  State<FullscreenPreview> createState() => _FullscreenPreviewState();
}

class _FullscreenPreviewState extends State<FullscreenPreview> {
  // Video state
  bool _videoActive = false;   // false = show collage, true = show player
  Player? _player;
  VideoController? _videoController;
  bool _isPlaying = false;
  bool _controlsVisible = false;

  // ── paths ────────────────────────────────────────────────────────────────
  String get _collagePath {
    final base = p.basenameWithoutExtension(widget.media.path);
    return p.join(p.dirname(widget.media.path), '${base}_collage.jpg');
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  // ── video control ──────────────────────────────────────────────────────────
  void _startVideo() {
    _player = Player();
    _videoController = VideoController(_player!);
    _player!.open(Media(widget.media.path));
    _player!.stream.playing.listen((v) {
      if (mounted) setState(() => _isPlaying = v);
    });
    setState(() => _videoActive = true);
  }

  void _stopVideo() {
    _player?.dispose();
    _player = null;
    _videoController = null;
    setState(() {
      _videoActive = false;
      _isPlaying = false;
    });
  }

  void _togglePlayPause() => _player?.playOrPause();

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (_videoActive) {
            _stopVideo();
          } else {
            widget.onClose();
          }
        }
        if (event.logicalKey == LogicalKeyboardKey.space && _videoActive) {
          _togglePlayPause();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Main area ─────────────────────────────────────────────────
            _buildMainContent(),

            // ── Top bar ───────────────────────────────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: _TopBar(
                media: widget.media,
                isKept: widget.isKept,
                isVideoActive: _videoActive,
                onClose: _videoActive ? _stopVideo : widget.onClose,
                onDelete: widget.onDelete,
                onKeep: widget.onKeep,
              ),
            ),

            // ── Video controls overlay (only while player is active) ──────
            if (_videoActive && _player != null)
              MouseRegion(
                opaque: false,
                onEnter: (_) => setState(() => _controlsVisible = true),
                onExit: (_) => setState(() => _controlsVisible = false),
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _VideoControls(
                      player: _player!,
                      isPlaying: _isPlaying,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (!widget.media.isVideo) {
      // Photo – just show full-res image
      return _buildCollageViewer(widget.media.path);
    }

    if (_videoActive && _videoController != null) {
      // Video player – niente controlli built-in di media_kit
      return Video(
        controller: _videoController!,
        controls: NoVideoControls,   // ← disabilita i controlli nativi
      );
    }

    // Collage preview per video – click centrale avvia player
    return GestureDetector(
      onTap: _startVideo,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildCollageViewer(_collagePath),
          // Big play button overlay
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 44),
            ),
          ),
          // Hint text
          const Positioned(
            bottom: 80,
            left: 0, right: 0,
            child: Center(
              child: Text(
                'Click to play video',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollageViewer(String path) {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() == 0) {
      return const Center(
        child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary, size: 64),
      );
    }
    return InteractiveViewer(
      maxScale: 6.0,
      minScale: 0.5,
      child: Center(
        child: Image.file(
          file,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final MediaClass media;
  final bool isKept;
  final bool isVideoActive;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onKeep;

  const _TopBar({
    required this.media,
    required this.isKept,
    required this.isVideoActive,
    required this.onClose,
    required this.onDelete,
    required this.onKeep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Close / Back to collage
          _TopBarButton(
            icon: isVideoActive ? Icons.arrow_back_rounded : Icons.close_rounded,
            tooltip: isVideoActive ? 'Back to collage (Esc)' : 'Close (Esc)',
            onTap: onClose,
          ),
          const SizedBox(width: 16),

          // File name
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.basename(media.path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isVideoActive)
                  const Text(
                    'Video Player',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  )
                else if (media.isVideo)
                  const Text(
                    'Collage preview',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),

          // Keep badge
          if (isKept)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF3ECF8E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF3ECF8E).withValues(alpha: 0.5),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 13, color: Color(0xFF3ECF8E)),
                  SizedBox(width: 4),
                  Text(
                    'Kept',
                    style: TextStyle(
                      color: Color(0xFF3ECF8E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Delete
          _TopBarButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete',
            color: const Color(0xFFFF5C5C),
            onTap: onDelete,
          ),
          const SizedBox(width: 8),

          // Keep / Un-keep
          _TopBarButton(
            icon: isKept ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
            tooltip: isKept ? 'Remove from kept' : 'Keep',
            color: const Color(0xFF3ECF8E),
            onTap: onKeep,
          ),
        ],
      ),
    );
  }
}

class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _TopBarButton({
    required this.icon,
    required this.tooltip,
    this.color = AppColors.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom video controls bar (bottom overlay)
// ─────────────────────────────────────────────────────────────────────────────
class _VideoControls extends StatefulWidget {
  final Player player;
  final bool isPlaying;

  const _VideoControls({required this.player, required this.isPlaying});

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  double _position = 0;
  double _duration = 1;
  double _volume = 100;
  bool _isDragging = false;
  late final List<StreamSubscription<dynamic>> _subs;

  @override
  void initState() {
    super.initState();
    _subs = [
      widget.player.stream.position.listen((pos) {
        if (mounted && !_isDragging) setState(() => _position = pos.inMilliseconds.toDouble());
      }),
      widget.player.stream.duration.listen((dur) {
        if (mounted && dur.inMilliseconds > 0) {
          setState(() => _duration = dur.inMilliseconds.toDouble());
        }
      }),
      widget.player.stream.volume.listen((vol) {
        if (mounted) setState(() => _volume = vol);
      }),
    ];
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  String _fmt(double ms) {
    final d = Duration(milliseconds: ms.toInt());
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.88),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Seek bar
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
              overlayColor: Colors.white24,
            ),
            child: Slider(
              value: _position.clamp(0, _duration),
              min: 0,
              max: _duration,
              onChanged: (val) {
                setState(() => _position = val);
              },
              onChangeStart: (_) {
                _isDragging = true;
              },
              onChangeEnd: (val) {
                widget.player.seek(Duration(milliseconds: val.toInt()));
                _isDragging = false;
              },
            ),
          ),

          // Controls row
          Row(
            children: [
              // Play / Pause
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  widget.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: () => widget.player.playOrPause(),
              ),
              const SizedBox(width: 12),

              // Time
              Text(
                '${_fmt(_position)} / ${_fmt(_duration)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),

              const Spacer(),

              // Volume icon + mini slider
              Icon(
                _volume == 0
                    ? Icons.volume_off_rounded
                    : (_volume < 50
                        ? Icons.volume_down_rounded
                        : Icons.volume_up_rounded),
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 80,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    value: _volume,
                    min: 0,
                    max: 100,
                    onChanged: (val) {
                      widget.player.setVolume(val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
