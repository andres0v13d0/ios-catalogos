// Tests del SharedCatalogsController (tareas 1.14/1.15).
//
// - Tras el sync, la lista queda poblada (AsyncData con los catálogos).
// - Caché Hive: una carga exitosa persiste la lista; una carga posterior con la
//   red mockeada en fallo sigue devolviendo la lista cacheada (ruta offline).
//
// Se usa un directorio temporal de Hive (como test/core/storage) y un Dio
// mockeado con http_mock_adapter. Sin red ni Firebase reales.

import 'dart:io';

import 'package:catalogos/core/network/error_interceptor.dart';
import 'package:catalogos/core/storage/local_cache.dart';
import 'package:catalogos/features/shared_catalogs/data/shared_catalogs_repository.dart';
import 'package:catalogos/features/shared_catalogs/presentation/shared_catalogs_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Directory tempDir;
  late LocalCache cache;
  late Dio dio;
  late DioAdapter adapter;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('shared_catalogs_ctrl');
    Hive.init(tempDir.path);
    cache = await initLocalCache(boxName: 'ctrl_box', initHive: false);

    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(const ErrorInterceptor());
    adapter = DioAdapter(dio: dio);
  });

  tearDown(() async {
    await cache.close();
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  ProviderContainer buildContainer() {
    final c = ProviderContainer(
      overrides: [
        localCacheProvider.overrideWithValue(cache),
        sharedCatalogsRepositoryProvider
            .overrideWithValue(SharedCatalogsRepository(dio)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  void stubSyncOk() {
    adapter.onPost(
      '/reseller/sync-shared-catalogs',
      (server) => server.reply(200, <String, dynamic>{
        'linked': 1,
        'catalogs': <Map<String, dynamic>>[],
      }),
      data: <String, dynamic>{},
    );
  }

  void stubListOk() {
    adapter.onGet(
      '/reseller/me/shared-catalogs',
      (server) => server.reply(200, <String, dynamic>{
        'catalogs': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 1,
            'catalogId': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            'providerId': 10,
            'catalog': <String, dynamic>{
              'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
              'publicName': 'Alfa',
            },
            'provider': <String, dynamic>{
              'id': 10,
              'nombreEmpresa': 'Proveedor A',
            },
          },
          <String, dynamic>{
            'id': 2,
            'catalogId': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
            'providerId': 20,
            'catalog': <String, dynamic>{
              'id': 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
              'publicName': 'Beta',
            },
            'provider': <String, dynamic>{
              'id': 20,
              'nombreEmpresa': 'Proveedor B',
            },
          },
        ],
      }),
    );
  }

  test('tras el sync, la lista queda poblada (AsyncData)', () async {
    stubSyncOk();
    stubListOk();
    final container = buildContainer();

    final state =
        await container.read(sharedCatalogsControllerProvider.future);

    expect(state.catalogs, hasLength(2));
    expect(state.catalogs.map((c) => c.displayName), <String>['Alfa', 'Beta']);
    expect(state.fromCache, isFalse);
    expect(state.linked, 1);
  });

  test('una carga exitosa persiste la lista en la caché Hive', () async {
    stubSyncOk();
    stubListOk();
    final container = buildContainer();

    await container.read(sharedCatalogsControllerProvider.future);

    final raw = cache.get(kSharedCatalogsCacheKey);
    expect(raw, isNotNull);
    expect(raw, contains('Alfa'));
    expect(raw, contains('Beta'));
  });

  test('con red en fallo pero caché presente, devuelve la lista cacheada',
      () async {
    // 1) Primera carga exitosa que llena la caché.
    stubSyncOk();
    stubListOk();
    final first = buildContainer();
    await first.read(sharedCatalogsControllerProvider.future);
    first.dispose();

    // 2) Segunda carga con la red en fallo (sync falla). La caché ya existe.
    final failDio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    failDio.interceptors.add(const ErrorInterceptor());
    final failAdapter = DioAdapter(dio: failDio);
    failAdapter.onPost(
      '/reseller/sync-shared-catalogs',
      (server) => server.throws(
        0,
        DioException(
          requestOptions:
              RequestOptions(path: '/reseller/sync-shared-catalogs'),
          type: DioExceptionType.connectionError,
        ),
      ),
      data: <String, dynamic>{},
    );

    final offline = ProviderContainer(
      overrides: [
        localCacheProvider.overrideWithValue(cache),
        sharedCatalogsRepositoryProvider
            .overrideWithValue(SharedCatalogsRepository(failDio)),
      ],
    );
    addTearDown(offline.dispose);

    final state =
        await offline.read(sharedCatalogsControllerProvider.future);

    expect(state.catalogs, hasLength(2),
        reason: 'debe venir de la caché offline');
    expect(state.fromCache, isTrue);
  });
}
