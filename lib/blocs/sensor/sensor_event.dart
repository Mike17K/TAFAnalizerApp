abstract class SensorEvent {}

class StartRecordingEvent extends SensorEvent {
  final double athleteWeightKg;
  final String athleteName;
  StartRecordingEvent({required this.athleteWeightKg, required this.athleteName});
}

class StopRecordingEvent extends SensorEvent {}

class ResetSensorEvent extends SensorEvent {}
