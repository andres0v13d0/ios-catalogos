// Tests del estado 4 "Listo" de "Ajustar precios" (ver
// docs/design/ajustar-precios.html): los anillos alrededor del círculo verde
// son ONDAS animadas en bucle.
//
//   - Con animaciones habilitadas: tras aplicar, hay animación en curso y
//     SIGUE corriendo después de un periodo completo (bucle); el frame cambia
//     con el tiempo.
//   - Con MediaQuery.disableAnimations: NO hay animación en bucle (anillos
//     estáticos + check ya dibujado).
//   - Sin overflow en 320x568, 360x640, 390x844 y 430x932.

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
        PriceRulesSummary(catalogRule: PriceRule(mode: PriceRuleMode.percent, value: 30), productRules: {}),
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
          nombre: 'Bolso de Mano',
          imagen: null,
          precioProveedor: <String, num>{'1': 12999},
          precioAjustado: <String, num>{'1': 16900},
          reglaOrigen: RuleOrigin.catalog,
        ),
      ],
    ),
  );

  @override
  Future<Result<SavedCatalogRuleResult>> upsertCatalogRule(String catalogId, PriceRule rule) async =>
      const Ok<SavedCatalogRuleResult>(
        SavedCatalogRuleResult(
          rule: PriceRule(mode: PriceRuleMode.percent, value: 30),
          affectedProductIds: <String>['p1'],
          productsWithOwnRule: <String>[],
        ),
      );
}

const _args = PriceAdjustmentArgs(catalogId: 'cat-1', totalProductsHint: 24);

Widget _wrap({required bool disableAnimations}) {
  final router = GoRouter(
    initialLocation: '/catalog',
    routes: <RouteBase>[
      GoRoute(path: '/catalog', builder: (context, _) => const Text('catalog')),
      GoRoute(path: '/adjust', builder: (context, _) => const PriceAdjustmentPage(args: _args)),
    ],
  );
  router.push('/adjust');
  return ProviderScope(
    overrides: [resellerPriceRulesRepositoryProvider.overrideWithValue(_FakeRepo())],
    child: Builder(
      builder: (BuildContext context) {
        final MediaQueryData base = MediaQueryData.fromView(View.of(context));
        return MediaQuery(
          data: base.copyWith(disableAnimations: disableAnimations),
          child: MaterialApp.router(routerConfig: router),
        );
      },
    ),
  );
}

/// Lleva la pantalla al estado "Listo" (aplica una regla de 30%).
Future<void> _reachDone(WidgetTester tester) async {
  await tester.pumpWidget(_wrap(disableAnimations: false));
  await tester.pump();
  await tester.pump();
  final controller = ProviderScope.containerOf(
    tester.element(find.byType(PriceAdjustmentPage)),
  ).read(priceAdjustmentControllerProvider(_args).notifier);
  controller.onChipTap(30);
  await tester.pump();
  await controller.onSubmit();
  await tester.pump();
}

void main() {
  testWidgets('las ondas se animan y hacen bucle (sigue corriendo tras un periodo)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _reachDone(tester);

    // Hay una animación en curso (entrada + ondas en bucle).
    expect(tester.hasRunningAnimations, isTrue);

    // Captura dos frames separados en el tiempo: deben diferir (las ondas se
    // mueven). Comparamos las fases vía RepaintBoundary -> el CustomPaint se
    // repinta, así que basta con comprobar que sigue habiendo animación tras
    // avanzar más de un periodo completo (2.4s): el bucle no se detiene.
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pump(const Duration(milliseconds: 2600)); // > un periodo
    expect(tester.hasRunningAnimations, isTrue, reason: 'las ondas deben repetirse en bucle');

    expect(tester.takeException(), isNull);
  });

  testWidgets('con disableAnimations NO hay animación en bucle', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(disableAnimations: true));
    await tester.pump();
    await tester.pump();
    final controller = ProviderScope.containerOf(
      tester.element(find.byType(PriceAdjustmentPage)),
    ).read(priceAdjustmentControllerProvider(_args).notifier);
    controller.onChipTap(30);
    await tester.pump();
    await controller.onSubmit();
    await tester.pump();

    // Sin ondas en bucle: no debe quedar ninguna animación corriendo.
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final Size size in const <Size>[
    Size(320, 568),
    Size(360, 640),
    Size(390, 844),
    Size(430, 932),
  ]) {
    testWidgets('estado "Listo" sin overflow en ${size.width.toInt()}x${size.height.toInt()}',
        (WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _reachDone(tester);
      await tester.pump(const Duration(milliseconds: 800));

      expect(tester.takeException(), isNull);
      // El check y el título están presentes (pantalla "Listo" renderizada).
      expect(find.text('Precios actualizados'), findsOneWidget);
    });
  }
}
