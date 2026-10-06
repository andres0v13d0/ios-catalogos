// Captura temporal de verificación visual (NO es un test de regresión
// permanente): renderiza las pantallas reales a 390x844 con Poppins
// cargada, para comparar contra los HTML de referencia. Se borra tras usarla.

import 'dart:io';

import 'package:catalogos/core/result/failure.dart';
import 'package:catalogos/core/result/result.dart';
import 'package:catalogos/features/shared_catalogs/data/reseller_price_rules_repository.dart';
import 'package:catalogos/features/shared_catalogs/domain/catalog_detail.dart';
import 'package:catalogos/features/shared_catalogs/domain/price_rule_calculator.dart';
import 'package:catalogos/features/shared_catalogs/domain/price_rules_contract.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_detail_controller.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_detail_page.dart';
import 'package:catalogos/features/shared_catalogs/presentation/price_adjustment_controller.dart';
import 'package:catalogos/features/shared_catalogs/presentation/price_adjustment_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> _loadPoppins() async {
  final weights = <String, String>{
    '400': 'Poppins-Regular.ttf',
    '500': 'Poppins-Medium.ttf',
    '600': 'Poppins-SemiBold.ttf',
    '700': 'Poppins-Bold.ttf',
  };
  for (final entry in weights.entries) {
    final loader = FontLoader('Poppins');
    final bytes = File('assets/fonts/${entry.value}').readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

const String _catalogId = 'cat-1';

List<Product> _products(int count) => List<Product>.generate(
  count,
  (int i) => Product(
    id: 'p$i',
    nombre: <String>['Camiseta Básica Algodón', 'Chaqueta Deportiva', 'Bolso de Mano', 'Gorra Clásica'][i % 4],
    precios: <String, num>{
      '1': <num>[26000, 110500, 16900, 5800][i % 4],
    },
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

class _FakeOverlayRepo extends ResellerPriceRulesRepository {
  _FakeOverlayRepo() : super(Dio());

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
  }) async => Ok<PriceRulesProductsPage>(
    PriceRulesProductsPage(
      total: 24,
      page: 1,
      pageSize: 100,
      products: <CatalogPriceRuleProduct>[
        for (int i = 0; i < 4; i++)
          CatalogPriceRuleProduct(
            id: 'p$i',
            nombre: <String>['Camiseta Básica Algodón', 'Chaqueta Deportiva', 'Bolso de Mano', 'Gorra Clásica'][i],
            imagen: null,
            precioProveedor: <String, num>{'1': <num>[20000, 85000, 12999, 4449][i]},
            precioAjustado: <String, num>{'1': <num>[26000, 110500, 16900, 5800][i]},
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
          affectedProductIds: <String>['p0', 'p1', 'p2', 'p3'],
          productsWithOwnRule: <String>['x'],
        ),
      );
}

Widget _wrapCatalogDetail() {
  final detail = CatalogDetail(
    id: _catalogId,
    publicName: 'Colección Primavera',
    priceField: 'mayorista',
    products: _products(24),
  );
  final router = GoRouter(
    initialLocation: '/catalog/$_catalogId',
    routes: <RouteBase>[
      GoRoute(path: '/catalog/:id', builder: (context, _) => const CatalogDetailPage(catalogId: _catalogId)),
    ],
  );
  return ProviderScope(
    overrides: [
      catalogDetailControllerProvider(_catalogId).overrideWith(
        () => _FakeDetailController(CatalogDetailState(detail: detail)),
      ),
      resellerPriceRulesRepositoryProvider.overrideWithValue(_FakeOverlayRepo()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _wrapAdjust(PriceAdjustmentArgs args) {
  final router = GoRouter(
    initialLocation: '/catalog',
    routes: <RouteBase>[
      GoRoute(path: '/catalog', builder: (context, _) => const Text('catalog')),
      GoRoute(path: '/adjust', builder: (context, _) => PriceAdjustmentPage(args: args)),
    ],
  );
  router.push('/adjust');
  return ProviderScope(
    overrides: [resellerPriceRulesRepositoryProvider.overrideWithValue(_FakeOverlayRepo())],
    child: MaterialApp.router(routerConfig: router),
  );
}

const CatalogPriceRuleProduct _singleProduct = CatalogPriceRuleProduct(
  id: 'p0',
  nombre: 'Camiseta Básica Algodón',
  imagen: null,
  precioProveedor: <String, num>{'1': 20000},
  precioAjustado: <String, num>{'1': 28000},
  reglaOrigen: RuleOrigin.catalog,
);

/// Controlador de detalle que SIEMPRE falla, para capturar el estado de error
/// de "Productos del catálogo".
class _FailingDetailController extends CatalogDetailController {
  _FailingDetailController() : super(_catalogId);
  @override
  Future<CatalogDetailState> build() async => throw Exception('fallo de red');
  @override
  Future<void> refresh() async {}
}

Widget _wrapCatalogDetailError() {
  final router = GoRouter(
    initialLocation: '/catalog/$_catalogId',
    routes: <RouteBase>[
      GoRoute(path: '/catalog/:id', builder: (context, _) => const CatalogDetailPage(catalogId: _catalogId)),
    ],
  );
  return ProviderScope(
    overrides: [
      catalogDetailControllerProvider(_catalogId).overrideWith(_FailingDetailController.new),
      resellerPriceRulesRepositoryProvider.overrideWithValue(_FakeOverlayRepo()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Repositorio que falla al cargar: estado de error de "Ajustar precios".
class _FailingAdjustRepo extends ResellerPriceRulesRepository {
  _FailingAdjustRepo() : super(Dio());
  @override
  Future<Result<PriceRulesSummary>> getRulesSummary(String catalogId) async =>
      const Err<PriceRulesSummary>(ServerFailure(message: 'No pudimos cargar el ajuste de precios.'));
}

Widget _wrapAdjustError(PriceAdjustmentArgs args) {
  final router = GoRouter(
    initialLocation: '/catalog',
    routes: <RouteBase>[
      GoRoute(path: '/catalog', builder: (context, _) => const Text('catalog')),
      GoRoute(path: '/adjust', builder: (context, _) => PriceAdjustmentPage(args: args)),
    ],
  );
  router.push('/adjust');
  return ProviderScope(
    overrides: [resellerPriceRulesRepositoryProvider.overrideWithValue(_FailingAdjustRepo())],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  setUpAll(_loadPoppins);

  Future<void> capture(
    WidgetTester tester, {
    required Size size,
    required Widget widget,
    required Finder finder,
    required String goldenPath,
    void Function(WidgetTester tester)? afterPump,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    afterPump?.call(tester);
    await tester.pump();
    await expectLater(finder, matchesGoldenFile(goldenPath));
  }

  testWidgets('productos-a', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrapCatalogDetail());
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(CatalogDetailPage), matchesGoldenFile('../_visual_out/productos_a.png'));
  });

  testWidgets('productos-a-360x640', (WidgetTester tester) async {
    await capture(
      tester,
      size: const Size(360, 640),
      widget: _wrapCatalogDetail(),
      finder: find.byType(CatalogDetailPage),
      goldenPath: '../_visual_out/productos_a_360.png',
    );
  });

  testWidgets('productos-a-error', (WidgetTester tester) async {
    await capture(
      tester,
      size: const Size(390, 844),
      widget: _wrapCatalogDetailError(),
      finder: find.byType(CatalogDetailPage),
      goldenPath: '../_visual_out/productos_a_error.png',
    );
  });

  testWidgets('ajustar-1-porcentaje', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _wrapAdjust(const PriceAdjustmentArgs(catalogId: _catalogId, totalProductsHint: 24)),
    );
    await tester.pump();
    await tester.pump();
    final controller = ProviderScope.containerOf(
      tester.element(find.byType(PriceAdjustmentPage)),
    ).read(priceAdjustmentControllerProvider(const PriceAdjustmentArgs(catalogId: _catalogId, totalProductsHint: 24)).notifier);
    controller.onChipTap(30);
    await tester.pump();
    await expectLater(find.byType(PriceAdjustmentPage), matchesGoldenFile('../_visual_out/ajustar_1.png'));
  });

  testWidgets('ajustar-2-valorfijo', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const args = PriceAdjustmentArgs(catalogId: _catalogId, totalProductsHint: 24);
    await tester.pumpWidget(_wrapAdjust(args));
    await tester.pump();
    await tester.pump();
    final controller =
        ProviderScope.containerOf(tester.element(find.byType(PriceAdjustmentPage))).read(priceAdjustmentControllerProvider(args).notifier);
    controller.onModeChanged(PriceRuleMode.fixed);
    controller.onChipTap(5000);
    await tester.pump();
    await expectLater(find.byType(PriceAdjustmentPage), matchesGoldenFile('../_visual_out/ajustar_2.png'));
  });

  testWidgets('ajustar-3-producto', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const args = PriceAdjustmentArgs(catalogId: _catalogId, totalProductsHint: 24, singleProduct: _singleProduct);
    await tester.pumpWidget(_wrapAdjust(args));
    await tester.pump();
    await tester.pump();
    final controller = ProviderScope.containerOf(tester.element(find.byType(PriceAdjustmentPage))).read(priceAdjustmentControllerProvider(args).notifier);
    controller.onChipTap(40);
    await tester.pump();
    await expectLater(find.byType(PriceAdjustmentPage), matchesGoldenFile('../_visual_out/ajustar_3.png'));
  });

  testWidgets('ajustar-4-listo', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const args = PriceAdjustmentArgs(catalogId: _catalogId, totalProductsHint: 24);
    await tester.pumpWidget(_wrapAdjust(args));
    await tester.pump();
    await tester.pump();
    final controller = ProviderScope.containerOf(tester.element(find.byType(PriceAdjustmentPage))).read(priceAdjustmentControllerProvider(args).notifier);
    controller.onChipTap(30);
    await tester.pump();
    await controller.onSubmit();
    await tester.pump();
    // Avanza la animación de entrada (~450ms) para que el check ya esté
    // dibujado y las ondas estén en una posición intermedia visible.
    await tester.pump(const Duration(milliseconds: 700));
    await expectLater(find.byType(PriceAdjustmentPage), matchesGoldenFile('../_visual_out/ajustar_4.png'));
  });

  testWidgets('ajustar-1-porcentaje-360x640', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const args = PriceAdjustmentArgs(catalogId: _catalogId, totalProductsHint: 24);
    await tester.pumpWidget(_wrapAdjust(args));
    await tester.pump();
    await tester.pump();
    final controller = ProviderScope.containerOf(
      tester.element(find.byType(PriceAdjustmentPage)),
    ).read(priceAdjustmentControllerProvider(args).notifier);
    controller.onChipTap(30);
    await tester.pump();
    await expectLater(find.byType(PriceAdjustmentPage), matchesGoldenFile('../_visual_out/ajustar_1_360.png'));
  });

  testWidgets('ajustar-error', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const args = PriceAdjustmentArgs(catalogId: _catalogId, totalProductsHint: 24);
    await tester.pumpWidget(_wrapAdjustError(args));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await expectLater(find.byType(PriceAdjustmentPage), matchesGoldenFile('../_visual_out/ajustar_error.png'));
  });
}
