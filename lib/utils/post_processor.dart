import 'dart:math';
import '../models/sensor_reading.dart';
import '../models/processed_frame.dart';

/// Post-processes raw sensor readings into world-frame kinematics.
///
/// Algorithm (no smoothing, no calibration stage):
/// 1. Detect gravity direction from the mean of ALL accelerometer readings.
///    Since the person is standing for most of the recording, the mean
///    converges to the gravity vector in phone coordinates.
/// 2. Build a rotation matrix R that maps phone-frame → world-frame (Y = up).
/// 3. For each sample: subtract gravity from raw accel → linear acceleration,
///    rotate linear accel to world frame.
/// 4. Integrate world-frame linear accel → velocity (starting at v=0) → position.
/// 5. Use gyroscope integration for body orientation tracking.
/// 6. Compute force = mass × |linear_accel_world|.
/// 7. Mark propulsion frames (vertical velocity increasing AND >= 0).
/// 8. Apply linear drift correction assuming v ≈ 0 at start and end.
class PostProcessor {
  final List<SensorReading> rawReadings;
  final double athleteMassKg;

  PostProcessor({
    required this.rawReadings,
    required this.athleteMassKg,
  });

  /// Main entry point — returns the list of processed frames.
  List<ProcessedFrame> process() {
    if (rawReadings.length < 2) return [];

    // ── Step 1: Compute gravity vector from mean of all readings ──
    // The full accelerometer (with gravity) reads the reaction to gravity
    // when stationary. Since the athlete is standing for most of the
    // recording, the average acceleration ≈ gravity direction in phone frame.
    final gravity = _computeGravityVector();

    // ── Step 2: Build rotation matrix (phone → world, Y = up) ──
    final rot = _buildRotationMatrix(gravity);

    // ── Step 3 & 4: Subtract gravity, rotate, integrate ──────────
    final frames = <ProcessedFrame>[];
    double vx = 0, vy = 0, vz = 0;
    double px = 0, py = 0, pz = 0;

    // Gyroscope-integrated orientation for athlete body angles
    double gyroPitch = 0, gyroRoll = 0, gyroYaw = 0;

    for (int i = 0; i < rawReadings.length; i++) {
      final r = rawReadings[i];
      final dt = (i == 0)
          ? 0.0
          : (r.timestampMs - rawReadings[i - 1].timestampMs) / 1000.0;

      // Linear acceleration in phone frame = raw accel − gravity
      final linAx = r.accelX - gravity[0];
      final linAy = r.accelY - gravity[1];
      final linAz = r.accelZ - gravity[2];

      // Rotate linear accel to world frame (Y = up)
      final awx = rot[0][0] * linAx + rot[0][1] * linAy + rot[0][2] * linAz;
      final awy = rot[1][0] * linAx + rot[1][1] * linAy + rot[1][2] * linAz;
      final awz = rot[2][0] * linAx + rot[2][1] * linAy + rot[2][2] * linAz;

      // Integrate velocity (starts at 0)
      vx += awx * dt;
      vy += awy * dt;
      vz += awz * dt;

      // Integrate position
      px += vx * dt;
      py += vy * dt;
      pz += vz * dt;

      // ── Step 5: Gyro-integrated body orientation (relative to start) ──
      // Raw gyroscope gives angular velocity in phone frame (rad/s).
      // We also rotate gyro into world frame for meaningful body angles.
      if (i > 0) {
        // Rotate gyro vector to world frame for proper pitch/roll/yaw
        final gwx = rot[0][0] * r.gyroX + rot[0][1] * r.gyroY + rot[0][2] * r.gyroZ;
        final gwy = rot[1][0] * r.gyroX + rot[1][1] * r.gyroY + rot[1][2] * r.gyroZ;
        final gwz = rot[2][0] * r.gyroX + rot[2][1] * r.gyroY + rot[2][2] * r.gyroZ;

        // Integrate: world-frame pitch (X rot), roll (Z rot), yaw (Y rot)
        gyroPitch += gwx * dt * (180 / pi);
        gyroRoll  += gwz * dt * (180 / pi);
        gyroYaw   += gwy * dt * (180 / pi);
      }

      // Normalise yaw to [-180, 180]
      while (gyroYaw > 180) { gyroYaw -= 360; }
      while (gyroYaw < -180) { gyroYaw += 360; }

      // ── Step 6: Force from linear acceleration ──
      final accelMag = _mag3(awx, awy, awz);
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
        athletePitch: gyroPitch,
        athleteRoll: gyroRoll,
        athleteYaw: gyroYaw,
        isPropulsion: false, // set in step 7
      ));
    }

    // ── Step 8: Linear drift correction ──────────────────────────
    _applyDriftCorrection(frames);

    // ── Step 7: Mark propulsion frames ───────────────────────────
    _markPropulsionFrames(frames);

    return frames;
  }

  // ═══════════════════════════════════════════════════════════════
  // Private helpers
  // ═══════════════════════════════════════════════════════════════

  /// Compute gravity vector from the mean of all raw accelerometer readings.
  /// When the athlete is standing (most of the recording), the accelerometer
  /// reads the gravitational reaction force pointing upward in phone coords.
  List<double> _computeGravityVector() {
    double sx = 0, sy = 0, sz = 0;
    for (final r in rawReadings) {
      sx += r.accelX;
      sy += r.accelY;
      sz += r.accelZ;
    }
    final n = rawReadings.length.toDouble();
    return [sx / n, sy / n, sz / n];
  }

  /// Build rotation matrix from phone frame to world frame (Y = up).
  ///
  /// The gravity vector in phone frame points "up" (reaction to gravity).
  /// We use it to define the world Y axis, then pick orthogonal X and Z.
  List<List<double>> _buildRotationMatrix(List<double> gravity) {
    final gMag = _mag3(gravity[0], gravity[1], gravity[2]);
    if (gMag < 0.01) {
      // Fallback: identity matrix (should not happen with real data)
      return [
        [1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, 0.0, 1.0],
      ];
    }

    // Up direction in phone frame (normalised gravity)
    final ux = gravity[0] / gMag;
    final uy = gravity[1] / gMag;
    final uz = gravity[2] / gMag;

    // Choose a reference vector not parallel to up
    double refX, refY, refZ;
    if (ux.abs() < 0.9) {
      refX = 1; refY = 0; refZ = 0;
    } else {
      refX = 0; refY = 0; refZ = 1;
    }

    // Right = cross(up, ref), normalised → world X axis in phone coords
    double rx = uy * refZ - uz * refY;
    double ry = uz * refX - ux * refZ;
    double rz = ux * refY - uy * refX;
    final rMag = _mag3(rx, ry, rz);
    rx /= rMag; ry /= rMag; rz /= rMag;

    // Forward = cross(right, up) → world Z axis in phone coords
    final fx = ry * uz - rz * uy;
    final fy = rz * ux - rx * uz;
    final fz = rx * uy - ry * ux;

    // Rotation matrix: rows are world axes expressed in phone coordinates
    // v_world = R * v_phone
    return [
      [rx, ry, rz], // world X (right)
      [ux, uy, uz], // world Y (up)
      [fx, fy, fz], // world Z (forward)
    ];
  }

  /// Linear drift correction: assume velocity ≈ 0 at start and end.
  /// Subtracts a linearly increasing velocity bias, then re-integrates
  /// position from the corrected velocity.
  void _applyDriftCorrection(List<ProcessedFrame> frames) {
    if (frames.length < 2) return;

    final endFrame = frames.last;
    final totalTime = endFrame.timeSec;
    if (totalTime <= 0) return;

    // Drift rate = residual velocity / total time
    final driftRateX = endFrame.velX / totalTime;
    final driftRateY = endFrame.velY / totalTime;
    final driftRateZ = endFrame.velZ / totalTime;

    // Subtract linear drift and re-integrate position
    double px = 0, py = 0, pz = 0;
    for (int i = 0; i < frames.length; i++) {
      final f = frames[i];
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
        isPropulsion: f.isPropulsion,
      );
    }
  }

  /// Mark frames where the athlete is actively generating propulsive force.
  ///
  /// Propulsion = vertical velocity is increasing (d(vy)/dt > 0) AND vy >= 0.
  /// This excludes:
  /// - Free-fall / airborne phases (vy decreasing or negative)
  /// - Landing impact (vy negative, even if becoming less negative)
  /// Only propulsion-phase force is used for peak force calculations.
  void _markPropulsionFrames(List<ProcessedFrame> frames) {
    if (frames.length < 2) return;

    for (int i = 1; i < frames.length; i++) {
      final prevVy = frames[i - 1].velY;
      final curVy = frames[i].velY;
      // Propulsion: vertical velocity is going up AND is non-negative
      final isProp = curVy > prevVy && curVy >= 0;

      if (isProp != frames[i].isPropulsion) {
        frames[i] = ProcessedFrame(
          timeSec: frames[i].timeSec,
          accelXw: frames[i].accelXw,
          accelYw: frames[i].accelYw,
          accelZw: frames[i].accelZw,
          velX: frames[i].velX,
          velY: frames[i].velY,
          velZ: frames[i].velZ,
          posX: frames[i].posX,
          posY: frames[i].posY,
          posZ: frames[i].posZ,
          forceN: frames[i].forceN,
          forceKg: frames[i].forceKg,
          athletePitch: frames[i].athletePitch,
          athleteRoll: frames[i].athleteRoll,
          athleteYaw: frames[i].athleteYaw,
          isPropulsion: isProp,
        );
      }
    }
  }

  double _mag3(double x, double y, double z) {
    final sq = x * x + y * y + z * z;
    return sq <= 0 || sq.isNaN ? 0.0 : sqrt(sq);
  }
}
