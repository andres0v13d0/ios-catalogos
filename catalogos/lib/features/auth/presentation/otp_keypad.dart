import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'auth_vector_icons.dart';

/// Teclado numérico propio de la pantalla de código (rediseño "Código B", ver
/// `docs/design/codigo-b.html`): 3 columnas, teclas 1-9, hueco, 0, borrar.
/// Nunca abre el teclado del sistema (no hay ningún `TextField` detrás).
///
/// - Pulsar un dígito llama [onDigit]; mantenerlo NO hace nada especial.
/// - Pulsar "borrar" llama [onBackspace]; mantenerlo presionado llama
///   [onClear] (limpia todo el código).
/// - Cuando [locked] es `true` (verificando el código) ninguna tecla
///   responde.
class OtpKeypad extends StatelessWidget {
  const OtpKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    required this.onClear,
    required this.locked,
    required this.keyHeight,
    required this.padding,
    required this.gap,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool locked;
  final double keyHeight;
  final EdgeInsets padding;
  final double gap;

  static const List<String> _digitRows = <String>[
    '123',
    '456',
    '789',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: const BoxDecoration(
        color: Color(0x8C000C20), // rgba(0,12,32,0.55)
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final String row in _digitRows) ...<Widget>[
            _KeypadRow(
              height: keyHeight,
              gap: gap,
              children: row
                  .split('')
                  .map(
                    (d) => _KeypadKey(
                      label: d,
                      height: keyHeight,
                      locked: locked,
                      onTap: () => onDigit(d),
                    ),
                  )
                  .toList(),
            ),
            SizedBox(height: gap),
          ],
          _KeypadRow(
            height: keyHeight,
            gap: gap,
            children: <Widget>[
              SizedBox(height: keyHeight),
              _KeypadKey(
                label: '0',
                height: keyHeight,
                locked: locked,
                onTap: () => onDigit('0'),
              ),
              _BackspaceKey(
                height: keyHeight,
                locked: locked,
                onTap: onBackspace,
                onLongPress: onClear,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeypadRow extends StatelessWidget {
  const _KeypadRow({required this.children, required this.height, required this.gap});

  final List<Widget> children;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(children.length, (i) {
        final Widget child = children[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == children.length - 1 ? 0 : gap),
            child: child,
          ),
        );
      }),
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({
    required this.label,
    required this.height,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final double height;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !locked,
      label: label,
      child: Material(
        color: const Color(0x1AFFFFFF), // rgba(255,255,255,0.1)
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: locked
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
          child: SizedBox(
            height: height,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  const _BackspaceKey({
    required this.height,
    required this.locked,
    required this.onTap,
    required this.onLongPress,
  });

  final double height;
  final bool locked;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !locked,
      label: 'Borrar',
      child: Material(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: locked
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
          onLongPress: locked
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onLongPress();
                },
          child: SizedBox(
            height: height,
            child: const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CustomPaint(painter: BackspacePainter(color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
