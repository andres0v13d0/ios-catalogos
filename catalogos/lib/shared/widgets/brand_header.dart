import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/auth/presentation/auth_background.dart';
import '../../features/shared_catalogs/presentation/home_palette.dart';

/// Fondo de las pantallas con lista (Chat, Pedidos, Cuenta).
const Color kSheetTint = Color(0xFFEEF3FB);

/// Cabecera azul de las pestañas. Se extiende por detrás de la barra de
/// estado (sin franja de otro color) y deja los iconos del sistema en blanco.
/// Termina en una curva del color de la pantalla ([sheetColor]) para que el
/// contenido de abajo parezca una hoja que sube sobre ella.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.leading,
    this.titleSize = 26,
    this.child,
    this.sheetColor = Colors.white,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Botón al inicio de la fila del título (p. ej. volver).
  final Widget? leading;

  /// Tamaño del título (más chico en pantallas con avatar, como el chat).
  final double titleSize;

  /// Contenido bajo el título (chips, tarjetas, indicadores).
  final Widget? child;

  /// Color de la pantalla bajo la cabecera.
  final Color sheetColor;

  static const double _curve = 24;

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.none,
                children: const <Widget>[
                  Positioned.fill(
                    child: AuthGradientBackground(
                      midStop: 0.55,
                      midColor: HomePalette.heroGradientMid,
                    ),
                  ),
                  Positioned(
                    top: -70,
                    right: -80,
                    width: 230,
                    height: 230,
                    child: AuthFlatGlow(color: Color(0x475DE0E6)),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, _curve + 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (leading != null) ...<Widget>[
                      leading!,
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: titleSize,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFCFE0F7),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (final Widget a in actions) ...<Widget>[
                      const SizedBox(width: 8),
                      a,
                    ],
                  ],
                ),
                if (child != null) ...<Widget>[
                  const SizedBox(height: 14),
                  child!,
                ],
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -1,
            height: _curve,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: sheetColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(_curve),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón circular translúcido para la cabecera (carrito, agregar, ayuda).
class BrandHeaderButton extends StatelessWidget {
  const BrandHeaderButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Badge(
        isLabelVisible: badge > 0,
        label: Text('$badge'),
        backgroundColor: const Color(0xFF5DE0E6),
        textColor: const Color(0xFF001634),
        child: Material(
          color: const Color(0x29FFFFFF),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, size: 21, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip de filtro sobre la cabecera azul (activo = blanco).
class BrandChip extends StatelessWidget {
  const BrandChip({
    super.key,
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: on ? Colors.white : const Color(0x29FFFFFF),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: on ? const Color(0xFF004AAD) : Colors.white,
          ),
        ),
      ),
    ),
  );
}

/// Cifra con etiqueta para la cabecera (Pedidos). Va dentro de un `Row`.
class BrandKpi extends StatelessWidget {
  const BrandKpi(this.value, this.label, {super.key});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x24FFFFFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xFFCFE0F7)),
          ),
        ],
      ),
    ),
  );
}
