import 'dart:convert';

import 'package:catalogos/core/storage/storage.dart';
import 'package:catalogos/features/auth/presentation/auth_state_provider.dart';
import 'package:catalogos/features/visitor/catalog_access.dart';
import 'package:catalogos/features/visitor/visitor_catalogs.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import '../../helpers/memory_cache.dart';

void main() {
  _sharedTests();
  _librarySyncTests();
  _publicAccessTests();
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
      final List<VisitorProduct> p = await api.previews(
        page.ids,
        id,
        shared: true,
      );
      expect(p.single.priceFrom, 20000);
    });

    test('Comprar muestra aparte el enlace propio guardado (mismo catálogo, otro código)', () {
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
                  name: 'Mi enlace',
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
        <String>['Compartido', 'Guardado', 'Mi enlace'],
      );
    });
  });
}

void _librarySyncTests() {
  group('biblioteca en la cuenta', () {
    const String local = 'aaaaaaaa-1111-4111-8111-111111111111';
    const String remote = 'bbbbbbbb-2222-4222-8222-222222222222';

    ProviderContainer build(Dio dio, {required bool signedIn}) {
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          localCacheProvider.overrideWithValue(
            MemoryCache()..put(
              'visitor_catalogs',
              jsonEncode(<Map<String, dynamic>>[
                const VisitorCatalog(
                  shortUuid: 'aaaaaaaa',
                  catalogId: local,
                  name: 'Local',
                  providerName: 'P',
                  phone: '1',
                ).toJson(),
              ]),
            ),
          ),
          isSignedInProvider.overrideWithValue(signedIn),
          visitorCatalogApiProvider.overrideWithValue(VisitorCatalogApi(dio)),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'con sesión sube lo local y trae lo que solo estaba en la cuenta',
      () async {
        final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
        final DioAdapter adapter = DioAdapter(dio: dio);
        adapter.onPost(
          '/reseller/app/library/sync',
          (s) => s.reply(200, <Map<String, dynamic>>[
            <String, dynamic>{'shortUuid': 'aaaaaaaa', 'catalogId': local},
            <String, dynamic>{'shortUuid': 'bbbbbbbb', 'catalogId': remote},
          ]),
          data: Matchers.any,
        );
        adapter.onGet(
          '/catalog/short/bbbbbbbb',
          (s) => s.reply(200, <String, dynamic>{
            'catalog': <String, dynamic>{
              'id': remote,
              'publicName': 'De la nube',
            },
            'nombre_empresa': 'Otro',
          }),
        );
        final ProviderContainer c = build(dio, signedIn: true);
        c.read(visitorCatalogsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          c.read(visitorCatalogsProvider).map((VisitorCatalog x) => x.name),
          <String>['Local', 'De la nube'],
        );
      },
    );

    test('sin sesión no llama a la cuenta', () async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      DioAdapter(dio: dio); // cualquier llamada sin ruta fallaría
      final ProviderContainer c = build(dio, signedIn: false);
      await c.read(visitorCatalogsProvider.notifier).syncWithCloud();
      expect(c.read(visitorCatalogsProvider).single.name, 'Local');
    });

    test('quitar con sesión también lo quita de la cuenta', () async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      final DioAdapter adapter = DioAdapter(dio: dio);
      adapter.onPost(
        '/reseller/app/library/sync',
        (s) => s.reply(200, <Map<String, dynamic>>[
          <String, dynamic>{'shortUuid': 'aaaaaaaa', 'catalogId': local},
        ]),
        data: Matchers.any,
      );
      bool deleted = false;
      adapter.onDelete('/reseller/app/library/$local', (s) {
        deleted = true;
        return s.reply(204, null);
      });
      final ProviderContainer c = build(dio, signedIn: true);
      await c.read(visitorCatalogsProvider.notifier).remove('aaaaaaaa');
      expect(c.read(visitorCatalogsProvider), isEmpty);
      expect(deleted, isTrue);
    });
  });
}

void _publicAccessTests() {
  group('acceso sin sesión', () {
    const String pub = 'cccccccc-3333-4333-8333-333333333333';
    const String priv = 'dddddddd-4444-4444-8444-444444444444';

    Future<CatalogAccess> access(String id, String mode) async {
      final Dio dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      DioAdapter(dio: dio).onGet(
        '/catalog-access/$id',
        (s) => s.reply(200, <String, dynamic>{'mode': mode}),
      );
      final ProviderContainer c = ProviderContainer(
        overrides: <Override>[
          isSignedInProvider.overrideWithValue(false),
          visitorCatalogApiProvider.overrideWithValue(VisitorCatalogApi(dio)),
        ],
      );
      addTearDown(c.dispose);
      return c.read(catalogAccessProvider(id).future);
    }

    test('catálogo público: ve precios', () async {
      expect(await access(pub, 'public'), CatalogAccess.approved);
    });
    test('con sesión u aprobación: pide iniciar sesión', () async {
      expect(await access(priv, 'open'), CatalogAccess.loginRequired);
      expect(await access(priv, 'approval'), CatalogAccess.loginRequired);
    });
  });
}
