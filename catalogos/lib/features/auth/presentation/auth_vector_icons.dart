// Íconos vectoriales de los rediseños "B" del flujo de login: ingreso de
// teléfono (`docs/design/ingreso-b.html`) y verificación de código
// (`docs/design/codigo-b.html`), redibujados con [CustomPainter] a partir de
// los mismos paths SVG de cada mockup (viewBox 0 0 24 24) para no depender
// de un paquete de íconos nuevo.
//
// Son puramente decorativos/visuales: no tienen relación con la lógica de
// autenticación.

import 'package:flutter/material.dart';

/// Cubo isométrico de la cabecera (trazo navy, hexágono + 3 aristas
/// interiores hacia el centro). Replica
/// `M12 3l8 4.5v9L12 21l-8-4.5v-9L12 3z` + `M12 12l8-4.5M12 12L4 7.5M12 12v9`.
class IsoCubePainter extends CustomPainter {
  const IsoCubePainter({required this.color, this.strokeWidth = 2});

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

    final Path hexagon = Path()
      ..moveTo(12 * s, 3 * s)
      ..lineTo(20 * s, 7.5 * s)
      ..lineTo(20 * s, 16.5 * s)
      ..lineTo(12 * s, 21 * s)
      ..lineTo(4 * s, 16.5 * s)
      ..lineTo(4 * s, 7.5 * s)
      ..close();

    final Path innerEdges = Path()
      ..moveTo(12 * s, 12 * s)
      ..lineTo(20 * s, 7.5 * s)
      ..moveTo(12 * s, 12 * s)
      ..lineTo(4 * s, 7.5 * s)
      ..moveTo(12 * s, 12 * s)
      ..lineTo(12 * s, 21 * s);

    canvas.drawPath(hexagon, paint);
    canvas.drawPath(innerEdges, paint);
  }

  @override
  bool shouldRepaint(covariant IsoCubePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Ícono de carrito de compras (círculo blanco flotante). Replica las 2
/// ruedas (círculos r1.4) y la canasta `M3 4h2.5l2.2 11h10.6l2-8H6.4`.
class CartPainter extends CustomPainter {
  const CartPainter({required this.color, this.strokeWidth = 2});

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

    final Path basket = Path()
      ..moveTo(3 * s, 4 * s)
      ..lineTo(5.5 * s, 4 * s)
      ..lineTo(7.7 * s, 15 * s)
      ..lineTo(18.3 * s, 15 * s)
      ..lineTo(20.3 * s, 7 * s)
      ..lineTo(6.4 * s, 7 * s);
    canvas.drawPath(basket, paint);

    canvas.drawCircle(Offset(9 * s, 20 * s), 1.4 * s, paint);
    canvas.drawCircle(Offset(18 * s, 20 * s), 1.4 * s, paint);
  }

  @override
  bool shouldRepaint(covariant CartPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Chevron hacia abajo del botón de país. Replica `M6 9l6 6 6-6`.
class ChevronDownPainter extends CustomPainter {
  const ChevronDownPainter({required this.color, this.strokeWidth = 2.4});

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

    final Path chevron = Path()
      ..moveTo(6 * s, 9 * s)
      ..lineTo(12 * s, 15 * s)
      ..lineTo(18 * s, 9 * s);
    canvas.drawPath(chevron, paint);
  }

  @override
  bool shouldRepaint(covariant ChevronDownPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Flecha "→" del botón "Enviar código". Replica `M5 12h14` + `M13 6l6 6-6 6`.
class ArrowForwardPainter extends CustomPainter {
  const ArrowForwardPainter({required this.color, this.strokeWidth = 2.2});

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

    final Path shaft = Path()
      ..moveTo(5 * s, 12 * s)
      ..lineTo(19 * s, 12 * s);
    final Path head = Path()
      ..moveTo(13 * s, 6 * s)
      ..lineTo(19 * s, 12 * s)
      ..lineTo(13 * s, 18 * s);

    canvas.drawPath(shaft, paint);
    canvas.drawPath(head, paint);
  }

  @override
  bool shouldRepaint(covariant ArrowForwardPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Palomita "✓" del botón "Verificar" (pantalla de código). Replica
/// `M5 12.5l4.5 4.5L19 7.5`.
class CheckPainter extends CustomPainter {
  const CheckPainter({required this.color, this.strokeWidth = 2.4});

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

    final Path check = Path()
      ..moveTo(5 * s, 12.5 * s)
      ..lineTo(9.5 * s, 17 * s)
      ..lineTo(19 * s, 7.5 * s);
    canvas.drawPath(check, paint);
  }

  @override
  bool shouldRepaint(covariant CheckPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Chevron "‹" del botón "Volver" (pantalla de código). Replica
/// `M15 6l-6 6 6 6`.
class ChevronLeftPainter extends CustomPainter {
  const ChevronLeftPainter({required this.color, this.strokeWidth = 2.2});

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

    final Path chevron = Path()
      ..moveTo(15 * s, 6 * s)
      ..lineTo(9 * s, 12 * s)
      ..lineTo(15 * s, 18 * s);
    canvas.drawPath(chevron, paint);
  }

  @override
  bool shouldRepaint(covariant ChevronLeftPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Ícono de WhatsApp (burbuja + cola) de la cabecera de la pantalla de
/// código. Replica
/// `M21 11.5a8.5 8.5 0 0 1-12.4 7.5L3 20.5l1.6-5.4A8.5 8.5 0 1 1 21 11.5z`.
class WhatsAppPainter extends CustomPainter {
  const WhatsAppPainter({required this.color, this.strokeWidth = 2});

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

    final Radius r = Radius.circular(8.5 * s);
    final Path bubble = Path()
      ..moveTo(21 * s, 11.5 * s)
      ..arcToPoint(Offset(8.6 * s, 19.0 * s), radius: r)
      ..lineTo(3 * s, 20.5 * s)
      ..lineTo(4.6 * s, 15.1 * s)
      ..arcToPoint(Offset(21 * s, 11.5 * s), radius: r, largeArc: true)
      ..close();

    canvas.drawPath(bubble, paint);
  }

  @override
  bool shouldRepaint(covariant WhatsAppPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Ícono de "Borrar" del teclado numérico propio. Replica
/// `M21 5H9l-6 7 6 7h12V5z` + `M13 9.5l5 5M18 9.5l-5 5`.
class BackspacePainter extends CustomPainter {
  const BackspacePainter({required this.color, this.strokeWidth = 2});

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

    final Path outline = Path()
      ..moveTo(21 * s, 5 * s)
      ..lineTo(9 * s, 5 * s)
      ..lineTo(3 * s, 12 * s)
      ..lineTo(9 * s, 19 * s)
      ..lineTo(21 * s, 19 * s)
      ..close();
    final Path cross = Path()
      ..moveTo(13 * s, 9.5 * s)
      ..lineTo(18 * s, 14.5 * s)
      ..moveTo(18 * s, 9.5 * s)
      ..lineTo(13 * s, 14.5 * s);

    canvas.drawPath(outline, paint);
    canvas.drawPath(cross, paint);
  }

  @override
  bool shouldRepaint(covariant BackspacePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
