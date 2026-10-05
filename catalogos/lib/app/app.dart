import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Raíz de la aplicación.
///
/// Fase 0:
/// - 0.1: pantalla placeholder.
/// - 0.3: tema FlyStock (Poppins + ColorScheme de marca).
/// - 0.5: migra a `MaterialApp.router` con go_router (rutas base + guard de
///   auth placeholder) y consume la configuración del router vía Riverpod.
class RevendedoresApp extends ConsumerWidget {
  const RevendedoresApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'FLYmovil',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      routerConfig: router,
    );
  }
}
