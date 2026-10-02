import 'package:flutter/painting.dart';

/// Paleta de color de la identidad visual FlyStock (diseño §2.8, UX-1).
///
/// Centraliza los colores de marca para que el `ThemeData` y los widgets
/// compartidos (p. ej. el botón con gradiente) usen una única fuente de verdad.
abstract final class AppColors {
  const AppColors._();

  /// Azul profundo. Color primario de la marca. `#001634`.
  static const Color primary = Color(0xFF001634);

  /// Azul vibrante. Color secundario / inicio del gradiente. `#004AAD`.
  static const Color secondary = Color(0xFF004AAD);

  /// Cian de acento / paso intermedio del gradiente. `#5DE0E6`.
  static const Color accent = Color(0xFF5DE0E6);

  /// Verde de marca / final del gradiente. `#00FF94`.
  static const Color brand = Color(0xFF00FF94);

  /// Fondo general de la app. `#F8F9FA`.
  static const Color background = Color(0xFFF8F9FA);

  /// Color de texto principal. `#212529`.
  static const Color text = Color(0xFF212529);

  /// Blanco de superficies/contenido sobre colores oscuros.
  static const Color onDark = Color(0xFFFFFFFF);

  /// Secuencia de colores del gradiente del botón primario:
  /// `#004AAD → #5DE0E6 → #00FF94`.
  static const List<Color> primaryGradient = <Color>[
    secondary,
    accent,
    brand,
  ];
}
