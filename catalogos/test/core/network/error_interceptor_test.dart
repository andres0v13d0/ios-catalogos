// Tests del mapeo de errores HTTP → Failure (tarea 0.4).
//
// Cubre el criterio de aceptación: "mapeo de 401/429". Verifica el flujo
// completo a través de Dio (DioAdapter devuelve el status, el ErrorInterceptor
// mapea a Failure) y además el mapeo directo con mapDioExceptionToFailure.

import 'package:catalogos/core/network/error_interceptor.dart';
import 'package:catalogos/core/result/failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  group('ErrorInterceptor (vía Dio + mock adapter)', () {
    late Dio dio;
    late DioAdapter adapter;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
      dio.interceptors.add(const ErrorInterceptor());
      adapter = DioAdapter(dio: dio);
    });

    /// Ejecuta una petición que el servidor responde con [status] y devuelve
    /// el Failure mapeado adjuntado por el ErrorInterceptor.
    Future<Failure> failureForStatus(
      int status, {
      Map<String, List<String>>? headers,
    }) async {
      adapter.onGet(
        '/resource',
        (server) => server.reply(status, {'error': 'boom'}),
        headers: headers,
      );
      try {
        await dio.get<dynamic>('/resource');
        fail('Se esperaba una DioException para el status $status');
      } on DioException catch (e) {
        expect(e.error, isA<Failure>(),
            reason: 'El ErrorInterceptor debe adjuntar un Failure');
        return e.error as Failure;
      }
    }

    test('401 → UnauthorizedFailure', () async {
      final failure = await failureForStatus(401);
      expect(failure, isA<UnauthorizedFailure>());
      expect(failure.statusCode, 401);
    });

    test('429 → RateLimitFailure', () async {
      final failure = await failureForStatus(429);
      expect(failure, isA<RateLimitFailure>());
      expect(failure.statusCode, 429);
    });

    test('500 → ServerFailure', () async {
      final failure = await failureForStatus(500);
      expect(failure, isA<ServerFailure>());
      expect(failure.statusCode, 500);
    });
  });

  group('mapDioExceptionToFailure (mapeo puro)', () {
    DioException exceptionWithStatus(int status) {
      final requestOptions = RequestOptions(path: '/x');
      return DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: status,
        ),
      );
    }

    test('401 → UnauthorizedFailure', () {
      final failure = mapDioExceptionToFailure(exceptionWithStatus(401));
      expect(failure, isA<UnauthorizedFailure>());
    });

    test('429 con Retry-After → RateLimitFailure con retryAfter', () {
      final requestOptions = RequestOptions(path: '/x');
      final err = DioException(
        requestOptions: requestOptions,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: requestOptions,
          statusCode: 429,
          headers: Headers.fromMap({
            'retry-after': ['30'],
          }),
        ),
      );

      final failure = mapDioExceptionToFailure(err);
      expect(failure, isA<RateLimitFailure>());
      expect((failure as RateLimitFailure).retryAfter, const Duration(seconds: 30));
    });

    test('timeout de conexión → NetworkFailure', () {
      final err = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionTimeout,
      );
      expect(mapDioExceptionToFailure(err), isA<NetworkFailure>());
    });

    test('error sin respuesta (unknown) → NetworkFailure', () {
      final err = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.unknown,
      );
      expect(mapDioExceptionToFailure(err), isA<NetworkFailure>());
    });

    test('5xx → ServerFailure con statusCode', () {
      final failure = mapDioExceptionToFailure(exceptionWithStatus(503));
      expect(failure, isA<ServerFailure>());
      expect(failure.statusCode, 503);
    });
  });
}
