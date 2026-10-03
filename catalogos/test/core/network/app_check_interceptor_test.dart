// Tests de AppCheckInterceptor (tarea 1.11).
//
// Cubre el CA "requests incluyen token App Check en header" y la resiliencia:
// - cuando la fuente devuelve un token, la petición lleva X-Firebase-AppCheck;
// - cuando la fuente devuelve null, la petición sale SIN la cabecera;
// - cuando la fuente LANZA, la petición igual sale (sin cabecera, no bloquea).
//
// Usa una fuente de token fake y el DioAdapter de http_mock_adapter (sin red
// ni Firebase reales).

import 'package:catalogos/core/network/app_check_interceptor.dart';
import 'package:catalogos/core/network/app_check_token_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

class _FakeTokenSource implements AppCheckTokenSource {
  _FakeTokenSource({this.token, this.throwError = false});

  final String? token;
  final bool throwError;

  @override
  Future<String?> getToken() async {
    if (throwError) {
      throw StateError('App Check no configurado');
    }
    return token;
  }
}

void main() {
  group('AppCheckInterceptor', () {
    late Dio dio;
    late DioAdapter adapter;

    Dio buildDio(AppCheckTokenSource source) {
      final client = Dio(BaseOptions(baseUrl: 'https://api.test'));
      client.interceptors.add(AppCheckInterceptor(source));
      adapter = DioAdapter(dio: client);
      return client;
    }

    test('adjunta X-Firebase-AppCheck cuando hay token', () async {
      dio = buildDio(_FakeTokenSource(token: 'app-check-token-xyz'));
      adapter.onGet('/ping', (server) => server.reply(200, {'ok': true}));

      final response = await dio.get<Map<String, dynamic>>('/ping');

      expect(
        response.requestOptions.headers[AppCheckInterceptor.appCheckHeader],
        'app-check-token-xyz',
      );
    });

    test('no adjunta la cabecera cuando el token es null', () async {
      dio = buildDio(_FakeTokenSource(token: null));
      adapter.onGet('/ping', (server) => server.reply(200, {'ok': true}));

      final response = await dio.get<Map<String, dynamic>>('/ping');

      expect(
        response.requestOptions.headers
            .containsKey(AppCheckInterceptor.appCheckHeader),
        isFalse,
      );
    });

    test('la petición continúa sin cabecera cuando la fuente lanza', () async {
      dio = buildDio(_FakeTokenSource(throwError: true));
      adapter.onGet('/ping', (server) => server.reply(200, {'ok': true}));

      final response = await dio.get<Map<String, dynamic>>('/ping');

      expect(response.statusCode, 200);
      expect(
        response.requestOptions.headers
            .containsKey(AppCheckInterceptor.appCheckHeader),
        isFalse,
      );
    });
  });
}
