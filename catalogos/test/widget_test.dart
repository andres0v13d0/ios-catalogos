// Smoke test de la app de Revendedores (Fase 0).
//
// Tras la tarea 0.5 la app usa go_router con un guard de auth placeholder.
// Sin sesión, el guard redirige a `/login`, por lo que la pantalla inicial es
// la de ingreso.

import 'package:catalogos/app/app.dart';
import 'package:catalogos/features/auth/presentation/login_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('La app arranca y, sin sesión, muestra la pantalla de login',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RevendedoresApp()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
