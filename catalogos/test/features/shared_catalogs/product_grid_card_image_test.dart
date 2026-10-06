// Tests de la IMAGEN de la tarjeta de producto (diseño A, ver
// docs/design/productos-a.html):
//   - La imagen vive dentro de un contenedor de proporción FIJA 1:1
//     (`AspectRatio`) con esquinas redondeadas (`ClipRRect`), así una imagen
//     16:9 o 3:4 se RECORTA (BoxFit.cover) sin cambiar su proporción (nunca
//     `contain` que deja franjas, ni `fill`/`exact` que deforma).
//   - Al decodificar se pasa SOLO el ancho (`memCacheWidth`), nunca ancho +
//     alto a la vez (política "exact" que estiraría la foto).
//   - Dos tarjetas de una misma fila tienen EXACTAMENTE la misma altura.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:catalogos/features/shared_catalogs/domain/catalog_detail.dart';
import 'package:catalogos/features/shared_catalogs/presentation/product_grid_card.dart';
import 'package:catalogos/features/shared_catalogs/presentation/product_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Product _product(String id, String nombre, String? imageUrl) => Product(
  id: id,
  nombre: nombre,
  imagenes: imageUrl == null
      ? const <ProductImage>[]
      : <ProductImage>[ProductImage(imageUrl: imageUrl)],
  precios: const <String, num>{'1': 26000},
);

/// Dos tarjetas en la MISMA fila de una cuadrícula de 2 columnas, con el mismo
/// `childAspectRatio` (como en la pantalla real): así la altura de la celda es
/// idéntica para ambas, independientemente de que una tenga nombre corto (1
/// línea + "Proveedor $X") y la otra un nombre de 2 líneas.
Widget _wrapTwoCards() {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: GridView(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.62,
          ),
          children: <Widget>[
            ProductGridCard(
              key: const Key('card_a'),
              product: _product('a', 'Producto corto', 'https://example.com/16x9.jpg'),
              priceHidden: false,
              memCachePixels: 300,
              onTap: () {},
              markupBadgeLabel: '+30%',
              providerPriceLowest: 20000,
            ),
            ProductGridCard(
              key: const Key('card_b'),
              product: _product(
                'b',
                'Producto con un nombre bastante largo que ocupa dos líneas completas',
                'https://example.com/3x4.jpg',
              ),
              priceHidden: false,
              memCachePixels: 300,
              onTap: () {},
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('la imagen usa BoxFit.cover y SOLO ancho de decodificación', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrapTwoCards());
    await tester.pump();

    final Iterable<CachedNetworkImage> images =
        tester.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage));
    expect(images, isNotEmpty);
    for (final CachedNetworkImage image in images) {
      // Cover (recorta sin deformar), centrado.
      expect(image.fit, BoxFit.cover);
      expect(image.alignment, Alignment.center);
      // Solo ancho: pasar ancho+alto obliga a "exact" y deforma.
      expect(image.memCacheWidth, isNotNull);
      expect(image.memCacheHeight, isNull);
    }
  });

  testWidgets('la imagen vive en un contenedor cuadrado (AspectRatio 1:1) recortado', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrapTwoCards());
    await tester.pump();

    // El contenedor de imagen de cada tarjeta es un AspectRatio 1:1, y su
    // caja renderizada es cuadrada: una fuente 16:9 o 3:4 se recorta a ese
    // cuadrado (cover), nunca se estira para rellenarlo.
    final Finder aspects = find.descendant(
      of: find.byKey(const Key('card_a')),
      matching: find.byType(AspectRatio),
    );
    expect(aspects, findsWidgets);
    final AspectRatio aspect = tester.widget<AspectRatio>(aspects.first);
    expect(aspect.aspectRatio, 1.0);

    final Size imageBox = tester.getSize(aspects.first);
    expect(
      (imageBox.width - imageBox.height).abs(),
      lessThan(0.5),
      reason: 'la caja de imagen debe ser cuadrada: $imageBox',
    );

    // Esquinas redondeadas: hay un ClipRRect envolviendo la imagen.
    expect(
      find.descendant(of: find.byKey(const Key('card_a')), matching: find.byType(ClipRRect)),
      findsWidgets,
    );
  });

  testWidgets('dos tarjetas de una misma fila tienen la misma altura', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrapTwoCards());
    await tester.pump();

    final double heightA = tester.getSize(find.byKey(const Key('card_a'))).height;
    final double heightB = tester.getSize(find.byKey(const Key('card_b'))).height;
    expect(
      (heightA - heightB).abs(),
      lessThan(0.5),
      reason: 'las tarjetas de una fila deben tener la misma altura: a=$heightA b=$heightB',
    );
    expect(tester.takeException(), isNull);
  });

  // --- ProductThumbnail compartido (cuadrícula + vista previa de Ajustar) ---

  Widget thumb(String? url, {double side = 48, double radius = 12}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: side,
          height: side,
          child: ProductThumbnail(url: url, memCachePixels: 96, borderRadius: radius),
        ),
      ),
    ),
  );

  testWidgets('ProductThumbnail: contenedor cuadrado (una fuente 16:9 o 3:4 se recorta, no se deforma)',
      (WidgetTester tester) async {
    // 16:9 y 3:4 son proporciones de la FUENTE; el contenedor sigue siendo
    // 1:1 y la imagen usa cover (recorta sin cambiar proporción).
    for (final String url in <String>['https://e.com/16x9.jpg', 'https://e.com/3x4.jpg']) {
      await tester.pumpWidget(thumb(url));
      await tester.pump();

      final AspectRatio aspect = tester.widget<AspectRatio>(
        find.descendant(of: find.byType(ProductThumbnail), matching: find.byType(AspectRatio)),
      );
      expect(aspect.aspectRatio, 1.0);

      final CachedNetworkImage image =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(image.fit, BoxFit.cover);
      expect(image.alignment, Alignment.center);
      expect(image.memCacheWidth, isNotNull);
      expect(image.memCacheHeight, isNull);

      final Size box = tester.getSize(find.byType(ProductThumbnail));
      expect((box.width - box.height).abs(), lessThan(0.5), reason: 'debe ser cuadrado: $box');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('ProductThumbnail: esquinas redondeadas y respaldo con ícono si no hay imagen',
      (WidgetTester tester) async {
    await tester.pumpWidget(thumb(null));
    await tester.pump();

    expect(find.descendant(of: find.byType(ProductThumbnail), matching: find.byType(ClipRRect)), findsOneWidget);
    // Sin URL: respaldo con ícono (no CachedNetworkImage).
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });
}
