// Tests del CatalogDetailController (tareas 1.16/1.18).
//
// - Carga de productos → AsyncData con el detalle; la bandera "sin precios" se
//   expone correctamente.
// - Caché por id (tarea 1.18): una carga exitosa persiste el detalle bajo
//   `catalog_detail:<id>`; una apertura posterior con la red mockeada en fallo
//   devuelve el detalle cacheado (ruta offline, CA de 1.18).
//
// Directorio temporal de Hive (como test/core/storage) + Dio mockeado con
// http_mock_adapter. Sin red ni Firebase reales.

import 'dart:io';

import 'package:catalogos/core/network/error_interceptor.dart';
import 'package:catalogos/core/storage/local_cache.dart';
import 'package:catalogos/features/shared_catalogs/data/catalog_detail_repository.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_detail_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

const String _catalogId = 'cat-1';

Map<String, dynamic> _detailPayload({bool sinPrecios = false}) =>
    <String, dynamic>{
      'banner_url': 'https://cdn/banner.jpg',
      'provider_id': 42,
      'catalog': <String, dynamic>{
        'id': _catalogId,
        'publicName': 'Catálogo Público',
        'priceField': sinPrecios ? 'none' : 'mayorista',
      },
      'products': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'p1',
          'nombre': 'Camiseta',
          'imagenes': <String>['https://cdn/p1.jpg'],
          'colores': <String>['Rojo'],
          'tallas': <String>['M'],
          'precios': sinPrecios
              ? <String, dynamic>{'1': 0, '6': 0}
              : <String, dynamic>{'1': 20000, '6': 18000},
        },
      ],
    };

void main() {
  late Directory tempDir;
  late LocalCache cache;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('catalog_detail_ctrl');
    Hive.init(tempDir.path);
    cache = await initLocalCache(boxName: 'detail_box', initHive: false);
  });

  tearDown(() async {
    await cache.close();
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Dio buildDioOk({bool sinPrecios = false}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(const ErrorInterceptor());
    final adapter = DioAdapter(dio: dio);
    adapter.onGet(
      '/catalog/by-catalog/$_catalogId/products',
      (server) => server.reply(200, _detailPayload(sinPrecios: sinPrecios)),
    );
    return dio;
  }

  Dio buildDioFail() {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(const ErrorInterceptor());
    final adapter = DioAdapter(dio: dio);
    adapter.onGet(
      '/catalog/by-catalog/$_catalogId/products',
      (server) => server.throws(
        0,
        DioException(
          requestOptions:
              RequestOptions(path: '/catalog/by-catalog/$_catalogId/products'),
          type: DioExceptionType.connectionError,
        ),
      ),
    );
    return dio;
  }

  ProviderContainer buildContainer(Dio dio) {
    final c = ProviderContainer(
      overrides: [
        localCacheProvider.overrideWithValue(cache),
        catalogDetailRepositoryProvider
            .overrideWithValue(CatalogDetailRepository(dio)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('carga productos → AsyncData con el detalle', () async {
    final container = buildContainer(buildDioOk());

    final state = await container
        .read(catalogDetailControllerProvider(_catalogId).future);

    expect(state.detail.products, hasLength(1));
    expect(state.detail.products.first.nombre, 'Camiseta');
    expect(state.detail.priceHidden, isFalse);
    expect(state.fromCache, isFalse);
  });

  test('expone la bandera "sin precios" correctamente', () async {
    final container = buildContainer(buildDioOk(sinPrecios: true));

    final state = await container
        .read(catalogDetailControllerProvider(_catalogId).future);

    expect(state.detail.priceHidden, isTrue);
    // Cantidades preservadas pese a precios ocultos.
    expect(state.detail.products.first.cantidades, <String>['1', '6']);
  });

  test('una carga exitosa persiste el detalle en la caché por id (1.18)',
      () async {
    final container = buildContainer(buildDioOk());

    await container.read(catalogDetailControllerProvider(_catalogId).future);

    final raw = cache.get(catalogDetailCacheKey(_catalogId));
    expect(raw, isNotNull);
    expect(raw, contains('Camiseta'));
  });

  test(
      'con la red en fallo pero caché presente, devuelve el detalle cacheado '
      '(offline, CA de 1.18)', () async {
    // 1) Carga exitosa que llena la caché.
    final first = buildContainer(buildDioOk());
    await first.read(catalogDetailControllerProvider(_catalogId).future);
    first.dispose();

    // 2) Apertura posterior con la red mockeada en fallo. La caché ya existe.
    final offline = buildContainer(buildDioFail());

    final state = await offline
        .read(catalogDetailControllerProvider(_catalogId).future);

    expect(state.detail.products, hasLength(1),
        reason: 'debe venir de la caché offline');
    expect(state.detail.products.first.nombre, 'Camiseta');
    expect(state.fromCache, isTrue);
  });

  test('sin caché y con la red en fallo, propaga AsyncError', () async {
    final container = buildContainer(buildDioFail());

    await expectLater(
      container.read(catalogDetailControllerProvider(_catalogId).future),
      throwsA(anything),
    );
  });
}
