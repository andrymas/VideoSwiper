import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import '../theme/app_colors.dart';
import '../widgets/fullscreen_preview.dart';
import '../../customTypes.dart';

/// Vista Swiper: mostra i media uno alla volta, navigazione con tasti o pulsanti.
/// Schiacciare il collage / pulsante Play apre il player a schermo intero.
class SwiperView extends StatefulWidget {
  final List<MediaClass> mediaFiles;
  final Set<String> keptPaths;
  final Function(MediaClass) onDelete;
  final Function(MediaClass) onKeep;
  final bool isSidebarVisible;
  final VoidCallback onToggleSidebar;

  const SwiperView({
    Key? key,
    required this.mediaFiles,
    required this.keptPaths,
    required this.onDelete,
    required this.onKeep,
    required this.isSidebarVisible,
    required this.onToggleSidebar,
  }) : super(key: key);

  @override
  State<SwiperView> createState() => _SwiperViewState();
}

class _SwiperViewState extends State<SwiperView>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _inFullscreen = false;

  // Animazione slide per la transizione tra media
  late final AnimationController _animController;
  late Animation<double> _slideAnim;
  int _slideDir = 1; // 1 = avanti, -1 = indietro

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _buildAnimation();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _buildAnimation() {
    _slideAnim = Tween<double>(begin: 60.0 * _slideDir, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
  }

  void _goTo(int newIndex) {
    if (widget.mediaFiles.isEmpty) return;
    final clamped = newIndex.clamp(0, widget.mediaFiles.length - 1);
    if (clamped == _index) return;
    _slideDir = clamped > _index ? 1 : -1;
    _buildAnimation();
    setState(() => _index = clamped);
    _animController.forward(from: 0);
  }

  void _next() {
    if (_index < widget.mediaFiles.length - 1) _goTo(_index + 1);
  }

  void _prev() {
    if (_index > 0) _goTo(_index - 1);
  }

  void _delete() {
    final media = widget.mediaFiles[_index];
    widget.onDelete(media);
    // index si aggiusta da solo se l'elenco si accorcia
    if (_index >= widget.mediaFiles.length && _index > 0) {
      setState(() => _index = widget.mediaFiles.length - 1);
    } else {
      setState(() {});
    }
  }

  void _keep() {
    widget.onKeep(widget.mediaFiles[_index]);
    setState(() {});
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Schermo intero preview (video player / image zoom)
    if (_inFullscreen && widget.mediaFiles.isNotEmpty) {
      final media = widget.mediaFiles[_index];
      return FullscreenPreview(
        media: media,
        isKept: widget.keptPaths.contains(media.path),
        onClose: () => setState(() => _inFullscreen = false),
        onDelete: () {
          widget.onDelete(media);
          setState(() {
            _inFullscreen = false;
            if (_index >= widget.mediaFiles.length && _index > 0) {
              _index = widget.mediaFiles.length - 1;
            }
          });
        },
        onKeep: () {
          widget.onKeep(media);
          setState(() {});
        },
      );
    }

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is! KeyDownEvent) return;
        if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
            event.logicalKey == LogicalKeyboardKey.arrowDown) _next();
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
            event.logicalKey == LogicalKeyboardKey.arrowUp) _prev();
        if (event.logicalKey == LogicalKeyboardKey.delete) _delete();
        if (event.logicalKey == LogicalKeyboardKey.keyK) _keep();
      },
      child: widget.mediaFiles.isEmpty
          ? _buildEmpty()
          : _buildSwiper(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined, size: 56, color: AppColors.border),
          const SizedBox(height: 16),
          const Text(
            'No media loaded.\nOpen a folder to start swiping.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildSwiper() {
    final media = widget.mediaFiles[_index];
    final isKept = widget.keptPaths.contains(media.path);

    return Column(
      children: [
        // ── Top progress bar + counter ────────────────────────────────────
        _buildProgressHeader(),

        // ── Main collage / image ───────────────────────────────────────────
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Collage con animazione slide
              AnimatedBuilder(
                animation: _animController,
                builder: (ctx, child) => Transform.translate(
                  offset: Offset(_slideAnim.value, 0),
                  child: child,
                ),
                child: _CollageViewer(
                  key: ValueKey(media.path),
                  media: media,
                  isKept: isKept,
                ),
              ),

              // ── Freccia sinistra ─────────────────────────────────────────
              if (_index > 0)
                Positioned(
                  left: 20,
                  top: 0, bottom: 0,
                  child: Center(
                    child: _NavArrow(
                      icon: Icons.chevron_left_rounded,
                      onTap: _prev,
                    ),
                  ),
                ),

              // ── Freccia destra ───────────────────────────────────────────
              if (_index < widget.mediaFiles.length - 1)
                Positioned(
                  right: 20,
                  top: 0, bottom: 0,
                  child: Center(
                    child: _NavArrow(
                      icon: Icons.chevron_right_rounded,
                      onTap: _next,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Bottom action bar ──────────────────────────────────────────────
        _buildActionBar(media, isKept),
      ],
    );
  }

  Widget _buildProgressHeader() {
    final total = widget.mediaFiles.length;
    final current = _index + 1;
    final progress = total > 0 ? current / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              widget.isSidebarVisible ? Icons.menu_open_rounded : Icons.menu_rounded,
              color: AppColors.textSecondary,
              size: 24,
            ),
            splashRadius: 20,
            onPressed: widget.onToggleSidebar,
            tooltip: 'Toggle Sidebar',
          ),
          const SizedBox(width: 12),
          Text(
            'Swiper',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation(AppColors.active),
                    minHeight: 3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$current / $total',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(MediaClass media, bool isKept) {
    final fileName = p.basenameWithoutExtension(media.path);
    final ext = p.extension(media.path).toLowerCase();
    final fileSizeMB = (media.fileReference.lengthSync() / (1024 * 1024))
        .toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '$fileSizeMB MB',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.hover,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ext.isEmpty ? 'file' : ext.substring(1).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isKept) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3ECF8E)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '✓ Kept',
                          style: TextStyle(
                            color: Color(0xFF3ECF8E),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Keyboard hints
          const _KeyHint(key1: '← →', label: 'Navigate'),

          const SizedBox(width: 24),

          // Delete button
          _ActionBtn(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: const Color(0xFFFF5C5C),
            onTap: _delete,
          ),
          const SizedBox(width: 10),

          // Keep button
          _ActionBtn(
            icon: isKept
                ? Icons.check_circle_rounded
                : Icons.check_circle_outline_rounded,
            label: isKept ? 'Kept ✓' : 'Keep',
            color: const Color(0xFF3ECF8E),
            outlined: isKept,
            onTap: _keep,
          ),

          if (media.isVideo) ...[
            const SizedBox(width: 10),
            _ActionBtn(
              icon: Icons.play_arrow_rounded,
              label: 'Play Video',
              color: Colors.white,
              primary: true,
              onTap: () => setState(() => _inFullscreen = true),
            ),
          ],


        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collage Viewer – mostra il collage o l'immagine del media corrente
// ─────────────────────────────────────────────────────────────────────────────
class _CollageViewer extends StatelessWidget {
  final MediaClass media;
  final bool isKept;

  const _CollageViewer({Key? key, required this.media, required this.isKept})
      : super(key: key);

  String get _imagePath {
    if (media.isVideo) {
      final base = p.basenameWithoutExtension(media.path);
      return p.join(p.dirname(media.path), '${base}_collage.jpg');
    }
    return media.path;
  }

  @override
  Widget build(BuildContext context) {
    final file = File(_imagePath);
    final exists = file.existsSync() && file.lengthSync() > 0;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Image ─────────────────────────────────────────────────────────
          if (exists)
            InteractiveViewer(
              minScale: 1.0,
              maxScale: 5.0,
              child: Image.file(
                file,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                frameBuilder: (ctx, child, frame, _) {
                  if (frame != null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textSecondary,
                    size: 64,
                  ),
                ),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    media.isVideo
                        ? Icons.video_file_outlined
                        : Icons.image_not_supported_outlined,
                    color: AppColors.textSecondary,
                    size: 64,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No preview available',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),



          // ── Kept badge top-right ──────────────────────────────────────────
          if (isKept)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3ECF8E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        const Color(0xFF3ECF8E).withValues(alpha: 0.6),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded,
                        size: 13, color: Color(0xFF3ECF8E)),
                    SizedBox(width: 4),
                    Text('Kept',
                        style: TextStyle(
                            color: Color(0xFF3ECF8E),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav Arrow button
// ─────────────────────────────────────────────────────────────────────────────
class _NavArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavArrow({required this.icon, required this.onTap});

  @override
  State<_NavArrow> createState() => _NavArrowState();
}

class _NavArrowState extends State<_NavArrow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: _hovered ? 0.35 : 0.15),
            ),
          ),
          child: Icon(
            widget.icon,
            color: Colors.white.withValues(alpha: _hovered ? 1.0 : 0.7),
            size: 28,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Button (Delete / Keep / Play)
// ─────────────────────────────────────────────────────────────────────────────
class _ActionBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool outlined;
  final bool primary;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.outlined = false,
    this.primary = false,
    required this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.primary
        ? (widget.color.withValues(alpha: _hovered ? 1.0 : 0.85))
        : (widget.outlined
            ? widget.color.withValues(alpha: _hovered ? 0.15 : 0.08)
            : widget.color.withValues(alpha: _hovered ? 0.2 : 0.1));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.color.withValues(
                  alpha: widget.primary ? 0 : (_hovered ? 0.5 : 0.25)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 17,
                color: widget.primary ? Colors.black : widget.color,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.primary ? Colors.black : widget.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Keyboard hint chip
// ─────────────────────────────────────────────────────────────────────────────
class _KeyHint extends StatelessWidget {
  final String key1;
  final String label;

  const _KeyHint({required this.key1, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.hover,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            key1,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}
