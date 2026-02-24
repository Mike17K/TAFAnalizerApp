import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../models/sensor_reading.dart';
import '../../models/session_result.dart';
import 'sensor_event.dart';
import 'sensor_state.dart';

// Internal event: timer pushes each 20ms sample into the bloc safely
class _SampleTakenEvent extends SensorEvent {
  final SensorReading reading;
  _SampleTakenEvent(this.reading);
}

// Internal event: stabilization countdown tick
class _StabilizeTickEvent extends SensorEvent {
  final int remainingSeconds;
  _StabilizeTickEvent(this.remainingSeconds);
}

class SensorBloc extends Bloc<SensorEvent, SensorState> {
  static const int _stabilizeSeconds = 3;

  double _rawAx = 0, _rawAy = 0, _rawAz = 0;
  double _rawGx = 0, _rawGy = 0, _rawGz = 0;
  double _yaw = 0;
  bool _hasData = false;

  DateTime? _sessionStart;
  DateTime? _lastSampleTime;
  String _athleteName = '';
  double _athleteWeightKg = 70.0;
  final List<SensorReading> _readings = [];

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  Timer? _timer;
  Timer? _stabilizeTimer;

  SensorBloc() : super(SensorIdle()) {
    on<StartRecordingEvent>(_onStart);
    on<StopRecordingEvent>(_onStop);
    on<ResetSensorEvent>(_onReset);
    on<_SampleTakenEvent>(_onSample);
    on<_StabilizeTickEvent>(_onStabilizeTick);
  }

  void _onStart(StartRecordingEvent event, Emitter<SensorState> emit) async {
    _athleteName = event.athleteName;
    _athleteWeightKg = event.athleteWeightKg;
    _readings.clear();
    _sessionStart = DateTime.now();
    _lastSampleTime = _sessionStart;
    _yaw = 0;
    _hasData = false;

    // Start sensors immediately so they warm up during stabilization
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((e) {
      _rawAx = e.x; _rawAy = e.y; _rawAz = e.z; _hasData = true;
    }, onError: (_) {});

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((e) {
      _rawGx = e.x; _rawGy = e.y; _rawGz = e.z;
    }, onError: (_) {});

    // Stabilization countdown — 3 seconds before recording starts
    emit(SensorStabilizing(remainingSeconds: _stabilizeSeconds));

    int remaining = _stabilizeSeconds;
    _stabilizeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      remaining--;
      if (remaining > 0) {
        add(_StabilizeTickEvent(remaining));
      } else {
        _stabilizeTimer?.cancel();
        _stabilizeTimer = null;
        _sessionStart = DateTime.now();
        _lastSampleTime = _sessionStart;
        // Begin actual 50Hz sampling
        _timer = Timer.periodic(const Duration(milliseconds: 20), (__) {
          if (!_hasData) return;
          add(_SampleTakenEvent(_computeReading()));
        });
        add(_StabilizeTickEvent(0)); // signal recording start
      }
    });
  }

  void _onStabilizeTick(_StabilizeTickEvent event, Emitter<SensorState> emit) {
    if (state is SensorIdle || state is SensorComplete || state is SensorError) return;
    if (event.remainingSeconds > 0) {
      emit(SensorStabilizing(remainingSeconds: event.remainingSeconds));
    } else {
      // Countdown done — start recording
      emit(SensorRecording(
        readings: const [],
        latest: null,
        elapsedMs: 0,
      ));
    }
  }

  void _onSample(_SampleTakenEvent event, Emitter<SensorState> emit) {
    if (state is SensorIdle || state is SensorStabilizing || state is SensorComplete || state is SensorError) {
      return;
    }
    _readings.add(event.reading);
    final count = _readings.length;

    // Refresh UI every 5 samples (~10 Hz)
    if (count % 5 == 0) {
      emit(SensorRecording(
        readings: List.from(_readings),
        latest: event.reading,
        elapsedMs: event.reading.timestampMs,
      ));
    }
  }

  SensorReading _computeReading() {
    final now = DateTime.now();
    final dt = now.difference(_lastSampleTime!).inMicroseconds / 1000000.0;
    _lastSampleTime = now;
    final elapsedMs = now.difference(_sessionStart!).inMilliseconds;

    // Integrate yaw from raw gyroscope for live display
    _yaw += _rawGz * dt * (180 / pi);
    while (_yaw > 180) { _yaw -= 360; }
    while (_yaw < -180) { _yaw += 360; }

    // Instant pitch/roll from raw accelerometer (including gravity) for live display
    final pitch = atan2(-_rawAx, sqrt(_rawAy * _rawAy + _rawAz * _rawAz)) * (180 / pi);
    final roll = atan2(_rawAy, _rawAz) * (180 / pi);

    // Store raw values — no low-pass or complementary filtering
    return SensorReading(
      timestampMs: elapsedMs,
      accelX: _rawAx, accelY: _rawAy, accelZ: _rawAz,
      gyroX: _rawGx, gyroY: _rawGy, gyroZ: _rawGz,
      pitch: pitch, roll: roll, yaw: _yaw,
    );
  }

  void _onStop(StopRecordingEvent event, Emitter<SensorState> emit) async {
    await _stopStreams();
    if (_readings.isEmpty) {
      emit(SensorError('No data recorded. Please try again.'));
      return;
    }
    emit(SensorProcessing());
    final result = SessionResult.fromReadings(
      readings: List.from(_readings),
      athleteWeightKg: _athleteWeightKg,
      athleteName: _athleteName,
      date: _sessionStart ?? DateTime.now(),
    );
    emit(SensorComplete(result));
  }

  void _onReset(ResetSensorEvent event, Emitter<SensorState> emit) async {
    await _stopStreams();
    _readings.clear();
    emit(SensorIdle());
  }

  Future<void> _stopStreams() async {
    _stabilizeTimer?.cancel(); _stabilizeTimer = null;
    _timer?.cancel(); _timer = null;
    await _accelSub?.cancel(); _accelSub = null;
    await _gyroSub?.cancel();  _gyroSub  = null;
  }

  @override
  Future<void> close() async {
    await _stopStreams();
    return super.close();
  }
}
