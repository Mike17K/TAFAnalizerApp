import '../../models/sensor_reading.dart';
import '../../models/session_result.dart';

abstract class SensorState {}

class SensorIdle extends SensorState {}

/// Phone is stationary — calibrating gravity direction.
class SensorCalibrating extends SensorState {
  final int samplesCollected;
  final int samplesNeeded;
  final int elapsedMs;
  SensorCalibrating({
    required this.samplesCollected,
    required this.samplesNeeded,
    required this.elapsedMs,
  });
  double get progress =>
      samplesNeeded == 0 ? 0 : (samplesCollected / samplesNeeded).clamp(0, 1);
}

class SensorRecording extends SensorState {
  final List<SensorReading> readings;
  final SensorReading? latest;
  final int elapsedMs;
  /// Whether calibration succeeded (gravity direction captured)
  final bool calibrated;

  SensorRecording({
    required this.readings,
    this.latest,
    required this.elapsedMs,
    this.calibrated = false,
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
