import 'package:flutter/material.dart';

import '../../auth/presentation/auth_background.dart';
import '../../auth/presentation/auth_palette.dart';
import 'home_palette.dart';

/// Cabecera curva de "Productos del catálogo" (ver
/// `docs/design/productos-a.html`): degradado de marca, 2 círculos
/// decorativos, la onda blanca inferior, el botón "Volver" y el nombre
/// público del catálogo + "N productos".
///
/// Comparte el degradado con el hero de inicio (mismo `midStop`/`midColor`,
/// ver `docs/design/inicio-a-carrusel.html`); los círculos decorativos y la
/// onda inferior son propios de este diseño (altura de cabecera distinta,
/// 200dp en vez de hasta 260dp, y sin tarjeta asomando).
class CatalogProductsHeader extends StatelessWidget {
  const CatalogProductsHeader({
    super.key,
    required this.height,
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  final double height;

  /// Nombre PÚBLICO del catálogo. NUNCA el nombre interno.
  final String title;

  /// `"N productos"`, o cadena vacía mientras se desconoce (no se dibuja).
  final String subtitle;

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  const Positioned.fill(
                    child: AuthGradientBackground(
                      midStop: 0.55,
                      midColor: HomePalette.heroGradientMid,
                    ),
                  ),
                  const Positioned(
                    top: -70,
                    right: -80,
                    width: 230,
                    height: 230,
                    child: AuthFlatGlow(
                      color: Color(0x475DE0E6),
                    ), // rgba(93,224,230,0.28)
                  ),
                  Positioned(
                    top: 60,
                    left: -100,
                    width: 170,
                    height: 170,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(
                            0x665DE0E6,
                          ), // rgba(93,224,230,0.4)
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -1,
                    child: SizedBox(
                      height: 50,
                      child: CustomPaint(painter: _WaveBottomPainter()),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botón "Volver".
          Positioned(left: 16, top: 48, child: _BackButton(onTap: onBack)),

          // Nombre público + "N productos".
          Positioned(
            left: 72,
            right: 72,
            top: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AuthPalette.textMutedOnDark,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Volver',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x24FFFFFF), // rgba(255,255,255,0.14)
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
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
