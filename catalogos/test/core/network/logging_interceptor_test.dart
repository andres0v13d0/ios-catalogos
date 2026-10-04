// Tests del LoggingInterceptor (punto D: observabilidad de red).
//
// Verifica, SIN red ni Firebase reales (http_mock_adapter):
// - en 400 / 500 / connection error se emite un log `[NET-ERR]` que contiene
//   método, path, status y tipo de error de Dio (y cuerpo truncado cuando hay),
// - un cuerpo largo se trunca con la longitud original anotada,
// - con `enableLogging: false` NO se emite nada,
// - el interceptor reenvía siempre (handler.next): el Failure sigue propagando
//   (comportamiento inalterado).
//
// Se usa un sink inyectable (no `stdout`/zonas) para capturar de forma fiable.

import 'package:catalogos/app/env/environment.dart';
import 'package:catalogos/core/network/error_interceptor.dart';
import 'package:catalogos/core/network/logging_interceptor.dart';
import 'package:catalogos/core/result/failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late List<String> logs;
  late Environment devEnv;
  late Environment prodEnv;

  setUp(() {
    logs = <String>[];
    devEnv = Environment.test(enableLogging: true);
    prodEnv = Environment.test(flavor: Flavor.prod, enableLogging: false);
  });

  /// Monta un Dio con ErrorInterceptor + LoggingInterceptor (orden real) y un
  /// mock adapter. [environment] controla el gating.
  (Dio, DioAdapter) buildDio(Environment environment) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(const ErrorInterceptor());
    dio.interceptors.add(
      LoggingInterceptor(environment: environment, sink: logs.add),
    );
    final adapter = DioAdapter(dio: dio);
    return (dio, adapter);
  }

  group('onError logging (gated dev)', () {
    test('400 → log con método, path, status=400, type y cuerpo', () async {
      final (dio, adapter) = buildDio(devEnv);
      adapter.onGet(
        '/catalog/by-catalog/not-a-uuid/products',
        (server) => server.reply(400, {'message': 'invalid uuid'}),
      );

      Failure? propagated;
      try {
        await dio.get<dynamic>('/catalog/by-catalog/not-a-uuid/products');
      } on DioException catch (e) {
        propagated = e.error as Failure?;
      }

      expect(logs, hasLength(1));
      final line = logs.single;
      expect(line, contains(kNetErrorTag));
      expect(line, contains('GET'));
      expect(line, contains('/catalog/by-catalog/not-a-uuid/products'));
      expect(line, contains('status=400'));
      expect(line, contains('type='));
      expect(line, contains('invalid uuid'));
      // Comportamiento inalterado: el Failure sigue propagando.
      expect(propagated, isA<ServerFailure>());
    });

    test('500 → log con status=500 y ServerFailure propagado', () async {
      final (dio, adapter) = buildDio(devEnv);
      adapter.onGet(
        '/x',
        (server) => server.reply(500, {'error': 'boom'}),
      );

      Failure? propagated;
      try {
        await dio.get<dynamic>('/x');
      } on DioException catch (e) {
        propagated = e.error as Failure?;
      }

      expect(logs.single, contains('status=500'));
      expect(propagated, isA<ServerFailure>());
    });

    test('connection error (sin respuesta) → status=n/a + message', () async {
      final (dio, adapter) = buildDio(devEnv);
      adapter.onGet(
        '/down',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: '/down'),
            type: DioExceptionType.connectionError,
            message: 'socket down',
          ),
        ),
      );

      Failure? propagated;
      try {
        await dio.get<dynamic>('/down');
      } on DioException catch (e) {
        propagated = e.error as Failure?;
      }

      final line = logs.single;
      expect(line, contains('status=n/a'));
      expect(line, contains('type=DioExceptionType.connectionError'));
      // Sin respuesta → se emite un detalle de transporte (`message=...`).
      expect(line, contains('message='));
      expect(propagated, isA<NetworkFailure>());
    });

    test('cuerpo largo se trunca con longitud original anotada', () async {
      final (dio, adapter) = buildDio(devEnv);
      final longValue = 'x' * 1000;
      adapter.onGet(
        '/big',
        (server) => server.reply(400, {'data': longValue}),
      );

      try {
        await dio.get<dynamic>('/big');
      } on DioException catch (_) {
        // ignorado: solo nos interesa el log.
      }

      final line = logs.single;
      expect(line, contains('truncado de'));
      // La línea no debe contener el valor completo de 1000 chars.
      expect(line.contains(longValue), isFalse);
    });
  });

  group('gating por entorno', () {
    test('enableLogging=false → no se emite nada', () async {
      final (dio, adapter) = buildDio(prodEnv);
      adapter.onGet('/x', (server) => server.reply(500, {'e': 1}));

      try {
        await dio.get<dynamic>('/x');
      } on DioException catch (_) {}

      expect(logs, isEmpty);
    });
  });

  group('formatNetError / truncateBody (unidad)', () {
    test('trunca exactamente a kNetLogBodyMaxChars', () {
      final text = 'a' * (kNetLogBodyMaxChars + 50);
      final out = truncateBody(text);
      expect(out, startsWith('a' * kNetLogBodyMaxChars));
      expect(out, contains('truncado de ${kNetLogBodyMaxChars + 50} chars'));
    });

    test('no trunca cuerpos cortos', () {
      expect(truncateBody('hola'), 'hola');
    });

    test('serializa mapas con jsonEncode', () {
      expect(truncateBody({'a': 1}), '{"a":1}');
    });

    test('null → "null"', () {
      expect(truncateBody(null), 'null');
    });
  });
}
