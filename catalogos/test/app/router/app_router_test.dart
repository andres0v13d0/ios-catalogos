// Tests del router + guard de auth (tarea 0.5).
//
// Cubre el criterio de aceptación:
//   - "navegación entre 2 rutas": autenticado, navegar de /login a /home
//     funciona.
//   - "guard redirige a login si no hay sesión": sin sesión, cualquier intento
//     de ir a /home termina en /login.

import 'package:catalogos/app/router/app_router.dart';
import 'package:catalogos/app/router/app_routes.dart';
import 'package:catalogos/app/theme/app_theme.dart';
import 'package:catalogos/features/auth/presentation/auth_state_provider.dart';
import 'package:catalogos/features/auth/presentation/login_page.dart';
import 'package:catalogos/features/shared_catalogs/presentation/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Monta la app usando el router real bajo un [ProviderScope], con la
/// posibilidad de sobreescribir el estado de auth inicial.
Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  AuthStatus initialStatus = AuthStatus.signedOut,
}) async {
  final ProviderContainer container = ProviderContainer();
  addTearDown(container.dispose);

  // Fija el estado inicial de la sesión antes de construir el router.
  if (initialStatus == AuthStatus.signedIn) {
    container.read(authStateProvider.notifier).signIn();
  }

  final GoRouter router = container.read(appRouterProvider);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.themeData,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();

  return router;
}

void main() {
  group('Guard de auth (sin sesión)', () {
    testWidgets('arranca en /login cuando no hay sesión',
        (WidgetTester tester) async {
      final GoRouter router = await _pumpApp(tester);

      expect(router.state.matchedLocation, AppRoutes.login);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
    });

    testWidgets('redirige a /login al intentar entrar a /home sin sesión',
        (WidgetTester tester) async {
      final GoRouter router = await _pumpApp(tester);

      router.go(AppRoutes.home);
      await tester.pumpAndSettle();

      // El guard impide el acceso: terminamos en /login.
      expect(router.state.matchedLocation, AppRoutes.login);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
    });
  });

  group('Navegación entre 2 rutas (con sesión)', () {
    testWidgets('autenticado puede ver /home y no queda atrapado en /login',
        (WidgetTester tester) async {
      final GoRouter router =
          await _pumpApp(tester, initialStatus: AuthStatus.signedIn);

      // Con sesión, ir a /login redirige a /home.
      router.go(AppRoutes.login);
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, AppRoutes.home);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('login simulado navega de /login a /home',
        (WidgetTester tester) async {
      final GoRouter router = await _pumpApp(tester);

      // Partimos en login (sin sesión).
      expect(find.byType(LoginPage), findsOneWidget);

      // Pulsar "Entrar" marca la sesión y navega a /home.
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();

      expect(router.state.matchedLocation, AppRoutes.home);
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });
  });
}
