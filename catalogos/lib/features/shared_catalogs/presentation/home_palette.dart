import 'package:flutter/material.dart';

/// Colores del rediseño "Tus catálogos" (carrusel, ver
/// `docs/design/inicio-a-carrusel.html`) que no forman parte de `AppColors`
/// porque son específicos de esta pantalla (borde de tarjeta, degradado del
/// hero, puntos del carrusel, insignias de precio). Los colores de marca ya
/// existentes (navy/azul/cian/verde) se reutilizan desde `AppColors`, y el
/// texto secundario sobre fondo oscuro/claro desde `AuthPalette`.
abstract final class HomePalette {
  const HomePalette._();

  /// Fondo de la pantalla "Tus catálogos" bajo la cabecera: todo (zona del
  /// carrusel, huecos entre tarjeta y cabecera, franja de los puntos, área
  /// segura inferior) es este mismo blanco — sin excepciones ni contenedores
  /// con otro tono — para que no se note ninguna franja. `#FFFFFF`.
  static const Color screenBackground = Color(0xFFFFFFFF);

  /// Intermedio del degradado del hero (165°, distinto del de login/código).
  /// `#00306E`.
  static const Color heroGradientMid = Color(0xFF00306E);

  /// Borde sutil de las tarjetas del carrusel. `#E3ECF7`.
  static const Color cardBorder = Color(0xFFE3ECF7);

  /// Punto inactivo del carrusel (vecino/borde). `#C5D3E8`.
  static const Color dotInactive = Color(0xFFC5D3E8);

  /// Fondo de la insignia "Con precios". `rgba(0,255,148,0.2)`.
  static const Color priceOnBackground = Color(0x3300FF94);

  /// Texto de la insignia "Con precios". `#005C37`.
  static const Color priceOnText = Color(0xFF005C37);

  /// Fondo de la insignia "Sin precios" (neutro; el mockup solo define el
  /// estado "con precios" — este tono gris-azulado sigue la misma familia que
  /// el resto de superficies discretas de la app).
  static const Color priceOffBackground = Color(0xFFEEF2F8);

  /// Texto de la insignia "Sin precios".
  static const Color priceOffText = Color(0xFF4A5A75);
}
