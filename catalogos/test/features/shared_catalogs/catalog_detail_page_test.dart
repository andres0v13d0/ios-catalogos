// Widget test de CatalogDetailPage (tareas 1.16/1.17/1.18).
//
// - Renderiza banner + productos (nombre, variantes, precios por cantidad).
// - En un catálogo "sin precios" oculta los importes reales pero muestra las
//   cantidades (CA de 1.16).
// - La búsqueda por nombre filtra los productos (1.17).
// - Muestra el indicador offline cuando la vista proviene de la caché (1.18).
//
// Se sobreescribe el controlador (familia) con un fake en memoria (sin Hive ni
// red). Las `Image.network` fallan en el entorno de test y el `errorBuilder`
// de la pantalla renderiza un marcador de reemplazo, por lo que la UI no
// depende de red real para probarse.

import 'package:catalogos/features/shared_catalogs/domain/catalog_detail.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_detail_controller.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const String _catalogId = 'cat-1';

CatalogDetail _detail({required bool sinPrecios}) => CatalogDetail(
      id: _catalogId,
      publicName: 'Catálogo Público',
      bannerUrl: 'https://cdn/banner.jpg',
      priceField: sinPrecios ? 'none' : 'mayorista',
      products: <Product>[
        Product(
          id: 'p1',
          nombre: 'Camiseta',
          imagenes: const <String>['https://cdn/p1.jpg'],
          colores: const <Variant>[Variant(id: 'r', name: 'Rojo')],
          tallas: const <Variant>[Variant(id: 'm', name: 'M')],
          precios: sinPrecios
              ? const <String, num>{'1': 0, '6': 0}
              : const <String, num>{'1': 20000, '6': 18000},
        ),
        Product(
          id: 'p2',
          nombre: 'Gorra',
          imagenes: const <String>[],
          precios: sinPrecios
              ? const <String, num>{'1': 0}
              : const <String, num>{'1': 9000},
        ),
      ],
    );

/// Fake del controlador (familia): estado fijo AsyncData, sin red ni caché.
class _FakeDetailController extends CatalogDetailController {
  _FakeDetailController(this._state) : super(_catalogId);

  final CatalogDetailState _state;

  @override
  Future<CatalogDetailState> build() async => _state;

  @override
  Future<void> refresh() async {}
}

void main() {
  Widget wrap(CatalogDetailState state) {
    return ProviderScope(
      overrides: [
        catalogDetailControllerProvider(_catalogId)
            .overrideWith(() => _FakeDetailController(state)),
      ],
      child: const MaterialApp(
        home: CatalogDetailPage(catalogId: _catalogId),
      ),
    );
  }

  testWidgets('renderiza banner y productos con precios por cantidad',
      (WidgetTester tester) async {
    // Superficie alta para que ambas tarjetas de producto se construyan (el
    // CustomScrollView construye sus slivers de forma perezosa).
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrap(CatalogDetailState(detail: _detail(sinPrecios: false))),
    );
    await tester.pump();

    // Banner presente.
    expect(find.byKey(const Key('catalog_detail_banner')), findsOneWidget);
    // Productos.
    expect(find.text('Camiseta'), findsOneWidget);
    expect(find.text('Gorra'), findsOneWidget);
    // Variantes: la línea del producto "Colores: Rojo" (además del chip de
    // faceta "Rojo", de ahí que busquemos la etiqueta compuesta).
    expect(find.text('Colores: Rojo'), findsOneWidget);
    // Precios por cantidad formateados (COP).
    expect(find.textContaining(r'$ 20.000'), findsOneWidget);
    expect(find.textContaining(r'$ 18.000'), findsOneWidget);
    // No debe mostrar el marcador de "a convenir" cuando hay precios.
    expect(find.textContaining('a convenir'), findsNothing);
  });

  testWidgets('catálogo "sin precios": oculta importes y muestra cantidades',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(CatalogDetailState(detail: _detail(sinPrecios: true))),
    );
    await tester.pump();

    // Aviso de modo "sin precios".
    expect(
      find.byKey(const Key('catalog_detail_price_hidden')),
      findsOneWidget,
    );
    // Las cantidades siguen visibles (x1, x6).
    expect(find.textContaining('x1'), findsWidgets);
    expect(find.textContaining('x6'), findsWidgets);
    // No se muestra ningún precio real como $ 0.
    expect(find.textContaining(r'$ 0'), findsNothing);
    // Se muestra el marcador de "a convenir".
    expect(find.textContaining('a convenir'), findsWidgets);
  });

  testWidgets('la búsqueda filtra los productos por nombre (1.17)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(CatalogDetailState(detail: _detail(sinPrecios: false))),
    );
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('catalog_detail_search_field')),
      'gorr',
    );
    await tester.pump();

    expect(find.text('Gorra'), findsOneWidget);
    expect(find.text('Camiseta'), findsNothing);
  });

  testWidgets('muestra el indicador offline cuando fromCache es true (1.18)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      wrap(
        CatalogDetailState(
          detail: _detail(sinPrecios: false),
          fromCache: true,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('catalog_detail_offline_banner')),
      findsOneWidget,
    );
  });
}
