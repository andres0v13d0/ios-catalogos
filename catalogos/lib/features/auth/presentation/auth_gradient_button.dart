import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Botón de degradado cian→verde compartido por el flujo de login: "Enviar
/// código" (`docs/design/ingreso-b.html`) y "Verificar"
/// (`docs/design/codigo-b.html`) son visualmente idénticos salvo el texto y
/// el ícono final, así que viven en un solo widget en vez de duplicar el
/// `Container`/degradado/sombra/estado de carga en cada pantalla.
///
/// - [enabled]`false` → opacidad 0.5 (p. ej. código incompleto en la
///   pantalla de verificación).
/// - [loading]`true` → el contenido se reemplaza por un indicador circular
///   navy y el botón deja de responder al toque, independientemente de
///   [enabled].
class AuthGradientButton extends StatelessWidget {
  const AuthGradientButton({
    super.key,
    required this.label,
    required this.iconPainter,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final CustomPainter iconPainter;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool interactive = enabled && !loading;
    return Semantics(
      button: true,
      enabled: interactive,
      label: label,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[AppColors.accent, AppColors.brand],
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color.fromRGBO(0, 255, 148, 0.3),
                offset: Offset(0, 10),
                blurRadius: 24,
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: interactive ? onPressed : null,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CustomPaint(painter: iconPainter),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
