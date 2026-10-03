// Widget tests de la pantalla de ingreso de teléfono (tarea 1.9).
//
// Cubre:
// - un número inválido muestra el error de formato inline y NO envía OTP;
// - un número válido se normaliza a +57… y dispara verifyPhoneNumber con ese
//   E.164 (vía el FakePhoneAuthService).
//
// No usa el router completo: monta solo LoginPage dentro de un MaterialApp
// con los providers de Riverpod sobreescritos (sin Firebase ni red).

import 'package:catalogos/features/auth/presentation/auth_controller.dart';
import 'package:catalogos/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'fake_phone_auth_service.dart';

Widget _wrap(FakePhoneAuthService fake) {
  // Router mínimo: al enviarse el OTP, LoginPage hace push a /login/otp;
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
      phoneAuthServiceProvider.overrideWithValue(fake),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('número inválido muestra error de formato y no envía OTP',
      (WidgetTester tester) async {
    final fake = FakePhoneAuthService();
    await tester.pumpWidget(_wrap(fake));

    await tester.enterText(find.byType(TextFormField), '123');
    await tester.tap(find.text('Enviar código'));
    await tester.pump();

    expect(find.text('Ingresa un número de teléfono válido.'), findsOneWidget);
    expect(fake.verifyCount, 0);
  });

  testWidgets('número válido envía OTP con el E.164 normalizado (+57)',
      (WidgetTester tester) async {
    final fake = FakePhoneAuthService();
    await tester.pumpWidget(_wrap(fake));

    await tester.enterText(find.byType(TextFormField), '300 123 4567');
    await tester.tap(find.text('Enviar código'));
    await tester.pump();
    await tester.pump();

    expect(fake.verifyCalls, <String>['+573001234567']);
  });
}
