import 'package:flutter/material.dart';

import 'theme/app_colors.dart';

/// App de error que se muestra cuando el arranque de Firebase/App Check falla
/// en una plataforma soportada (android/web).
///
/// En lugar de continuar en silencio (lo que dejaría la autenticación OTP rota
/// de forma invisible), se presenta una pantalla clara explicando que Firebase
/// no pudo inicializarse y el detalle del error, para que el fallo sea evidente
/// durante el desarrollo y en producción.
class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key, required this.error});

  /// Error capturado durante el bootstrap (se muestra como detalle).
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FLYmovil',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.secondary,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No se pudo iniciar la aplicación',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Firebase no se pudo inicializar. Revisa la configuración '
                    '(google-services.json / GoogleService-Info.plist y App '
                    'Check) e inténtalo de nuevo.',
                    style: TextStyle(color: AppColors.text),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$error',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.text,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
