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

  // Fixtures con la FORMA REAL anidada del backend (serializeSharedCatalog):
  // top-level id = id del vínculo (INT); catalogId = UUID del catálogo.
  const String uuid1 = '11111111-1111-1111-1111-111111111111';
  const String uuid2 = '22222222-2222-2222-2222-222222222222';

  Map<String, dynamic> nestedLink({
    required int linkId,
    required String catalogUuid,
    required String publicName,
    required int providerId,
    required String providerName,
    String? catalogBanner,
    String? priceField,
    bool? isReseller,
  }) {
    return <String, dynamic>{
      'id': linkId,
      'catalogId': catalogUuid,
      'providerId': providerId,
      'linkedAt': '2025-01-01T00:00:00.000Z',
      'catalog': <String, dynamic>{
        'id': catalogUuid,
        'publicName': publicName,
        'description': 'desc',
        'bannerUrl': catalogBanner,
        'enlace': 'enlace',
        'priceField': priceField,
      },
      'provider': <String, dynamic>{
        'id': providerId,
        'nombreEmpresa': providerName,
        'logoUrl': 'https://cdn/logo-$providerId.png',
        'logoOptimizedUrl': 'https://cdn/logo-$providerId.webp',
        'bannerUrl': 'https://cdn/prov-$providerId.jpg',
        'bannerDesktopUrl': null,
        'bannerMobileUrl': null,
      },
      'isReseller': ?isReseller,
    };
  }

  group('syncSharedCatalogs (tarea 1.14)', () {
    test('parsea { linked, catalogs } del contrato real (anidado)', () async {
      adapter.onPost(
        '/reseller/sync-shared-catalogs',
        (server) => server.reply(200, <String, dynamic>{
          'linked': 2,
          'catalogs': <Map<String, dynamic>>[
            nestedLink(
              linkId: 3,
              catalogUuid: uuid1,
              publicName: 'Catálogo Uno',
              providerId: 10,
              providerName: 'Proveedor A',
              catalogBanner: 'https://cdn/b1.jpg',
              isReseller: true,
            ),
            nestedLink(
              linkId: 4,
              catalogUuid: uuid2,
              publicName: 'Catálogo Dos',
              providerId: 20,
              providerName: 'Proveedor B',
            ),
          ],
        }),
        data: <String, dynamic>{},
      );

      final result = await repo.syncSharedCatalogs();

      expect(result, isA<Ok<SyncResult>>());
      final value = (result as Ok<SyncResult>).value;
      expect(value.linked, 2);
      expect(value.catalogs, hasLength(2));
      // id = UUID del catálogo (NO el id numérico del vínculo).
      expect(value.catalogs.first.id, uuid1);
      expect(value.catalogs.first.linkId, 3);
      expect(value.catalogs.first.displayName, 'Catálogo Uno');
      expect(value.catalogs.first.providerId, 10);
      expect(value.catalogs.first.providerName, 'Proveedor A');
      expect(value.catalogs.first.isReseller, isTrue);
    });

    test('segunda llamada idempotente → linked: 0 (manejada)', () async {
      adapter.onPost(
        '/reseller/sync-shared-catalogs',
        (server) => server.reply(200, <String, dynamic>{
          'linked': 0,
          'catalogs': <Map<String, dynamic>>[
            nestedLink(
              linkId: 3,
              catalogUuid: uuid1,
              publicName: 'Catálogo Uno',
              providerId: 10,
              providerName: 'Proveedor A',
            ),
          ],
        }),
        data: <String, dynamic>{},
      );

      final result = await repo.syncSharedCatalogs();

      final value = (result as Ok<SyncResult>).value;
      expect(value.linked, 0);
      expect(value.catalogs, hasLength(1));
      expect(value.catalogs.single.id, uuid1);
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
    test('parsea { catalogs } (forma anidada real) y usa el UUID como id', () async {
      adapter.onGet(
        '/reseller/me/shared-catalogs',
        (server) => server.reply(200, <String, dynamic>{
          'catalogs': <Map<String, dynamic>>[
            nestedLink(
              linkId: 3,
              catalogUuid: uuid1,
              publicName: 'Alfa',
              providerId: 10,
              providerName: 'Proveedor A',
              catalogBanner: 'https://cdn/a.jpg',
              priceField: 'price1',
            ),
          ],
        }),
      );

      final result = await repo.getSharedCatalogs();

      final list = (result as Ok<List<Catalog>>).value;
      expect(list, hasLength(1));
      final c = list.first;
      // id = UUID → el path del detalle es /catalog/by-catalog/<uuid>/products.
      expect(c.id, uuid1);
      expect(
        '/catalog/by-catalog/${c.id}/products',
        '/catalog/by-catalog/$uuid1/products',
      );
      expect(c.displayName, 'Alfa');
      expect(c.providerName, 'Proveedor A');
      expect(c.providerLogoUrl, 'https://cdn/logo-10.webp');
      expect(c.bannerUrl, 'https://cdn/a.jpg');
      expect(c.priceField, 'price1');
    });

    test('fromJson tolerante: snake_case anidado se parsea igual', () async {
      const String uuidSnake = '99999999-9999-9999-9999-999999999999';
      adapter.onGet(
        '/reseller/me/shared-catalogs',
        (server) => server.reply(200, <String, dynamic>{
          'catalogs': <Map<String, dynamic>>[
            // snake_case anidado (tolerancia para caché/legado).
            <String, dynamic>{
              'id': 7,
              'catalog_id': uuidSnake,
              'provider_id': 99,
              'catalog': <String, dynamic>{
                'id': uuidSnake,
                'public_name': 'Snake Uno',
                'banner_url': 'https://cdn/snake.jpg',
                'price_field': 'none',
                'is_reseller': false,
              },
              'provider': <String, dynamic>{
                'id': 99,
                'nombre_empresa': 'Proveedor Snake',
                'logo_url': 'https://cdn/snake-logo.png',
              },
            },
          ],
        }),
      );

      final list = (await repo.getSharedCatalogs() as Ok<List<Catalog>>).value;

      expect(list, hasLength(1));
      final c = list.first;
      expect(c.id, uuidSnake);
      expect(c.linkId, 7);
      expect(c.displayName, 'Snake Uno');
      expect(c.providerId, 99);
      expect(c.providerName, 'Proveedor Snake');
      expect(c.providerLogoUrl, 'https://cdn/snake-logo.png');
      expect(c.bannerUrl, 'https://cdn/snake.jpg');
      expect(c.priceField, 'none');
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

      final result = await repo.getSharedCatalogs(
        providerId: 10,
        search: 'alfa',
      );

      // Si el stub no coincidiera con los query params, el adapter lanzaría.
      expect(result, isA<Ok<List<Catalog>>>());
    });

    test('error de red → Err con NetworkFailure', () async {
      adapter.onGet(
        '/reseller/me/shared-catalogs',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(
              path: '/reseller/me/shared-catalogs',
            ),
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
