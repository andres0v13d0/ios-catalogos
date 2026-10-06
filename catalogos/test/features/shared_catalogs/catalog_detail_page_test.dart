// Widget tests de CatalogDetailPage — "Productos del catálogo" (diseño A,
// ver docs/design/productos-a.html). Etapa 1: solo ver productos.
//
// Cubre:
// - cuadrícula de productos (nombre, "Desde $X" con el precio menor);
// - "sin precios" (priceField 'none') no muestra ninguna línea de precio;
// - cabecera con nombre público y "N productos" (nunca el nombre interno);
// - la búsqueda por nombre filtra tras el debounce (~250ms);
// - estados vacío (catálogo sin productos / sin resultados), error con
//   Reintentar, y aviso de "sin conexión" cuando fromCache es true;
// - el botón "Volver" existe y es accesible.
//
// Controlador (familia) sobreescrito con un fake en memoria (sin Hive ni
// red). Las `Image.network` fallan en el entorno de test y el
// `errorBuilder` de la tarjeta renderiza el marcador de reemplazo.

import 'package:catalogos/features/shared_catalogs/domain/catalog_detail.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_detail_controller.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_detail_page.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_price_overlay_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const String _catalogId = 'cat-1';

CatalogDetail _detail({required bool sinPrecios, List<Product>? products}) =>
    CatalogDetail(
      id: _catalogId,
      publicName: 'Catálogo Público',
      priceField: sinPrecios ? 'none' : 'mayorista',
      products:
          products ??
          <Product>[
            const Product(
              id: 'p1',
              nombre: 'Camiseta Básica Algodón',
              precios: <String, num>{'1': 26000, '6': 24000},
            ),
            const Product(
              id: 'p2',
              nombre: 'Chaqueta Deportiva',
              precios: <String, num>{'1': 110500},
            ),
          ],
    );

/// Fake del controlador (familia): estado fijo AsyncData (o error), sin red
/// ni caché.
class _FakeDetailController extends CatalogDetailController {
  _FakeDetailController(this._state, {this.error, this.onRefreshCalled})
    : super(_catalogId);

  final CatalogDetailState? _state;
  final Object? error;
  final VoidCallback? onRefreshCalled;

  @override
  Future<CatalogDetailState> build() async {
    if (error != null) throw error!;
    return _state!;
  }

  @override
  Future<void> refresh() async => onRefreshCalled?.call();
}

/// Overlay de "Ajustar precios" fijo en vacío: estos tests no ejercitan esa
/// función y no deben depender de Dio/Firebase reales.
class _FakeOverlayController extends CatalogPriceOverlayController {
  _FakeOverlayController() : super(_catalogId);

  @override
  Future<CatalogPriceOverlayState> build() async => CatalogPriceOverlayState.empty;
}

void main() {
  Widget wrap({
    CatalogDetailState? state,
    Object? error,
    VoidCallback? onRefreshCalled,
  }) {
    final GoRouter router = GoRouter(
      initialLocation: '/catalog/$_catalogId',
      routes: <RouteBase>[
        GoRoute(
          path: '/catalog/:id',
          builder: (context, _) => const CatalogDetailPage(
            catalogId: _catalogId,
            title: 'Catálogo Público',
          ),
        ),
        GoRoute(path: '/home', builder: (context, _) => const Text('home')),
      ],
    );
    return ProviderScope(
      overrides: [
        catalogDetailControllerProvider(_catalogId).overrideWith(
          () => _FakeDetailController(
            state,
            error: error,
            onRefreshCalled: onRefreshCalled,
          ),
        ),
        catalogPriceOverlayControllerProvider(_catalogId).overrideWith(() => _FakeOverlayController()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    CatalogDetailState? state,
    Object? error,
    Size size = const Size(390, 844),
    VoidCallback? onRefreshCalled,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrap(state: state, error: error, onRefreshCalled: onRefreshCalled),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
    'muestra el nombre público, "N productos" y las tarjetas con "Desde \$X"',
    (WidgetTester tester) async {
      await pumpPage(
        tester,
        state: CatalogDetailState(detail: _detail(sinPrecios: false)),
      );

      expect(find.text('Catálogo Público'), findsOneWidget);
      expect(find.text('2 productos'), findsOneWidget);
      expect(find.text('Camiseta Básica Algodón'), findsOneWidget);
      expect(find.text('Chaqueta Deportiva'), findsOneWidget);
      // Precio menor de cada producto, formato COP sin espacio tras "$" (igual
      // que la página pública: Math.round(x) con separador de miles es-CO).
      expect(find.textContaining(r'$24.000'), findsOneWidget);
      expect(find.textContaining(r'$110.500'), findsOneWidget);
    },
  );

  testWidgets('catálogo "sin precios": no muestra ninguna línea de precio', (
    WidgetTester tester,
  ) async {
    await pumpPage(
      tester,
      state: CatalogDetailState(detail: _detail(sinPrecios: true)),
    );

    expect(find.textContaining('Desde'), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('con un solo producto, "1 producto" (singular)', (
    WidgetTester tester,
  ) async {
    await pumpPage(
      tester,
      state: CatalogDetailState(
        detail: _detail(
          sinPrecios: false,
          products: const <Product>[
            Product(
              id: 'p1',
              nombre: 'Único',
              precios: <String, num>{'1': 1000},
            ),
          ],
        ),
      ),
    );

    expect(find.text('1 producto'), findsOneWidget);
  });

  testWidgets('la búsqueda filtra los productos por nombre tras el debounce', (
    WidgetTester tester,
  ) async {
    await pumpPage(
      tester,
      state: CatalogDetailState(detail: _detail(sinPrecios: false)),
    );

    await tester.enterText(
      find.byKey(const Key('catalog_products_search_field')),
      'chaq',
    );
    // Antes del debounce (~250ms) el filtro no se aplicó todavía.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Camiseta Básica Algodón'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Chaqueta Deportiva'), findsOneWidget);
    expect(find.text('Camiseta Básica Algodón'), findsNothing);
  });

  testWidgets(
    'búsqueda sin coincidencias muestra "Sin resultados para tu búsqueda"',
    (WidgetTester tester) async {
      await pumpPage(
        tester,
        state: CatalogDetailState(detail: _detail(sinPrecios: false)),
      );

      await tester.enterText(
        find.byKey(const Key('catalog_products_search_field')),
        'zapatos',
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sin resultados para tu búsqueda.'), findsOneWidget);
    },
  );

  testWidgets('catálogo vacío muestra "Este catálogo aún no tiene productos"', (
    WidgetTester tester,
  ) async {
    await pumpPage(
      tester,
      state: CatalogDetailState(
        detail: _detail(sinPrecios: false, products: const <Product>[]),
      ),
    );

    expect(find.text('Este catálogo aún no tiene productos.'), findsOneWidget);
  });

  testWidgets('el aviso de "sin conexión" aparece cuando fromCache es true', (
    WidgetTester tester,
  ) async {
    await pumpPage(
      tester,
      state: CatalogDetailState(
        detail: _detail(sinPrecios: false),
        fromCache: true,
      ),
    );

    expect(
      find.byKey(const Key('catalog_products_offline_banner')),
      findsOneWidget,
    );
  });

  testWidgets('el botón "Volver" es accesible', (WidgetTester tester) async {
    await pumpPage(
      tester,
      state: CatalogDetailState(detail: _detail(sinPrecios: false)),
    );

    expect(find.bySemanticsLabel('Volver'), findsOneWidget);
  });

  testWidgets(
    'estado de error muestra mensaje y Reintentar llama a refresh()',
    (WidgetTester tester) async {
      int refreshCount = 0;
      await pumpPage(
        tester,
        error: Exception('boom'),
        onRefreshCalled: () => refreshCount++,
      );

      expect(find.text('No pudimos cargar los productos.'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pump();

      expect(refreshCount, 1);
    },
  );
}
