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

class SensorBloc extends Bloc<SensorEvent, SensorState> {
  static const double _lpAlpha = 0.2;      // 0.8*prev + 0.2*new
  static const double _cfAccelW = 0.02;    // complementary filter: accel trust
  static const double _cfGyroW  = 0.98;    // complementary filter: gyro trust
  static const int _calibSamples = 50;     // ~1 second at 50Hz
  static const double _calibVarianceThresh = 0.15; // m/s² variance threshold

  double _fAx = 0, _fAy = 0, _fAz = 0;
  double _fGx = 0, _fGy = 0, _fGz = 0;
  double _pitch = 0, _roll = 0, _yaw = 0;

  DateTime? _sessionStart;
  DateTime? _lastSampleTime;
  String _athleteName = '';
  double _athleteWeightKg = 70.0;
  final List<SensorReading> _readings = [];
  bool _isFirst = true;
  bool _calibrated = false;

  double _rawAx = 0, _rawAy = 0, _rawAz = 0;
  double _rawGx = 0, _rawGy = 0, _rawGz = 0;
  bool _hasData = false;

  StreamSubscription? _accelSub;
  StreamSubscription? _gyroSub;
  Timer? _timer;

  SensorBloc() : super(SensorIdle()) {
    on<StartRecordingEvent>(_onStart);
    on<StopRecordingEvent>(_onStop);
    on<ResetSensorEvent>(_onReset);
    on<_SampleTakenEvent>(_onSample);
  }

  void _onStart(StartRecordingEvent event, Emitter<SensorState> emit) async {
    _athleteName = event.athleteName;
    _athleteWeightKg = event.athleteWeightKg;
    _readings.clear();
    _sessionStart = DateTime.now();
    _lastSampleTime = _sessionStart;
    _isFirst = true;
    _calibrated = false;
    _pitch = _roll = _yaw = 0;
    _fAx = _fAy = _fAz = _fGx = _fGy = _fGz = 0;
    _hasData = false;

    _accelSub = userAccelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((e) { _rawAx = e.x; _rawAy = e.y; _rawAz = e.z; _hasData = true; },
        onError: (_) {});

    _gyroSub = gyroscopeEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen((e) { _rawGx = e.x; _rawGy = e.y; _rawGz = e.z; },
        onError: (_) {});

    emit(SensorCalibrating(
      samplesCollected: 0,
      samplesNeeded: _calibSamples,
      elapsedMs: 0,
    ));

    // 50Hz timer — safe add() call outside emitter
    _timer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      if (!_hasData) return;
      add(_SampleTakenEvent(_computeReading()));
    });
  }

  void _onSample(_SampleTakenEvent event, Emitter<SensorState> emit) {
    if (state is SensorIdle || state is SensorComplete || state is SensorError) return;
    _readings.add(event.reading);
    final count = _readings.length;
    final elapsedMs = event.reading.timestampMs;

    // Calibration phase
    if (!_calibrated) {
      if (count < _calibSamples) {
        if (count % 5 == 0) {
          emit(SensorCalibrating(
            samplesCollected: count,
            samplesNeeded: _calibSamples,
            elapsedMs: elapsedMs,
          ));
        }
        return;
      }
      // Check if stationary: compute variance of accel magnitude
      if (_isStationary(_readings)) {
        _calibrated = true;
        emit(SensorRecording(
          readings: List.from(_readings),
          latest: event.reading,
          elapsedMs: elapsedMs,
          calibrated: true,
        ));
      } else {
        // Keep collecting — slide window
        emit(SensorCalibrating(
          samplesCollected: count,
          samplesNeeded: _calibSamples,
          elapsedMs: elapsedMs,
        ));
      }
      return;
    }

    // Recording phase — refresh UI every 5 samples (~10 Hz)
    if (count % 5 == 0) {
      emit(SensorRecording(
        readings: List.from(_readings),
        latest: event.reading,
        elapsedMs: elapsedMs,
        calibrated: true,
      ));
    }
  }

  bool _isStationary(List<SensorReading> readings) {
    final last = readings.length < _calibSamples
        ? readings
        : readings.sublist(readings.length - _calibSamples);
    if (last.length < 10) return false;

    final mags = last.map((r) => r.accelMagnitude).toList();
    final mean = mags.reduce((a, b) => a + b) / mags.length;
    final variance = mags.map((m) => (m - mean) * (m - mean)).reduce((a, b) => a + b) / mags.length;
    return sqrt(variance) < _calibVarianceThresh;
  }

  SensorReading _computeReading() {
    final now = DateTime.now();
    final dt = now.difference(_lastSampleTime!).inMicroseconds / 1_000_000.0;
    _lastSampleTime = now;
    final elapsedMs = now.difference(_sessionStart!).inMilliseconds;

    if (_isFirst) {
      _fAx = _rawAx; _fAy = _rawAy; _fAz = _rawAz;
      _fGx = _rawGx; _fGy = _rawGy; _fGz = _rawGz;
      _pitch = _accelPitch(_rawAx, _rawAy, _rawAz);
      _roll  = _accelRoll(_rawAy, _rawAz);
      _isFirst = false;
    } else {
      _fAx = (1 - _lpAlpha) * _fAx + _lpAlpha * _rawAx;
      _fAy = (1 - _lpAlpha) * _fAy + _lpAlpha * _rawAy;
      _fAz = (1 - _lpAlpha) * _fAz + _lpAlpha * _rawAz;
      _fGx = (1 - _lpAlpha) * _fGx + _lpAlpha * _rawGx;
      _fGy = (1 - _lpAlpha) * _fGy + _lpAlpha * _rawGy;
      _fGz = (1 - _lpAlpha) * _fGz + _lpAlpha * _rawGz;

      final pitchAccel = _accelPitch(_fAx, _fAy, _fAz);
      final rollAccel  = _accelRoll(_fAy, _fAz);
      _pitch = _cfGyroW * (_pitch + _fGx * dt * (180 / pi)) + _cfAccelW * pitchAccel;
      _roll  = _cfGyroW * (_roll  + _fGy * dt * (180 / pi)) + _cfAccelW * rollAccel;
      _yaw  += _fGz * dt * (180 / pi);
      while (_yaw >  180) { _yaw -= 360; }
      while (_yaw < -180) { _yaw += 360; }
    }

    return SensorReading(
      timestampMs: elapsedMs,
      accelX: _fAx, accelY: _fAy, accelZ: _fAz,
      gyroX: _fGx,  gyroY: _fGy,  gyroZ: _fGz,
      pitch: _pitch, roll: _roll,  yaw: _yaw,
    );
  }

  void _onStop(StopRecordingEvent event, Emitter<SensorState> emit) async {
    await _stopStreams();
    if (_readings.isEmpty) {
      emit(SensorError('No data recorded. Please try again.'));
      return;
    }
    emit(SensorProcessing());
    // Post-processing is done inside SessionResult.fromReadings (via PostProcessor)
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
    _timer?.cancel(); _timer = null;
    await _accelSub?.cancel(); _accelSub = null;
    await _gyroSub?.cancel();  _gyroSub  = null;
  }

  double _accelPitch(double ax, double ay, double az) =>
      atan2(-ax, sqrt(ay * ay + az * az)) * (180 / pi);

  double _accelRoll(double ay, double az) =>
      atan2(ay, az) * (180 / pi);

  @override
  Future<void> close() async {
    await _stopStreams();
    return super.close();
  }
}
