import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Tema visual FlyStock de la app de Revendedores (diseño §2.8, UX-1).
///
/// Expone el [ThemeData] con tipografía Poppins (vía `google_fonts`) y un
/// [ColorScheme] derivado de la paleta de marca definida en [AppColors]:
/// primario `#001634`, secundario `#004AAD`, acento `#5DE0E6`,
/// brand `#00FF94`; fondo `#F8F9FA`, texto `#212529`.
abstract final class AppTheme {
  const AppTheme._();

  /// Nombre de la familia tipográfica de marca.
  static const String fontFamily = 'Poppins';

  /// [ColorScheme] de la identidad FlyStock, en modo claro.
  static const ColorScheme colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onDark,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onDark,
    tertiary: AppColors.accent,
    onTertiary: AppColors.primary,
    // El verde de marca se expone como color de "estado positivo"/acento fuerte.
    surfaceTint: AppColors.brand,
    error: Color(0xFFB00020),
    onError: AppColors.onDark,
    surface: AppColors.onDark,
    onSurface: AppColors.text,
  );

  /// [ThemeData] completo de la app con Poppins + [colorScheme].
  static ThemeData get themeData {
    final TextTheme baseTextTheme = ThemeData.light().textTheme.apply(
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: fontFamily,
      // Aplica Poppins a todo el TextTheme preservando tamaños/pesos base.
      textTheme: _poppinsTextTheme(baseTextTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onDark,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  /// Aplica la fuente Poppins (vía `google_fonts`) sobre cada estilo del
  /// [TextTheme] de Flutter, devolviendo un [TextTheme] de Material.
  ///
  /// No usamos `GoogleFonts.poppinsTextTheme()` directamente porque, en el
  /// toolchain de este proyecto, esa API devuelve/espera el `TextTheme` del
  /// paquete `material_ui` (dependencia interna de `google_fonts`), que es un
  /// tipo distinto e incompatible con el `TextTheme` de `flutter/material.dart`.
  /// En cambio, `GoogleFonts.poppins(textStyle: ...)` sí devuelve un
  /// [TextStyle] de Flutter (y dispara la carga de la fuente), por lo que
  /// construimos el [TextTheme] estilo por estilo manteniéndonos en los tipos
  /// de Material.
  static TextTheme _poppinsTextTheme(TextTheme base) {
    TextStyle? poppins(TextStyle? style) =>
        style == null ? null : GoogleFonts.poppins(textStyle: style);

    return base.copyWith(
      displayLarge: poppins(base.displayLarge),
      displayMedium: poppins(base.displayMedium),
      displaySmall: poppins(base.displaySmall),
      headlineLarge: poppins(base.headlineLarge),
      headlineMedium: poppins(base.headlineMedium),
      headlineSmall: poppins(base.headlineSmall),
      titleLarge: poppins(base.titleLarge),
      titleMedium: poppins(base.titleMedium),
      titleSmall: poppins(base.titleSmall),
      bodyLarge: poppins(base.bodyLarge),
      bodyMedium: poppins(base.bodyMedium),
      bodySmall: poppins(base.bodySmall),
      labelLarge: poppins(base.labelLarge),
      labelMedium: poppins(base.labelMedium),
      labelSmall: poppins(base.labelSmall),
    );
  }
}
