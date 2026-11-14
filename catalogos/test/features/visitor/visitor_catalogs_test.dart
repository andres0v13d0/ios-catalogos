import 'dart:convert';

import 'package:catalogos/core/storage/storage.dart';
import 'package:catalogos/features/visitor/visitor_catalogs.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../helpers/memory_cache.dart';

void main() {
  _sharedTests();
  group('parseCatalogCode', () {
    test(
      'código suelto',
      () => expect(parseCatalogCode('aB3dE5fG7hJk'), 'aB3dE5fG7hJk'),
    );
    test('enlace flystock', () {
      expect(
        parseCatalogCode('https://acme.flystock.com.co/aB3dE5fG/'),
        'aB3dE5fG',
      );
    });
    test('enlace api', () {
      expect(
        parseCatalogCode('https://api.minymol.com/catalog/short/57e0dffb'),
        '57e0dffb',
      );
    });
    test('inválidos', () {
      expect(parseCatalogCode(''), isNull);
      expect(parseCatalogCode('corto'), isNull);
    });
  });

  test('VisitorProduct: precio por umbral y desde', () {
    final VisitorProduct p = VisitorProduct.fromJson(<String, dynamic>{
      'id': 'p1',
      'nombre': ' Camisa ',
      'precios': <String, dynamic>{'6': 33000, '12': 30000, '3': 0},
      'colores': <String>['Rojo', ' ', 'Rojo'],
    });
    expect(p.name, 'Camisa');
    expect(p.priceFrom, 30000);
    expect(p.priceFor(6), 33000);
    expect(p.priceFor(20), 30000);
    expect(p.colors, <String>['Rojo']);
  });
}

void _sharedTests() {
  group('catálogos compartidos por proveedor (revendedor)', () {
    const String id = '11111111-1111-4111-8111-111111111111';

    test('la página y los previews salen del endpoint del revendedor (precio proveedor)', () async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final DioAdapter adapter = DioAdapter(dio: dio);
      adapter.onGet(
        '/reseller/app/catalogs/$id/page',
        (s) => s.reply(200, <String, dynamic>{
          'catalog': <String, dynamic>{'id': id, 'publicName': 'Mayorista'},
          'productIds': <String>['p1'],
          'newProductIds': <String>[],
          'nombre_empresa': 'Proveedor SA',
        }),
      );
      adapter.onPost(
        '/reseller/app/catalogs/$id/previews',
        (s) => s.reply(200, <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'p1',
            'nombre': 'Blusa',
            'precios': <String, dynamic>{'1': 20000},
          },
        ]),
        data: <String, dynamic>{
          'ids': <String>['p1'],
        },
      );
      final VisitorCatalogApi api = VisitorCatalogApi(
        dio,
        isReseller: (String x) => x == id,
      );
      final CatalogPage page = await api.fetchPage(id);
      expect(page.catalog.catalogId, id);
      expect(page.catalog.providerName, 'Proveedor SA');
      final List<VisitorProduct> p = await api.previews(page.ids, id);
      expect(p.single.priceFrom, 20000);
    });

    test('Comprar junta compartidos y guardados sin repetir', () {
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          localCacheProvider.overrideWithValue(
            MemoryCache()..put(
              'visitor_catalogs',
              jsonEncode(<Map<String, dynamic>>[
                const VisitorCatalog(
                  shortUuid: 'ab12cd34',
                  catalogId: 'otro',
                  name: 'Guardado',
                ).toJson(),
                const VisitorCatalog(
                  shortUuid: 'zzzzzzzz',
                  catalogId: id,
                  name: 'Repetido',
                ).toJson(),
              ]),
            ),
          ),
          sharedBuyCatalogsProvider.overrideWithValue(<VisitorCatalog>[
            const VisitorCatalog(
              shortUuid: id,
              catalogId: id,
              name: 'Compartido',
            ),
          ]),
        ],
      );
      addTearDown(c.dispose);
      expect(
        c.read(buyCatalogsProvider).map((VisitorCatalog x) => x.name).toList(),
        <String>['Compartido', 'Guardado'],
      );
    });
  });
}
