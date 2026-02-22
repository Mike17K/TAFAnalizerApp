import 'dart:math';

class SensorReading {
  /// Milliseconds since session start
  final int timestampMs;

  // Low-pass filtered linear acceleration (gravity removed) in m/s²
  final double accelX;
  final double accelY;
  final double accelZ;

  // Low-pass filtered angular velocity in rad/s
  final double gyroX;
  final double gyroY;
  final double gyroZ;

  // Euler angles in degrees (from complementary filter)
  final double pitch;
  final double roll;
  final double yaw;

  const SensorReading({
    required this.timestampMs,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.pitch,
    required this.roll,
    required this.yaw,
  });

  /// Total linear acceleration magnitude in m/s²
  double get accelMagnitude =>
      sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);

  /// Total angular velocity magnitude in rad/s
  double get gyroMagnitude =>
      sqrt(gyroX * gyroX + gyroY * gyroY + gyroZ * gyroZ);

  /// Time in seconds since session start
  double get timeSeconds => timestampMs / 1000.0;

  Map<String, dynamic> toJson() => {
        'ts': timestampMs,
        'ax': accelX,
        'ay': accelY,
        'az': accelZ,
        'gx': gyroX,
        'gy': gyroY,
        'gz': gyroZ,
        'pitch': pitch,
        'roll': roll,
        'yaw': yaw,
      };

  factory SensorReading.fromJson(Map<String, dynamic> json) => SensorReading(
        timestampMs: json['ts'] as int,
        accelX: (json['ax'] as num).toDouble(),
        accelY: (json['ay'] as num).toDouble(),
        accelZ: (json['az'] as num).toDouble(),
        gyroX: (json['gx'] as num).toDouble(),
        gyroY: (json['gy'] as num).toDouble(),
        gyroZ: (json['gz'] as num).toDouble(),
        pitch: (json['pitch'] as num).toDouble(),
        roll: (json['roll'] as num).toDouble(),
        yaw: (json['yaw'] as num).toDouble(),
      );
}
