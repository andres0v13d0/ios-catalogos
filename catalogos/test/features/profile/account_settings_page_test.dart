// Widget tests de AccountSettingsPage ("Cuenta"): muestra el número del
// revendedor y las acciones de cerrar sesión / eliminar cuenta (antes vivían
// en un menú sobre el pill "Salir" de home_hero.dart; ahora tienen pantalla
// propia, abierta desde el ícono de engranaje).
//
// Cubre:
// - muestra el número formateado;
// - "Cerrar sesión" pide confirmación; cancelar no cierra sesión, confirmar sí;
// - "Eliminar cuenta" pide confirmación; confirmar llama a deleteAccount() y,
//   si tiene éxito, cierra sesión; si falla, muestra el error y no cierra.

import 'package:catalogos/app/router/app_routes.dart';
import 'package:catalogos/features/auth/data/session_store.dart';
import 'package:catalogos/features/auth/presentation/auth_state_provider.dart';
import 'package:catalogos/features/profile/presentation/account_settings_page.dart';
import 'package:catalogos/features/profile/presentation/profile_controller.dart';
import 'package:catalogos/shared/models/reseller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/fake_auth_dependencies.dart';

class _FakeSessionStore implements SessionStore {
  bool cleared = false;

  @override
  Future<void> clear() async => cleared = true;

  @override
  Future<SessionMetadata> read() async => const SessionMetadata();

  @override
  Future<void> save(SessionMetadata metadata) async {}
}

/// Controlador fake: perfil ya cargado con un reseller fijo, y
/// [deleteAccount] controlable sin tocar la red real.
class _FakeProfileController extends ProfileController {
  _FakeProfileController({this.deleteSucceeds = true});

  final bool deleteSucceeds;
  int deleteAccountCalls = 0;

  @override
  ProfileState build() => const ProfileState(
    status: ProfileStatus.complete,
    reseller: Reseller(
      id: 1,
      telefonoE164: '+573144567890',
      countryCode: 'CO',
      nombre: 'Ana',
    ),
  );

  @override
  Future<bool> deleteAccount() async {
    deleteAccountCalls++;
    if (!deleteSucceeds) {
      state = state.copyWith(errorMessage: 'No pudimos eliminar tu cuenta.');
    }
    return deleteSucceeds;
  }
}

Future<
  ({
    GoRouter router,
    FakeAuthUserService authUser,
    _FakeSessionStore sessionStore,
    _FakeProfileController profile,
  })
>
_pumpSettings(WidgetTester tester, {bool deleteSucceeds = true}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final authUser = FakeAuthUserService();
  final sessionStore = _FakeSessionStore();
  final profile = _FakeProfileController(deleteSucceeds: deleteSucceeds);

  final GoRouter router = GoRouter(
    initialLocation: '/home',
    routes: <RouteBase>[
      GoRoute(path: AppRoutes.home, builder: (context, _) => const Text('home-stub')),
      GoRoute(
        path: AppRoutes.accountSettings,
        builder: (context, _) => const AccountSettingsPage(),
      ),
      GoRoute(path: AppRoutes.login, builder: (context, _) => const Text('login-stub')),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authUserServiceProvider.overrideWithValue(authUser),
        sessionStoreProvider.overrideWithValue(sessionStore),
        profileControllerProvider.overrideWith(() => profile),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push(AppRoutes.accountSettings);
  await tester.pump();
  await tester.pump();

  return (router: router, authUser: authUser, sessionStore: sessionStore, profile: profile);
}

void main() {
  testWidgets('muestra el número del revendedor formateado', (WidgetTester tester) async {
    await _pumpSettings(tester);

    expect(find.text('+57 314 456 7890'), findsOneWidget);
  });

  testWidgets(
    '"Cerrar sesión" pide confirmación; cancelar no cierra sesión, confirmar sí',
    (WidgetTester tester) async {
      final ctx = await _pumpSettings(tester);

      await tester.tap(find.text('Cerrar sesión').first);
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(ctx.authUser.signedOut, isFalse);
      expect(ctx.sessionStore.cleared, isFalse);

      await tester.tap(find.text('Cerrar sesión').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();

      expect(ctx.authUser.signedOut, isTrue);
      expect(ctx.sessionStore.cleared, isTrue);
      expect(find.text('login-stub'), findsOneWidget);
    },
  );

  testWidgets(
    '"Eliminar cuenta" confirmado con éxito borra y cierra sesión',
    (WidgetTester tester) async {
      final ctx = await _pumpSettings(tester);

      await tester.tap(find.text('Eliminar cuenta').first);
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(ctx.profile.deleteAccountCalls, 1);
      expect(ctx.authUser.signedOut, isTrue);
      expect(ctx.sessionStore.cleared, isTrue);
      expect(find.text('login-stub'), findsOneWidget);
    },
  );

  testWidgets(
    '"Eliminar cuenta" con fallo muestra el error y no cierra sesión',
    (WidgetTester tester) async {
      final ctx = await _pumpSettings(tester, deleteSucceeds: false);

      await tester.tap(find.text('Eliminar cuenta').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('No pudimos eliminar tu cuenta.'), findsOneWidget);
      expect(ctx.authUser.signedOut, isFalse);
      expect(find.text('login-stub'), findsNothing);
    },
  );
}
