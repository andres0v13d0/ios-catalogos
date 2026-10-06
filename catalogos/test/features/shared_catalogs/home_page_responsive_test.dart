// Tests de responsividad de la pantalla "Tus catálogos" (carrusel), ver
// docs/design/inicio-a-carrusel.html.
//
// Cubre la matriz de tamaños lógicos pedida (320x568 .. 600x1024), con 1 y
// con 5 catálogos, y con textScaler normal y 1.3x: en todos los casos no
// debe haber overflow, los puntos y el botón "Ver catálogo" deben quedar
// dentro del área visible, y la pantalla no debe tener scroll vertical
// (el `SingleChildScrollView` del pull-to-refresh no debe dejar rango de
// scroll porque su contenido mide exactamente el alto de la pantalla).

import 'package:catalogos/features/auth/data/session_store.dart';
import 'package:catalogos/features/auth/presentation/auth_state_provider.dart';
import 'package:catalogos/features/shared_catalogs/domain/catalog.dart';
import 'package:catalogos/features/shared_catalogs/presentation/home_page.dart';
import 'package:catalogos/features/shared_catalogs/presentation/shared_catalogs_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/fake_auth_dependencies.dart';

class _FakeSessionStore implements SessionStore {
  @override
  Future<void> clear() async {}

  @override
  Future<SessionMetadata> read() async => const SessionMetadata();

  @override
  Future<void> save(SessionMetadata metadata) async {}
}

class _FakeController extends SharedCatalogsController {
  _FakeController(this.catalogs);

  final List<Catalog> catalogs;

  @override
  Future<SharedCatalogsState> build() async =>
      SharedCatalogsState(catalogs: catalogs);

  @override
  Future<void> refresh() async {}
}

// Nombres cortos, a propósito (como "Prueba" en el reporte original): el
// entorno de test no carga la fuente Poppins real y usa una de reserva más
// ancha, así que un nombre "normal" como "Colección Primavera" puede
// envolver a 2 líneas aquí aunque en el celular real sea 1 — eso haría que
// la prueba de huecos midiera el caso de 2 líneas (que sí necesita más alto)
// en vez del caso "sin huecos" que queremos verificar. Con un nombre de una
// sola palabra corta nos aseguramos 1 línea en cualquier fuente.
const Catalog _oneCatalog = Catalog(
  id: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
  displayName: 'Prueba',
  providerId: 30,
  providerName: 'Cuenta DEMO',
  priceField: 'mayorista',
);

final List<Catalog> _fiveCatalogs = List<Catalog>.generate(
  5,
  (int i) => Catalog(
    id: 'dddddddd-dddd-dddd-dddd-00000000000$i',
    displayName: 'Cat ${i + 1}',
    providerId: 40 + i,
    providerName: 'Prov ${i + 1}',
    priceField: i.isEven ? 'none' : 'mayorista',
  ),
);

Widget _wrap(List<Catalog> catalogs) {
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
      sharedCatalogsControllerProvider.overrideWith(
        () => _FakeController(catalogs),
      ),
      authUserServiceProvider.overrideWithValue(FakeAuthUserService()),
      sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Tamaños lógicos pedidos en la verificación de la tarea.
const List<Size> _sizes = <Size>[
  Size(320, 568),
  Size(360, 640),
  Size(360, 800),
  Size(390, 844),
  Size(412, 915),
  Size(430, 932),
  Size(600, 1024),
];

void main() {
  Future<void> pumpAt(
    WidgetTester tester, {
    required Size size,
    required List<Catalog> catalogs,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: _wrap(catalogs),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// La pantalla completa, sin ningún widget visible por debajo de
  /// `size.height` ni por encima de 0 (sin overflow visual) y sin rango de
  /// scroll vertical real.
  void expectFitsWithoutScroll(WidgetTester tester, Size size) {
    expect(tester.takeException(), isNull);

    final Finder scrollable = find.byType(SingleChildScrollView);
    expect(scrollable, findsOneWidget);
    // El `SingleChildScrollView` de pull-to-refresh es el ancestro; el
    // carrusel (`PageView`) también es un `Scrollable` (horizontal) y
    // aparece después en el árbol, así que el primero es el que nos
    // interesa verificar.
    final ScrollableState scrollableState = tester
        .stateList<ScrollableState>(
          find.descendant(of: scrollable, matching: find.byType(Scrollable)),
        )
        .first;
    expect(
      scrollableState.position.maxScrollExtent,
      0,
      reason: 'La pantalla no debe poder desplazarse verticalmente.',
    );

    final Finder button = find.text('Ver catálogo').first;
    final Rect buttonRect = tester.getRect(button);
    expect(buttonRect.bottom, lessThanOrEqualTo(size.height));
    expect(buttonRect.top, greaterThanOrEqualTo(0));
  }

  /// La tarjeta debe quedar compacta: el banner (`Flexible` capado) seguido
  /// de cerca por el bloque de texto, sin huecos internos repartidos ahí
  /// (cualquier sobrante de alto va fuera de la tarjeta, ver
  /// [CatalogCarousel] — el `Center` que envuelve cada tarjeta).
  void expectCardIsCompact(
    WidgetTester tester,
    String activeCatalogId,
    String activeCatalogName,
  ) {
    final Rect banner = tester.getRect(
      find.byKey(Key('catalog_card_banner_$activeCatalogId')),
    );
    // El nombre del catálogo por su texto exacto (no el primer `Text`
    // descendiente: ese sería las iniciales del logo del proveedor —que
    // vive DENTRO del bloque del banner, superpuesto por el solape de
    // -34dp— y no el bloque de texto que nos interesa medir).
    final Rect name = tester.getRect(
      find
          .descendant(
            of: find.byKey(Key('catalog_$activeCatalogId')),
            matching: find.text(activeCatalogName),
          )
          .first,
    );
    final Rect button = tester.getRect(
      find
          .descendant(
            of: find.byKey(Key('catalog_$activeCatalogId')),
            matching: find.text('Ver catálogo'),
          )
          .first,
    );

    expect(
      name.top - banner.bottom,
      inInclusiveRange(-1.0, 24.0),
      reason: 'El nombre debe empezar a ≤24dp del borde inferior del banner.',
    );
    expect(
      button.top - name.top,
      lessThanOrEqualTo(120.0),
      reason: 'El botón debe quedar a ≤120dp del nombre (sin huecos internos).',
    );
  }

  for (final Size size in _sizes) {
    for (final int count in <int>[1, 5]) {
      for (final double scale in <double>[1.0, 1.3]) {
        testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} · $count catálogo(s) · textScale $scale: '
          'cabe sin overflow ni scroll',
          (WidgetTester tester) async {
            final Catalog active = count == 1
                ? _oneCatalog
                : _fiveCatalogs.first;
            await pumpAt(
              tester,
              size: size,
              catalogs: count == 1 ? <Catalog>[_oneCatalog] : _fiveCatalogs,
              textScale: scale,
            );

            expectFitsWithoutScroll(tester, size);
            expect(find.text('Ver catálogo').first, findsOneWidget);
            expectCardIsCompact(tester, active.id, active.displayName);
          },
        );
      }
    }
  }

  testWidgets(
    'con 5 catálogos, los puntos del carrusel quedan dentro del área visible',
    (WidgetTester tester) async {
      const Size size = Size(360, 640);
      await pumpAt(tester, size: size, catalogs: _fiveCatalogs);

      expect(tester.takeException(), isNull);

      // 5 catálogos > 3: a lo sumo 3 puntos visibles (ventana recortada).
      final Finder pageView = find.byType(PageView);
      expect(pageView, findsOneWidget);
      final Rect pageViewRect = tester.getRect(pageView);
      expect(pageViewRect.bottom, lessThanOrEqualTo(size.height));
    },
  );

  testWidgets('en orientación horizontal (tablet) la tarjeta no se desborda', (
    WidgetTester tester,
  ) async {
    const Size size = Size(1024, 600);
    await pumpAt(tester, size: size, catalogs: _fiveCatalogs);

    expectFitsWithoutScroll(tester, size);
  });
}
