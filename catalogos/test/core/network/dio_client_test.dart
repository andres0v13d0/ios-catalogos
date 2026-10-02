// Tests de la fábrica DioClient (tarea 0.4).
//
// Verifica que el cliente se construye con la baseUrl del Environment y con la
// cadena de interceptores esperada (Auth → AppCheck → Error).

import 'package:catalogos/app/env/environment.dart';
import 'package:catalogos/core/network/app_check_interceptor.dart';
import 'package:catalogos/core/network/auth_interceptor.dart';
import 'package:catalogos/core/network/dio_client.dart';
import 'package:catalogos/core/network/error_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DioClient.create', () {
    test('usa la apiBaseUrl del Environment actual', () {
      final dio = DioClient.create();
      expect(dio.options.baseUrl, Environment.current.apiBaseUrl);
    });

    test('registra Auth, AppCheck y Error interceptors en orden', () {
      final dio = DioClient.create();
      // Se filtran los interceptores propios (Dio no agrega otros por defecto).
      final types = dio.interceptors.map((i) => i.runtimeType).toList();

      expect(types, contains(AuthInterceptor));
      expect(types, contains(AppCheckInterceptor));
      expect(types, contains(ErrorInterceptor));

      final authIndex = types.indexOf(AuthInterceptor);
      final appCheckIndex = types.indexOf(AppCheckInterceptor);
      final errorIndex = types.indexOf(ErrorInterceptor);
      expect(authIndex, lessThan(appCheckIndex));
      expect(appCheckIndex, lessThan(errorIndex));
    });

    test('tiene timeouts configurados', () {
      final dio = DioClient.create();
      expect(dio.options.connectTimeout, isNotNull);
      expect(dio.options.receiveTimeout, isNotNull);
    });
  });
}
