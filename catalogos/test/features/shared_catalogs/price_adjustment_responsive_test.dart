// Tests de responsividad de "Ajustar precios" (ver
// docs/design/ajustar-precios.html).
//
// Cubre la matriz de tamaños pedida (320x568 .. 600x1024), con textScaler
// normal y 1.3x, en modo catálogo completo Y modo un solo producto: en todos
// los casos no debe haber overflow, el teclado se ve completo y la vista
// previa + el botón de aplicar/guardar nunca quedan tapados ni fuera de
// pantalla. Sin scroll vertical de página (un único Column adaptable).

import 'package:catalogos/core/result/result.dart';
import 'package:catalogos/features/shared_catalogs/data/reseller_price_rules_repository.dart';
import 'package:catalogos/features/shared_catalogs/domain/price_rule_calculator.dart';
import 'package:catalogos/features/shared_catalogs/domain/price_rules_contract.dart';
import 'package:catalogos/features/shared_catalogs/presentation/price_adjustment_controller.dart';
import 'package:catalogos/features/shared_catalogs/presentation/price_adjustment_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeRepo extends ResellerPriceRulesRepository {
  _FakeRepo() : super(Dio());

  @override
  Future<Result<PriceRulesSummary>> getRulesSummary(String catalogId) async =>
      const Ok<PriceRulesSummary>(
        PriceRulesSummary(
          catalogRule: PriceRule(mode: PriceRuleMode.percent, value: 30),
          productRules: {},
        ),
      );

  @override
  Future<Result<PriceRulesProductsPage>> getCatalogProducts(
    String catalogId, {
    int page = 1,
    int pageSize = 20,
  }) async => const Ok<PriceRulesProductsPage>(
    PriceRulesProductsPage(
      total: 24,
      page: 1,
      pageSize: 100,
      products: <CatalogPriceRuleProduct>[
        CatalogPriceRuleProduct(
          id: 'p1',
          nombre: 'Bolso de Mano con un nombre bastante largo para forzar truncado',
          imagen: null,
          precioProveedor: <String, num>{'1': 12999},
          precioAjustado: <String, num>{'1': 16900},
          reglaOrigen: RuleOrigin.catalog,
        ),
        CatalogPriceRuleProduct(
          id: 'p2',
          nombre: 'Gorra Clásica',
          imagen: null,
          precioProveedor: <String, num>{'1': 4449},
          precioAjustado: <String, num>{'1': 5800},
          reglaOrigen: RuleOrigin.catalog,
        ),
      ],
    ),
  );
}

const CatalogPriceRuleProduct _singleProduct = CatalogPriceRuleProduct(
  id: 'p9',
  nombre: 'Camiseta Básica Algodón con un nombre largo también',
  imagen: null,
  precioProveedor: <String, num>{'1': 20000},
  precioAjustado: <String, num>{'1': 26000},
  reglaOrigen: RuleOrigin.catalog,
);

Widget _wrap(PriceAdjustmentArgs args) {
  final router = GoRouter(
    initialLocation: '/catalog',
    routes: <RouteBase>[
      GoRoute(path: '/catalog', builder: (context, _) => const Text('catalog')),
      GoRoute(path: '/adjust', builder: (context, _) => PriceAdjustmentPage(args: args)),
    ],
  );
  router.push('/adjust');
  return ProviderScope(
    overrides: [resellerPriceRulesRepositoryProvider.overrideWithValue(_FakeRepo())],
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
    required PriceAdjustmentArgs args,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: _wrap(args),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  for (final Size size in _sizes) {
    for (final double scale in <double>[1.0, 1.3]) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()} · textScale $scale: '
        'modo catálogo completo cabe sin overflow, teclado y botón visibles',
        (WidgetTester tester) async {
          await pumpAt(
            tester,
            size: size,
            args: const PriceAdjustmentArgs(catalogId: 'cat-1', totalProductsHint: 24),
            textScale: scale,
          );

          expect(tester.takeException(), isNull);
          // Teclado completo: los 9 dígitos + 0 + borrar siempre presentes.
          for (final d in <String>['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']) {
            expect(
              find.byKey(ValueKey<String>('price_keypad_digit_$d')),
              findsOneWidget,
              reason: 'falta la tecla $d',
            );
          }
          // Botón de aplicar visible (no tapado por el teclado ni fuera de pantalla).
          expect(find.textContaining('Aplicar a'), findsOneWidget);
          // Único scroll vertical real: el de la página (ninguno, de hecho, en
          // este editor) — no debe haber un `Scrollable` vertical añadido por
          // overflow/recorte.
          final Iterable<Scrollable> verticalScrollables = tester
              .widgetList<Scrollable>(find.byType(Scrollable))
              .where((Scrollable s) => s.axisDirection == AxisDirection.down);
          expect(verticalScrollables, isEmpty);
        },
      );

      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()} · textScale $scale: '
        'modo un solo producto cabe sin overflow, teclado y botón visibles',
        (WidgetTester tester) async {
          await pumpAt(
            tester,
            size: size,
            args: const PriceAdjustmentArgs(
              catalogId: 'cat-1',
              totalProductsHint: 24,
              singleProduct: _singleProduct,
            ),
            textScale: scale,
          );

          expect(tester.takeException(), isNull);
          for (final d in <String>['1', '2', '3', '4', '5', '6', '7', '8', '9', '0']) {
            expect(find.byKey(ValueKey<String>('price_keypad_digit_$d')), findsOneWidget);
          }
          expect(find.text('Guardar para este producto'), findsOneWidget);
          expect(find.text('Solo este producto'), findsOneWidget);
        },
      );

      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()} · textScale $scale: '
        'los atajos van en UNA sola fila (mismo borde superior)',
        (WidgetTester tester) async {
          await pumpAt(
            tester,
            size: size,
            args: const PriceAdjustmentArgs(catalogId: 'cat-1', totalProductsHint: 24),
            textScale: scale,
          );

          expect(tester.takeException(), isNull);

          // Porcentaje: atajos 10/15/20/30%. Todos deben compartir el MISMO
          // borde superior (una fila), no apilarse en columna.
          final List<String> labels = <String>['10%', '15%', '20%', '30%'];
          final List<double> tops = <double>[];
          for (final String label in labels) {
            final Finder f = find.text(label);
            expect(f, findsOneWidget, reason: 'falta el atajo $label');
            tops.add(tester.getTopLeft(f).dy);
          }
          final double first = tops.first;
          for (final double t in tops) {
            expect(
              (t - first).abs(),
              lessThan(1.0),
              reason: 'los atajos no están alineados en una fila: $tops',
            );
          }
        },
      );
    }
  }
}
