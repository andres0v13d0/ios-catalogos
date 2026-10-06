// Tests del ResellerPriceRulesRepository — backend de "Ajustar precios"
// (PASO 0: contrato verificado contra `reseller-price-rules.controller.ts`/
// `.service.ts` reales del backend). Mock de Dio con http_mock_adapter, sin
// red ni Firebase reales.

import 'package:catalogos/core/network/error_interceptor.dart';
import 'package:catalogos/core/result/failure.dart';
import 'package:catalogos/core/result/result.dart';
import 'package:catalogos/features/shared_catalogs/data/reseller_price_rules_repository.dart';
import 'package:catalogos/features/shared_catalogs/domain/price_rule_calculator.dart';
import 'package:catalogos/features/shared_catalogs/domain/price_rules_contract.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ResellerPriceRulesRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(const ErrorInterceptor());
    adapter = DioAdapter(dio: dio);
    repo = ResellerPriceRulesRepository(dio);
  });

  group('getCatalogProducts', () {
    test('parsea precioProveedor, precioAjustado y reglaOrigen', () async {
      adapter.onGet(
        '/reseller/app/catalogs/cat-1/products',
        (server) => server.reply(200, <String, dynamic>{
          'total': 2,
          'page': 1,
          'pageSize': 20,
          'products': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'p1',
              'nombre': 'Bolso',
              'imagen': 'https://cdn/p1.jpg',
              'precioProveedor': <String, dynamic>{'1': 12999},
              'precioAjustado': <String, dynamic>{'1': 16900},
              'reglaOrigen': 'catalog',
            },
            <String, dynamic>{
              'id': 'p2',
              'nombre': 'Gorra',
              'imagen': null,
              'precioProveedor': <String, dynamic>{'1': 4449},
              'precioAjustado': <String, dynamic>{'1': 4449},
              'reglaOrigen': null,
            },
          ],
        }),
        queryParameters: <String, dynamic>{'page': 1, 'pageSize': 20},
      );

      final result = await repo.getCatalogProducts('cat-1');

      expect(result, isA<Ok<PriceRulesProductsPage>>());
      final page = (result as Ok<PriceRulesProductsPage>).value;
      expect(page.total, 2);
      expect(page.products, hasLength(2));
      expect(page.products[0].precioProveedor, <String, num>{'1': 12999});
      expect(page.products[0].precioAjustado, <String, num>{'1': 16900});
      expect(page.products[0].reglaOrigen, RuleOrigin.catalog);
      expect(page.products[1].imagen, isNull);
      expect(page.products[1].reglaOrigen, isNull);
    });
  });

  group('getRulesSummary', () {
    test('parsea catalogRule y productRules', () async {
      adapter.onGet(
        '/reseller/app/catalogs/cat-1/price-rules',
        (server) => server.reply(200, <String, dynamic>{
          'catalogRule': <String, dynamic>{'mode': 'percent', 'value': 30},
          'productRules': <Map<String, dynamic>>[
            <String, dynamic>{
              'productId': 'p9',
              'rule': <String, dynamic>{'mode': 'fixed', 'value': 5000},
            },
          ],
        }),
      );

      final result = await repo.getRulesSummary('cat-1');

      expect(result, isA<Ok<PriceRulesSummary>>());
      final summary = (result as Ok<PriceRulesSummary>).value;
      expect(summary.catalogRule, const PriceRule(mode: PriceRuleMode.percent, value: 30));
      expect(
        summary.productRules['p9'],
        const PriceRule(mode: PriceRuleMode.fixed, value: 5000),
      );
    });

    test('catalogRule null cuando no hay regla de catálogo', () async {
      adapter.onGet(
        '/reseller/app/catalogs/cat-1/price-rules',
        (server) => server.reply(200, <String, dynamic>{
          'catalogRule': null,
          'productRules': <Map<String, dynamic>>[],
        }),
      );

      final result = await repo.getRulesSummary('cat-1');
      expect((result as Ok<PriceRulesSummary>).value.catalogRule, isNull);
    });
  });

  group('upsertCatalogRule', () {
    test('éxito: parsea rule/affectedProductIds/productsWithOwnRule', () async {
      adapter.onPut(
        '/reseller/app/catalogs/cat-1/price-rules',
        (server) => server.reply(200, <String, dynamic>{
          'rule': <String, dynamic>{'mode': 'percent', 'value': 30},
          'affectedProductIds': <String>['p1', 'p2'],
          'productsWithOwnRule': <String>['p9'],
        }),
        data: <String, dynamic>{'mode': 'percent', 'value': 30},
      );

      final result = await repo.upsertCatalogRule(
        'cat-1',
        const PriceRule(mode: PriceRuleMode.percent, value: 30),
      );

      expect(result, isA<Ok<SavedCatalogRuleResult>>());
      final value = (result as Ok<SavedCatalogRuleResult>).value;
      expect(value.affectedProductIds, <String>['p1', 'p2']);
      expect(value.productsWithOwnRule, <String>['p9']);
    });

    test('400 → ValidationFailure con el mensaje del backend', () async {
      adapter.onPut(
        '/reseller/app/catalogs/cat-1/price-rules',
        (server) => server.reply(400, <String, dynamic>{
          'message': 'El porcentaje debe estar entre 1 y 300',
        }),
        data: <String, dynamic>{'mode': 'percent', 'value': 301},
      );

      final result = await repo.upsertCatalogRule(
        'cat-1',
        const PriceRule(mode: PriceRuleMode.percent, value: 301),
      );

      expect(result, isA<Err<SavedCatalogRuleResult>>());
      final failure = (result as Err<SavedCatalogRuleResult>).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'El porcentaje debe estar entre 1 y 300');
    });

    test('403 → catálogo no disponible para este revendedor', () async {
      adapter.onPut(
        '/reseller/app/catalogs/cat-1/price-rules',
        (server) => server.reply(403, <String, dynamic>{'message': 'Forbidden'}),
        data: <String, dynamic>{'mode': 'percent', 'value': 30},
      );

      final result = await repo.upsertCatalogRule(
        'cat-1',
        const PriceRule(mode: PriceRuleMode.percent, value: 30),
      );

      final failure = (result as Err<SavedCatalogRuleResult>).failure;
      expect(failure.statusCode, 403);
      expect(failure.message, contains('no está disponible'));
    });

    test('409 → catálogo sin precios', () async {
      adapter.onPut(
        '/reseller/app/catalogs/cat-1/price-rules',
        (server) => server.reply(409, <String, dynamic>{'message': 'Conflict'}),
        data: <String, dynamic>{'mode': 'percent', 'value': 30},
      );

      final result = await repo.upsertCatalogRule(
        'cat-1',
        const PriceRule(mode: PriceRuleMode.percent, value: 30),
      );

      final failure = (result as Err<SavedCatalogRuleResult>).failure;
      expect(failure.statusCode, 409);
      expect(failure.message, contains('no muestra precios'));
    });

    test('sin conexión → NetworkFailure', () async {
      adapter.onPut(
        '/reseller/app/catalogs/cat-1/price-rules',
        (server) => server.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(path: '/reseller/app/catalogs/cat-1/price-rules'),
            reason: 'Failed host lookup',
          ),
        ),
        data: <String, dynamic>{'mode': 'percent', 'value': 30},
      );

      final result = await repo.upsertCatalogRule(
        'cat-1',
        const PriceRule(mode: PriceRuleMode.percent, value: 30),
      );

      expect((result as Err<SavedCatalogRuleResult>).failure, isA<NetworkFailure>());
    });
  });

  group('upsertProductRule', () {
    test('404 → producto ajeno al catálogo', () async {
      adapter.onPut(
        '/reseller/app/catalogs/cat-1/products/px/price-rule',
        (server) => server.reply(404, <String, dynamic>{'message': 'Not found'}),
        data: <String, dynamic>{'mode': 'fixed', 'value': 5000},
      );

      final result = await repo.upsertProductRule(
        'cat-1',
        'px',
        const PriceRule(mode: PriceRuleMode.fixed, value: 5000),
      );

      final failure = (result as Err<SavedProductRuleResult>).failure;
      expect(failure.statusCode, 404);
      expect(failure.message, contains('no pertenece a este catálogo'));
    });

    test('éxito: parsea rule y productId', () async {
      adapter.onPut(
        '/reseller/app/catalogs/cat-1/products/p1/price-rule',
        (server) => server.reply(200, <String, dynamic>{
          'rule': <String, dynamic>{'mode': 'fixed', 'value': 5000},
          'productId': 'p1',
        }),
        data: <String, dynamic>{'mode': 'fixed', 'value': 5000},
      );

      final result = await repo.upsertProductRule(
        'cat-1',
        'p1',
        const PriceRule(mode: PriceRuleMode.fixed, value: 5000),
      );

      expect((result as Ok<SavedProductRuleResult>).value.productId, 'p1');
    });
  });

  group('deleteCatalogRule / deleteProductRule', () {
    test('deleteCatalogRule éxito', () async {
      adapter.onDelete(
        '/reseller/app/catalogs/cat-1/price-rules',
        (server) => server.reply(200, <String, dynamic>{'deleted': true}),
      );

      final result = await repo.deleteCatalogRule('cat-1');
      expect(result, isA<Ok<void>>());
    });

    test('deleteProductRule 403 catálogo ajeno', () async {
      adapter.onDelete(
        '/reseller/app/catalogs/cat-1/products/p1/price-rule',
        (server) => server.reply(403, <String, dynamic>{'message': 'Forbidden'}),
      );

      final result = await repo.deleteProductRule('cat-1', 'p1');
      expect((result as Err<void>).failure.statusCode, 403);
    });
  });
}
