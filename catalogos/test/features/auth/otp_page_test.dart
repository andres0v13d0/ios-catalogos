// Widget tests de la pantalla de verificación del código WhatsApp (tarea 1.10).
//
// Cubre:
// - el botón "Reenviar código" está deshabilitado durante el cooldown
//   (muestra la cuenta regresiva) y se habilita al terminar;
// - un código correcto transiciona el estado de sesión a signedIn (vía
//   verify-code → signInWithCustomToken fake);
// - un código incorrecto muestra el error mapeado.
//
// Monta OtpPage dejando antes el controlador en estado "codeSent" (como si ya
// se hubiera solicitado el código). Override de authRepositoryProvider +
// authUserServiceProvider (fakes) + FakeProfileController. Sin Firebase/red.

import 'package:catalogos/features/auth/data/backend_auth_repository.dart';
import 'package:catalogos/features/auth/presentation/auth_controller.dart';
import 'package:catalogos/features/auth/presentation/auth_state_provider.dart';
import 'package:catalogos/features/auth/presentation/otp_page.dart';
import 'package:catalogos/features/profile/presentation/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_auth_dependencies.dart';
import 'fake_profile_controller.dart';

/// Monta OtpPage. Antes de pumpear, deja el controlador en estado `codeSent`
/// con el teléfono fijado (como si ya se hubiera solicitado el código).
Future<ProviderContainer> _pumpOtp(
  WidgetTester tester,
  FakeAuthRepository repo,
  FakeAuthUserService authUser,
) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      authUserServiceProvider.overrideWithValue(authUser),
      profileControllerProvider.overrideWith(FakeProfileController.new),
    ],
  );
  addTearDown(container.dispose);

  // Simula una solicitud previa para fijar el teléfono/estado en el controlador.
  await container.read(authControllerProvider.notifier).sendCode(
        rawPhone: '3001234567',
      );

  // Router mínimo: OtpPage navega a /home al autenticar; proveemos ambas rutas.
  final router = GoRouter(
    initialLocation: '/otp',
    routes: <RouteBase>[
      GoRoute(
        path: '/otp',
        builder: (context, state) => const OtpPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('home-stub')),
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  return container;
}

void main() {
  testWidgets('reenvío deshabilitado durante el cooldown y habilitado después',
      (WidgetTester tester) async {
    final repo = FakeAuthRepository();
    await _pumpOtp(tester, repo, FakeAuthUserService());
    await tester.pump();

    // Durante el cooldown el botón muestra la cuenta regresiva y está disabled.
    expect(find.textContaining('Reenviar código en'), findsOneWidget);
    final TextButton button = tester.widget<TextButton>(
      find.ancestor(
        of: find.textContaining('Reenviar código'),
        matching: find.byType(TextButton),
      ),
    );
    expect(button.onPressed, isNull);

    // Avanza más allá del cooldown (60s) para que se habilite.
    await tester.pump(const Duration(seconds: 61));
    await tester.pump();

    expect(find.text('Reenviar código'), findsOneWidget);
  });

  testWidgets('código correcto transiciona a sesión iniciada',
      (WidgetTester tester) async {
    final repo = FakeAuthRepository(validCode: '123456');
    final container = await _pumpOtp(tester, repo, FakeAuthUserService());
    await tester.pump();

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verificar'));
    await tester.pump();
    await tester.pump();

    expect(container.read(authStateProvider), AuthStatus.signedIn);
  });

  testWidgets('código incorrecto muestra error',
      (WidgetTester tester) async {
    final repo = FakeAuthRepository(validCode: '123456');
    final container = await _pumpOtp(tester, repo, FakeAuthUserService());
    await tester.pump();

    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Verificar'));
    await tester.pump();
    await tester.pump();

    expect(container.read(authStateProvider), AuthStatus.signedOut);
    expect(find.textContaining('Código'), findsWidgets);
  });
}
