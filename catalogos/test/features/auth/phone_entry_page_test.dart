// Widget tests de la pantalla de ingreso de teléfono (tarea 1.9).
//
// Cubre:
// - un número inválido muestra el error de formato inline y NO llama al backend;
// - un número válido se normaliza a +57… y dispara `requestCode` con ese E.164
//   (vía el FakeAuthRepository).
//
// No usa el router completo: monta solo LoginPage dentro de un MaterialApp
// con los providers de Riverpod sobreescritos (sin Firebase ni red).

import 'package:catalogos/features/auth/data/backend_auth_repository.dart';
import 'package:catalogos/features/auth/presentation/auth_state_provider.dart';
import 'package:catalogos/features/auth/presentation/login_page.dart';
import 'package:catalogos/features/profile/presentation/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_auth_dependencies.dart';
import 'fake_profile_controller.dart';

Widget _wrap(FakeAuthRepository repo, FakeAuthUserService authUser) {
  // Router mínimo: al confirmarse el envío, LoginPage hace push a /login/otp;
  // proveemos esa ruta con un stub para no depender del router real.
  final router = GoRouter(
    initialLocation: '/login',
    routes: <RouteBase>[
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/login/otp',
        builder: (context, state) => const Scaffold(body: Text('otp-stub')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      authUserServiceProvider.overrideWithValue(authUser),
      profileControllerProvider.overrideWith(FakeProfileController.new),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('número inválido muestra error de formato y no llama al backend',
      (WidgetTester tester) async {
    final repo = FakeAuthRepository();
    await tester.pumpWidget(_wrap(repo, FakeAuthUserService()));
    // Deja asentar la animación de entrada (rediseño "B", máx. 600ms) antes
    // de interactuar, para que la hoja inferior esté en su posición final.
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '123');
    await tester.tap(find.text('Enviar código'));
    await tester.pump();

    expect(find.text('Ingresa un número de teléfono válido.'), findsOneWidget);
    expect(repo.requestCalls, isEmpty);
  });

  testWidgets('número válido solicita el código con el E.164 normalizado (+57)',
      (WidgetTester tester) async {
    final repo = FakeAuthRepository();
    await tester.pumpWidget(_wrap(repo, FakeAuthUserService()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '300 123 4567');
    await tester.tap(find.text('Enviar código'));
    await tester.pump();
    await tester.pump();

    expect(repo.requestCalls, <String>['+573001234567']);
  });
}
