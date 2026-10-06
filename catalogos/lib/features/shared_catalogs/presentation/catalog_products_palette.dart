import 'package:flutter/material.dart';

/// Colores de "Productos del catálogo" (diseño A, ver
/// `docs/design/productos-a.html`) que no forman parte de `AppColors` ni de
/// las paletas de otras pantallas porque son específicos de aquí (sombra de
/// la tarjeta de producto). El resto de colores de esta pantalla se
/// reutilizan: fondo blanco y borde de tarjeta de [HomePalette], texto
/// mutado/relleno de campo de [AuthPalette], marca de [AppColors].
abstract final class CatalogProductsPalette {
  const CatalogProductsPalette._();

  /// Sombra de la tarjeta de producto. `rgba(0,22,52,0.10)`.
  static const Color cardShadow = Color(0x1A001634);
}
