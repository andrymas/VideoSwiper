import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../theme/app_colors.dart';
import '../../customTypes.dart';

/// Robust image loader from local file with spinner + broken_image fallback.
class _LocalImage extends StatelessWidget {
  final String path;
  final BoxFit fit;

  const _LocalImage({required this.path, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() == 0) {
      return _buildError();
    }

    return Image.file(
      file,
      fit: fit,
      frameBuilder: (ctx, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.textSecondary),
          ),
        );
      },
      errorBuilder: (ctx, error, stack) => _buildError(),
    );
  }

  Widget _buildError() => Container(
    color: const Color(0xFF1A1A1D),
    child: const Center(
      child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary, size: 36),
    ),
  );
}

class VideoCard extends StatefulWidget {
  final MediaClass media;
  final bool isKept;
  final VoidCallback onDelete;
  final VoidCallback onKeep;
  final VoidCallback onTap;

  const VideoCard({
    Key? key,
    required this.media,
    required this.isKept,
    required this.onDelete,
    required this.onKeep,
    required this.onTap,
  }) : super(key: key);

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  bool _isHovered = false;

  String _getThumbnailPath(MediaClass mediaFile) {
    if (mediaFile.isVideo) {
      final base = p.basenameWithoutExtension(mediaFile.path);
      final dir = p.dirname(mediaFile.path);
      return p.join(dir, '${base}_collage.jpg');
    }
    return mediaFile.path;
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basenameWithoutExtension(widget.media.path);
    final fileSizeMB = (widget.media.fileReference.lengthSync() / (1024 * 1024)).toStringAsFixed(1);
    final thumbPath = _getThumbnailPath(widget.media);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: _isHovered
              ? (Matrix4.diagonal3Values(1.025, 1.025, 1.0))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: AppColors.panelBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isKept
                  ? const Color(0xFF3ECF8E).withOpacity(0.7)
                  : (_isHovered ? AppColors.active : AppColors.border),
              width: widget.isKept ? 1.5 : 1,
            ),
            boxShadow: _isHovered
                ? [BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 18, offset: const Offset(0, 8))]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Thumbnail ────────────────────────────────────────────────
                _LocalImage(path: thumbPath, fit: BoxFit.cover),

                // ── Bottom gradient overlay ───────────────────────────────────
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black],
                      stops: [0.45, 1.0],
                    ),
                  ),
                ),

                // ── File info at the bottom ───────────────────────────────────
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
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
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '$fileSizeMB MB',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          if (widget.isKept) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3ECF8E).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                '✓ Kept',
                                style: TextStyle(
                                  color: Color(0xFF3ECF8E),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // ── Action buttons (visible on hover) ─────────────────────────
                AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ActionButton(
                            icon: Icons.delete_outline_rounded,
                            color: const Color(0xFFFF5C5C),
                            tooltip: 'Delete',
                            onTap: widget.onDelete,
                          ),
                          const SizedBox(width: 6),
                          _ActionButton(
                            icon: widget.isKept
                                ? Icons.check_circle_rounded
                                : Icons.check_circle_outline_rounded,
                            color: const Color(0xFF3ECF8E),
                            tooltip: widget.isKept ? 'Un-keep' : 'Keep',
                            onTap: widget.onKeep,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Video badge ────────────────────────────────────────────────
                if (widget.media.isVideo)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
