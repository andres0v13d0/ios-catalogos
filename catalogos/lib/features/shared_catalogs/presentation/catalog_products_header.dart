import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/auth_vector_icons.dart';
import 'catalog_design_tokens.dart';
import 'catalog_products_icons.dart';

/// Cabecera + fila de accesos rápidos de "Productos del catálogo" (diseño A,
/// ver `docs/design/productos-a.html`), fusionadas en un solo widget porque
/// las tarjetas de acceso MONTAN sobre el borde de la cabecera (mitad sobre
/// el degradado, mitad sobre el blanco) — igual que en el HTML, donde todo
/// vive en el mismo marco `position:relative`.
///
/// Escala con [catalogScale] (ver `catalog_design_tokens.dart`): todas las
/// posiciones/tamaños están en el marco de referencia 390×844 y se
/// multiplican por `s`. Nunca se redimensiona de forma independiente
/// (ni se "adivinan" valores): son los del HTML.
class CatalogProductsHero extends StatelessWidget {
  const CatalogProductsHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onShare,
    required this.showAdjustPrices,
    required this.adjustPricesBadge,
    required this.onAdjustPrices,
    required this.onImageLink,
    required this.onShareLink,
  });

  /// Nombre PÚBLICO del catálogo. NUNCA el nombre interno.
  final String title;

  /// `"N productos"`, o cadena vacía mientras se desconoce (no se dibuja).
  final String subtitle;

  final VoidCallback onBack;
  final VoidCallback onShare;

  /// `false` en catálogos "sin precios": el acceso "Ajustar precios" se
  /// oculta y los otros dos se reparten el ancho completo.
  final bool showAdjustPrices;

  /// Insignia del ajuste activo (p. ej. "+30%"), o `null` si no hay regla.
  final String? adjustPricesBadge;

  final VoidCallback onAdjustPrices;
  final VoidCallback onImageLink;
  final VoidCallback onShareLink;

  // ---- Marco de referencia (390×844, ver productos-a.html) ----
  static const double _headerHeightRef = 200;
  static const double _cardsTopRef = 148;

  /// Alto REAL de una tarjeta de acceso rápido (no una aproximación): es la
  /// suma de sus partes en el marco de referencia, idéntica a la que arma
  /// [_QuickActionCard] — padding vertical (10+10) + círculo del ícono (34) +
  /// hueco (6) + etiqueta de hasta 2 líneas (12dp × 1.25 × 2). Se usa para
  /// RESERVAR su alto en el layout, de modo que el buscador y la cuadrícula
  /// empiecen SIEMPRE debajo (nunca detrás) de las tarjetas.
  static const double _cardLabelLineHeightRef = 12 * 1.25;
  static const double _cardHeightRef =
      10 + 34 + 6 + (_cardLabelLineHeightRef * 2) + 10; // = 100

  @override
  Widget build(BuildContext context) {
    final double s = catalogScale(context);
    final double headerHeight = _headerHeightRef * s;
    // Reservar hasta el borde inferior REAL de las tarjetas (su cima + su alto
    // completo), nunca solo la parte que sobresale: así el buscador que va
    // debajo de esta cabecera arranca por debajo de las tarjetas, con el
    // espacio de separación que añade quien la coloca (≥16dp).
    final double totalHeight = (_cardsTopRef + _cardHeightRef) * s;

    return SizedBox(
      height: totalHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: headerHeight,
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment(-0.57, -1), // ~165°
                          end: Alignment(0.57, 1),
                          stops: <double>[0.0, 0.55, 1.0],
                          colors: <Color>[
                            AppColors.primary,
                            CatalogTokens.headerGradientMid,
                            AppColors.secondary,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -70 * s,
                    right: -80 * s,
                    width: 230 * s,
                    height: 230 * s,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CatalogTokens.headerCircleGlow,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 60 * s,
                    left: -100 * s,
                    width: 170 * s,
                    height: 170 * s,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: CatalogTokens.headerRing, width: 2 * s),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -1,
                    child: SizedBox(
                      height: 50 * s,
                      child: CustomPaint(painter: _WaveBottomPainter()),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(left: 16 * s, top: 48 * s, child: _CircleIconButton(size: 44 * s, onTap: onBack, child: _BackIcon(size: 22 * s))),

          Positioned(
            left: 72 * s,
            right: 72 * s,
            top: 50 * s,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18 * s, height: 1.3, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12 * s, height: 1.4, color: CatalogTokens.subtitleOnDark),
                  ),
              ],
            ),
          ),

          Positioned(
            right: 16 * s,
            top: 48 * s,
            child: _CircleIconButton(
              size: 44 * s,
              background: AppColors.brand,
              shadow: <BoxShadow>[
                BoxShadow(color: CatalogTokens.greenGlowShadow, offset: Offset(0, 10 * s), blurRadius: 22 * s),
              ],
              onTap: onShare,
              semanticLabel: 'Compartir enlace',
              child: SizedBox(
                width: 20 * s,
                height: 20 * s,
                child: CustomPaint(painter: ShareNodesPainter(color: AppColors.primary)),
              ),
            ),
          ),

          Positioned(
            left: 20 * s,
            right: 20 * s,
            top: _cardsTopRef * s,
            // IntrinsicHeight + stretch: las 3 tarjetas comparten EXACTAMENTE
            // la misma altura (la de la más alta) y el mismo borde superior,
            // aunque una etiqueta ocupe 1 línea y las otras 2 (ver
            // productos-a.html). Su contenido se alinea arriba (ícono y, debajo,
            // la etiqueta), nunca centrado a alturas distintas.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                if (showAdjustPrices) ...<Widget>[
                  Expanded(
                    child: _QuickActionCard(
                      scale: s,
                      label: 'Ajustar precios',
                      iconBackground: AppColors.accent,
                      iconColor: AppColors.primary,
                      icon: PercentDiagonalPainter(color: AppColors.primary),
                      badge: adjustPricesBadge,
                      onTap: onAdjustPrices,
                    ),
                  ),
                  SizedBox(width: 10 * s),
                ],
                Expanded(
                  child: _QuickActionCard(
                    scale: s,
                    label: 'Imagen del enlace',
                    iconBackground: AppColors.brand,
                    iconColor: AppColors.primary,
                    icon: ImageIconPainter(color: AppColors.primary),
                    onTap: onImageLink,
                  ),
                ),
                SizedBox(width: 10 * s),
                Expanded(
                  child: _QuickActionCard(
                    scale: s,
                    label: 'Compartir enlace',
                    iconBackground: AppColors.primary,
                    iconColor: AppColors.brand,
                    icon: WhatsAppPainter(color: AppColors.brand),
                    onTap: onShareLink,
                  ),
                ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.scale,
    required this.label,
    required this.iconBackground,
    required this.iconColor,
    required this.icon,
    required this.onTap,
    this.badge,
  });

  final double scale;
  final String label;
  final Color iconBackground;
  final Color iconColor;
  final CustomPainter icon;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Semantics(
      button: true,
      label: badge == null ? label : '$label, ajuste activo $badge',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        child: InkWell(
          borderRadius: BorderRadius.circular(18 * s),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 10 * s),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: CatalogTokens.cardBorder),
              borderRadius: BorderRadius.circular(18 * s),
              boxShadow: <BoxShadow>[
                BoxShadow(color: CatalogTokens.quickActionShadow, offset: Offset(0, 12 * s), blurRadius: 26 * s),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      width: 34 * s,
                      height: 34 * s,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
                      child: SizedBox(width: 18 * s, height: 18 * s, child: CustomPaint(painter: icon)),
                    ),
                    if (badge != null)
                      Positioned(
                        right: -10 * s,
                        top: -6 * s,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6 * s, vertical: 1 * s),
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: <BoxShadow>[
                              BoxShadow(color: CatalogTokens.greenGlowShadow, offset: Offset(0, 4 * s), blurRadius: 10 * s),
                            ],
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(fontSize: 9.5 * s, fontWeight: FontWeight.w700, color: AppColors.primary),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 6 * s),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w600, height: 1.25, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.size,
    required this.onTap,
    required this.child,
    this.background = const Color(0x24FFFFFF),
    this.shadow,
    this.semanticLabel,
  });

  final double size;
  final VoidCallback onTap;
  final Widget child;
  final Color background;
  final List<BoxShadow>? shadow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? 'Volver',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: background, boxShadow: shadow),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _BackIcon extends StatelessWidget {
  const _BackIcon({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ChevronLeftPainter()),
    );
  }
}

class _ChevronLeftPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width / 24;
    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Path path = Path()
      ..moveTo(15 * s, 6 * s)
      ..lineTo(9 * s, 12 * s)
      ..lineTo(15 * s, 18 * s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChevronLeftPainter oldDelegate) => false;
}

/// Onda blanca que separa la cabecera del cuerpo. Replica
/// `M0 25 C 90 60, 230 0, 390 30 L390 50 L0 50 Z` (viewBox 390x50), escalada
/// al ancho real del dispositivo.
class _WaveBottomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 390;
    final double sy = size.height / 50;
    final Path path = Path()
      ..moveTo(0, 25 * sy)
      ..cubicTo(90 * sx, 60 * sy, 230 * sx, 0, 390 * sx, 30 * sy)
      ..lineTo(390 * sx, 50 * sy)
      ..lineTo(0, 50 * sy)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _WaveBottomPainter oldDelegate) => false;
}
