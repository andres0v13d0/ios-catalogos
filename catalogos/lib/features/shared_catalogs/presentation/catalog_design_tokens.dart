// Fuente ÚNICA de tokens visuales de "Productos del catálogo"
// (`docs/design/productos-a.html`) y "Ajustar precios"
// (`docs/design/ajustar-precios.html`). TODOS los valores (colores, radios,
// sombras, espacios, tamaños de texto) son los EXACTOS de esos HTML — nunca
// derivados del tema ni aproximados. Las dos pantallas importan SOLO de
// aquí (más `AppColors` para los 4 colores de marca universales); no
// reutilizan paletas de otras pantallas (login/inicio), que tienen su propio
// propósito y pueden divergir con el tiempo.
//
// Los números de espaciado/tamaño están en el marco de referencia 390×844dp
// de los HTML; se multiplican por [catalogScale] en el punto de uso — nunca
// se usan "en crudo" salvo que la pantalla ya esté a 390dp de ancho.

import 'package:flutter/material.dart';

/// Escala única: ancho/alto del dispositivo respecto al marco de referencia
/// 390×844 de los HTML. `min()` preserva la proporción (nunca deforma, nunca
/// estira imágenes ni cambia el estilo); los límites evitan extremos
/// ilegibles (muy chico) o gigantes (muy grande) en dispositivos atípicos.
double catalogScale(BuildContext context) {
  final Size size = MediaQuery.sizeOf(context);
  final double raw = (size.width / 390 < size.height / 844)
      ? size.width / 390
      : size.height / 844;
  return raw.clamp(0.82, 1.15);
}

abstract final class CatalogTokens {
  const CatalogTokens._();

  // ======================== Colores — productos-a.html ========================

  /// Intermedio del degradado de cabecera (165°, 55%). `#00306E`.
  static const Color headerGradientMid = Color(0xFF00306E);

  /// Brillo circular superior derecho de la cabecera. `rgba(93,224,230,0.28)`.
  static const Color headerCircleGlow = Color(0x475DE0E6);

  /// Anillo circular izquierdo de la cabecera. `rgba(93,224,230,0.4)`.
  static const Color headerRing = Color(0x665DE0E6);

  /// Sombra de las tarjetas de acceso rápido. `rgba(0,22,52,0.16)`.
  static const Color quickActionShadow = Color(0x29001634);

  /// Sombra del botón verde de compartir (cabecera) y de la insignia de
  /// ajuste. `rgba(0,255,148,0.35)`.
  static const Color greenGlowShadow = Color(0x5900FF94);

  /// Borde de tarjetas/buscador. `#E3ECF7`.
  static const Color cardBorder = Color(0xFFE3ECF7);

  /// Sombra de la tarjeta de producto de la cuadrícula. `rgba(0,22,52,0.10)`.
  static const Color gridCardShadow = Color(0x1A001634);

  /// Sombra del botón lápiz circular. `rgba(0,22,52,0.2)`.
  static const Color pencilShadow = Color(0x33001634);

  /// Fondo del buscador. `#F4F8FC`.
  static const Color searchBackground = Color(0xFFF4F8FC);

  /// Texto secundario gris-azulado sobre fondo claro. `#4A5A75`.
  static const Color textMuted = Color(0xFF4A5A75);

  /// Texto secundario sobre fondo oscuro (subtítulo de cabecera). `#C9D8EE`.
  static const Color subtitleOnDark = Color(0xFFC9D8EE);

  /// Color de placeholder del buscador. `#5F6E88`.
  static const Color searchHint = Color(0xFF5F6E88);

  /// Pares de degradado placeholder de la imagen de producto (mientras
  /// carga o si falla), ciclados por índice — nunca el degradado de marca
  /// (ese es solo para banners). Tomados tal cual de los 4 productos de
  /// ejemplo del HTML.
  static const List<List<Color>> productPlaceholderGradients = <List<Color>>[
    <Color>[Color(0xFFDDF3FF), Color(0xFFE8FBF3)],
    <Color>[Color(0xFFE8FBF3), Color(0xFFD6EEFF)],
    <Color>[Color(0xFFEAF0FF), Color(0xFFDDF3FF)],
    <Color>[Color(0xFFE8FBF3), Color(0xFFEAF0FF)],
  ];

  // ======================= Colores — ajustar-precios.html ======================

  /// Intermedio del degradado de fondo del editor (180°, 55%). `#003A85`.
  static const Color adjustGradientMid = Color(0xFF003A85);

  static const Color whiteOverlay08 = Color(0x14FFFFFF); // rgba(255,255,255,.08)
  static const Color whiteOverlay10 = Color(0x1AFFFFFF); // rgba(255,255,255,.1)
  static const Color whiteOverlay12 = Color(0x1FFFFFFF); // rgba(255,255,255,.12)
  static const Color whiteOverlay14 = Color(0x24FFFFFF); // rgba(255,255,255,.14)
  static const Color whiteOverlay20 = Color(0x33FFFFFF); // rgba(255,255,255,.2)
  static const Color whiteOverlay28 = Color(0x47FFFFFF); // rgba(255,255,255,.28)
  static const Color whiteOverlay30 = Color(0x4DFFFFFF); // rgba(255,255,255,.3)

  /// Fondo del teclado propio. `rgba(0,12,32,0.55)`.
  static const Color keypadBackground = Color(0x8C000C20);

  /// Sombra oscura de tarjeta/número sobre fondo navy. `rgba(0,10,30,0.35)`.
  static const Color darkCardShadow = Color(0x59000A1E);

  /// Sombra de pestaña activa (blanca) del selector Porcentaje/Valor fijo.
  /// `rgba(0,10,30,0.25)`.
  static const Color tabActiveShadow = Color(0x40000A1E);

  /// Anillo decorativo exterior del estado "Listo". `rgba(93,224,230,0.18)`.
  static const Color successRingOuter = Color(0x2E5DE0E6);

  /// Anillo decorativo interior del estado "Listo". `rgba(93,224,230,0.35)`.
  static const Color successRingInner = Color(0x595DE0E6);

  /// Sombra del círculo de éxito. `rgba(0,255,148,0.4)`.
  static const Color successGlowShadow = Color(0x6600FF94);

  /// Fondo de la insignia "+$X por unidad". `rgba(0,255,148,0.22)`.
  static const Color perUnitBadgeBackground = Color(0x3800FF94);

  /// Texto de la insignia "+$X por unidad". `#005C37`.
  static const Color perUnitBadgeText = Color(0xFF005C37);

  /// Separador entre renglones de la tarjeta resumen del estado "Listo".
  /// `#E3ECF7`.
  static const Color summaryDivider = Color(0xFFE3ECF7);

  /// Rojo de error sobre fondo oscuro (mismo tono que el resto de la app).
  static const Color errorOnDark = Color(0xFFFFB4B4);
}
