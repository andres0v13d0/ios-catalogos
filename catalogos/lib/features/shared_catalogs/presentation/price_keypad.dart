import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../auth/presentation/auth_vector_icons.dart';
import 'catalog_design_tokens.dart';

/// Teclado numérico propio de "Ajustar precios" (ver
/// `docs/design/ajustar-precios.html`): 3 columnas, teclas 1-9, "000" (solo
/// Valor fijo) / hueco (Porcentaje), 0, borrar. Nunca abre el teclado del
/// sistema (no hay ningún `TextField` detrás) — mismo enfoque que
/// `OtpKeypad`.
///
/// - Pulsar un dígito llama [onDigit]; "000" llama [onAppendZeros].
/// - Pulsar "borrar" llama [onBackspace]; mantenerlo presionado llama
///   [onClear] (limpia todo el número).
/// - Cuando [locked] es `true` (guardando/quitando) ninguna tecla responde.
class PriceKeypad extends StatelessWidget {
  const PriceKeypad({
    super.key,
    required this.showZerosKey,
    required this.onDigit,
    required this.onAppendZeros,
    required this.onBackspace,
    required this.onClear,
    required this.locked,
    required this.keyHeight,
    required this.padding,
    required this.gap,
  });

  /// `true` en modo Valor fijo (muestra "000" en vez del hueco).
  final bool showZerosKey;

  final ValueChanged<String> onDigit;
  final VoidCallback onAppendZeros;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final bool locked;
  final double keyHeight;
  final EdgeInsets padding;
  final double gap;

  static const List<String> _digitRows = <String>['123', '456', '789'];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: const BoxDecoration(
        color: CatalogTokens.keypadBackground,
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
                      key: ValueKey<String>('price_keypad_digit_$d'),
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
              if (showZerosKey)
                _KeypadKey(
                  key: const ValueKey<String>('price_keypad_digit_000'),
                  label: '000',
                  height: keyHeight,
                  locked: locked,
                  onTap: onAppendZeros,
                )
              else
                SizedBox(height: keyHeight),
              _KeypadKey(
                key: const ValueKey<String>('price_keypad_digit_0'),
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
    super.key,
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
        color: CatalogTokens.whiteOverlay10,
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
                style: TextStyle(
                  // 22 a la altura de referencia (52dp, ver ajustar-precios.html).
                  fontSize: 22 * (height / 52),
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
        color: CatalogTokens.whiteOverlay10,
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
            child: Center(
              child: SizedBox(
                width: 26 * (height / 52),
                height: 26 * (height / 52),
                child: const CustomPaint(painter: BackspacePainter(color: Colors.white)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
