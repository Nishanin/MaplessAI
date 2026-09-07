import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../state/mapping_controller.dart';

/// Creator Walkthrough & Sensor Mapping Screen
/// Owner: Nishant (Complete UI/UX & Sensors)
class CreatorMappingScreen extends ConsumerWidget {
  const CreatorMappingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mappingProvider);
    final controller = ref.read(mappingProvider.notifier);

    return AppScaffold(
      title: 'Creator Mapping Mode',
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: state.isRecordingWalkthrough ? Colors.green.shade50 : Colors.blueGrey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      state.isRecordingWalkthrough ? Icons.fiber_manual_record : Icons.pause_circle_outline,
                      color: state.isRecordingWalkthrough ? Colors.red : Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.isRecordingWalkthrough ? 'Recording Walkthrough...' : 'Creator Idle',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            state.isRecordingWalkthrough
                                ? 'Smartphone sensors tracking steps & headings'
                                : 'Press Start Walkthrough to record hallway paths',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Sensor Readings Grid
            const Text(
              'Live Sensor Telemetry (Creator Only)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                _SensorTile(
                  title: 'Step Counter',
                  value: '${state.recordedSteps} steps',
                  icon: Icons.directions_walk,
                ),
                const SizedBox(width: 12),
                const _SensorTile(
                  title: 'Compass Heading',
                  value: '90.0° (East)',
                  icon: Icons.explore,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                _SensorTile(
                  title: 'Accelerometer',
                  value: 'X: 0.0 Y: 9.8 Z: 0.1',
                  icon: Icons.speed,
                ),
                SizedBox(width: 12),
                _SensorTile(
                  title: 'Gyroscope',
                  value: 'Yaw: 0.01 rad/s',
                  icon: Icons.screen_rotation,
                ),
              ],
            ),

            const Spacer(),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: state.isRecordingWalkthrough ? Colors.red : AppColors.primary,
                ),
                onPressed: () {
                  if (state.isRecordingWalkthrough) {
                    controller.stopWalkthrough();
                  } else {
                    controller.startWalkthrough();
                  }
                },
                icon: Icon(state.isRecordingWalkthrough ? Icons.stop : Icons.play_arrow),
                label: Text(
                  state.isRecordingWalkthrough ? 'Stop Recording' : 'Start Walkthrough',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SensorTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SensorTile({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
