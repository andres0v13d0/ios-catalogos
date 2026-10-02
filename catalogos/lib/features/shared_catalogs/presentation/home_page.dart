import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_state_provider.dart';

/// Pantalla principal / autenticada (placeholder de Fase 0.5).
///
/// Representa el destino al que se llega tras iniciar sesión. En Fase 1
/// (tarea 1.15) aquí irá la lista de catálogos compartidos. Por ahora muestra
/// un placeholder y permite cerrar sesión (vuelve el guard a redirigir a
/// `/login`), lo que ayuda a demostrar el CA de la tarea 0.5.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authStateProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Bienvenido', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Aquí verás tus catálogos compartidos.',
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
