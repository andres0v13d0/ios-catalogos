import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import 'auth_palette.dart';

// Fondo compartido del flujo de login: degradado vertical de marca + brillos
// circulares de atmósfera. Usado por la pantalla de ingreso
// (`docs/design/ingreso-b.html`) y la de código (`docs/design/codigo-b.html`),
// que difieren solo en el punto medio del degradado y en la posición/tamaño/
// opacidad de los brillos (cada pantalla los posiciona con su propio
// `Positioned`).

/// Degradado vertical navy → [AuthPalette.heroGradientMid] → azul, a pantalla
/// completa. [midStop] es el punto (0..1) del color intermedio: 0.6 en
/// ingreso, 0.55 en código.
class AuthGradientBackground extends StatelessWidget {
  const AuthGradientBackground({super.key, required this.midStop});

  final double midStop;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: <double>[0.0, midStop, 1.0],
          colors: const <Color>[
            AppColors.primary,
            AuthPalette.heroGradientMid,
            AppColors.secondary,
          ],
        ),
      ),
    );
  }
}

/// Brillo circular radial (centro opaco → borde transparente). [color] ya
/// lleva el alfa del pico (p. ej. `Color(0x735DE0E6)`); se desvanece a
/// transparente en [fadeStop] (68% en ambos mockups).
class AuthRadialGlow extends StatelessWidget {
  const AuthRadialGlow({super.key, required this.color, this.fadeStop = 0.68});

  final Color color;
  final double fadeStop;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[color, color.withAlpha(0)],
          stops: <double>[0.0, fadeStop],
        ),
      ),
    );
  }
}

/// Círculo plano de un solo color translúcido (sin degradado). [color] ya
/// lleva el alfa (p. ej. `Color(0x2E00FF94)`).
class AuthFlatGlow extends StatelessWidget {
  const AuthFlatGlow({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
