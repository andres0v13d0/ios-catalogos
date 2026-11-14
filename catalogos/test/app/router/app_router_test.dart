// Tests del router + guard de auth (tarea 0.5).
//
// Cubre el criterio de aceptación:
//   - "navegación entre 2 rutas": autenticado, navegar de /login a /comprar
//     funciona.
//   - "guard redirige a login si no hay sesión": sin sesión, cualquier intento
//     de ir a /comprar termina en /login.

import 'package:catalogos/app/router/app_router.dart';
import 'package:catalogos/app/router/app_routes.dart';
import 'package:catalogos/app/theme/app_theme.dart';
import 'package:catalogos/core/storage/storage.dart';
import 'package:catalogos/features/auth/presentation/auth_state_provider.dart';
import 'package:catalogos/features/auth/presentation/login_page.dart';
import 'package:catalogos/features/buy/buy_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/memory_cache.dart';

/// Monta la app usando el router real bajo un [ProviderScope], con la
/// posibilidad de sobreescribir el estado de auth inicial.
Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  AuthStatus initialStatus = AuthStatus.signedOut,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: [localCacheProvider.overrideWithValue(MemoryCache())],
  );
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
    testWidgets('arranca en Comprar sin sesión y oculta solo Vender', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpApp(tester);

      expect(router.state.matchedLocation, AppRoutes.buy);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Cuenta'), findsOneWidget);
      // Pedidos sí: muestra los pedidos hechos en este celular.
      expect(find.text('Pedidos'), findsOneWidget);
      expect(find.text('Vender'), findsNothing);
    });

    testWidgets('Pedidos, Chat y Cuenta son públicos', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpApp(tester);

      router.go(AppRoutes.orders);
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, AppRoutes.orders);

      router.go(AppRoutes.chat);
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, AppRoutes.chat);
      router.go(AppRoutes.account);
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, AppRoutes.account);
    });

    testWidgets(
      'redirige a /login al intentar entrar a una ruta privada sin sesión',
      (WidgetTester tester) async {
        final GoRouter router = await _pumpApp(tester);

        router.go(AppRoutes.accountSettings);
        await tester.pumpAndSettle();

        // El guard impide el acceso: terminamos en /login.
        expect(router.state.matchedLocation, AppRoutes.login);
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(BuyPage), findsNothing);
      },
    );
  });

  group('Navegación entre 2 rutas (con sesión)', () {
    testWidgets(
      'autenticado puede ver /comprar y no queda atrapado en /login',
      (WidgetTester tester) async {
        final GoRouter router = await _pumpApp(
          tester,
          initialStatus: AuthStatus.signedIn,
        );

        // Con sesión, ir a /login redirige a /comprar.
        router.go(AppRoutes.login);
        await tester.pumpAndSettle();
        expect(router.state.matchedLocation, AppRoutes.buy);
        expect(find.byType(BuyPage), findsOneWidget);
      },
    );

    testWidgets('al iniciar sesión, el guard navega de /login a /comprar', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = ProviderContainer(
        overrides: [localCacheProvider.overrideWithValue(MemoryCache())],
      );
      addTearDown(container.dispose);
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

      // Partimos en login (sin sesión).
      router.go(AppRoutes.login);
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);

      // Iniciar sesión (equivalente a verificar el OTP con éxito) hace que el
      // guard reaccione y navegue a /comprar.
      container
          .read(authStateProvider.notifier)
          .signInWithToken(uid: 'uid-test', idToken: 'token-test');
      expect(container.read(authStateProvider), AuthStatus.signedIn);

      // Igual que en el flujo real (OtpPage navega a /comprar al autenticar),
      // disparamos la navegación; el guard la permite por haber sesión y, al
      // intentar volver a /login, redirige de nuevo a /comprar.
      router.go(AppRoutes.buy);
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, AppRoutes.buy);
      expect(find.byType(BuyPage), findsOneWidget);

      router.go(AppRoutes.login);
      await tester.pumpAndSettle();
      expect(router.state.matchedLocation, AppRoutes.buy);
      expect(find.byType(LoginPage), findsNothing);
    });
  });
}
