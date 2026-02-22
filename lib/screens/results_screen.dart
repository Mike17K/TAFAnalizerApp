import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/leaderboard/leaderboard_bloc.dart';
import '../blocs/leaderboard/leaderboard_event.dart';
import '../models/athlete_profile.dart';
import '../models/leaderboard_entry.dart';
import '../models/sensor_reading.dart';
import '../models/session_result.dart';
import '../widgets/orientation_3d_widget.dart';

class ResultsScreen extends StatefulWidget {
  final SessionResult result;
  final AthleteProfile profile;

  const ResultsScreen({
    super.key,
    required this.result,
    required this.profile,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  double _scrubberPosition = 0; // 0.0 to 1.0

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    // Initialise scrubber at peak
    if (widget.result.readings.isNotEmpty) {
      _scrubberPosition =
          widget.result.peakReadingIndex / (widget.result.readings.length - 1);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // Downsample readings to at most maxPts for chart performance
  List<SensorReading> _downsample(int maxPts) {
    final r = widget.result.readings;
    if (r.length <= maxPts) return r;
    final step = r.length / maxPts;
    return List.generate(maxPts, (i) => r[(i * step).floor()]);
  }

  SensorReading get _currentReading {
    final idx = (_scrubberPosition * (widget.result.readings.length - 1))
        .round()
        .clamp(0, widget.result.readings.length - 1);
    return widget.result.readings[idx];
  }

  String _formatDur(double secs) {
    final s = secs.floor();
    final ms = ((secs - s) * 100).floor();
    return '${(s ~/ 60).toString().padLeft(2, "0")}:'
        '${(s % 60).toString().padLeft(2, "0")}.'
        '${ms.toString().padLeft(2, "0")}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final result = widget.result;
    final peak = result.peakReading;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Session Results',
            style:
                theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          //  Stats row 
          _buildStatsRow(cs, theme, result),

          const SizedBox(height: 20),
          //  Charts section 
          _buildChartsSection(theme, cs),

          const SizedBox(height: 20),
          //  Force Direction 3D 
          if (peak != null) ...[
            _SectionHeader('Peak Force Direction', Icons.bolt),
            const SizedBox(height: 12),
            Center(
              child: ForceVector3D(
                ax: peak.accelX,
                ay: peak.accelY,
                az: peak.accelZ,
                peakForceKg: result.peakForceKg,
                size: 260,
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Direction of peak ${result.peakForceKg.toStringAsFixed(1)} kg force '
                'at t=${_formatDur(peak.timeSeconds)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 20),
          //  3D Orientation Replay 
          _SectionHeader('Orientation Replay', Icons.accessibility_new),
          const SizedBox(height: 8),
          Center(
            child: OrientationFigure3D(
              pitch: _currentReading.pitch,
              roll: _currentReading.roll,
              yaw: _currentReading.yaw,
              primaryColor: cs.primary,
              accentColor: cs.secondary,
              size: 260,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'P:${_currentReading.pitch.toStringAsFixed(1)}  '
                'R:${_currentReading.roll.toStringAsFixed(1)}  '
                'Y:${_currentReading.yaw.toStringAsFixed(1)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                't=${_formatDur(_currentReading.timeSeconds)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          Slider(
            value: _scrubberPosition,
            onChanged: (v) => setState(() => _scrubberPosition = v),
            activeColor: cs.primary,
            inactiveColor: cs.outlineVariant,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0:00.00', style: theme.textTheme.labelSmall),
              Text(_formatDur(result.durationSeconds),
                  style: theme.textTheme.labelSmall),
            ],
          ),

          const SizedBox(height: 20),
          //  Leaderboard button 
          _buildLeaderboardButton(context, cs, theme, result),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ColorScheme cs, ThemeData theme, SessionResult result) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Peak Force',
            value: '${result.peakForceKg.toStringAsFixed(1)}',
            unit: 'kg',
            icon: Icons.fitness_center,
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Peak Accel',
            value: '${result.peakAccelMagnitude.toStringAsFixed(2)}',
            unit: 'm/s',
            icon: Icons.speed,
            color: cs.secondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Duration',
            value: _formatDur(result.durationSeconds),
            unit: '',
            icon: Icons.timer_outlined,
            color: cs.tertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildChartsSection(ThemeData theme, ColorScheme cs) {
    final ds = _downsample(400);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader('Sensor Data', Icons.show_chart),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              TabBar(
                controller: _tabCtrl,
                labelColor: cs.primary,
                unselectedLabelColor: cs.onSurfaceVariant,
                indicatorColor: cs.primary,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: 'ACCEL'),
                  Tab(text: 'EULER'),
                  Tab(text: 'GYRO'),
                  Tab(text: 'GYRO |M|'),
                ],
              ),
              SizedBox(
                height: 220,
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // 1. Accelerometer x/y/z
                    _SensorChart(
                      readings: ds,
                      line1: (r) => r.accelX,
                      line2: (r) => r.accelY,
                      line3: (r) => r.accelZ,
                      l1Name: 'X', l2Name: 'Y', l3Name: 'Z',
                      unit: 'm/s',
                      peakXs: [widget.result.readings[widget.result.peakReadingIndex].timeSeconds],
                    ),
                    // 2. Euler angles
                    _SensorChart(
                      readings: ds,
                      line1: (r) => r.pitch,
                      line2: (r) => r.roll,
                      line3: (r) => r.yaw,
                      l1Name: 'Pitch', l2Name: 'Roll', l3Name: 'Yaw',
                      unit: '',
                      peakXs: [],
                    ),
                    // 3. Gyroscope x/y/z
                    _SensorChart(
                      readings: ds,
                      line1: (r) => r.gyroX,
                      line2: (r) => r.gyroY,
                      line3: (r) => r.gyroZ,
                      l1Name: 'X', l2Name: 'Y', l3Name: 'Z',
                      unit: 'rad/s',
                      peakXs: [widget.result.readings[widget.result.peakReadingIndex].timeSeconds],
                    ),
                    // 4. Gyro magnitude
                    _GyroMagnitudeChart(readings: ds),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardButton(
      BuildContext context, ColorScheme cs, ThemeData theme, SessionResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader('Leaderboard', Icons.leaderboard_outlined),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.add_chart),
          label: const Text('Submit to Leaderboard'),
          onPressed: () => _showLeaderboardDialog(context, result),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ],
    );
  }

  void _showLeaderboardDialog(BuildContext context, SessionResult result) {
    final notesCtrl = TextEditingController();
    bool validated = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return AlertDialog(
            title: const Text('Submit to Leaderboard'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResultRow('Athlete', result.athleteName),
                _ResultRow('Peak Force',
                    '${result.peakForceKg.toStringAsFixed(2)} kg'),
                _ResultRow('Peak Accel',
                    '${result.peakAccelMagnitude.toStringAsFixed(3)} m/s'),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mark as Validated'),
                    Switch(
                      value: validated,
                      onChanged: (v) => setS(() => validated = v),
                    ),
                  ],
                ),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    hintText: 'e.g. warm-up, competition',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final entry = LeaderboardEntry(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    athleteName: result.athleteName,
                    athleteWeightKg: result.athleteWeightKg,
                    peakForceKg: result.peakForceKg,
                    peakAccelMs2: result.peakAccelMagnitude,
                    date: result.date,
                    isValidated: validated,
                    notes:
                        notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                  );
                  context
                      .read<LeaderboardBloc>()
                      .add(AddEntryEvent(entry));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Added to leaderboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  const _ResultRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  final IconData icon;
  const _SectionHeader(this.text, this.icon);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
                fontSize: 18,
              )),
          if (unit.isNotEmpty)
            Text(unit,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: color.withOpacity(0.8))),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant, fontSize: 10)),
        ],
      ),
    );
  }
}

// 
// Sensor line chart (3 lines: x=red, y=green, z=blue)
// 
class _SensorChart extends StatelessWidget {
  final List<SensorReading> readings;
  final double Function(SensorReading) line1;
  final double Function(SensorReading) line2;
  final double Function(SensorReading) line3;
  final String l1Name, l2Name, l3Name, unit;
  final List<double> peakXs;

  const _SensorChart({
    required this.readings,
    required this.line1,
    required this.line2,
    required this.line3,
    required this.l1Name,
    required this.l2Name,
    required this.l3Name,
    required this.unit,
    required this.peakXs,
  });

  List<FlSpot> _spots(double Function(SensorReading) fn) =>
      readings.map((r) => FlSpot(r.timeSeconds, fn(r))).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (readings.isEmpty) {
      return const Center(child: Text('No data'));
    }

    final l1 = _spots(line1);
    final l2 = _spots(line2);
    final l3 = _spots(line3);

    final allVals = [...l1, ...l2, ...l3].map((s) => s.y);
    final minY = allVals.reduce(min) * 1.2;
    final maxY = allVals.reduce(max) * 1.2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
      child: Column(
        children: [
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(Colors.red, l1Name),
              const SizedBox(width: 12),
              _LegendDot(Colors.green, l2Name),
              const SizedBox(width: 12),
              _LegendDot(Colors.blue, l3Name),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: cs.outlineVariant.withOpacity(0.4),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(1),
                        style: TextStyle(
                            fontSize: 9, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toStringAsFixed(1)}s',
                        style: TextStyle(
                            fontSize: 9, color: cs.onSurfaceVariant),
                      ),
                      interval: readings.last.timeSeconds / 4,
                    ),
                  ),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                minY: minY,
                maxY: maxY,
                extraLinesData: ExtraLinesData(
                  verticalLines: peakXs
                      .map((x) => VerticalLine(
                            x: x,
                            color: cs.error.withOpacity(0.6),
                            strokeWidth: 1.5,
                            dashArray: [4, 4],
                          ))
                      .toList(),
                ),
                lineBarsData: [
                  _bar(l1, Colors.red),
                  _bar(l2, Colors.green),
                  _bar(l3, Colors.blue),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              s.y.toStringAsFixed(2),
                              TextStyle(
                                  color: s.bar.color, fontWeight: FontWeight.bold),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _bar(List<FlSpot> spots, Color color) => LineChartBarData(
        spots: spots,
        color: color,
        barWidth: 1.5,
        isCurved: false,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _GyroMagnitudeChart extends StatelessWidget {
  final List<SensorReading> readings;
  const _GyroMagnitudeChart({required this.readings});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (readings.isEmpty) return const Center(child: Text('No data'));

    final spots = readings
        .map((r) => FlSpot(r.timeSeconds, r.gyroMagnitude))
        .toList();
    final maxY = spots.map((s) => s.y).reduce(max) * 1.2;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _LegendDot(cs.secondary, 'Angular Magnitude (rad/s)'),
          ]),
          const SizedBox(height: 4),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: cs.outlineVariant.withOpacity(0.4),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (v, _) => Text(
                        v.toStringAsFixed(1),
                        style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toStringAsFixed(1)}s',
                        style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                      ),
                      interval: readings.last.timeSeconds / 4,
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    color: cs.secondary,
                    barWidth: 2,
                    isCurved: true,
                    curveSmoothness: 0.2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: cs.secondary.withOpacity(0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
