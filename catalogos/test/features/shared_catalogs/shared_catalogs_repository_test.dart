// Tests del SharedCatalogsRepository (tareas 1.14/1.15).
//
// Mock de Dio con http_mock_adapter usando las respuestas EXACTAS del contrato
// real (camelCase), más una variante snake_case para verificar el fromJson
// tolerante. Sin red ni Firebase reales.

import 'package:catalogos/core/network/error_interceptor.dart';
import 'package:catalogos/core/result/failure.dart';
import 'package:catalogos/core/result/result.dart';
import 'package:catalogos/features/shared_catalogs/data/shared_catalogs_repository.dart';
import 'package:catalogos/features/shared_catalogs/domain/catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late SharedCatalogsRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(const ErrorInterceptor());
    adapter = DioAdapter(dio: dio);
    repo = SharedCatalogsRepository(dio);
  });

  group('syncSharedCatalogs (tarea 1.14)', () {
    test('parsea { linked, catalogs } del contrato real (camelCase)', () async {
      adapter.onPost(
        '/reseller/sync-shared-catalogs',
        (server) => server.reply(200, <String, dynamic>{
          'linked': 2,
          'catalogs': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'c1',
              'publicName': 'Catálogo Uno',
              'providerId': 10,
              'providerName': 'Proveedor A',
              'bannerUrl': 'https://cdn/b1.jpg',
              'isReseller': true,
            },
            <String, dynamic>{
              'id': 'c2',
              'publicName': 'Catálogo Dos',
              'providerId': 20,
              'providerName': 'Proveedor B',
              'bannerUrl': null,
            },
          ],
        }),
        data: <String, dynamic>{},
      );

      final result = await repo.syncSharedCatalogs();

      expect(result, isA<Ok<SyncResult>>());
      final value = (result as Ok<SyncResult>).value;
      expect(value.linked, 2);
      expect(value.catalogs, hasLength(2));
      expect(value.catalogs.first.displayName, 'Catálogo Uno');
      expect(value.catalogs.first.providerId, 10);
      expect(value.catalogs.first.isReseller, isTrue);
    });

    test('segunda llamada idempotente → linked: 0 (manejada)', () async {
      adapter.onPost(
        '/reseller/sync-shared-catalogs',
        (server) => server.reply(200, <String, dynamic>{
          'linked': 0,
          'catalogs': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'c1',
              'publicName': 'Catálogo Uno',
              'providerId': 10,
              'providerName': 'Proveedor A',
            },
          ],
        }),
        data: <String, dynamic>{},
      );

      final result = await repo.syncSharedCatalogs();

      final value = (result as Ok<SyncResult>).value;
      expect(value.linked, 0);
      expect(value.catalogs, hasLength(1));
    });

    test('error del servidor → Err con Failure', () async {
      adapter.onPost(
        '/reseller/sync-shared-catalogs',
        (server) => server.reply(500, <String, dynamic>{'error': 'boom'}),
        data: <String, dynamic>{},
      );

      final result = await repo.syncSharedCatalogs();

      expect(result, isA<Err<SyncResult>>());
      expect((result as Err<SyncResult>).failure, isA<ServerFailure>());
    });
  });

  group('getSharedCatalogs (tarea 1.14/1.15)', () {
    test('parsea { catalogs } (camelCase)', () async {
      adapter.onGet(
        '/reseller/me/shared-catalogs',
        (server) => server.reply(200, <String, dynamic>{
          'catalogs': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'c1',
              'publicName': 'Alfa',
              'providerId': 10,
              'providerName': 'Proveedor A',
              'bannerUrl': 'https://cdn/a.jpg',
            },
          ],
        }),
      );

      final result = await repo.getSharedCatalogs();

      final list = (result as Ok<List<Catalog>>).value;
      expect(list, hasLength(1));
      expect(list.first.displayName, 'Alfa');
      expect(list.first.bannerUrl, 'https://cdn/a.jpg');
    });

    test('fromJson tolerante: snake_case se parsea igual que camelCase',
        () async {
      adapter.onGet(
        '/reseller/me/shared-catalogs',
        (server) => server.reply(200, <String, dynamic>{
          'catalogs': <Map<String, dynamic>>[
            // snake_case + nombre bajo `public_name`
            <String, dynamic>{
              'id': 's1',
              'public_name': 'Snake Uno',
              'provider_id': 99,
              'provider_name': 'Proveedor Snake',
              'banner_url': 'https://cdn/snake.jpg',
              'is_reseller': false,
            },
          ],
        }),
      );

      final list = (await repo.getSharedCatalogs() as Ok<List<Catalog>>).value;

      expect(list, hasLength(1));
      final c = list.first;
      expect(c.id, 's1');
      expect(c.displayName, 'Snake Uno');
      expect(c.providerId, 99);
      expect(c.providerName, 'Proveedor Snake');
      expect(c.bannerUrl, 'https://cdn/snake.jpg');
      expect(c.isReseller, isFalse);
    });

    test('envía providerId y search como query params', () async {
      adapter.onGet(
        '/reseller/me/shared-catalogs',
        (server) => server.reply(200, <String, dynamic>{
          'catalogs': <Map<String, dynamic>>[],
        }),
        queryParameters: <String, dynamic>{'providerId': 10, 'search': 'alfa'},
      );

      final result =
          await repo.getSharedCatalogs(providerId: 10, search: 'alfa');

      // Si el stub no coincidiera con los query params, el adapter lanzaría.
      expect(result, isA<Ok<List<Catalog>>>());
    });

    test('error de red → Err con NetworkFailure', () async {
      adapter.onGet(
        '/reseller/me/shared-catalogs',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/reseller/me/shared-catalogs'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      final result = await repo.getSharedCatalogs();

      expect(result, isA<Err<List<Catalog>>>());
      expect((result as Err<List<Catalog>>).failure, isA<NetworkFailure>());
    });
  });
}
