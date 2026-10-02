import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Botón primario de la identidad FlyStock (diseño §2.8, UX-1).
///
/// Renderiza un botón con el gradiente de marca
/// `#004AAD → #5DE0E6 → #00FF94` ([AppColors.primaryGradient]) y texto en
/// blanco. Cuando [onPressed] es `null` el botón se muestra deshabilitado
/// (gradiente atenuado y sin respuesta al toque).
class FlyPrimaryButton extends StatelessWidget {
  const FlyPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  /// Texto visible del botón.
  final String label;

  /// Acción al pulsar. Si es `null`, el botón queda deshabilitado.
  final VoidCallback? onPressed;

  /// Ícono opcional a la izquierda del texto.
  final IconData? icon;

  /// Si el botón ocupa todo el ancho disponible.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    final Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, color: AppColors.onDark, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: const TextStyle(
            color: AppColors.onDark,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ],
    );

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.primaryGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
