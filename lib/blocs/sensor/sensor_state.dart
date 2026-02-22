import '../../models/sensor_reading.dart';
import '../../models/session_result.dart';

abstract class SensorState {}

class SensorIdle extends SensorState {}

class SensorRecording extends SensorState {
  final List<SensorReading> readings;
  final SensorReading? latest;
  final int elapsedMs;

  SensorRecording({
    required this.readings,
    this.latest,
    required this.elapsedMs,
  });
}

class SensorComplete extends SensorState {
  final SessionResult result;
  SensorComplete(this.result);
}

class SensorError extends SensorState {
  final String message;
  SensorError(this.message);
}
