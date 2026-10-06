// Widget tests de HomePage — rediseño "Tus catálogos" (carrusel), ver
// docs/design/inicio-a-carrusel.html.
//
// Cubre:
// - el carrusel muestra nombre público/proveedor/insignia de precio de la
//   tarjeta activa, y el subtítulo correcto según la cantidad de catálogos;
// - con un solo catálogo no hay puntos (y el subtítulo es "Toca para ver...");
// - el avatar del proveedor cae a iniciales si no hay logo;
// - tocar "Ver catálogo" navega al detalle con el UUID del catálogo;
// - pull-to-refresh invoca refresh();
// - estados vacío, error (con Reintentar) y "sin conexión" (fromCache);
// - el botón "Salir" pide confirmación antes de cerrar sesión.
//
// Se sobreescribe el controlador de catálogos con un fake en memoria (sin
// Hive ni red) y las dependencias de auth con los fakes ya existentes de
// `test/features/auth/fake_auth_dependencies.dart` (sin Firebase real).

import 'package:catalogos/features/auth/data/session_store.dart';
import 'package:catalogos/features/auth/presentation/auth_state_provider.dart';
import 'package:catalogos/features/shared_catalogs/domain/catalog.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_detail_page.dart';
import 'package:catalogos/features/shared_catalogs/presentation/home_page.dart';
import 'package:catalogos/features/shared_catalogs/presentation/shared_catalogs_controller.dart';
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

/// Controlador fake: estado fijo (AsyncData) con 2 catálogos, o lo que
/// indique [stateOverride]/[errorOverride].
class _FakeController extends SharedCatalogsController {
  _FakeController({this.stateOverride, this.errorOverride});

  final SharedCatalogsState? stateOverride;
  final Object? errorOverride;
  int refreshCount = 0;

  static const List<Catalog> twoCatalogs = <Catalog>[
    Catalog(
      id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      displayName: 'Colección Primavera',
      providerId: 10,
      providerName: 'Distribuidora Andina',
      providerLogoUrl: 'https://cdn/logo-a.webp',
      priceField: 'none',
    ),
    Catalog(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      displayName: 'Hogar y Cocina',
      providerId: 20,
      providerName: 'Mundo Casa',
      priceField: 'mayorista',
    ),
  ];

  static const List<Catalog> oneCatalog = <Catalog>[
    Catalog(
      id: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
      displayName: 'Catálogo Único',
      providerId: 30,
      providerName: 'Proveedor Solo',
      priceField: 'mayorista',
    ),
  ];

  @override
  Future<SharedCatalogsState> build() async {
    if (errorOverride != null) throw errorOverride!;
    return stateOverride ?? const SharedCatalogsState(catalogs: twoCatalogs);
  }

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

void main() {
  late _FakeController fake;

  Widget wrap({
    SharedCatalogsState? state,
    Object? error,
    Size size = const Size(390, 844),
  }) {
    fake = _FakeController(stateOverride: state, errorOverride: error);
    final GoRouter router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        GoRoute(path: '/home', builder: (context, _) => const HomePage()),
        GoRoute(
          path: '/catalog/:id',
          builder: (context, state) =>
              Scaffold(body: Text('detail-${state.pathParameters['id']}')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        sharedCatalogsControllerProvider.overrideWith(() => fake),
        authUserServiceProvider.overrideWithValue(FakeAuthUserService()),
        sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> pumpHome(
    WidgetTester tester, {
    SharedCatalogsState? state,
    Object? error,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(state: state, error: error));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets(
    'muestra nombre, proveedor, "Con precios"/"Sin precios" y el subtítulo de varios',
    (WidgetTester tester) async {
      await pumpHome(tester);

      expect(find.text('Tus catálogos'), findsOneWidget);
      expect(find.text('Desliza para ver más'), findsOneWidget);
      expect(find.text('Colección Primavera'), findsOneWidget);
      expect(find.text('Distribuidora Andina'), findsOneWidget);
      expect(find.text('Sin precios'), findsOneWidget);
    },
  );

  testWidgets(
    'con un solo catálogo no hay puntos y el subtítulo es "Toca para ver sus productos"',
    (WidgetTester tester) async {
      await pumpHome(
        tester,
        state: const SharedCatalogsState(catalogs: _FakeController.oneCatalog),
      );

      expect(find.text('Toca para ver sus productos'), findsOneWidget);
      expect(find.text('Catálogo Único'), findsOneWidget);
      expect(find.byType(PageView), findsNothing);
    },
  );

  testWidgets('el avatar del proveedor cae a iniciales cuando no hay logo', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    // "Hogar y Cocina" (Mundo Casa, sin logo) → iniciales 'MC'.
    expect(find.text('MC'), findsOneWidget);
  });

  testWidgets(
    'tocar "Ver catálogo" navega al detalle con el UUID del catálogo',
    (WidgetTester tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Ver catálogo').first);
      await tester.pumpAndSettle();

      expect(find.byType(CatalogDetailPage), findsNothing); // stub, no la real
      expect(
        find.text('detail-aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
        findsOneWidget,
      );
    },
  );

  testWidgets('el pull-to-refresh invoca refresh()', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    final RefreshIndicator indicator = tester.widget(
      find.byType(RefreshIndicator),
    );
    expect(fake.refreshCount, 0);
    await indicator.onRefresh();
    expect(fake.refreshCount, 1);
  });

  testWidgets('estado vacío muestra el mensaje sin mencionar proveedores', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      state: const SharedCatalogsState(catalogs: <Catalog>[]),
    );

    expect(find.text('Aún no tienes catálogos compartidos.'), findsOneWidget);
    expect(find.textContaining('proveedor'), findsNothing);
    expect(find.textContaining('Proveedor'), findsNothing);
  });

  testWidgets(
    'estado de error muestra mensaje y Reintentar llama a refresh()',
    (WidgetTester tester) async {
      await pumpHome(tester, error: Exception('boom'));

      expect(find.text('No pudimos cargar tus catálogos.'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pump();

      expect(fake.refreshCount, 1);
    },
  );

  testWidgets('el aviso de "sin conexión" aparece cuando fromCache es true', (
    WidgetTester tester,
  ) async {
    await pumpHome(
      tester,
      state: const SharedCatalogsState(
        catalogs: _FakeController.twoCatalogs,
        fromCache: true,
      ),
    );

    expect(find.textContaining('Sin conexión'), findsOneWidget);
  });

  testWidgets(
    '"Salir" pide confirmación; "Cancelar" no cierra sesión; confirmar sí',
    (WidgetTester tester) async {
      final authUser = FakeAuthUserService();
      final sessionStore = _FakeSessionStore();
      final container = ProviderContainer(
        overrides: [
          sharedCatalogsControllerProvider.overrideWith(
            () => _FakeController(
              stateOverride: const SharedCatalogsState(
                catalogs: _FakeController.twoCatalogs,
              ),
            ),
          ),
          authUserServiceProvider.overrideWithValue(authUser),
          sessionStoreProvider.overrideWithValue(sessionStore),
        ],
      );
      addTearDown(container.dispose);

      final GoRouter router = GoRouter(
        initialLocation: '/home',
        routes: <RouteBase>[
          GoRoute(path: '/home', builder: (context, _) => const HomePage()),
        ],
      );

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      // Abre el diálogo y cancela: no cierra sesión.
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar sesión?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar sesión?'), findsNothing);
      expect(sessionStore.cleared, isFalse);
      expect(authUser.signedOut, isFalse);

      // Reabre y confirma: sí cierra sesión.
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();
      // Dos coincidencias ahora: el botón de la cabecera y el del diálogo.
      await tester.tap(find.text('Salir').last);
      await tester.pumpAndSettle();

      expect(authUser.signedOut, isTrue);
      expect(sessionStore.cleared, isTrue);
      expect(container.read(authStateProvider), AuthStatus.signedOut);
    },
  );
}
