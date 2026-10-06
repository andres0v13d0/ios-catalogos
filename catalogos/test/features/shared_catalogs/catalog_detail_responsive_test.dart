// Tests de responsividad de "Productos del catálogo" (diseño A, ver
// docs/design/productos-a.html).
//
// Cubre la matriz de tamaños lógicos pedida (320x568 .. 600x1024), con
// textScaler normal y 1.3x: en todos los casos no debe haber overflow, el
// nombre se trunca con ellipsis y la pantalla usa un único scroll (sin
// scroll anidado). En pantallas anchas (≥600dp) la cuadrícula usa más
// columnas (3+).

import 'package:catalogos/features/shared_catalogs/domain/catalog_detail.dart';
import 'package:catalogos/features/shared_catalogs/domain/price_rule_calculator.dart';
import 'package:catalogos/features/shared_catalogs/domain/price_rules_contract.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_detail_controller.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_detail_page.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_price_overlay_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const String _catalogId = 'cat-1';

final List<Product> _products = List<Product>.generate(
  9,
  (int i) => Product(
    id: 'p$i',
    nombre: 'Producto de prueba número ${i + 1} con nombre bastante largo',
    precios: <String, num>{'1': 12999 + i * 1000, '6': 10000 + i * 900},
  ),
);

CatalogDetail _detail({bool sinPrecios = false}) => CatalogDetail(
  id: _catalogId,
  publicName: 'Catálogo de prueba con nombre largo para forzar ellipsis',
  priceField: sinPrecios ? 'none' : 'mayorista',
  products: _products,
);

class _FakeDetailController extends CatalogDetailController {
  _FakeDetailController(this._state) : super(_catalogId);

  final CatalogDetailState _state;

  @override
  Future<CatalogDetailState> build() async => _state;

  @override
  Future<void> refresh() async {}
}

/// Overlay de "Ajustar precios" fijo en vacío: estos tests no ejercitan esa
/// función y no deben depender de Dio/Firebase reales.
class _FakeOverlayController extends CatalogPriceOverlayController {
  _FakeOverlayController() : super(_catalogId);

  @override
  Future<CatalogPriceOverlayState> build() async => CatalogPriceOverlayState.empty;
}

/// Overlay POBLADO: cada producto tiene precio del proveedor Y ajustado
/// (ajuste real), de modo que la tarjeta dibuja además la etiqueta "+X%" y la
/// línea "Proveedor $X". Reproduce el caso que antes desbordaba la tarjeta
/// (el alto de esa 3ª línea no se reservaba): aquí sirve de regresión.
class _FakeOverlayWithRules extends CatalogPriceOverlayController {
  _FakeOverlayWithRules() : super(_catalogId);

  @override
  Future<CatalogPriceOverlayState> build() async => CatalogPriceOverlayState(
    catalogRule: const PriceRule(mode: PriceRuleMode.percent, value: 30),
    byProductId: <String, CatalogPriceRuleProduct>{
      for (final Product p in _products)
        p.id: CatalogPriceRuleProduct(
          id: p.id,
          nombre: p.nombre,
          imagen: null,
          precioProveedor: <String, num>{'1': 20000},
          precioAjustado: <String, num>{'1': 26000}, // +30%, distinto del proveedor
          reglaOrigen: RuleOrigin.catalog,
        ),
    },
  );
}

Widget _wrap(CatalogDetailState state, {bool withRules = false}) {
  final GoRouter router = GoRouter(
    initialLocation: '/catalog/$_catalogId',
    routes: <RouteBase>[
      GoRoute(
        path: '/catalog/:id',
        builder: (context, _) => const CatalogDetailPage(catalogId: _catalogId),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      catalogDetailControllerProvider(_catalogId)
          .overrideWith(() => _FakeDetailController(state)),
      catalogPriceOverlayControllerProvider(_catalogId).overrideWith(
        () => withRules ? _FakeOverlayWithRules() : _FakeOverlayController(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

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
    required CatalogDetailState state,
    double textScale = 1.0,
    bool withRules = false,
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
        child: _wrap(state, withRules: withRules),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  for (final Size size in _sizes) {
    for (final double scale in <double>[1.0, 1.3]) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()} · textScale $scale: '
        'cabe sin overflow, con precios',
        (WidgetTester tester) async {
          await pumpAt(
            tester,
            size: size,
            state: CatalogDetailState(detail: _detail()),
            textScale: scale,
          );

          expect(tester.takeException(), isNull);
          expect(
            find.byKey(const Key('catalog_products_grid')),
            findsOneWidget,
          );
          expect(
            find.text(
              'Catálogo de prueba con nombre largo para forzar ellipsis',
            ),
            findsOneWidget,
          );

          // Único scroll VERTICAL (el de la pantalla, vía CustomScrollView):
          // nada de PageView ni Scrollable vertical anidado. El único otro
          // Scrollable que puede existir es el horizontal interno del campo
          // de texto de búsqueda (desplazamiento del cursor), que no cuenta
          // como "scroll anidado raro".
          final Iterable<Scrollable> verticalScrollables = tester
              .widgetList<Scrollable>(find.byType(Scrollable))
              .where((Scrollable s) => s.axisDirection == AxisDirection.down);
          expect(verticalScrollables, hasLength(1));
        },
      );

      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()} · textScale $scale: '
        'cabe sin overflow, catálogo "sin precios"',
        (WidgetTester tester) async {
          await pumpAt(
            tester,
            size: size,
            state: CatalogDetailState(detail: _detail(sinPrecios: true)),
            textScale: scale,
          );

          expect(tester.takeException(), isNull);
          expect(find.textContaining(r'$'), findsNothing);
        },
      );

      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()} · textScale $scale: '
        'cabe sin overflow, con ajuste (línea "Proveedor \$X" visible)',
        (WidgetTester tester) async {
          await pumpAt(
            tester,
            size: size,
            state: CatalogDetailState(detail: _detail()),
            textScale: scale,
            withRules: true,
          );

          // La 3ª línea "Proveedor $X" se dibuja Y su alto está reservado: no
          // debe haber ningún overflow en toda la matriz de tamaños/escala.
          expect(tester.takeException(), isNull);
          expect(find.textContaining('Proveedor'), findsWidgets);
        },
      );
    }
  }

  testWidgets('en pantallas anchas (≥600dp) la cuadrícula usa 3+ columnas', (
    WidgetTester tester,
  ) async {
    await pumpAt(
      tester,
      size: const Size(600, 1024),
      state: CatalogDetailState(detail: _detail()),
    );

    final SliverGrid grid = tester.widget(find.byType(SliverGrid));
    final SliverGridDelegateWithFixedCrossAxisCount delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, greaterThanOrEqualTo(3));
  });

  testWidgets('en móvil angosto la cuadrícula usa 2 columnas', (
    WidgetTester tester,
  ) async {
    await pumpAt(
      tester,
      size: const Size(390, 844),
      state: CatalogDetailState(detail: _detail()),
    );

    final SliverGrid grid = tester.widget(find.byType(SliverGrid));
    final SliverGridDelegateWithFixedCrossAxisCount delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
  });
}
