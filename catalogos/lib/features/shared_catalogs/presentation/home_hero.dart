import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/auth_background.dart';
import '../../auth/presentation/auth_palette.dart';
import 'home_palette.dart';

/// Cabecera curva de "Tus catálogos" (ver
/// `docs/design/inicio-a-carrusel.html`): degradado de marca, 2 círculos
/// decorativos, la onda blanca inferior, la marca "FLYmovil", el ícono de
/// ajustes de cuenta y el título/subtítulo.
///
/// Puramente visual + el callback de abrir ajustes; no conoce el estado de
/// los catálogos.
class HomeHero extends StatelessWidget {
  const HomeHero({
    super.key,
    required this.height,
    required this.subtitle,
    required this.onOpenSettings,
    required this.onPlayVideo,
    this.compact = false,
  });

  final double height;
  final String subtitle;
  final VoidCallback onOpenSettings;
  final VoidCallback onPlayVideo;

  /// Pantallas cortas (≤640dp de alto): título más pequeño y subtítulo en
  /// una sola línea, para que la cabecera siga cabiendo sin desbordarse.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          // Degradado + brillos decorativos, recortados al alto del hero.
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
                    top: 100,
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
                      height: 60,
                      child: CustomPaint(painter: _WaveBottomPainter()),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Marca "FLYmovil".
          const Positioned(left: 24, top: 16, child: _WordmarkSmall()),

          // Ícono de play: reabre el modal del video de onboarding.
          Positioned(
            right: 68,
            top: 2,
            child: _HeroIconButton(
              icon: Icons.play_arrow_rounded,
              label: 'Ver video de ayuda',
              onTap: onPlayVideo,
            ),
          ),

          // Ícono de ajustes: abre la pantalla "Cuenta" (número, cerrar
          // sesión, eliminar cuenta).
          Positioned(
            right: 20,
            top: 2,
            child: _HeroIconButton(
              icon: Icons.settings_outlined,
              label: 'Ajustes de cuenta',
              onTap: onOpenSettings,
            ),
          ),

          // Título + subtítulo.
          Positioned(
            left: 24,
            right: 24,
            top: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Tus catálogos',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 24 : 28,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      height: 1.5,
                      color: AuthPalette.textMutedOnDark,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WordmarkSmall extends StatelessWidget {
  const _WordmarkSmall();

  @override
  Widget build(BuildContext context) {
    return const Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 18, height: 1.0),
        children: <InlineSpan>[
          TextSpan(
            text: 'FLY',
            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          TextSpan(
            text: '+',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón circular del hero (ajustes, play del video de ayuda): mismo cristal
/// translúcido y área táctil ≥48dp (accesibilidad).
class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: const Color(0x24FFFFFF), // rgba(255,255,255,0.14)
        shape: const CircleBorder(
          side: BorderSide(color: Color(0x47FFFFFF), width: 1), // rgba(255,255,255,0.28)
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Onda blanca que separa el hero del cuerpo. Replica
/// `M0 30 C 90 72, 230 0, 390 36 L390 60 L0 60 Z` (viewBox 390x60), escalada
/// al ancho real del dispositivo.
class _WaveBottomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double sx = size.width / 390;
    final double sy = size.height / 60;
    final Path path = Path()
      ..moveTo(0, 30 * sy)
      ..cubicTo(90 * sx, 72 * sy, 230 * sx, 0, 390 * sx, 36 * sy)
      ..lineTo(390 * sx, 60 * sy)
      ..lineTo(0, 60 * sy)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _WaveBottomPainter oldDelegate) => false;
}
