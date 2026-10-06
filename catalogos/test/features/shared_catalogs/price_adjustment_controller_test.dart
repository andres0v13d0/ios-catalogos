// Tests de PriceAdjustmentController: carga, teclado propio (límites,
// "000", backspace/clear), chips, rotación de vista previa, guardar y
// quitar (catálogo completo y un solo producto). Repositorio fake vía
// ProviderContainer override (sin Dio real).

import 'package:catalogos/core/result/failure.dart';
import 'package:catalogos/core/result/result.dart';
import 'package:catalogos/features/shared_catalogs/data/reseller_price_rules_repository.dart';
import 'package:catalogos/features/shared_catalogs/domain/price_rule_calculator.dart';
import 'package:catalogos/features/shared_catalogs/domain/price_rules_contract.dart';
import 'package:catalogos/features/shared_catalogs/presentation/price_adjustment_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepo extends ResellerPriceRulesRepository {
  _FakeRepo() : super(Dio());

  PriceRulesSummary summary = const PriceRulesSummary(catalogRule: null, productRules: {});
  PriceRulesProductsPage page = const PriceRulesProductsPage(
    total: 1,
    page: 1,
    pageSize: 100,
    products: <CatalogPriceRuleProduct>[
      CatalogPriceRuleProduct(
        id: 'p1',
        nombre: 'Bolso',
        imagen: null,
        precioProveedor: <String, num>{'1': 20000},
        precioAjustado: <String, num>{'1': 20000},
        reglaOrigen: null,
      ),
    ],
  );

  Failure? summaryError;
  Failure? upsertCatalogError;
  Failure? upsertProductError;
  Failure? deleteError;

  int upsertCatalogCalls = 0;
  int deleteCatalogCalls = 0;
  int deleteProductCalls = 0;
  String? lastDeleteProductId;

  @override
  Future<Result<PriceRulesSummary>> getRulesSummary(String catalogId) async {
    if (summaryError != null) return Err<PriceRulesSummary>(summaryError!);
    return Ok<PriceRulesSummary>(summary);
  }

  @override
  Future<Result<PriceRulesProductsPage>> getCatalogProducts(
    String catalogId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    return Ok<PriceRulesProductsPage>(this.page);
  }

  @override
  Future<Result<SavedCatalogRuleResult>> upsertCatalogRule(String catalogId, PriceRule rule) async {
    upsertCatalogCalls++;
    if (upsertCatalogError != null) return Err<SavedCatalogRuleResult>(upsertCatalogError!);
    return Ok<SavedCatalogRuleResult>(
      SavedCatalogRuleResult(
        rule: rule,
        affectedProductIds: const <String>['p1'],
        productsWithOwnRule: const <String>[],
      ),
    );
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
  ) async {
    if (upsertProductError != null) return Err<SavedProductRuleResult>(upsertProductError!);
    return Ok<SavedProductRuleResult>(SavedProductRuleResult(rule: rule, productId: productId));
  }

  @override
  Future<Result<void>> deleteProductRule(String catalogId, String productId) async {
    deleteProductCalls++;
    lastDeleteProductId = productId;
    if (deleteError != null) return Err<void>(deleteError!);
    return const Ok<void>(null);
  }
}

const CatalogPriceRuleProduct _singleProduct = CatalogPriceRuleProduct(
  id: 'p9',
  nombre: 'Camiseta',
  imagen: null,
  precioProveedor: <String, num>{'1': 12999},
  precioAjustado: <String, num>{'1': 12999},
  reglaOrigen: null,
);

void main() {
  late _FakeRepo repo;
  late ProviderContainer container;

  setUp(() {
    repo = _FakeRepo();
    container = ProviderContainer(
      overrides: [resellerPriceRulesRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  Future<PriceAdjustmentReady> readReady(PriceAdjustmentArgs args) async {
    container.read(priceAdjustmentControllerProvider(args));
    while (container.read(priceAdjustmentControllerProvider(args)) is PriceAdjustmentLoading) {
      await Future<void>.delayed(Duration.zero);
    }
    return container.read(priceAdjustmentControllerProvider(args)) as PriceAdjustmentReady;
  }

  group('carga inicial', () {
    test('modo catálogo: usa page.total y precarga el modo/valor de la regla existente', () async {
      repo.summary = const PriceRulesSummary(
        catalogRule: PriceRule(mode: PriceRuleMode.fixed, value: 5000),
        productRules: {},
      );
      const args = PriceAdjustmentArgs(catalogId: 'cat-1', totalProductsHint: 999);

      final ready = await readReady(args);

      expect(ready.totalProducts, 1); // del page.total del fake, no del hint
      expect(ready.mode, PriceRuleMode.fixed);
      expect(ready.rawDigits, '5000');
      expect(ready.hasOwnRule, isTrue);
    });

    test('modo un solo producto: usa el producto pasado, sin pedirlo a la red', () async {
      const args = PriceAdjustmentArgs(
        catalogId: 'cat-1',
        totalProductsHint: 24,
        singleProduct: _singleProduct,
      );

      final ready = await readReady(args);

      expect(ready.previewProducts, <CatalogPriceRuleProduct>[_singleProduct]);
      expect(ready.totalProducts, 24);
      expect(ready.hasOwnRule, isFalse);
    });

    test('error de red al cargar → LoadError', () async {
      repo.summaryError = const NetworkFailure();
      const args = PriceAdjustmentArgs(catalogId: 'cat-1', totalProductsHint: 1);

      container.read(priceAdjustmentControllerProvider(args));
      while (container.read(priceAdjustmentControllerProvider(args)) is PriceAdjustmentLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(container.read(priceAdjustmentControllerProvider(args)), isA<PriceAdjustmentLoadError>());
    });
  });

  group('teclado y validación', () {
    const args = PriceAdjustmentArgs(catalogId: 'cat-1', totalProductsHint: 1);
    late PriceAdjustmentController controller;

    setUp(() async {
      await readReady(args);
      controller = container.read(priceAdjustmentControllerProvider(args).notifier);
    });

    PriceAdjustmentReady ready() => container.read(priceAdjustmentControllerProvider(args)) as PriceAdjustmentReady;

    test('porcentaje: no deja escribir más allá de 300', () {
      controller.onDigit('3');
      controller.onDigit('0');
      controller.onDigit('1'); // 301 > 300 → se ignora
      expect(ready().rawDigits, '30');
    });

    test('porcentaje: botón deshabilitado en 0 o vacío', () {
      expect(ready().canSubmit, isFalse);
      controller.onDigit('0');
      expect(ready().canSubmit, isFalse);
      controller.onBackspace();
      controller.onDigit('5');
      expect(ready().canSubmit, isTrue);
    });

    test('cambiar de pestaña limpia el número', () {
      controller.onDigit('5');
      controller.onModeChanged(PriceRuleMode.fixed);
      expect(ready().rawDigits, '');
      expect(ready().mode, PriceRuleMode.fixed);
    });

    test('"000" solo agrega en modo fijo y respeta el tope', () {
      controller.onAppendZeros(); // vacío → no hace nada
      expect(ready().rawDigits, '');

      controller.onModeChanged(PriceRuleMode.fixed);
      controller.onDigit('5');
      controller.onAppendZeros();
      expect(ready().rawDigits, '5000');
    });

    test('chip rellena el valor directamente', () {
      controller.onChipTap(30);
      expect(ready().rawDigits, '30');
    });

    test('clear borra todo', () {
      controller.onDigit('9');
      controller.onDigit('9');
      controller.onClear();
      expect(ready().rawDigits, '');
    });

    test('vista previa en vivo calcula con applyPriceRule', () {
      controller.onChipTap(30);
      // Producto fake: 20000 proveedor, +30% → 26000.
      expect(ready().previewAdjustedPrice, 26000);
    });
  });

  group('guardar y quitar — modo catálogo', () {
    const args = PriceAdjustmentArgs(catalogId: 'cat-1', totalProductsHint: 1);

    test('onSubmit éxito → PriceAdjustmentSavedCatalog', () async {
      await readReady(args);
      final controller = container.read(priceAdjustmentControllerProvider(args).notifier);
      controller.onChipTap(30);

      final ok = await controller.onSubmit();

      expect(ok, isTrue);
      expect(container.read(priceAdjustmentControllerProvider(args)), isA<PriceAdjustmentSavedCatalog>());
      expect(repo.upsertCatalogCalls, 1);
    });

    test('onSubmit 409 → vuelve a Ready con actionError, sin perder el borrador', () async {
      repo.upsertCatalogError = const ServerFailure(
        message: 'Este catálogo no muestra precios.',
        statusCode: 409,
      );
      await readReady(args);
      final controller = container.read(priceAdjustmentControllerProvider(args).notifier);
      controller.onChipTap(30);

      final ok = await controller.onSubmit();

      expect(ok, isFalse);
      final ready = container.read(priceAdjustmentControllerProvider(args)) as PriceAdjustmentReady;
      expect(ready.actionError?.statusCode, 409);
      expect(ready.rawDigits, '30'); // el borrador no se pierde
      expect(ready.saving, isFalse);
    });

    test('onRemove éxito → PriceAdjustmentRemoved, borra solo la de catálogo', () async {
      await readReady(args);
      final controller = container.read(priceAdjustmentControllerProvider(args).notifier);

      final ok = await controller.onRemove();

      expect(ok, isTrue);
      expect(container.read(priceAdjustmentControllerProvider(args)), isA<PriceAdjustmentRemoved>());
      expect(repo.deleteCatalogCalls, 1);
      expect(repo.deleteProductCalls, 0);
    });
  });

  group('guardar y quitar — modo un solo producto', () {
    const args = PriceAdjustmentArgs(
      catalogId: 'cat-1',
      totalProductsHint: 1,
      singleProduct: _singleProduct,
    );

    test('onSubmit llama upsertProductRule con el id del producto', () async {
      await readReady(args);
      final controller = container.read(priceAdjustmentControllerProvider(args).notifier);
      controller.onChipTap(40);

      final ok = await controller.onSubmit();

      expect(ok, isTrue);
      final saved = container.read(priceAdjustmentControllerProvider(args)) as PriceAdjustmentSavedProduct;
      expect(saved.result.productId, 'p9');
    });

    test('onUseCatalogRule borra la regla propia del producto (no la de catálogo)', () async {
      await readReady(args);
      final controller = container.read(priceAdjustmentControllerProvider(args).notifier);

      final ok = await controller.onUseCatalogRule();

      expect(ok, isTrue);
      expect(repo.deleteProductCalls, 1);
      expect(repo.lastDeleteProductId, 'p9');
      expect(repo.deleteCatalogCalls, 0);
    });
  });
}
