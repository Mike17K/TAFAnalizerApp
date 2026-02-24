import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/leaderboard/leaderboard_bloc.dart';
import '../blocs/leaderboard/leaderboard_event.dart';
import '../models/athlete_profile.dart';
import '../models/leaderboard_entry.dart';
import '../models/processed_frame.dart';
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
    _tabCtrl = TabController(length: 3, vsync: this);
    // Initialise scrubber at peak height
    if (widget.result.frames.isNotEmpty) {
      _scrubberPosition =
          widget.result.maxHeightIndex / (widget.result.frames.length - 1);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  /// Downsample processed frames for chart performance
  List<ProcessedFrame> _downsample(int maxPts) {
    final f = widget.result.frames;
    if (f.length <= maxPts) return f;
    final step = f.length / maxPts;
    return List.generate(maxPts, (i) => f[(i * step).floor()]);
  }

  ProcessedFrame get _currentFrame {
    final idx = (_scrubberPosition * (widget.result.frames.length - 1))
        .round()
        .clamp(0, widget.result.frames.length - 1);
    return widget.result.frames[idx];
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

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Jump Analysis',
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
          // Stats row
          _buildStatsRow(cs, theme, result),

          const SizedBox(height: 20),
          // Charts section
          _buildChartsSection(theme, cs),

          const SizedBox(height: 20),
          // 3D Orientation Replay with corrected athlete angles
          _SectionHeader('Athlete Orientation', Icons.accessibility_new),
          const SizedBox(height: 8),
          Center(
            child: OrientationFigure3D(
              pitch: _currentFrame.athletePitch,
              roll: _currentFrame.athleteRoll,
              yaw: _currentFrame.athleteYaw,
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
                'Speed: ${_currentFrame.speed.toStringAsFixed(2)} m/s  '
                'Height: ${_currentFrame.height.toStringAsFixed(3)} m',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                't=${_formatDur(_currentFrame.timeSec)}',
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
          // Leaderboard button
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
            label: 'Peak Height',
            value: result.maxHeight.toStringAsFixed(2),
            unit: 'm',
            icon: Icons.height,
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Max Speed',
            value: result.maxSpeed.toStringAsFixed(2),
            unit: 'm/s',
            icon: Icons.speed,
            color: cs.secondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Peak Force',
            value: result.peakForceKg.toStringAsFixed(1),
            unit: 'kg',
            icon: Icons.fitness_center,
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
        _SectionHeader('Jump Data', Icons.show_chart),
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
                  Tab(text: 'HEIGHT'),
                  Tab(text: 'FORCE'),
                  Tab(text: 'SPEED'),
                ],
              ),
              SizedBox(
                height: 220,
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // 1. Height (posY)
                    _FrameChart(
                      frames: ds,
                      lines: [
                        _ChartLine('Height', Colors.teal, (f) => f.height),
                      ],
                      unit: 'm',
                      peakTimeSec: widget.result.maxHeightFrame?.timeSec,
                      fillBelow: true,
                    ),
                    // 2. Force (propulsion-only peak marked)
                    _FrameChart(
                      frames: ds,
                      lines: [
                        _ChartLine('Force', Colors.deepOrange, (f) => f.forceKg),
                      ],
                      unit: 'kg',
                      peakTimeSec: widget.result.peakForceFrame?.timeSec,
                      fillBelow: true,
                    ),
                    // 3. Speed (total only)
                    _FrameChart(
                      frames: ds,
                      lines: [
                        _ChartLine('Speed', Colors.blue, (f) => f.speed),
                      ],
                      unit: 'm/s',
                      peakTimeSec: widget.result.maxSpeedFrame?.timeSec,
                    ),
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
                _ResultRow('Peak Height',
                    '${result.maxHeight.toStringAsFixed(3)} m'),
                _ResultRow('Max Speed',
                    '${result.maxSpeed.toStringAsFixed(2)} m/s'),
                _ResultRow('Peak Force',
                    '${result.peakForceKg.toStringAsFixed(1)} kg'),
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

// ─────────────────────────────────────────────────────────────────────────────
// Reusable helper widgets
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Chart widgets for ProcessedFrame data
// ─────────────────────────────────────────────────────────────────────────────

class _ChartLine {
  final String name;
  final Color color;
  final double Function(ProcessedFrame) valueGetter;
  const _ChartLine(this.name, this.color, this.valueGetter);
}

class _FrameChart extends StatelessWidget {
  final List<ProcessedFrame> frames;
  final List<_ChartLine> lines;
  final String unit;
  final double? peakTimeSec;
  final bool fillBelow;

  const _FrameChart({
    required this.frames,
    required this.lines,
    required this.unit,
    this.peakTimeSec,
    this.fillBelow = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (frames.isEmpty) return const Center(child: Text('No data'));

    // Build spots for each line
    final allSpots = <List<FlSpot>>[];
    double globalMin = double.infinity;
    double globalMax = double.negativeInfinity;

    for (final line in lines) {
      final spots = frames.map((f) {
        final v = line.valueGetter(f);
        return FlSpot(f.timeSec, v);
      }).toList();
      allSpots.add(spots);
      for (final s in spots) {
        if (s.y < globalMin) globalMin = s.y;
        if (s.y > globalMax) globalMax = s.y;
      }
    }

    final range = (globalMax - globalMin).clamp(0.01, double.infinity);
    final minY = globalMin - range * 0.15;
    final maxY = globalMax + range * 0.15;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 16, 16),
      child: Column(
        children: [
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: lines.map((l) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _LegendDot(l.color, l.name),
              );
            }).toList(),
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
                      reservedSize: 40,
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
                      interval: frames.last.timeSec > 0
                          ? frames.last.timeSec / 4
                          : 1,
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
                  verticalLines: peakTimeSec != null
                      ? [
                          VerticalLine(
                            x: peakTimeSec!,
                            color: cs.error.withOpacity(0.6),
                            strokeWidth: 1.5,
                            dashArray: [4, 4],
                          ),
                        ]
                      : [],
                ),
                lineBarsData: [
                  for (int i = 0; i < lines.length; i++)
                    LineChartBarData(
                      spots: allSpots[i],
                      color: lines[i].color,
                      barWidth: 1.8,
                      isCurved: true,
                      curveSmoothness: 0.15,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: fillBelow && lines.length == 1,
                        color: lines[i].color.withOpacity(0.12),
                      ),
                    ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              '${s.y.toStringAsFixed(2)} $unit',
                              TextStyle(
                                  color: s.bar.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
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
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    ]);
  }
}
