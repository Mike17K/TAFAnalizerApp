import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

/// A widget that renders a 3D stick-figure athlete with given euler angles.
/// pitch, roll, yaw are in degrees.
class OrientationFigure3D extends StatelessWidget {
  final double pitch;
  final double roll;
  final double yaw;
  final Color primaryColor;
  final Color accentColor;
  final double size;

  const OrientationFigure3D({
    super.key,
    required this.pitch,
    required this.roll,
    required this.yaw,
    this.primaryColor = Colors.blue,
    this.accentColor = Colors.lightBlueAccent,
    this.size = 240,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _FigurePainter(
          pitch: pitch,
          roll: roll,
          yaw: yaw,
          primaryColor: primaryColor,
          accentColor: accentColor,
        ),
      ),
    );
  }
}

/// A force-direction 3D arrow visualization.
class ForceVector3D extends StatelessWidget {
  final double ax;
  final double ay;
  final double az;
  final double peakForceKg;
  final double size;

  const ForceVector3D({
    super.key,
    required this.ax,
    required this.ay,
    required this.az,
    required this.peakForceKg,
    this.size = 240,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ForceArrowPainter(
          ax: ax,
          ay: ay,
          az: az,
          peakForceKg: peakForceKg,
          primaryColor: cs.primary,
          axisColor: cs.outline,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal painters
// ─────────────────────────────────────────────────────────────────────────────

class _FigurePainter extends CustomPainter {
  final double pitch;
  final double roll;
  final double yaw;
  final Color primaryColor;
  final Color accentColor;

  _FigurePainter({
    required this.pitch,
    required this.roll,
    required this.yaw,
    required this.primaryColor,
    required this.accentColor,
  });

  // Stick-figure keypoints, y-up, scale ~1.0 unit = half figure height
  static const List<List<double>> _points = [
    [0,    1.9,  0],  // 0  head top
    [0,    1.6,  0],  // 1  head bottom / neck
    [-0.5, 1.4,  0],  // 2  left shoulder
    [0.5,  1.4,  0],  // 3  right shoulder
    [-0.7, 0.85, 0],  // 4  left elbow
    [0.7,  0.85, 0],  // 5  right elbow
    [-0.75,0.35, 0],  // 6  left hand
    [0.75, 0.35, 0],  // 7  right hand
    [0,    0.85, 0],  // 8  hip center (torso base)
    [-0.25,0.85, 0],  // 9  left hip
    [0.25, 0.85, 0],  // 10 right hip
    [-0.28,0.3,  0],  // 11 left knee
    [0.28, 0.3,  0],  // 12 right knee
    [-0.3, -0.25,0],  // 13 left foot
    [0.3,  -0.25,0],  // 14 right foot
  ];

  // Line segments by index pairs
  static const List<List<int>> _segments = [
    [0, 1],   // head
    [1, 2],   // neck → left shoulder
    [1, 3],   // neck → right shoulder
    [2, 4],   // left arm upper
    [4, 6],   // left arm lower
    [3, 5],   // right arm upper
    [5, 7],   // right arm lower
    [1, 8],   // torso
    [8, 9],   // hip left split
    [8, 10],  // hip right split
    [9, 11],  // left thigh
    [11, 13], // left shin
    [10, 12], // right thigh
    [12, 14], // right shin
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width * 0.28;

    // Build rotation matrix from Euler angles (ZYX convention)
    final pRad = pitch * (pi / 180);
    final rRad = roll  * (pi / 180);
    final yRad = yaw   * (pi / 180);

    final rotX = vm.Matrix4.rotationX(pRad);
    final rotY = vm.Matrix4.rotationY(rRad);
    final rotZ = vm.Matrix4.rotationZ(yRad);
    final rot = rotZ * rotY * rotX;

    // Transform all points to 2D
    List<Offset> projected = _points.map((p) {
      final v = vm.Vector4(p[0], p[1], p[2], 1.0);
      final t = rot.transform(v);
      // Perspective projection (Z into screen)
      final fov = 4.0;
      final px = scale * t.x / (1 + t.z / fov) + cx;
      final py = scale * -t.y / (1 + t.z / fov) + cy;
      return Offset(px, py);
    }).toList();

    // Draw axes (small, bottom-right corner)
    _drawAxes(canvas, size, rot, scale * 0.20);

    // Draw figure shadows (depth cue: slightly shifted darker version)
    final shadowPaint = Paint()
      ..color = primaryColor.withOpacity(0.12)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var seg in _segments) {
      final a = projected[seg[0]] + const Offset(4, 4);
      final b = projected[seg[1]] + const Offset(4, 4);
      canvas.drawLine(a, b, shadowPaint);
    }

    // Draw figure
    final limbPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final torsoSegments = [6, 7, 8]; // torso: indices of torso-connecting segs
    for (var i = 0; i < _segments.length; i++) {
      final seg = _segments[i];
      final a = projected[seg[0]];
      final b = projected[seg[1]];
      // Slightly different colour for torso
      limbPaint.color = (torsoSegments.contains(i))
          ? accentColor
          : primaryColor;
      canvas.drawLine(a, b, limbPaint);
    }

    // Draw head circle
    final headCenter = projected[1];
    final headR = scale * 0.17;
    canvas.drawCircle(headCenter, headR, Paint()..color = Colors.grey.shade800..style = PaintingStyle.fill);
    canvas.drawCircle(
        headCenter, headR,
        Paint()..color = accentColor..style = PaintingStyle.stroke..strokeWidth = 3);

    // Draw joints
    final jointPaint = Paint()
      ..color = accentColor.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    for (var idx in [2, 3, 4, 5, 9, 10, 11, 12]) {
      canvas.drawCircle(projected[idx], 3.5, jointPaint);
    }
  }

  void _drawAxes(Canvas canvas, Size size, vm.Matrix4 rot, double len) {
    final origin = Offset(size.width - 36, size.height - 36);
    final fov = 4.0;

    Offset project(vm.Vector4 v) {
      final t = rot.transform(v);
      return Offset(t.x / (1 + t.z / fov) * len,
                   -t.y / (1 + t.z / fov) * len);
    }

    final x3 = project(vm.Vector4(1, 0, 0, 1));
    final y3 = project(vm.Vector4(0, 1, 0, 1));
    final z3 = project(vm.Vector4(0, 0, 1, 1));

    for (final pair in [
      [x3, Colors.red],
      [y3, Colors.green],
      [z3, Colors.blue],
    ]) {
      final end = origin + (pair[0] as Offset);
      canvas.drawLine(origin, end,
          Paint()..color = (pair[1] as Color).withOpacity(0.8)..strokeWidth = 2.5);
    }
  }

  @override
  bool shouldRepaint(_FigurePainter old) =>
      old.pitch != pitch || old.roll != roll || old.yaw != yaw;
}

// ─────────────────────────────────────────────────────────────────────────────

class _ForceArrowPainter extends CustomPainter {
  final double ax, ay, az;
  final double peakForceKg;
  final Color primaryColor;
  final Color axisColor;

  _ForceArrowPainter({
    required this.ax,
    required this.ay,
    required this.az,
    required this.peakForceKg,
    required this.primaryColor,
    required this.axisColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.width * 0.30;
    const fov = 5.0;

    // Slight isometric view rotation
    final rot = vm.Matrix4.rotationX(-0.4) * vm.Matrix4.rotationY(0.6);

    Offset proj(double x, double y, double z) {
      final v = vm.Vector4(x, y, z, 1.0);
      final t = rot.transform(v);
      return Offset(t.x / (1 + t.z / fov) * scale + cx,
                   -t.y / (1 + t.z / fov) * scale + cy);
    }

    final origin = proj(0, 0, 0);

    // Draw XYZ axes
    final axisPaint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final ax_ in [
      [1.0, 0.0, 0.0, Colors.red],
      [0.0, 1.0, 0.0, Colors.green],
      [0.0, 0.0, 1.0, Colors.blue],
    ]) {
      axisPaint.color = (ax_[3] as Color).withOpacity(0.4);
      canvas.drawLine(
          proj(-(ax_[0] as double) * 0.9, -(ax_[1] as double) * 0.9,
              -(ax_[2] as double) * 0.9),
          proj((ax_[0] as double) * 0.9, (ax_[1] as double) * 0.9,
              (ax_[2] as double) * 0.9),
          axisPaint);
    }

    // Axis labels
    void paintLabel(String s, Offset o, Color c) {
      final sp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      sp.paint(canvas, o - Offset(sp.width / 2, sp.height / 2));
    }
    paintLabel('X', proj(1.05, 0, 0), Colors.red);
    paintLabel('Y', proj(0, 1.05, 0), Colors.green);
    paintLabel('Z', proj(0, 0, 1.05), Colors.blue);

    // Normalize the acceleration vector
    final mag = sqrt(ax * ax + ay * ay + az * az);
    if (mag < 0.001) return;
    final nx = ax / mag;
    final ny = ay / mag;
    final nz = az / mag;

    // Draw force arrow (0 → 0.85 * unit vector)
    const arrowLen = 0.85;
    final arrowEnd = proj(nx * arrowLen, ny * arrowLen, nz * arrowLen);

    final arrowPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(origin, arrowEnd, arrowPaint);

    // Arrow head
    final direction = arrowEnd - origin;
    final dLen = direction.distance;
    if (dLen > 0) {
      final d = direction / dLen;
      final perp = Offset(-d.dy, d.dx);
      final tip = arrowEnd;
      final base1 = tip - d * 18 + perp * 9;
      final base2 = tip - d * 18 - perp * 9;
      final arrowHeadPath = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(base1.dx, base1.dy)
        ..lineTo(base2.dx, base2.dy)
        ..close();
      canvas.drawPath(arrowHeadPath, Paint()..color = primaryColor);
    }

    // Force sphere at tip
    final sphereR = 14.0 + peakForceKg.clamp(0, 100) * 0.12;
    canvas.drawCircle(
        arrowEnd,
        sphereR,
        Paint()
          ..color = primaryColor.withOpacity(0.25)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        arrowEnd,
        sphereR,
        Paint()
          ..color = primaryColor.withOpacity(0.7)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);

    // Draw force label
    final label = '${peakForceKg.toStringAsFixed(1)} kg';
    final tp2 = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: primaryColor,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp2.paint(canvas, arrowEnd + Offset(-tp2.width / 2, sphereR + 4));
  }

  @override
  bool shouldRepaint(_ForceArrowPainter old) =>
      old.ax != ax || old.ay != ay || old.az != az;
}
