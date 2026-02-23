import 'sensor_reading.dart';
import 'processed_frame.dart';
import '../utils/post_processor.dart';

class SessionResult {
  final List<SensorReading> readings;

  /// Post-processed world-frame data (velocity, position, height, force)
  final List<ProcessedFrame> frames;

  /// Athlete weight in kg (used for force calculation)
  final double athleteWeightKg;
  final String athleteName;
  final DateTime date;

  /// Index into [frames] at which peak force occurred
  final int peakForceIndex;

  /// Index into [frames] at which max height occurred
  final int maxHeightIndex;

  /// Index into [frames] at which max speed occurred
  final int maxSpeedIndex;

  /// Calibration window end index (where movement starts)
  final int calibEndIndex;

  const SessionResult({
    required this.readings,
    required this.frames,
    required this.athleteWeightKg,
    required this.athleteName,
    required this.date,
    required this.peakForceIndex,
    required this.maxHeightIndex,
    required this.maxSpeedIndex,
    required this.calibEndIndex,
  });

  factory SessionResult.fromReadings({
    required List<SensorReading> readings,
    required double athleteWeightKg,
    required String athleteName,
    required DateTime date,
  }) {
    // Run post-processing pipeline
    final processor = PostProcessor(
      rawReadings: readings,
      athleteMassKg: athleteWeightKg,
    );
    final frames = processor.process();

    // Find peaks
    int peakForce = 0, maxHeight = 0, maxSpeed = 0;
    double pf = -1, mh = -999, ms = -1;
    for (int i = 0; i < frames.length; i++) {
      if (frames[i].forceKg > pf) {
        pf = frames[i].forceKg;
        peakForce = i;
      }
      if (frames[i].height > mh) {
        mh = frames[i].height;
        maxHeight = i;
      }
      if (frames[i].speed > ms) {
        ms = frames[i].speed;
        maxSpeed = i;
      }
    }

    return SessionResult(
      readings: readings,
      frames: frames,
      athleteWeightKg: athleteWeightKg,
      athleteName: athleteName,
      date: date,
      peakForceIndex: peakForce,
      maxHeightIndex: maxHeight,
      maxSpeedIndex: maxSpeed,
      calibEndIndex: frames.length > 25 ? 25 : frames.length ~/ 2,
    );
  }

  // ── Convenience getters ────────────────────────────────────

  ProcessedFrame? get peakForceFrame =>
      frames.isEmpty ? null : frames[peakForceIndex];

  ProcessedFrame? get maxHeightFrame =>
      frames.isEmpty ? null : frames[maxHeightIndex];

  ProcessedFrame? get maxSpeedFrame =>
      frames.isEmpty ? null : frames[maxSpeedIndex];

  double get peakForceKg => peakForceFrame?.forceKg ?? 0;
  double get peakForceN => peakForceFrame?.forceN ?? 0;
  double get maxHeight => maxHeightFrame?.height ?? 0;
  double get maxSpeed => maxSpeedFrame?.speed ?? 0;
  double get maxVerticalSpeed => frames.isEmpty
      ? 0
      : frames.map((f) => f.verticalSpeed).reduce((a, b) => a > b ? a : b);

  double get peakAccelMagnitude => peakForceFrame?.accelMagWorld ?? 0;

  double get durationSeconds =>
      frames.isEmpty ? 0 : frames.last.timeSec;

  Map<String, dynamic> toJson() => {
        'athleteWeightKg': athleteWeightKg,
        'athleteName': athleteName,
        'date': date.toIso8601String(),
        'peakForceIndex': peakForceIndex,
        'maxHeightIndex': maxHeightIndex,
        'maxSpeedIndex': maxSpeedIndex,
        'calibEndIndex': calibEndIndex,
        'readings': readings.map((r) => r.toJson()).toList(),
        'frames': frames.map((f) => f.toJson()).toList(),
      };

  factory SessionResult.fromJson(Map<String, dynamic> json) {
    final readings = (json['readings'] as List)
        .map((r) => SensorReading.fromJson(r as Map<String, dynamic>))
        .toList();
    final frames = (json['frames'] as List?)
            ?.map((f) => ProcessedFrame.fromJson(f as Map<String, dynamic>))
            .toList() ??
        [];
    return SessionResult(
      readings: readings,
      frames: frames,
      athleteWeightKg: (json['athleteWeightKg'] as num).toDouble(),
      athleteName: json['athleteName'] as String,
      date: DateTime.parse(json['date'] as String),
      peakForceIndex: json['peakForceIndex'] as int? ?? 0,
      maxHeightIndex: json['maxHeightIndex'] as int? ?? 0,
      maxSpeedIndex: json['maxSpeedIndex'] as int? ?? 0,
      calibEndIndex: json['calibEndIndex'] as int? ?? 0,
    );
  }
}
