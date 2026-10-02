// Tests de AuthInterceptor (tarea 0.4).
//
// Cubre el criterio de aceptación: "test unitario que verifica header
// `Authorization`". Usa el DioAdapter de http_mock_adapter para interceptar la
// petición y capturar las cabeceras realmente enviadas (sin red real).

import 'package:catalogos/core/network/auth_interceptor.dart';
import 'package:catalogos/core/network/token_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  group('AuthInterceptor', () {
    late Dio dio;
    late DioAdapter adapter;

    Dio buildDio(TokenProvider provider) {
      final client = Dio(BaseOptions(baseUrl: 'https://api.test'));
      client.interceptors.add(AuthInterceptor(provider));
      adapter = DioAdapter(dio: client);
      return client;
    }

    test('adjunta "Authorization: Bearer <idToken>" cuando hay token',
        () async {
      dio = buildDio(StaticTokenProvider(token: 'id-token-123'));

      // Responde eco de las cabeceras recibidas para poder verificarlas.
      adapter.onGet(
        '/me',
        (server) => server.reply(200, {'ok': true}),
      );

      final response = await dio.get<Map<String, dynamic>>('/me');

      final sentAuth =
          response.requestOptions.headers[AuthInterceptor.authorizationHeader];
      expect(sentAuth, 'Bearer id-token-123');
    });

    test('no adjunta Authorization cuando no hay token (sesión ausente)',
        () async {
      dio = buildDio(StaticTokenProvider(token: null));

      adapter.onGet(
        '/me',
        (server) => server.reply(200, {'ok': true}),
      );

      final response = await dio.get<Map<String, dynamic>>('/me');

      expect(
        response.requestOptions.headers
            .containsKey(AuthInterceptor.authorizationHeader),
        isFalse,
      );
    });

    test('actualiza el token tras setToken (p. ej. login posterior)', () async {
      final provider = StaticTokenProvider(token: null);
      dio = buildDio(provider);
      provider.setToken('fresh-token');

      adapter.onGet(
        '/me',
        (server) => server.reply(200, {'ok': true}),
      );

      final response = await dio.get<Map<String, dynamic>>('/me');

      expect(
        response.requestOptions.headers[AuthInterceptor.authorizationHeader],
        'Bearer fresh-token',
      );
    });
  });
}
