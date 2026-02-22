import 'sensor_reading.dart';

class SessionResult {
  final List<SensorReading> readings;

  /// Athlete weight in kg (used for force calculation)
  final double athleteWeightKg;
  final String athleteName;
  final DateTime date;

  /// Index into [readings] at which peak force occurred
  final int peakReadingIndex;

  const SessionResult({
    required this.readings,
    required this.athleteWeightKg,
    required this.athleteName,
    required this.date,
    required this.peakReadingIndex,
  });

  static int _findPeakIndex(List<SensorReading> readings) {
    if (readings.isEmpty) return 0;
    double max = -1;
    int idx = 0;
    for (int i = 0; i < readings.length; i++) {
      final mag = readings[i].accelMagnitude;
      if (mag > max) {
        max = mag;
        idx = i;
      }
    }
    return idx;
  }

  factory SessionResult.fromReadings({
    required List<SensorReading> readings,
    required double athleteWeightKg,
    required String athleteName,
    required DateTime date,
  }) {
    return SessionResult(
      readings: readings,
      athleteWeightKg: athleteWeightKg,
      athleteName: athleteName,
      date: date,
      peakReadingIndex: _findPeakIndex(readings),
    );
  }

  /// Peak linear acceleration in m/s²
  double get peakAccelMagnitude => readings.isEmpty
      ? 0
      : readings[peakReadingIndex].accelMagnitude;

  /// Peak force in kg-force: F = m * a / g  (where g ≈ 9.81)
  double get peakForceKg =>
      (athleteWeightKg * peakAccelMagnitude) / 9.81;

  /// Session duration in seconds
  double get durationSeconds => readings.isEmpty
      ? 0
      : readings.last.timeSeconds;

  SensorReading? get peakReading =>
      readings.isEmpty ? null : readings[peakReadingIndex];

  Map<String, dynamic> toJson() => {
        'athleteWeightKg': athleteWeightKg,
        'athleteName': athleteName,
        'date': date.toIso8601String(),
        'peakReadingIndex': peakReadingIndex,
        'readings': readings.map((r) => r.toJson()).toList(),
      };

  factory SessionResult.fromJson(Map<String, dynamic> json) {
    final readings = (json['readings'] as List)
        .map((r) => SensorReading.fromJson(r as Map<String, dynamic>))
        .toList();
    return SessionResult(
      readings: readings,
      athleteWeightKg: (json['athleteWeightKg'] as num).toDouble(),
      athleteName: json['athleteName'] as String,
      date: DateTime.parse(json['date'] as String),
      peakReadingIndex: json['peakReadingIndex'] as int,
    );
  }
}
