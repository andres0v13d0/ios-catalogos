import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import 'auth_palette.dart';

/// Las 6 casillas del código (rediseño "Código B", ver
/// `docs/design/codigo-b.html`). Son puramente de lectura: el dígito viene de
/// [code] (máx. 6 caracteres) y lo escribe el teclado numérico propio de
/// `OtpPage`, nunca un `TextField` del sistema.
///
/// Estados por casilla: vacía / activa (la primera vacía, con cursor
/// parpadeante) / llena; y un estado de error compartido ([hasError]) que
/// pinta el borde en rojo suave y sacude todo el bloque — lo dispara
/// `OtpPage` vía [shake] cuando el backend rechaza el código.
class OtpCodeBoxes extends StatefulWidget {
  const OtpCodeBoxes({
    super.key,
    required this.code,
    required this.hasError,
    required this.shake,
    required this.entrance,
    required this.boxHeight,
  });

  /// Dígitos ingresados hasta ahora (0 a 6 caracteres).
  final String code;

  /// `true` mientras se muestra el estado de error (borde rojo); se limpia
  /// en `OtpPage` al pulsar la siguiente tecla.
  final bool hasError;

  /// Progreso 0→1→0 de la sacudida de error (un solo ciclo por error).
  final Animation<double> shake;

  /// Progreso 0..1 de la animación de entrada (casillas escalonadas).
  final Animation<double> entrance;

  /// Alto de cada casilla (se compacta en pantallas pequeñas).
  final double boxHeight;

  @override
  State<OtpCodeBoxes> createState() => _OtpCodeBoxesState();
}

class _OtpCodeBoxesState extends State<OtpCodeBoxes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  double _entranceFor(int index) {
    final double start = index * 0.08;
    final double end = (start + 0.4).clamp(0.0, 1.0);
    final double raw = ((widget.entrance.value - start) / (end - start)).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(raw);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[widget.shake, widget.entrance, _blink]),
      builder: (context, _) {
        // Sacudida: oscilación horizontal de amplitud decreciente, completa
        // en el tiempo de `widget.shake` (lo dimensiona OtpPage, ≤350ms).
        final double s = widget.shake.value;
        final int half = (s * 8).floor();
        final double direction = half.isEven ? -1 : 1;
        final double dx = s <= 0 ? 0 : 8 * (1 - s) * direction;

        return Transform.translate(
          offset: Offset(dx, 0),
          child: Row(
            children: List<Widget>.generate(6, (i) {
              final bool filled = i < widget.code.length;
              final String digit = filled ? widget.code[i] : '';
              final bool isActive = !widget.hasError && i == widget.code.length;
              final double entranceT = _entranceFor(i);

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 5 ? 0 : 8),
                  child: Opacity(
                    opacity: entranceT.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.6 + 0.4 * entranceT.clamp(0.0, 1.0),
                      child: _CodeBox(
                        digit: digit,
                        isActive: isActive,
                        hasError: widget.hasError,
                        blink: _blink.value,
                        height: widget.boxHeight,
                        index: i,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _CodeBox extends StatelessWidget {
  const _CodeBox({
    required this.digit,
    required this.isActive,
    required this.hasError,
    required this.blink,
    required this.height,
    required this.index,
  });

  final String digit;
  final bool isActive;
  final bool hasError;
  final double blink;
  final double height;
  final int index;

  @override
  Widget build(BuildContext context) {
    final bool filled = digit.isNotEmpty;

    Color background;
    Color borderColor;
    double borderWidth;
    List<BoxShadow>? shadow;

    if (hasError) {
      background = filled
          ? const Color(0x1FFFFFFF) // rgba(255,255,255,0.12)
          : const Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
      borderColor = AuthPalette.codeErrorBorder;
      borderWidth = 1.5;
      shadow = null;
    } else if (isActive) {
      background = const Color(0x2E5DE0E6); // rgba(93,224,230,0.18)
      borderColor = AppColors.accent;
      borderWidth = 2;
      shadow = const <BoxShadow>[
        BoxShadow(
          color: Color.fromRGBO(93, 224, 230, 0.3),
          offset: Offset(0, 10),
          blurRadius: 24,
        ),
      ];
    } else if (filled) {
      background = const Color(0x1FFFFFFF); // rgba(255,255,255,0.12)
      borderColor = const Color(0x40FFFFFF); // rgba(255,255,255,0.25)
      borderWidth = 1.5;
      shadow = null;
    } else {
      background = const Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
      borderColor = const Color(0x2EFFFFFF); // rgba(255,255,255,0.18)
      borderWidth = 1.5;
      shadow = null;
    }

    final String semanticValue = filled ? digit : 'vacío';

    return Semantics(
      label: 'Dígito ${index + 1} de 6, $semanticValue',
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: shadow,
        ),
        child: isActive
            ? Opacity(
                opacity: 0.2 + 0.8 * blink,
                child: Container(width: 2, height: 28, color: AppColors.accent),
              )
            : Text(
                digit,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}
