import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/material.dart';

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
    required this.onPlayVideo,
    this.topInset = 0,
    this.compact = false,
  });

  final double height;
  final String subtitle;
  final VoidCallback onPlayVideo;

  /// Alto de la barra de estado: el azul se extiende detrás de ella.
  final double topInset;

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
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: -1,
                    height: 24,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Ícono de play: reabre el modal del video de onboarding.
          Positioned(
            right: 20,
            top: topInset + 8,
            child: _HeroIconButton(
              icon: LucideIcons.play,
              label: 'Ver video de ayuda',
              onTap: onPlayVideo,
            ),
          ),

          // Título + subtítulo.
          Positioned(
            left: 24,
            top: topInset + 16,
            right: 80,
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
          side: BorderSide(
            color: Color(0x47FFFFFF),
            width: 1,
          ), // rgba(255,255,255,0.28)
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
