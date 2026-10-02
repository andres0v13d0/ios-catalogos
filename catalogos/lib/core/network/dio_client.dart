import 'package:dio/dio.dart';

import '../../app/env/environment.dart';
import 'app_check_interceptor.dart';
import 'auth_interceptor.dart';
import 'error_interceptor.dart';
import 'token_provider.dart';

/// Fábrica del cliente [Dio] de la app.
///
/// Centraliza la configuración de red (diseño §2.4):
/// - `baseUrl` tomado de [Environment.apiBaseUrl] (por flavor),
/// - timeouts razonables,
/// - y la cadena de interceptores en orden:
///   1. [AuthInterceptor]      → adjunta `Authorization: Bearer <idToken>`
///   2. [AppCheckInterceptor]  → STUB de App Check (ver tarea 1.11)
///   3. [ErrorInterceptor]     → mapea errores HTTP a `Failure`
///
/// El orden importa: Auth y AppCheck actúan en `onRequest`; el ErrorInterceptor
/// va al final para que su `onError` sea el último en transformar el error.
class DioClient {
  const DioClient._();

  /// Timeouts por defecto.
  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _receiveTimeout = Duration(seconds: 20);
  static const Duration _sendTimeout = Duration(seconds: 20);

  /// Crea un [Dio] configurado para el entorno actual.
  ///
  /// - [tokenProvider]: fuente del `idToken` para [AuthInterceptor]. Si es
  ///   `null`, se usa un [StaticTokenProvider] vacío (sin sesión), apto como
  ///   placeholder hasta la tarea 1.12.
  /// - [environment]: permite inyectar un entorno distinto en tests; por
  ///   defecto usa [Environment.current].
  static Dio create({
    TokenProvider? tokenProvider,
    Environment? environment,
  }) {
    final env = environment ?? Environment.current;

    final dio = Dio(
      BaseOptions(
        baseUrl: env.apiBaseUrl,
        connectTimeout: _connectTimeout,
        receiveTimeout: _receiveTimeout,
        sendTimeout: _sendTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );

    dio.interceptors.addAll([
      AuthInterceptor(tokenProvider ?? StaticTokenProvider()),
      AppCheckInterceptor(),
      const ErrorInterceptor(),
    ]);

    return dio;
  }
}
