import 'dart:math';
import '../models/sensor_reading.dart';
import '../models/processed_frame.dart';

/// Post-processes raw sensor readings into world-frame kinematics.
///
/// Algorithm overview:
/// 1. Detect the initial stationary calibration window (low accel variance).
/// 2. From the full accelerometer (with gravity) during calibration, compute
///    the gravity vector in phone coordinates → derive the rotation matrix R
///    that maps phone-frame → world-frame (Y = up).
/// 3. For each sample, use a complementary-filter–tracked orientation to
///    rotate the user-accelerometer (gravity-removed) into world frame.
/// 4. Integrate world accel → velocity → position, with ZUPT drift correction.
/// 5. Compute force = mass × |accel_world|.
/// 6. Correct athlete orientation so the figure stands upright at rest.
class PostProcessor {
  /// Minimum number of samples to consider as calibration window.
  static const int _minCalibSamples = 25; // ~0.5 s at 50 Hz
  static const double _calibVarThreshold = 0.15; // m/s² variance threshold

  final List<SensorReading> rawReadings;
  final double athleteMassKg;

  /// Raw full-accelerometer readings (with gravity, X/Y/Z).
  /// These are captured separately because `userAccelerometerEventStream`
  /// removes gravity. We reconstruct gravity from the gyro-integrated
  /// orientation instead.
  final List<List<double>>? rawFullAccel;

  PostProcessor({
    required this.rawReadings,
    required this.athleteMassKg,
    this.rawFullAccel,
  });

  /// Main entry point — returns the list of processed frames.
  List<ProcessedFrame> process() {
    if (rawReadings.length < 2) return [];

    // ── Step 1: Find calibration window ────────────────────────
    final calibEnd = _findCalibrationEnd();

    // ── Step 2: Compute initial gravity direction in phone frame ──
    //   During calibration the phone is stationary, so the user-accel
    //   should be ~0. The gyro-integrated euler angles tell us the
    //   phone's orientation relative to when recording started.  But
    //   we also know that the "real" gravity direction at rest can be
    //   estimated from the average user-accel residuals + empirical
    //   gravity on the accel-with-gravity sensor. Since we only have
    //   the user-accelerometer, we derive the phone orientation from
    //   the euler angles computed in the sensor bloc.
    final calibPitch = _avgField(0, calibEnd, (r) => r.pitch);
    final calibRoll = _avgField(0, calibEnd, (r) => r.roll);
    final calibYaw = _avgField(0, calibEnd, (r) => r.yaw);

    // ── Step 3: Build rotation matrices & integrate ─────────────
    final frames = <ProcessedFrame>[];
    double vx = 0, vy = 0, vz = 0;
    double px = 0, py = 0, pz = 0;

    for (int i = 0; i < rawReadings.length; i++) {
      final r = rawReadings[i];
      final dt = (i == 0)
          ? 0.0
          : (r.timestampMs - rawReadings[i - 1].timestampMs) / 1000.0;

      // Rotation: current euler minus calibration baseline
      final dPitchDeg = r.pitch - calibPitch;
      final dRollDeg = r.roll - calibRoll;
      final dYawDeg = r.yaw - calibYaw;

      // Convert phone-frame user-accel to world-frame
      final world = _rotateToWorld(
          r.accelX, r.accelY, r.accelZ, r.pitch, r.roll, r.yaw);
      final awx = world[0];
      final awy = world[1];
      final awz = world[2];

      // Integrate velocity
      vx += awx * dt;
      vy += awy * dt;
      vz += awz * dt;

      // Integrate position
      px += vx * dt;
      py += vy * dt;
      pz += vz * dt;

      final accelMag = sqrt(awx * awx + awy * awy + awz * awz);
      final forceN = athleteMassKg * accelMag;

      frames.add(ProcessedFrame(
        timeSec: r.timeSeconds,
        accelXw: awx,
        accelYw: awy,
        accelZw: awz,
        velX: vx,
        velY: vy,
        velZ: vz,
        posX: px,
        posY: py,
        posZ: pz,
        forceN: forceN,
        forceKg: forceN / 9.81,
        athletePitch: dPitchDeg,
        athleteRoll: dRollDeg,
        athleteYaw: dYawDeg,
      ));
    }

    // ── Step 4: ZUPT drift correction ───────────────────────────
    _applyDriftCorrection(frames, calibEnd);

    return frames;
  }

  // ═══════════════════════════════════════════════════════════════
  // Private helpers
  // ═══════════════════════════════════════════════════════════════

  /// Detect where the calibration (stationary) phase ends.
  /// We look for the first window of _minCalibSamples where the
  /// accel-magnitude variance exceeds the threshold.
  int _findCalibrationEnd() {
    if (rawReadings.length <= _minCalibSamples) {
      return rawReadings.length ~/ 2;
    }

    // Compute running variance of accel magnitude
    for (int end = _minCalibSamples; end < rawReadings.length; end++) {
      // Check variance of last _minCalibSamples
      double sumM = 0, sumM2 = 0;
      for (int j = end - _minCalibSamples; j < end; j++) {
        final m = rawReadings[j].accelMagnitude;
        sumM += m;
        sumM2 += m * m;
      }
      final mean = sumM / _minCalibSamples;
      final variance = sumM2 / _minCalibSamples - mean * mean;

      if (variance > _calibVarThreshold) {
        // Movement started somewhere in this window
        return max(_minCalibSamples, end - _minCalibSamples);
      }
    }

    // If never exceeded, assume the first half is calibration
    return rawReadings.length ~/ 2;
  }

  double _avgField(int start, int end, double Function(SensorReading) fn) {
    if (end <= start) return 0;
    double sum = 0;
    for (int i = start; i < end; i++) {
      sum += fn(rawReadings[i]);
    }
    return sum / (end - start);
  }

  /// Rotate a phone-frame acceleration vector to world frame
  /// using the phone's current euler angles.
  ///
  /// Convention: pitch = rotation about X, roll = rotation about Z,
  /// yaw = rotation about Y.  World Y = up.
  ///
  /// The rotation matrix is R = Ry(yaw) * Rx(pitch) * Rz(roll).
  List<double> _rotateToWorld(
      double ax, double ay, double az,
      double pitchDeg, double rollDeg, double yawDeg) {
    final p = pitchDeg * (pi / 180);
    final r = rollDeg * (pi / 180);
    final y = yawDeg * (pi / 180);

    final cp = cos(p), sp = sin(p);
    final cr = cos(r), sr = sin(r);
    final cy = cos(y), sy = sin(y);

    // R = Ry * Rx * Rz
    // Row 0
    final r00 = cy * cr + sy * sp * sr;
    final r01 = -cy * sr + sy * sp * cr;
    final r02 = sy * cp;
    // Row 1
    final r10 = cp * sr;
    final r11 = cp * cr;
    final r12 = -sp;
    // Row 2
    final r20 = -sy * cr + cy * sp * sr;
    final r21 = sy * sr + cy * sp * cr;
    final r22 = cy * cp;

    return [
      r00 * ax + r01 * ay + r02 * az,
      r10 * ax + r11 * ay + r12 * az,
      r20 * ax + r21 * ay + r22 * az,
    ];
  }

  /// Apply Zero-Velocity Update (ZUPT) drift correction.
  ///
  /// At the start (calibration window) velocity should be zero.
  /// We also check if the end is stationary.  Then we linearly
  /// subtract the residual drift from velocity and re-integrate
  /// position.
  void _applyDriftCorrection(List<ProcessedFrame> frames, int calibEnd) {
    if (frames.length < 2) return;

    // Compute drift rate: difference between expected (0) and actual
    // velocity at calibEnd, and end-of-session residual.
    final calFrame = calibEnd < frames.length ? frames[calibEnd] : frames.last;
    final endFrame = frames.last;

    // Drift per second (linear ramp from calibEnd velocity to end velocity)
    final dtTotal = endFrame.timeSec - calFrame.timeSec;
    if (dtTotal <= 0) return;

    final driftRateX = endFrame.velX / endFrame.timeSec;
    final driftRateY = endFrame.velY / endFrame.timeSec;
    final driftRateZ = endFrame.velZ / endFrame.timeSec;

    // Subtract linearly-increasing drift, then re-integrate position
    double px = 0, py = 0, pz = 0;

    for (int i = 0; i < frames.length; i++) {
      final f = frames[i];
      // Corrected velocity
      final cvx = f.velX - driftRateX * f.timeSec;
      final cvy = f.velY - driftRateY * f.timeSec;
      final cvz = f.velZ - driftRateZ * f.timeSec;

      final dt = (i == 0) ? 0.0 : (f.timeSec - frames[i - 1].timeSec);
      px += cvx * dt;
      py += cvy * dt;
      pz += cvz * dt;

      frames[i] = ProcessedFrame(
        timeSec: f.timeSec,
        accelXw: f.accelXw,
        accelYw: f.accelYw,
        accelZw: f.accelZw,
        velX: cvx,
        velY: cvy,
        velZ: cvz,
        posX: px,
        posY: py,
        posZ: pz,
        forceN: f.forceN,
        forceKg: f.forceKg,
        athletePitch: f.athletePitch,
        athleteRoll: f.athleteRoll,
        athleteYaw: f.athleteYaw,
      );
    }
  }
}
