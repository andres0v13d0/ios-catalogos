// Widget tests de ProductDetailPage: fotos, colores, tallas y precio — todo
// de solo lectura salvo el botón "Editar precio", que reabre la MISMA
// pantalla de "Ajustar precios" que ya usa el lápiz de la cuadrícula.
//
// Cubre:
// - muestra nombre, "Desde $X", colores y tallas;
// - catálogo "sin precios": oculta precio y el botón de editar;
// - sin overlay cargado para el producto: no hay botón de editar;
// - con ajuste visible del overlay: aparece la insignia y "Editar precio"
//   navega a "Ajustar precios" con el producto correcto.

import 'package:catalogos/app/router/app_routes.dart';
import 'package:catalogos/features/shared_catalogs/domain/catalog_detail.dart';
import 'package:catalogos/features/shared_catalogs/domain/price_rules_contract.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_price_overlay_controller.dart';
import 'package:catalogos/features/shared_catalogs/presentation/price_adjustment_controller.dart';
import 'package:catalogos/features/shared_catalogs/presentation/product_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const String _catalogId = 'cat-1';

Product _product({
  bool withPrices = true,
  List<Variant> colores = const <Variant>[],
  List<Variant> tallas = const <Variant>[],
}) => Product(
  id: 'p1',
  nombre: 'Bolso de Mano',
  imagenes: const <ProductImage>[
    ProductImage(imageUrl: 'https://cdn/p1-a.jpg'),
    ProductImage(imageUrl: 'https://cdn/p1-b.jpg'),
  ],
  colores: colores,
  tallas: tallas,
  precios: withPrices ? const <String, num>{'1': 45000, '6': 40000} : const <String, num>{},
);

/// Overlay fijo (familia): devuelve el [fixedState] dado sin tocar red.
class _FakeOverlayController extends CatalogPriceOverlayController {
  _FakeOverlayController(this.fixedState) : super(_catalogId);

  final CatalogPriceOverlayState fixedState;

  @override
  Future<CatalogPriceOverlayState> build() async => fixedState;
}

/// Monta [ProductDetailPage] sobre una ruta previa ('/catalog', como en
/// `price_adjustment_page_test.dart`) y registra la ruta real de "Ajustar
/// precios" con un stub, para verificar que el botón "Editar precio" navega
/// ahí con el producto correcto — sin ejercitar el guardado real.
Future<void> _pumpDetail(
  WidgetTester tester, {
  required ProductDetailArgs args,
  CatalogPriceOverlayState overlay = CatalogPriceOverlayState.empty,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final GoRouter router = GoRouter(
    initialLocation: '/catalog',
    routes: <RouteBase>[
      GoRoute(path: '/catalog', builder: (context, _) => const Text('catalog-stub')),
      GoRoute(
        path: '/detail',
        builder: (context, _) => ProductDetailPage(args: args),
      ),
      GoRoute(
        path: AppRoutes.adjustPrices,
        builder: (context, state) {
          final PriceAdjustmentArgs adjustArgs = state.extra! as PriceAdjustmentArgs;
          return Text('adjust-stub-${adjustArgs.singleProduct?.id}');
        },
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        catalogPriceOverlayControllerProvider(
          _catalogId,
        ).overrideWith(() => _FakeOverlayController(overlay)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  router.push('/detail');
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'muestra nombre, "Desde \$X", colores y tallas',
    (WidgetTester tester) async {
      await _pumpDetail(
        tester,
        args: ProductDetailArgs(
          catalogId: _catalogId,
          product: _product(
            colores: const <Variant>[Variant(id: 'rojo', name: 'Rojo')],
            tallas: const <Variant>[Variant(id: 'm', name: 'M'), Variant(id: 'l', name: 'L')],
          ),
          priceHidden: false,
          totalProducts: 1,
        ),
      );

      // Aparece tanto en la cabecera como en el título del cuerpo.
      expect(find.text('Bolso de Mano'), findsNWidgets(2));
      // El precio grande es el texto EXACTO "$40.000"; la fila "Desde 6
      // unidades: $40.000" del detalle por cantidad lo contiene también, así
      // que se distinguen por igualdad exacta en vez de "contains".
      expect(find.text(r'$40.000'), findsOneWidget);
      expect(find.textContaining('Desde 6 unidades'), findsOneWidget);
      expect(find.text('Rojo'), findsOneWidget);
      expect(find.text('M'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
    },
  );

  testWidgets(
    'catálogo "sin precios": oculta el precio y no hay botón de editar',
    (WidgetTester tester) async {
      await _pumpDetail(
        tester,
        args: ProductDetailArgs(
          catalogId: _catalogId,
          product: _product(),
          priceHidden: true,
          totalProducts: 1,
        ),
      );

      expect(find.textContaining(r'$'), findsNothing);
      expect(find.text('Editar precio'), findsNothing);
    },
  );

  testWidgets(
    'sin overlay cargado para el producto: no hay botón de editar',
    (WidgetTester tester) async {
      await _pumpDetail(
        tester,
        args: ProductDetailArgs(
          catalogId: _catalogId,
          product: _product(),
          priceHidden: false,
          totalProducts: 1,
        ),
      );

      expect(find.text('Editar precio'), findsNothing);
    },
  );

  testWidgets(
    'con ajuste visible: muestra la insignia y "Editar precio" abre Ajustar precios',
    (WidgetTester tester) async {
      const CatalogPriceRuleProduct overlayProduct = CatalogPriceRuleProduct(
        id: 'p1',
        nombre: 'Bolso de Mano',
        imagen: null,
        precioProveedor: <String, num>{'1': 30000},
        precioAjustado: <String, num>{'1': 40000},
        reglaOrigen: RuleOrigin.catalog,
      );

      await _pumpDetail(
        tester,
        args: ProductDetailArgs(
          catalogId: _catalogId,
          product: _product(),
          priceHidden: false,
          totalProducts: 1,
        ),
        overlay: const CatalogPriceOverlayState(
          byProductId: <String, CatalogPriceRuleProduct>{'p1': overlayProduct},
        ),
      );

      expect(find.textContaining('+33%'), findsOneWidget);
      expect(find.textContaining(r'Proveedor $30.000'), findsOneWidget);
      expect(find.text('Editar precio'), findsOneWidget);

      await tester.tap(find.text('Editar precio'));
      await tester.pumpAndSettle();

      expect(find.text('adjust-stub-p1'), findsOneWidget);
    },
  );
}
