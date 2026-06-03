import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/view_mode.dart';
import '../widgets/sidebar.dart';
import '../widgets/content_area.dart';
import '../screens/swiper_view.dart';
import '../../customTypes.dart';

class MainLayout extends StatelessWidget {
  final List<MediaClass> mediaFiles;
  final Set<String> keptPaths;
  final ViewMode currentView;
  final VoidCallback onPickFolder;
  final VoidCallback onSettingsPressed;
  final VoidCallback onShowVersionInfo;
  final VoidCallback onMediaGathererPressed;
  final ValueChanged<ViewMode> onViewChanged;
  final Function(MediaClass) onDelete;
  final Function(MediaClass) onKeep;
  final bool isSidebarVisible;
  final VoidCallback onToggleSidebar;

  const MainLayout({
    Key? key,
    required this.mediaFiles,
    required this.keptPaths,
    required this.currentView,
    required this.onPickFolder,
    required this.onSettingsPressed,
    required this.onShowVersionInfo,
    required this.onMediaGathererPressed,
    required this.onViewChanged,
    required this.onDelete,
    required this.onKeep,
    required this.isSidebarVisible,
    required this.onToggleSidebar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar
          if (isSidebarVisible) ...[
            Sidebar(
              currentView: currentView,
              onPickFolder: onPickFolder,
              onSettingsPressed: onSettingsPressed,
              onMediaGathererPressed: onMediaGathererPressed,
              onVersionInfoPressed: onShowVersionInfo,
              onViewChanged: onViewChanged,
            ),
            // 1px separator
            Container(width: 1, color: AppColors.border),
          ],

          // Content area
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (currentView) {
      case ViewMode.library:
        return ContentArea(
          mediaFiles: mediaFiles,
          keptPaths: keptPaths,
          onDelete: onDelete,
          onKeep: onKeep,
          onPickFolder: onPickFolder,
          onToggleSidebar: onToggleSidebar,
          isSidebarVisible: isSidebarVisible,
        );
      case ViewMode.swiper:
        return SwiperView(
          mediaFiles: mediaFiles,
          keptPaths: keptPaths,
          onDelete: onDelete,
          onKeep: onKeep,
          onToggleSidebar: onToggleSidebar,
          isSidebarVisible: isSidebarVisible,
        );
    }
  }
}
