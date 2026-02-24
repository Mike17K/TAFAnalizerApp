import '../../models/sensor_reading.dart';
import '../../models/session_result.dart';

abstract class SensorState {}

class SensorIdle extends SensorState {}

/// Phone is on the athlete's body — stabilizing before recording starts.
class SensorStabilizing extends SensorState {
  final int remainingSeconds;
  SensorStabilizing({required this.remainingSeconds});
}

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

/// Post-processing in progress after recording stopped.
class SensorProcessing extends SensorState {}

class SensorComplete extends SensorState {
  final SessionResult result;
  SensorComplete(this.result);
}

class SensorError extends SensorState {
  final String message;
  SensorError(this.message);
}
