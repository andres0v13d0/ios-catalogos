// Tests de rendimiento de "Productos del catálogo" (ver tarea de
// optimización de imágenes):
// - una imagen grande se decodifica al tamaño de la celda, no a su tamaño
//   original (memCacheWidth/memCacheHeight de CachedNetworkImage);
// - cada tarjeta solo pide la PRIMERA imagen del producto, nunca las demás;
// - el scroll rápido por ~100 productos no produce overflow en los tamaños
//   pedidos (320x568, 360x640, 390x844, 430x932).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:catalogos/features/shared_catalogs/domain/catalog_detail.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_detail_controller.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const String _catalogId = 'cat-1';

List<Product> _products(int count) => List<Product>.generate(
  count,
  (int i) => Product(
    id: 'p$i',
    nombre: 'Producto $i',
    // Dos imágenes por producto: la tarjeta solo debe pedir la primera.
    imagenes: <ProductImage>[
      ProductImage(
        imageUrl: 'https://cdn.test/p$i-full.jpg',
        thumbnailUrl: 'https://cdn.test/p$i-thumb.webp',
      ),
      ProductImage(
        imageUrl: 'https://cdn.test/p$i-full-2.jpg',
        thumbnailUrl: 'https://cdn.test/p$i-thumb-2.webp',
      ),
    ],
    precios: <String, num>{'1': 10000 + i * 100},
  ),
);

class _FakeDetailController extends CatalogDetailController {
  _FakeDetailController(this._state) : super(_catalogId);

  final CatalogDetailState _state;

  @override
  Future<CatalogDetailState> build() async => _state;

  @override
  Future<void> refresh() async {}
}

Widget _wrap(List<Product> products) {
  final GoRouter router = GoRouter(
    initialLocation: '/catalog/$_catalogId',
    routes: <RouteBase>[
      GoRoute(
        path: '/catalog/:id',
        builder: (context, _) => const CatalogDetailPage(catalogId: _catalogId),
      ),
    ],
  );
  final CatalogDetail detail = CatalogDetail(
    id: _catalogId,
    publicName: 'Catálogo de rendimiento',
    priceField: 'mayorista',
    products: products,
  );
  return ProviderScope(
    overrides: [
      catalogDetailControllerProvider(_catalogId).overrideWith(
        () => _FakeDetailController(CatalogDetailState(detail: detail)),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets(
    'la imagen se decodifica al tamaño de la celda (memCacheWidth/Height), '
    'no al tamaño original',
    (WidgetTester tester) async {
      const Size size = Size(390, 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(_products(6)));
      await tester.pump();
      await tester.pump();

      final CachedNetworkImage firstImage = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage).first,
      );

      // Columna de ~168dp (2 columnas, 390 de ancho, 20+20 de relleno, 14 de
      // separación) × dpr 2.0 ≈ 320-340px físicos — muy por debajo de los
      // hasta 2000px que puede medir la imagen original. El valor exacto
      // depende del cálculo de `_gridGeometry`; lo importante es que NO sea
      // ni nulo (decodificaría al tamaño completo) ni el tamaño original.
      expect(firstImage.memCacheWidth, isNotNull);
      expect(firstImage.memCacheHeight, isNotNull);
      expect(firstImage.memCacheWidth, lessThan(500));
      expect(firstImage.memCacheWidth, greaterThan(50));
      expect(firstImage.memCacheWidth, firstImage.memCacheHeight);
    },
  );

  testWidgets('cada tarjeta pide solo la primera imagen del producto',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(_products(4)));
    await tester.pump();
    await tester.pump();

    final List<CachedNetworkImage> images = tester
        .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .toList();

    expect(images, isNotEmpty);
    for (final CachedNetworkImage image in images) {
      // Nunca la segunda imagen ("-2.webp"/"-full-2.jpg") de ningún producto.
      expect(image.imageUrl, isNot(contains('-2')));
      expect(image.imageUrl, contains('-thumb.webp'));
    }
  });

  for (final Size size in const <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(390, 844),
    Size(430, 932),
  ]) {
    testWidgets(
      '${size.width.toInt()}x${size.height.toInt()}: scroll rápido por '
      '~100 productos sin overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrap(_products(100)));
        await tester.pump();
        await tester.pump();

        // El scroll vertical de la pantalla (no el horizontal interno del
        // campo de búsqueda, ver home_page_responsive_test.dart).
        final Finder scrollable = find.byWidgetPredicate(
          (Widget w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        );

        // Varios arrastres rápidos y consecutivos, de punta a punta.
        for (int i = 0; i < 6; i++) {
          await tester.drag(scrollable, const Offset(0, -800));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }
}
