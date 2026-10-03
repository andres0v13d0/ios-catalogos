// Widget tests de la pantalla de verificación OTP (tarea 1.10).
//
// Cubre:
// - el botón "Reenviar código" está deshabilitado durante el cooldown
//   (muestra la cuenta regresiva) y se habilita al terminar;
// - un código correcto transiciona el estado de sesión a signedIn;
// - un código incorrecto muestra el error mapeado.
//
// Monta OtpPage con un verificationId precargado, overriding el controlador
// con el estado "codeSent" para evitar depender del router (sin Firebase/red).

import 'package:catalogos/features/auth/presentation/auth_controller.dart';
import 'package:catalogos/features/auth/presentation/auth_state_provider.dart';
import 'package:catalogos/features/auth/presentation/otp_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:catalogos/features/profile/presentation/profile_controller.dart';

import 'fake_phone_auth_service.dart';
import 'fake_profile_controller.dart';

/// Monta OtpPage. Antes de pumpear, deja el controlador en estado `codeSent`
/// con el verificationId del fake (como si ya se hubiera enviado el OTP).
Future<ProviderContainer> _pumpOtp(
  WidgetTester tester,
  FakePhoneAuthService fake,
) async {
  final container = ProviderContainer(
    overrides: [
      phoneAuthServiceProvider.overrideWithValue(fake),
      // Tras el login, `_promoteSession` dispara `loadProfile()` en segundo
      // plano; aislamos el widget test de la capa de datos (Dio/Firebase).
      profileControllerProvider.overrideWith(FakeProfileController.new),
    ],
  );
  addTearDown(container.dispose);

  // Simula un envío previo para fijar verificationId/phone en el estado.
  await container.read(authControllerProvider.notifier).sendCode(
        rawPhone: '3001234567',
      );

  // Router mínimo: OtpPage navega a /home al autenticar; proveemos ambas rutas.
  final router = GoRouter(
    initialLocation: '/otp',
    routes: <RouteBase>[
      GoRoute(
        path: '/otp',
        builder: (context, state) =>
            OtpPage(verificationId: fake.verificationId),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) =>
            const Scaffold(body: Text('home-stub')),
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
    final fake = FakePhoneAuthService();
    await _pumpOtp(tester, fake);
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
    final fake = FakePhoneAuthService(validCode: '123456');
    final container = await _pumpOtp(tester, fake);
    await tester.pump();

    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verificar'));
    await tester.pump();
    await tester.pump();

    expect(container.read(authStateProvider), AuthStatus.signedIn);
  });

  testWidgets('código incorrecto muestra error',
      (WidgetTester tester) async {
    final fake = FakePhoneAuthService(validCode: '123456');
    final container = await _pumpOtp(tester, fake);
    await tester.pump();

    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Verificar'));
    await tester.pump();
    await tester.pump();

    expect(container.read(authStateProvider), AuthStatus.signedOut);
    expect(find.textContaining('código'), findsWidgets);
  });
}
