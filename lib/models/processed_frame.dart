import 'dart:math' as math;

/// A single frame of post-processed, world-frame data.
/// All values are in the world coordinate system (Y = up/vertical).
class ProcessedFrame {
  /// Time in seconds since session start
  final double timeSec;

  // ── World-frame linear acceleration (gravity removed) ──
  final double accelXw; // horizontal-forward (m/s²)
  final double accelYw; // vertical/up (m/s²)
  final double accelZw; // horizontal-lateral (m/s²)

  // ── Velocity (integrated from world accel) ──
  final double velX; // m/s
  final double velY; // m/s
  final double velZ; // m/s

  // ── Position (integrated from velocity) ──
  final double posX; // m
  final double posY; // m  (= height)
  final double posZ; // m

  // ── Force ──
  /// Absolute force = mass * |accel_world| in Newtons
  final double forceN;

  /// Force in kg-force (= forceN / 9.81)
  final double forceKg;

  // ── Corrected athlete orientation (degrees) ──
  /// Body angles relative to standing upright, derived from gyroscope
  /// integration relative to the initial phone orientation.
  final double athletePitch; // forward/back lean (°)
  final double athleteRoll;  // side lean (°)
  final double athleteYaw;   // rotation around vertical (°)

  // ── Propulsion flag ──
  /// True when the athlete is actively generating force (speed increasing
  /// AND vertical velocity >= 0). Used to determine peak propulsion force,
  /// excluding gravity/falling phases.
  final bool isPropulsion;

  const ProcessedFrame({
    required this.timeSec,
    required this.accelXw,
    required this.accelYw,
    required this.accelZw,
    required this.velX,
    required this.velY,
    required this.velZ,
    required this.posX,
    required this.posY,
    required this.posZ,
    required this.forceN,
    required this.forceKg,
    required this.athletePitch,
    required this.athleteRoll,
    required this.athleteYaw,
    this.isPropulsion = false,
  });

  double get speed => _mag3(velX, velY, velZ);
  double get height => posY;
  double get accelMagWorld => _mag3(accelXw, accelYw, accelZw);
  double get horizontalSpeed => _mag3(velX, 0, velZ);
  double get verticalSpeed => velY;

  static double _mag3(double x, double y, double z) {
    final sq = x * x + y * y + z * z;
    return sq <= 0 || sq.isNaN ? 0 : math.sqrt(sq);
  }

  Map<String, dynamic> toJson() => {
        't': timeSec,
        'axw': accelXw, 'ayw': accelYw, 'azw': accelZw,
        'vx': velX, 'vy': velY, 'vz': velZ,
        'px': posX, 'py': posY, 'pz': posZ,
        'fN': forceN, 'fKg': forceKg,
        'ap': athletePitch, 'ar': athleteRoll, 'ay': athleteYaw,
        'prop': isPropulsion,
      };

  factory ProcessedFrame.fromJson(Map<String, dynamic> j) => ProcessedFrame(
        timeSec: (j['t'] as num).toDouble(),
        accelXw: (j['axw'] as num).toDouble(),
        accelYw: (j['ayw'] as num).toDouble(),
        accelZw: (j['azw'] as num).toDouble(),
        velX: (j['vx'] as num).toDouble(),
        velY: (j['vy'] as num).toDouble(),
        velZ: (j['vz'] as num).toDouble(),
        posX: (j['px'] as num).toDouble(),
        posY: (j['py'] as num).toDouble(),
        posZ: (j['pz'] as num).toDouble(),
        forceN: (j['fN'] as num).toDouble(),
        forceKg: (j['fKg'] as num).toDouble(),
        athletePitch: (j['ap'] as num).toDouble(),
        athleteRoll: (j['ar'] as num).toDouble(),
        athleteYaw: (j['ay'] as num).toDouble(),
        isPropulsion: j['prop'] as bool? ?? false,
      );
}
