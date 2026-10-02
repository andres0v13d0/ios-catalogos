import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../shared/widgets/fly_primary_button.dart';
import 'auth_state_provider.dart';

/// Pantalla de inicio de sesión (placeholder de Fase 0.5).
///
/// En Fase 1 (tareas 1.9–1.10) aquí irán el ingreso de teléfono y el OTP.
/// Por ahora ofrece un botón que simula el login alternando el
/// [authStateProvider] y navega a `/home`, lo que permite demostrar el CA de
/// la tarea 0.5 ("navegación entre 2 rutas").
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ingresar')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Revendedores', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Inicia sesión para ver tus catálogos.',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FlyPrimaryButton(
                label: 'Entrar',
                icon: Icons.login,
                onPressed: () {
                  // Placeholder: marca la sesión como autenticada y navega.
                  ref.read(authStateProvider.notifier).signIn();
                  context.go(AppRoutes.home);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
