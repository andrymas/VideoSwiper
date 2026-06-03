import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/view_mode.dart';

class Sidebar extends StatelessWidget {
  final ViewMode currentView;
  final VoidCallback onPickFolder;
  final VoidCallback onSettingsPressed;
  final VoidCallback onMediaGathererPressed;
  final VoidCallback onVersionInfoPressed;
  final ValueChanged<ViewMode> onViewChanged;

  const Sidebar({
    Key? key,
    required this.currentView,
    required this.onPickFolder,
    required this.onSettingsPressed,
    required this.onMediaGathererPressed,
    required this.onVersionInfoPressed,
    required this.onViewChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppColors.panelBackground,
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Logo ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 8.0, bottom: 28.0),
            child: Row(
              children: [
                const Icon(Icons.video_library_rounded,
                    color: AppColors.textPrimary, size: 22),
                const SizedBox(width: 10),
                const Text(
                  'VideoSwiper',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          // ── Views ────────────────────────────────────────────────────────
          _SectionLabel('VIEWS'),
          const SizedBox(height: 4),
          _NavItem(
            icon: Icons.grid_view_rounded,
            label: 'Library',
            isActive: currentView == ViewMode.library,
            onTap: () => onViewChanged(ViewMode.library),
          ),
          _NavItem(
            icon: Icons.swipe_right_alt_rounded,
            label: 'Swiper',
            isActive: currentView == ViewMode.swiper,
            onTap: () => onViewChanged(ViewMode.swiper),
          ),

          const SizedBox(height: 20),

          // ── Actions ──────────────────────────────────────────────────────
          _SectionLabel('ACTIONS'),
          const SizedBox(height: 4),
          _NavItem(
            icon: Icons.create_new_folder_outlined,
            label: 'Open Folder',
            onTap: onPickFolder,
          ),
          _NavItem(
            icon: Icons.archive_outlined,
            label: 'Media Gatherer',
            onTap: onMediaGathererPressed,
          ),

          const Spacer(),

          // ── Footer ──────────────────────────────────────────────────────
          _NavItem(
            icon: Icons.info_outline_rounded,
            label: 'Version Info',
            onTap: onVersionInfoPressed,
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: onSettingsPressed,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 2.0),
          padding: const EdgeInsets.symmetric(vertical: 9.0, horizontal: 12.0),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.active.withValues(alpha: 0.25)
                : (_isHovered ? AppColors.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(8.0),
            border: widget.isActive
                ? Border.all(color: AppColors.active.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.isActive
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: widget.isActive
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
