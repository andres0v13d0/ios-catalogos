// Íconos vectoriales propios de "Productos del catálogo"/"Ajustar precios"
// (ver docs/design/productos-a.html y docs/design/ajustar-precios.html),
// redibujados con CustomPainter a partir de los paths SVG del mockup
// (viewBox 0 0 24 24) — mismo enfoque que `auth_vector_icons.dart`, sin
// depender de un paquete de íconos nuevo.

import 'package:flutter/material.dart';

/// Lápiz de "Ajustar el precio de este producto". Replica
/// `M4 20h4L19 9l-4-4L4 16v4z` + `M13.5 6.5l4 4`.
class PencilPainter extends CustomPainter {
  const PencilPainter({required this.color, this.strokeWidth = 2.2});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path body = Path()
      ..moveTo(4 * s, 20 * s)
      ..lineTo(8 * s, 20 * s)
      ..lineTo(19 * s, 9 * s)
      ..lineTo(15 * s, 5 * s)
      ..lineTo(4 * s, 16 * s)
      ..close();
    final Path tip = Path()
      ..moveTo(13.5 * s, 6.5 * s)
      ..lineTo(17.5 * s, 10.5 * s);

    canvas.drawPath(body, paint);
    canvas.drawPath(tip, paint);
  }

  @override
  bool shouldRepaint(covariant PencilPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Ícono del acceso "Ajustar precios" (diagonal + 2 círculos, estilo "%").
/// Replica `M19 5L5 19` + círculos en (7,7) y (17,17), radio 2.5.
class PercentDiagonalPainter extends CustomPainter {
  const PercentDiagonalPainter({required this.color, this.strokeWidth = 2.3});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    final Paint strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * s
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(19 * s, 5 * s), Offset(5 * s, 19 * s), strokePaint);
    canvas.drawCircle(Offset(7 * s, 7 * s), 2.5 * s, strokePaint);
    canvas.drawCircle(Offset(17 * s, 17 * s), 2.5 * s, strokePaint);
  }

  @override
  bool shouldRepaint(covariant PercentDiagonalPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Ícono "compartir" (3 nodos conectados) del botón verde de la cabecera.
/// Replica círculos en (18,5), (6,12), (18,19) radio 3 + líneas
/// `M8.6 10.5l6.8-4` y `M8.6 13.5l6.8 4`.
class ShareNodesPainter extends CustomPainter {
  const ShareNodesPainter({required this.color, this.strokeWidth = 2.2});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * s
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(18 * s, 5 * s), 3 * s, stroke);
    canvas.drawCircle(Offset(6 * s, 12 * s), 3 * s, stroke);
    canvas.drawCircle(Offset(18 * s, 19 * s), 3 * s, stroke);
    canvas.drawLine(Offset(8.6 * s, 10.5 * s), Offset(15.4 * s, 6.5 * s), stroke);
    canvas.drawLine(Offset(8.6 * s, 13.5 * s), Offset(15.4 * s, 17.5 * s), stroke);
  }

  @override
  bool shouldRepaint(covariant ShareNodesPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Ícono "imagen" (marco + sol + montaña) del acceso "Imagen del enlace".
/// Replica `rect(3,4,18,16,rx3)` + círculo (9,10) r1.8 +
/// `M21 16l-5-5-8 8`.
class ImageIconPainter extends CustomPainter {
  const ImageIconPainter({required this.color, this.strokeWidth = 2.3});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final RRect frame = RRect.fromRectAndRadius(
      Rect.fromLTWH(3 * s, 4 * s, 18 * s, 16 * s),
      Radius.circular(3 * s),
    );
    canvas.drawRRect(frame, stroke);
    canvas.drawCircle(Offset(9 * s, 10 * s), 1.8 * s, stroke);
    final Path mountain = Path()
      ..moveTo(21 * s, 16 * s)
      ..lineTo(16 * s, 11 * s)
      ..lineTo(8 * s, 19 * s);
    canvas.drawPath(mountain, stroke);
  }

  @override
  bool shouldRepaint(covariant ImageIconPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// "Cambiar" (intercambiar/sincronizar). Replica
/// `M20 11a8 8 0 0 0-14-4.5L4 9` + `M4 4v5h5` +
/// `M4 13a8 8 0 0 0 14 4.5L20 15` + `M20 20v-5h-5`.
class SwapPainter extends CustomPainter {
  const SwapPainter({required this.color, this.strokeWidth = 2.2});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Rect topArcRect = Rect.fromCircle(center: Offset(12 * s, 11 * s), radius: 8 * s);
    final Path topArc = Path()
      ..addArc(topArcRect, _deg(-100), _deg(145))
      ..moveTo(4 * s, 4 * s)
      ..lineTo(4 * s, 9 * s)
      ..lineTo(9 * s, 9 * s);

    final Rect bottomArcRect = Rect.fromCircle(center: Offset(12 * s, 13 * s), radius: 8 * s);
    final Path bottomArc = Path()
      ..addArc(bottomArcRect, _deg(80), _deg(145))
      ..moveTo(20 * s, 20 * s)
      ..lineTo(20 * s, 15 * s)
      ..lineTo(15 * s, 15 * s);

    canvas.drawPath(topArc, paint);
    canvas.drawPath(bottomArc, paint);
  }

  double _deg(double degrees) => degrees * 3.1415926535 / 180;

  @override
  bool shouldRepaint(covariant SwapPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
