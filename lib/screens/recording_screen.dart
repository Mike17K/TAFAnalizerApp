import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/sensor/sensor_bloc.dart';
import '../blocs/sensor/sensor_event.dart';
import '../blocs/sensor/sensor_state.dart';
import '../models/athlete_profile.dart';
import '../models/sensor_reading.dart';
import 'results_screen.dart';

class RecordingScreen extends StatefulWidget {
  final AthleteProfile profile;
  const RecordingScreen({super.key, required this.profile});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(int ms) {
    final total = ms ~/ 1000;
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return BlocProvider(
      create: (_) => SensorBloc(),
      child: BlocConsumer<SensorBloc, SensorState>(
        listener: (context, state) {
          if (state is SensorComplete) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ResultsScreen(
                    result: state.result, profile: widget.profile),
              ),
            );
          } else if (state is SensorError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: cs.error,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        builder: (context, state) {
          final recordingState = state is SensorRecording ? state : null;
          final isRecording = recordingState != null;
          final latest = recordingState?.latest;
          final elapsedMs = recordingState?.elapsedMs ?? 0;

          return PopScope(
            canPop: !isRecording,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && isRecording) {
                _showStopDialog(context);
              }
            },
            child: Scaffold(
              backgroundColor: cs.surface,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  isRecording ? 'Recording...' : 'Ready',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                actions: [
                  if (isRecording)
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Chip(
                        avatar: const Icon(Icons.timer_outlined, size: 16),
                        label: Text(_formatDuration(elapsedMs)),
                        backgroundColor: cs.errorContainer,
                        labelStyle: TextStyle(
                          color: cs.onErrorContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    // Live readings panel
                    Expanded(
                      child: isRecording && latest != null
                          ? _LiveReadingsPanel(reading: latest)
                          : _IdlePanel(profile: widget.profile),
                    ),

                    // Big action button at bottom
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 24),
                      child: isRecording
                          ? _StopButton(
                              onStop: () => context
                                  .read<SensorBloc>()
                                  .add(StopRecordingEvent()))
                          : ScaleTransition(
                              scale: _pulseAnim,
                              child: _StartButton(
                                onStart: () {
                                  context.read<SensorBloc>().add(
                                        StartRecordingEvent(
                                          athleteWeightKg:
                                              widget.profile.weightKg,
                                          athleteName: widget.profile.name,
                                        ),
                                      );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showStopDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop Recording?'),
        content: const Text(
            'Going back will stop the current recording. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Recording'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SensorBloc>().add(StopRecordingEvent());
            },
            child: const Text('Stop & View'),
          ),
        ],
      ),
    );
  }
}

// 
class _StartButton extends StatelessWidget {
  final VoidCallback onStart;
  const _StartButton({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 100,
      child: FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.play_circle, size: 36),
        label: const Text('START'),
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  final VoidCallback onStop;
  const _StopButton({required this.onStop});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      height: 100,
      child: FilledButton.icon(
        onPressed: onStop,
        icon: const Icon(Icons.stop_circle, size: 36),
        label: const Text('STOP'),
        style: FilledButton.styleFrom(
          backgroundColor: cs.error,
          foregroundColor: cs.onError,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          textStyle: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

// 
class _IdlePanel extends StatelessWidget {
  final AthleteProfile profile;
  const _IdlePanel({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sensors, size: 80, color: cs.primary.withOpacity(0.6)),
            const SizedBox(height: 24),
            Text(
              'Ready to Record',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _InfoRow(Icons.person, 'Athlete', profile.name),
                  const Divider(height: 16),
                  _InfoRow(Icons.monitor_weight_outlined, 'Body Weight',
                      '${profile.weightKg.toStringAsFixed(1)} kg'),
                  const Divider(height: 16),
                  _InfoRow(Icons.smartphone, 'Device', 'Phone Sensors'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Secure your phone to your chest, then press START',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 12),
        Text(label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant)),
        const Spacer(),
        Text(value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// 
class _LiveReadingsPanel extends StatelessWidget {
  final SensorReading reading;
  const _LiveReadingsPanel({required this.reading});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SensorCard(
                  title: 'LINEAR ACCEL',
                  icon: Icons.vibration,
                  color: cs.primary,
                  values: {
                    'X': reading.accelX,
                    'Y': reading.accelY,
                    'Z': reading.accelZ,
                  },
                  unit: 'm/s',
                  magnitude: reading.accelMagnitude,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SensorCard(
                  title: 'GYROSCOPE',
                  icon: Icons.rotate_90_degrees_ccw,
                  color: cs.secondary,
                  values: {
                    'X': reading.gyroX,
                    'Y': reading.gyroY,
                    'Z': reading.gyroZ,
                  },
                  unit: 'rad/s',
                  magnitude: reading.gyroMagnitude,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AngleChip('Pitch', reading.pitch, ''),
                _AngleChip('Roll', reading.roll, ''),
                _AngleChip('Yaw', reading.yaw, ''),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Recording indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'RECORDING    ${reading.accelMagnitude.toStringAsFixed(2)} m/s  peak',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Map<String, double> values;
  final String unit;
  final double magnitude;

  const _SensorCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.values,
    required this.unit,
    required this.magnitude,
  });

  static const _axisColors = [Colors.red, Colors.green, Colors.blue];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(title,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 9,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          ...values.entries.toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final axis = entry.value.key;
            final val = entry.value.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: _axisColors[idx % 3],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(axis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      )),
                  const Spacer(),
                  Text(val.toStringAsFixed(2),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      )),
                ],
              ),
            );
          }),
          const Divider(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('|mag|',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
              Text('${magnitude.toStringAsFixed(2)} $unit',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _AngleChip extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  const _AngleChip(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: cs.onSurfaceVariant, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          '${value.toStringAsFixed(1)}$unit',
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
