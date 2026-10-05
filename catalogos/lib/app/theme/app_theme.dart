import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Tema visual FlyStock de la app de Revendedores (diseño §2.8, UX-1).
///
/// Expone el [ThemeData] con tipografía Poppins (empaquetada localmente en
/// `assets/fonts/`, ver `pubspec.yaml`; no se descarga en runtime) y un
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
      // Fija explícitamente `fontFamily: 'Poppins'` (el asset local
      // declarado en pubspec.yaml) en cada estilo del TextTheme base; no
      // depende de la fusión implícita de ThemeData ni de `google_fonts`.
      textTheme: baseTextTheme.apply(fontFamily: fontFamily),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onDark,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
