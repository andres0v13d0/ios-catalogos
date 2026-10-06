// Tests del CatalogDetailRepository + modelos (tarea 1.16).
//
// Mock de Dio con http_mock_adapter usando la forma EXACTA del contrato real
// (snake_case en raíz + camelCase dentro de `catalog`). Verifica:
// - parseo del payload real-shaped (banner, metadatos, productos),
// - fromJson tolerante de colores/tallas como objetos Y como strings,
// - mapa de precios parseado,
// - modo "sin precios" (priceField 'none' y todos los valores en 0) detectado.
// Sin red ni Firebase reales.

import 'package:catalogos/core/network/error_interceptor.dart';
import 'package:catalogos/core/network/logging_interceptor.dart';
import 'package:catalogos/core/result/failure.dart';
import 'package:catalogos/core/result/result.dart';
import 'package:catalogos/features/shared_catalogs/data/catalog_detail_repository.dart';
import 'package:catalogos/features/shared_catalogs/domain/catalog_detail.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

/// Payload "real-shaped" con precios reales y variantes como OBJETOS.
Map<String, dynamic> _payloadWithPrices() => <String, dynamic>{
  'banner_url': 'https://cdn/banner.jpg',
  'nombre_empresa': 'Empresa X',
  'provider_id': 42,
  'logo_url': 'https://cdn/logo.png',
  'banner_desktop_url': null,
  'banner_mobile_url': null,
  'logo_optimized_url': null,
  'catalog': <String, dynamic>{
    'id': 'cat-1',
    'internalName': 'interno',
    'publicName': 'Catálogo Público',
    'name': 'nombre',
    'description': 'desc',
    'type': 'private',
    'categoryId': 'c-10',
    'subcategoryId': 's-20',
    'banner_url': null,
    'telefono': '+573001112233',
    'priceField': 'mayorista',
  },
  'products': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'p1',
      'nombre': 'Camiseta',
      'descripcion': 'Algodón',
      // Forma real del backend: objeto con variantes de tamaño (ver
      // `getProductImages` en private-catalogs.service.ts), no strings.
      'imagenes': <Map<String, dynamic>>[
        <String, dynamic>{
          'imageUrl': 'https://cdn/p1a.jpg',
          'thumbnailUrl': 'https://cdn/p1a_thumb.jpg',
          'mediumUrl': 'https://cdn/p1a_medium.jpg',
          'fullUrl': 'https://cdn/p1a_full.jpg',
        },
        <String, dynamic>{'imageUrl': 'https://cdn/p1b.jpg'},
      ],
      'colores': <Map<String, dynamic>>[
        <String, dynamic>{'id': 'col1', 'name': 'Rojo'},
        <String, dynamic>{'id': 'col2', 'name': 'Azul'},
      ],
      'tallas': <Map<String, dynamic>>[
        <String, dynamic>{'id': 't1', 'name': 'M'},
      ],
      'precios': <String, dynamic>{'1': 20000, '6': 18000, '12': 15000},
      'unidadMedida': 'unidad',
      'moneda': 'COP',
    },
  ],
};

/// Payload con variantes como STRINGS (tolerancia).
Map<String, dynamic> _payloadStringVariants() => <String, dynamic>{
  'banner_url': null,
  'provider_id': 1,
  'catalog': <String, dynamic>{
    'id': 'cat-2',
    'publicName': 'Strings',
    'priceField': 'detal',
  },
  'products': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'p2',
      'nombre': 'Gorra',
      // Formato legado (string suelto, sin variantes de tamaño): debe
      // tolerarse igual que los objetos.
      'imagenes': <String>['https://cdn/p2.jpg'],
      'colores': <String>['Negro', 'Blanco'],
      'tallas': <String>['Única'],
      'precios': <String, dynamic>{'1': 9000},
    },
  ],
};

/// Payload en modo "sin precios": priceField 'none' + todos los valores en 0,
/// conservando las MISMAS claves de cantidad.
Map<String, dynamic> _payloadSinPrecios() => <String, dynamic>{
  'provider_id': 7,
  'catalog': <String, dynamic>{
    'id': 'cat-3',
    'publicName': 'Sin Precios',
    'priceField': 'none',
  },
  'products': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'p3',
      'nombre': 'Reloj',
      'imagenes': <String>['https://cdn/p3.jpg'],
      'colores': <Map<String, dynamic>>[],
      'tallas': <Map<String, dynamic>>[],
      'precios': <String, dynamic>{'1': 0, '10': 0, '50': 0},
    },
  ],
};

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late CatalogDetailRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(const ErrorInterceptor());
    adapter = DioAdapter(dio: dio);
    repo = CatalogDetailRepository(dio);
  });

  group('getCatalogProducts (tarea 1.16)', () {
    test(
      'parsea el payload real-shaped (banner, metadatos, productos)',
      () async {
        adapter.onGet(
          '/catalog/by-catalog/cat-1/products',
          (server) => server.reply(200, _payloadWithPrices()),
        );

        final result = await repo.getCatalogProducts('cat-1');

        expect(result, isA<Ok<CatalogDetail>>());
        final detail = (result as Ok<CatalogDetail>).value;
        expect(detail.id, 'cat-1');
        expect(detail.bannerUrl, 'https://cdn/banner.jpg');
        expect(detail.nombreEmpresa, 'Empresa X');
        expect(detail.providerId, 42);
        expect(detail.publicName, 'Catálogo Público');
        expect(detail.telefono, '+573001112233');
        expect(detail.categoryId, 'c-10');
        expect(detail.subcategoryId, 's-20');
        expect(detail.priceField, 'mayorista');
        expect(detail.products, hasLength(1));

        final p = detail.products.first;
        expect(p.id, 'p1');
        expect(p.nombre, 'Camiseta');
        expect(p.imagenes, hasLength(2));
        expect(p.primaryImage, 'https://cdn/p1a.jpg');
        // La cuadrícula usa la variante más chica disponible (miniatura).
        expect(p.primaryThumbnail, 'https://cdn/p1a_thumb.jpg');
        // Segunda imagen sin variantes: solo trae la URL original.
        expect(p.imagenes[1].thumbnailUrl, isNull);
        expect(p.imagenes[1].gridUrl, 'https://cdn/p1b.jpg');
        // Variantes como objetos → nombres extraídos.
        expect(p.colores.map((v) => v.name), <String>['Rojo', 'Azul']);
        expect(p.tallas.map((v) => v.name), <String>['M']);
        // Mapa de precios parseado y ordenado numéricamente.
        expect(p.precios, <String, num>{'1': 20000, '6': 18000, '12': 15000});
        expect(p.cantidades, <String>['1', '6', '12']);
        expect(p.hasRealPrices, isTrue);
      },
    );

    test('fromJson tolerante: colores/tallas/imagenes como strings', () async {
      adapter.onGet(
        '/catalog/by-catalog/cat-2/products',
        (server) => server.reply(200, _payloadStringVariants()),
      );

      final detail =
          (await repo.getCatalogProducts('cat-2') as Ok<CatalogDetail>).value;
      final p = detail.products.first;
      expect(p.colores.map((v) => v.name), <String>['Negro', 'Blanco']);
      expect(p.tallas.map((v) => v.name), <String>['Única']);
      // Imagen como string suelto (sin variantes): primaryThumbnail cae a la
      // URL original.
      expect(p.primaryImage, 'https://cdn/p2.jpg');
      expect(p.primaryThumbnail, 'https://cdn/p2.jpg');
      // Strings → id == name.
      expect(p.colores.first.id, 'Negro');
    });

    test(
      'modo "sin precios": priceField none + valores 0 → priceHidden',
      () async {
        adapter.onGet(
          '/catalog/by-catalog/cat-3/products',
          (server) => server.reply(200, _payloadSinPrecios()),
        );

        final detail =
            (await repo.getCatalogProducts('cat-3') as Ok<CatalogDetail>).value;

        expect(detail.priceField, 'none');
        expect(detail.priceHidden, isTrue);
        final p = detail.products.first;
        // Las cantidades se preservan aunque los importes estén ocultos.
        expect(p.cantidades, <String>['1', '10', '50']);
        expect(p.hasRealPrices, isFalse);
      },
    );

    test(
      'modo "sin precios" por valores 0 aunque priceField no sea none',
      () async {
        final payload = _payloadSinPrecios();
        (payload['catalog'] as Map<String, dynamic>)['priceField'] =
            'mayorista';
        adapter.onGet(
          '/catalog/by-catalog/cat-z/products',
          (server) => server.reply(200, payload),
        );

        final detail =
            (await repo.getCatalogProducts('cat-z') as Ok<CatalogDetail>).value;

        // priceField no es 'none', pero todos los precios son 0 → oculto.
        expect(detail.priceHidden, isTrue);
      },
    );

    test('error de red → Err con NetworkFailure', () async {
      adapter.onGet(
        '/catalog/by-catalog/cat-err/products',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(
              path: '/catalog/by-catalog/cat-err/products',
            ),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      final result = await repo.getCatalogProducts('cat-err');

      expect(result, isA<Err<CatalogDetail>>());
      expect((result as Err<CatalogDetail>).failure, isA<NetworkFailure>());
    });
  });

  group('getProductPreviews (POST previews)', () {
    test(
      'envía { ids, catalogId } y parsea la misma forma de respuesta',
      () async {
        adapter.onPost(
          '/catalog/products/previews',
          (server) => server.reply(200, _payloadWithPrices()),
          data: <String, dynamic>{
            'ids': <String>['p1'],
            'catalogId': 'cat-1',
          },
        );

        final result = await repo.getProductPreviews(<String>[
          'p1',
        ], catalogId: 'cat-1');

        final detail = (result as Ok<CatalogDetail>).value;
        expect(detail.products, hasLength(1));
        expect(detail.products.first.id, 'p1');
      },
    );
  });

  group('observabilidad del parse-error (200 OK con cuerpo mal formado)', () {
    test(
      '200 con cuerpo no-mapa → log [PARSE-ERR] y Err (sin cambio de Result)',
      () async {
        final logs = <String>[];
        final repoWithSink = CatalogDetailRepository(dio, logSink: logs.add);
        // 200 OK pero el cuerpo es una lista (forma inesperada) → _parseDetail
        // lanza FormatException, que NO es una DioException.
        adapter.onGet(
          '/catalog/by-catalog/cat-bad/products',
          (server) => server.reply(200, <dynamic>['no', 'es', 'un', 'mapa']),
        );

        final result = await repoWithSink.getCatalogProducts('cat-bad');

        // Comportamiento inalterado: sigue devolviendo Err(UnknownFailure).
        expect(result, isA<Err<CatalogDetail>>());
        expect((result as Err<CatalogDetail>).failure, isA<UnknownFailure>());

        // Y ahora el caso es visible.
        expect(logs, hasLength(1));
        final line = logs.single;
        expect(line, contains(kParseErrorTag));
        expect(line, contains('/catalog/by-catalog/cat-bad/products'));
        expect(line, contains('error='));
      },
    );
  });

  group('round-trip de caché (toJson/fromJson)', () {
    test('preserva priceHidden y cantidades tras serializar', () {
      final detail = CatalogDetail.fromJson(_payloadSinPrecios());
      final roundTripped = CatalogDetail.fromJson(detail.toJson());
      expect(roundTripped.priceHidden, isTrue);
      expect(roundTripped.products.first.cantidades, <String>['1', '10', '50']);
    });
  });
}
