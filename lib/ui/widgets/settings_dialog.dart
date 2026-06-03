import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/media_controller.dart';
import '../../customTypes.dart';
import '../theme/app_colors.dart';

class SettingsDialog extends StatelessWidget {
  final MediaController controller;

  const SettingsDialog({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panelBackground,
      title: Row(
        children: [
          Icon(Icons.tune, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          Text('Settings', style: TextStyle(color: AppColors.textPrimary)),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 550,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSlider(
                    context: context,
                    icon: Icons.photo_library,
                    label: 'Frames per collage',
                    value: controller.framesNumber.toDouble(),
                    min: 1,
                    max: 100,
                    divisions: 100,
                    onChanged: (val) => controller.setFramesNumber(val.toInt()),
                  ),
                  const SizedBox(height: 24),
                  _buildSlider(
                    context: context,
                    icon: Icons.developer_board,
                    label: 'Threads to use',
                    value: controller.threadsUsed.toDouble(),
                    min: 1,
                    max: Platform.numberOfProcessors.toDouble(),
                    divisions: Platform.numberOfProcessors - 1,
                    onChanged: (val) => controller.setThreadsUsed(val.toInt()),
                  ),
                  if (controller.threadsUsed == Platform.numberOfProcessors)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.yellow, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Warning: using all threads may cause lag.',
                              style: TextStyle(color: Colors.yellow, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  Text('Quality Settings', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  SegmentedButton<QualityLevel>(
                    segments: <ButtonSegment<QualityLevel>>[
                      ButtonSegment<QualityLevel>(value: QualityLevel.lowest, label: Text('Lowest'), icon: Icon(Icons.speed)),
                      ButtonSegment<QualityLevel>(value: QualityLevel.low, label: Text('Low'), icon: Icon(Icons.flash_on)),
                      ButtonSegment<QualityLevel>(value: QualityLevel.medium, label: Text('Medium'), icon: Icon(Icons.balance)),
                      ButtonSegment<QualityLevel>(value: QualityLevel.high, label: Text('High'), icon: Icon(Icons.photo_filter)),
                      ButtonSegment<QualityLevel>(value: QualityLevel.ultra, label: Text('Ultra'), icon: Icon(Icons.auto_awesome)),
                    ],
                    selected: controller.selectedQuality,
                    onSelectionChanged: (newSelection) {
                      if (newSelection.isNotEmpty) {
                        controller.setQuality(newSelection.first);
                      }
                    },
                    style: SegmentedButton.styleFrom(
                      foregroundColor: Colors.blueGrey,
                      selectedBackgroundColor: Colors.blueGrey,
                      selectedForegroundColor: Colors.white,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close', style: TextStyle(color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required BuildContext context,
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                activeColor: Colors.blueGrey,
                value: value,
                min: min,
                max: max,
                divisions: divisions,
                label: value.toInt().toString(),
                onChanged: onChanged,
              ),
            ),
            Text(value.toInt().toString(), style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
