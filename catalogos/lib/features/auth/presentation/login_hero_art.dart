import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import 'auth_background.dart';
import 'auth_palette.dart';
import 'auth_vector_icons.dart';

/// Composición decorativa superior ("hero") del rediseño "B · Hoja inferior"
/// de la pantalla de ingreso: brillos de fondo, cabecera "FLYmovil", las 3
/// tarjetas apiladas y las 2 etiquetas flotantes.
///
/// Réplica 1:1 de `docs/design/ingreso-b.html` en un lienzo fijo de
/// 390x450 dp (el marco de referencia del diseño); quien la use debe
/// escalarla con `FittedBox`/`BoxFit.contain` para adaptarla a otros tamaños
/// (ver `LoginPage`). Puramente visual: no contiene lógica de negocio.
class LoginHeroArt extends StatelessWidget {
  const LoginHeroArt({super.key, required this.t});

  /// Progreso 0..1 de la animación de entrada (abanico de tarjetas).
  /// En 1.0 queda exactamente en la posición final del mockup.
  final double t;

  static const double width = 390;
  static const double height = 450;

  double _seg(double start, double end, Curve curve) {
    final double raw = ((t - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(raw);
  }

  Widget _popIn({required double progress, double angleDeg = 0, required Widget child}) {
    final double opacity = progress.clamp(0.0, 1.0);
    final double scale = 0.7 + 0.3 * progress;
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Transform.rotate(
          angle: angleDeg * (3.14159265 / 180) * progress,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double headerT = _seg(0.0, 0.25, Curves.easeOut);
    final double centerCardT = _seg(0.0, 0.6, Curves.easeOutBack);
    final double sideCardsT = _seg(0.1, 0.7, Curves.easeOutBack);
    final double labelsT = _seg(0.35, 1.0, Curves.easeOutCubic);

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Brillo cian de fondo.
          const Positioned(
            left: -10,
            top: 60,
            width: 410,
            height: 410,
            child: AuthRadialGlow(color: Color(0x735DE0E6)), // rgba(93,224,230,0.45)
          ),
          // Círculo verde de fondo.
          const Positioned(
            right: -60,
            top: 250,
            width: 150,
            height: 150,
            child: AuthFlatGlow(color: Color(0x2E00FF94)), // rgba(0,255,148,0.18)
          ),

          // Cabecera: cubo + "FLYmovil".
          Positioned(
            left: 0,
            right: 0,
            top: 48,
            child: Opacity(
              opacity: headerT,
              child: const _HeroHeader(),
            ),
          ),

          // Tarjeta izquierda (detrás).
          Positioned(
            left: 52,
            top: 176,
            child: _popIn(
              progress: sideCardsT,
              angleDeg: -12,
              child: const _StackCard(
                width: 150,
                height: 196,
                imageHeight: 92,
                imageGradient: <Color>[AppColors.secondary, AppColors.accent],
                barWidths: <double>[0.78, 0.48],
              ),
            ),
          ),
          // Tarjeta derecha (detrás).
          Positioned(
            left: 188,
            top: 176,
            child: _popIn(
              progress: sideCardsT,
              angleDeg: 12,
              child: const _StackCard(
                width: 150,
                height: 196,
                imageHeight: 92,
                imageGradient: <Color>[AppColors.brand, AppColors.accent],
                barWidths: <double>[0.70, 0.55],
              ),
            ),
          ),
          // Tarjeta central (al frente).
          Positioned(
            left: 120,
            top: 140,
            child: _popIn(
              progress: centerCardT,
              child: const _StackCard(
                width: 150,
                height: 206,
                imageHeight: 100,
                imageGradient: <Color>[AppColors.primary, AppColors.secondary],
                barWidths: <double>[0.82, 0.52],
                shadowOffset: Offset(0, 24),
                shadowBlur: 44,
                shadowOpacity: 0.5,
                priceTag: r'$130.000',
              ),
            ),
          ),

          // Etiqueta flotante: "+20% tu ganancia".
          Positioned(
            left: 22,
            top: 352,
            child: _popIn(
              progress: labelsT,
              angleDeg: -4,
              child: const _GainPill(),
            ),
          ),
          // Círculo del carrito.
          Positioned(
            right: 34,
            top: 332,
            child: _popIn(
              progress: labelsT,
              child: const _CartBadge(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(painter: IsoCubePainter(color: AppColors.primary)),
          ),
        ),
        const SizedBox(width: 10),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontFamily: 'Poppins', fontSize: 22, height: 1.0),
            children: <InlineSpan>[
              TextSpan(
                text: 'FLY',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
              ),
              TextSpan(
                text: 'movil',
                style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.accent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Una de las 3 tarjetas apiladas del hero (imagen con degradado + barras
/// "esqueleto", y opcionalmente la píldora de precio de la tarjeta central).
class _StackCard extends StatelessWidget {
  const _StackCard({
    required this.width,
    required this.height,
    required this.imageHeight,
    required this.imageGradient,
    required this.barWidths,
    this.shadowOffset = const Offset(0, 18),
    this.shadowBlur = 36,
    this.shadowOpacity = 0.4,
    this.priceTag,
  });

  final double width;
  final double height;
  final double imageHeight;
  final List<Color> imageGradient;
  final List<double> barWidths;
  final Offset shadowOffset;
  final double shadowBlur;
  final double shadowOpacity;
  final String? priceTag;

  @override
  Widget build(BuildContext context) {
    final Widget card = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(0, 10, 30, shadowOpacity),
            offset: shadowOffset,
            blurRadius: shadowBlur,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: imageHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: imageGradient,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: barWidths[0],
            child: Container(
              height: 9,
              decoration: BoxDecoration(
                color: AuthPalette.skeleton,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 7),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: barWidths[1],
            child: Container(
              height: 9,
              decoration: BoxDecoration(
                color: AuthPalette.skeleton,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          if (priceTag != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                priceTag!,
                style: const TextStyle(
                  color: AppColors.brand,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return card;
  }
}

class _GainPill extends StatelessWidget {
  const _GainPill();

  @override
  Widget build(BuildContext context) {
    // La rotación final (-4deg) la aplica el `_popIn` del padre junto con la
    // animación de entrada; este widget solo pinta la píldora sin rotar.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(0, 255, 148, 0.35),
            offset: Offset(0, 10),
            blurRadius: 22,
          ),
        ],
      ),
      child: const Text(
        '+20% tu ganancia',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  const _CartBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(0, 10, 30, 0.4),
            offset: Offset(0, 12),
            blurRadius: 26,
          ),
        ],
      ),
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CustomPaint(painter: CartPainter(color: AppColors.primary)),
      ),
    );
  }
}
