import 'package:flutter/material.dart';

/// Colores de los rediseños "B" del flujo de login (ingreso de teléfono,
/// ver `docs/design/ingreso-b.html`, y verificación de código, ver
/// `docs/design/codigo-b.html`) que no forman parte de [AppColors] porque
/// son específicos de estas pantallas (fondos de campo, bordes, texto
/// secundario sobre fondo claro u oscuro, esqueletos). Los colores de marca
/// ya existentes en `AppColors` (navy/azul/cian/verde) sí se reutilizan desde
/// allí.
///
/// Alcance deliberadamente local al flujo de login: no se promueven a
/// `AppColors` para no afectar otras pantallas con estas tareas.
abstract final class AuthPalette {
  const AuthPalette._();

  /// Paso intermedio del degradado de fondo (60% en ingreso, 55% en código).
  /// `#003A85`.
  static const Color heroGradientMid = Color(0xFF003A85);

  /// Texto secundario gris-azulado sobre fondo CLARO (hoja inferior de
  /// ingreso: subtítulo, pie de página). `#4A5A75`.
  static const Color textMuted = Color(0xFF4A5A75);

  /// Borde de campos/asa de la hoja. `#D5E0F0`.
  static const Color fieldBorder = Color(0xFFD5E0F0);

  /// Fondo del botón de país. `#F4F8FC`.
  static const Color countryFieldBackground = Color(0xFFF4F8FC);

  /// Barras "esqueleto" de las tarjetas del hero. `#DCE6F3`.
  static const Color skeleton = Color(0xFFDCE6F3);

  /// Color de hint/placeholder del campo de teléfono. `#5F6E88`.
  static const Color hint = Color(0xFF5F6E88);

  /// Rojo oscuro de mensajes de error (validación y backend) en la pantalla
  /// de ingreso, con buen contraste sobre la hoja blanca.
  static const Color errorRed = Color(0xFFB3261E);

  /// Texto secundario sobre fondo OSCURO (pantalla de código: subtítulo,
  /// contador de cooldown). `#C9D8EE`.
  static const Color textMutedOnDark = Color(0xFFC9D8EE);

  /// Borde rojo suave de las casillas del código en estado de error.
  /// `#FF8A8A`.
  static const Color codeErrorBorder = Color(0xFFFF8A8A);

  /// Texto de error sobre fondo oscuro (pantalla de código), con buen
  /// contraste. `#FFB4B4`.
  static const Color codeErrorText = Color(0xFFFFB4B4);
}
