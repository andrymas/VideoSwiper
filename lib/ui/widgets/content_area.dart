import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'video_card.dart';
import 'fullscreen_preview.dart';
import '../../customTypes.dart';

class ContentArea extends StatefulWidget {
  final List<MediaClass> mediaFiles;
  final Set<String> keptPaths;
  final Function(MediaClass) onDelete;
  final Function(MediaClass) onKeep;
  final VoidCallback onPickFolder;
  final bool isSidebarVisible;
  final VoidCallback onToggleSidebar;

  const ContentArea({
    Key? key,
    required this.mediaFiles,
    required this.keptPaths,
    required this.onDelete,
    required this.onKeep,
    required this.onPickFolder,
    required this.isSidebarVisible,
    required this.onToggleSidebar,
  }) : super(key: key);

  @override
  State<ContentArea> createState() => _ContentAreaState();
}

class _ContentAreaState extends State<ContentArea> {
  MediaClass? _previewMedia;

  void _openPreview(MediaClass media) => setState(() => _previewMedia = media);
  void _closePreview() => setState(() => _previewMedia = null);

  @override
  Widget build(BuildContext context) {
    // Full-window preview overlay
    if (_previewMedia != null) {
      final media = _previewMedia!;
      return FullscreenPreview(
        media: media,
        isKept: widget.keptPaths.contains(media.path),
        onClose: _closePreview,
        onDelete: () {
          widget.onDelete(media);
          _closePreview();
        },
        onKeep: () {
          widget.onKeep(media);
          // Keep does NOT close preview – just refreshes the badge state.
          setState(() {});
        },
      );
    }

    // Normal grid view
    return Column(
      children: [
        _buildHeader(),
        Expanded(child: _buildGrid()),
      ],
    );
  }

  Widget _buildHeader() {
    final count = widget.mediaFiles.length;
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 32),
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
            'Library',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$count ${count == 1 ? 'file' : 'files'}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (widget.mediaFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined, size: 56, color: AppColors.border),
            const SizedBox(height: 16),
            const Text(
              'No media loaded. Open a folder to get started.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(28),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        childAspectRatio: 16 / 9,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: widget.mediaFiles.length,
      itemBuilder: (context, index) {
        final media = widget.mediaFiles[index];
        return VideoCard(
          key: ValueKey(media.path),
          media: media,
          isKept: widget.keptPaths.contains(media.path),
          onDelete: () => widget.onDelete(media),
          onKeep: () => widget.onKeep(media),
          onTap: () => _openPreview(media),
        );
      },
    );
  }
}


