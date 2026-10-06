// Widget tests de PriceAdjustmentPage ("Ajustar precios", ver
// docs/design/ajustar-precios.html): modo catálogo completo y modo un solo
// producto, teclado propio, chips, vista previa en vivo, guardar, quitar
// (con confirmación) y el estado "Listo". Repositorio fake (sin Dio real).

import 'package:catalogos/core/result/failure.dart';
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

  PriceRulesSummary summary = const PriceRulesSummary(catalogRule: null, productRules: {});
  PriceRulesProductsPage page = const PriceRulesProductsPage(
    total: 2,
    page: 1,
    pageSize: 100,
    products: <CatalogPriceRuleProduct>[
      CatalogPriceRuleProduct(
        id: 'p1',
        nombre: 'Bolso de Mano',
        imagen: null,
        precioProveedor: <String, num>{'1': 12999},
        precioAjustado: <String, num>{'1': 12999},
        reglaOrigen: null,
      ),
      CatalogPriceRuleProduct(
        id: 'p2',
        nombre: 'Gorra Clásica',
        imagen: null,
        precioProveedor: <String, num>{'1': 4449},
        precioAjustado: <String, num>{'1': 4449},
        reglaOrigen: null,
      ),
    ],
  );

  SavedCatalogRuleResult? lastCatalogResult;
  Failure? deleteError;
  int deleteCatalogCalls = 0;
  int deleteProductCalls = 0;

  /// Permite forzar el resultado de `upsertCatalogRule` en un test puntual
  /// (p. ej. simular un 409 después de que el editor ya cargó).
  Future<Result<SavedCatalogRuleResult>> Function(PriceRule rule)? upsertCatalogRuleOverride;

  @override
  Future<Result<PriceRulesSummary>> getRulesSummary(String catalogId) async =>
      Ok<PriceRulesSummary>(summary);

  @override
  Future<Result<PriceRulesProductsPage>> getCatalogProducts(
    String catalogId, {
    int page = 1,
    int pageSize = 20,
  }) async => Ok<PriceRulesProductsPage>(this.page);

  @override
  Future<Result<SavedCatalogRuleResult>> upsertCatalogRule(String catalogId, PriceRule rule) async {
    if (upsertCatalogRuleOverride != null) return upsertCatalogRuleOverride!(rule);
    final result = SavedCatalogRuleResult(
      rule: rule,
      affectedProductIds: const <String>['p1', 'p2'],
      productsWithOwnRule: const <String>[],
    );
    lastCatalogResult = result;
    return Ok<SavedCatalogRuleResult>(result);
  }

  @override
  Future<Result<void>> deleteCatalogRule(String catalogId) async {
    deleteCatalogCalls++;
    if (deleteError != null) return Err<void>(deleteError!);
    return const Ok<void>(null);
  }

  @override
  Future<Result<SavedProductRuleResult>> upsertProductRule(
    String catalogId,
    String productId,
    PriceRule rule,
  ) async => Ok<SavedProductRuleResult>(SavedProductRuleResult(rule: rule, productId: productId));

  @override
  Future<Result<void>> deleteProductRule(String catalogId, String productId) async {
    deleteProductCalls++;
    return const Ok<void>(null);
  }
}

const PriceAdjustmentArgs _catalogArgs = PriceAdjustmentArgs(catalogId: 'cat-1', totalProductsHint: 2);

const CatalogPriceRuleProduct _singleProduct = CatalogPriceRuleProduct(
  id: 'p9',
  nombre: 'Camiseta Básica Algodón',
  imagen: null,
  precioProveedor: <String, num>{'1': 20000},
  precioAjustado: <String, num>{'1': 20000},
  reglaOrigen: null,
);

/// El router registra una ruta previa ('/catalog') y EMPUJA (`push`, no
/// `go`) la de "Ajustar precios": así `Navigator.pop()` dentro de la página
/// (vuelve a `/catalog`) tiene a dónde ir — igual que en la app real, donde
/// siempre se llega aquí con `context.push(...)` desde `CatalogDetailPage`.
/// Sin esto, un `pop()` en un stack de una sola ruta es un no-op silencioso
/// y el spinner transitorio de "Removido" quedaría montado para siempre
/// (cuelga `pumpAndSettle`).
GoRouter _buildRouter(_FakeRepo repo, PriceAdjustmentArgs args) {
  return GoRouter(
    initialLocation: '/catalog',
    routes: <RouteBase>[
      GoRoute(path: '/catalog', builder: (context, _) => const Text('catalog')),
      GoRoute(
        path: '/adjust',
        builder: (context, _) => PriceAdjustmentPage(args: args),
      ),
    ],
  );
}

Widget _wrap(GoRouter router, _FakeRepo repo) {
  return ProviderScope(
    overrides: [resellerPriceRulesRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Pantalla móvil normal (390x844 lógicos): a 800x600 (tamaño por defecto de
/// `flutter_test`) el editor compacta el subtítulo (ver `compact` en
/// `_EditorBody`), lo que no refleja un dispositivo real.
///
/// Monta una ruta previa ('/catalog') y EMPUJA "Ajustar precios" sobre ella
/// (ver [_buildRouter]), para que `Navigator.pop()` dentro de la página
/// tenga a dónde volver.
Future<GoRouter> _pumpAdjustPage(
  WidgetTester tester,
  _FakeRepo repo,
  PriceAdjustmentArgs args,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = _buildRouter(repo, args);
  await tester.pumpWidget(_wrap(router, repo));
  router.push('/adjust');
  await tester.pump();
  await tester.pump();
  return router;
}

/// Tecla de dígito del teclado propio (desambigua del número grande, que
/// también puede mostrar "0").
Finder _digitKey(String digit) => find.byKey(ValueKey<String>('price_keypad_digit_$digit'));

void main() {
  group('modo catálogo completo', () {
    testWidgets('muestra pestañas, vista previa y botón "Aplicar a N productos"', (
      WidgetTester tester,
    ) async {
      await _pumpAdjustPage(tester, _FakeRepo(), _catalogArgs);

      expect(find.text('Ajustar precios'), findsOneWidget);
      expect(find.text('Catálogo completo · 2 productos'), findsOneWidget);
      expect(find.text('Porcentaje'), findsOneWidget);
      expect(find.text('Valor fijo'), findsOneWidget);
      expect(find.text('Bolso de Mano'), findsOneWidget); // vista previa: primer producto
      expect(find.text('Aplicar a 2 productos'), findsOneWidget);
      expect(find.text('Quitar'), findsNothing); // sin regla existente: no se dibuja
    });

    testWidgets('teclado propio: dígitos arman el valor y habilitan el botón', (
      WidgetTester tester,
    ) async {
      await _pumpAdjustPage(tester, _FakeRepo(), _catalogArgs);

      await tester.tap(_digitKey('3'));
      await tester.pump();
      await tester.tap(_digitKey('0'));
      await tester.pump();

      expect(find.text('30'), findsOneWidget);
      // Proveedor 12999 (vista previa inicial) + 30% → 16900.
      expect(find.textContaining('16.900'), findsOneWidget);
    });

    testWidgets('chip rellena el valor y "Cambiar" rota la vista previa', (
      WidgetTester tester,
    ) async {
      await _pumpAdjustPage(tester, _FakeRepo(), _catalogArgs);

      await tester.tap(find.text('30%'));
      await tester.pump();
      expect(find.text('30'), findsOneWidget);

      await tester.tap(find.text('Cambiar'));
      await tester.pump();
      expect(find.text('Gorra Clásica'), findsOneWidget);
    });

    testWidgets('Valor fijo: pestaña limpia el número y "000" solo aparece ahí', (
      WidgetTester tester,
    ) async {
      await _pumpAdjustPage(tester, _FakeRepo(), _catalogArgs);

      await tester.tap(find.text('30%'));
      await tester.pump();
      await tester.tap(find.text('Valor fijo'));
      await tester.pump();

      expect(find.text('30'), findsNothing); // se limpió al cambiar de pestaña
      expect(find.text('000'), findsOneWidget);
    });

    testWidgets('guardar llama a upsertCatalogRule y muestra el estado "Listo"', (
      WidgetTester tester,
    ) async {
      final repo = _FakeRepo();
      await _pumpAdjustPage(tester, repo, _catalogArgs);

      await tester.tap(find.text('30%'));
      await tester.pump();
      await tester.tap(find.text('Aplicar a 2 productos'));
      // El estado "Listo" tiene ondas en BUCLE (`repeat()`), así que
      // `pumpAndSettle` nunca asienta: se avanza un tiempo acotado para que
      // resuelva el guardado y se dibuje la pantalla de éxito.
      await tester.pump(); // resuelve el future de guardado
      await tester.pump(const Duration(milliseconds: 700)); // entrada del check

      expect(repo.lastCatalogResult?.rule, const PriceRule(mode: PriceRuleMode.percent, value: 30));
      expect(find.text('Precios actualizados'), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // productos afectados
    });

    testWidgets('"Quitar" pide confirmación antes de borrar la regla', (
      WidgetTester tester,
    ) async {
      final repo = _FakeRepo();
      repo.summary = const PriceRulesSummary(
        catalogRule: PriceRule(mode: PriceRuleMode.percent, value: 30),
        productRules: {},
      );
      await _pumpAdjustPage(tester, repo, _catalogArgs);

      expect(find.text('Quitar'), findsOneWidget);
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Quitar el ajuste de precio?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(repo.deleteCatalogCalls, 0);

      await tester.tap(find.text('Quitar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar').last);
      await tester.pumpAndSettle();

      expect(repo.deleteCatalogCalls, 1);
    });
  });

  group('modo un solo producto', () {
    const PriceAdjustmentArgs args = PriceAdjustmentArgs(
      catalogId: 'cat-1',
      totalProductsHint: 2,
      singleProduct: _singleProduct,
    );

    testWidgets('cabecera "Solo este producto" y botón "Guardar para este producto"', (
      WidgetTester tester,
    ) async {
      await _pumpAdjustPage(tester, _FakeRepo(), args);

      expect(find.text('Solo este producto'), findsOneWidget);
      expect(find.text('Camiseta Básica Algodón'), findsOneWidget);
      expect(find.text('Guardar para este producto'), findsOneWidget);
    });

    testWidgets('"Usar el ajuste del catálogo" borra la regla propia sin confirmación', (
      WidgetTester tester,
    ) async {
      final repo = _FakeRepo();
      repo.summary = const PriceRulesSummary(
        catalogRule: PriceRule(mode: PriceRuleMode.percent, value: 30),
        productRules: {'p9': PriceRule(mode: PriceRuleMode.fixed, value: 5000)},
      );
      await _pumpAdjustPage(tester, repo, args);

      expect(find.textContaining('Usar el ajuste del catálogo'), findsOneWidget);
      await tester.tap(find.text('Usar'));
      await tester.pumpAndSettle();

      expect(repo.deleteProductCalls, 1);
      expect(repo.deleteCatalogCalls, 0);
    });
  });

  group('errores', () {
    testWidgets('error del backend (409) se muestra y conserva el borrador', (
      WidgetTester tester,
    ) async {
      final repo = _FakeRepo();
      await _pumpAdjustPage(tester, repo, _catalogArgs);

      await tester.tap(find.text('30%'));
      await tester.pump();

      // Simula un fallo en el guardado sobreescribiendo el método tras el build.
      repo.upsertCatalogRuleOverride = (rule) async =>
          const Err<SavedCatalogRuleResult>(ServerFailure(message: 'Conflicto', statusCode: 409));

      await tester.tap(find.text('Aplicar a 2 productos'));
      await tester.pumpAndSettle();

      expect(find.text('Conflicto'), findsOneWidget);
      expect(find.text('30'), findsOneWidget); // el borrador no se pierde
    });
  });
}
