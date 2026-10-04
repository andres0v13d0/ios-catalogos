import 'package:dio/dio.dart';

import '../../app/env/environment.dart';
import 'app_check_interceptor.dart';
import 'app_check_token_source.dart';
import 'auth_interceptor.dart';
import 'error_interceptor.dart';
import 'logging_interceptor.dart';
import 'token_provider.dart';
import 'unauthorized_interceptor.dart';

/// Fábrica del cliente [Dio] de la app.
///
/// Centraliza la configuración de red (diseño §2.4):
/// - `baseUrl` tomado de [Environment.apiBaseUrl] (por flavor),
/// - timeouts razonables,
/// - y la cadena de interceptores en orden:
///   1. [AuthInterceptor]           → adjunta `Authorization: Bearer <idToken>`
///   2. [AppCheckInterceptor]       → adjunta `X-Firebase-AppCheck` (tarea 1.11)
///   3. [ErrorInterceptor]          → mapea errores HTTP a `Failure`
///   4. [LoggingInterceptor]        → observabilidad de red (punto D). Va
///      DESPUÉS del ErrorInterceptor para leer `err.response` ya mapeado sin
///      alterar el `Failure`. No-op si `Environment.enableLogging` es false.
///   5. [UnauthorizedInterceptor]   → política 401 persistente → logout (1.12)
///
/// El orden importa: Auth y AppCheck actúan en `onRequest`; el ErrorInterceptor
/// mapea el error ANTES de que el UnauthorizedInterceptor decida cerrar sesión.
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
  /// - [onUnauthorized]: si se provee, se añade un [UnauthorizedInterceptor]
  ///   que aplica la política "401 persistente → logout" (tarea 1.12). Si es
  ///   `null`, la cadena termina en el [ErrorInterceptor] (comportamiento de
  ///   fases previas, útil en tests de bajo nivel).
  static Dio create({
    TokenProvider? tokenProvider,
    AppCheckTokenSource? appCheckTokenSource,
    Environment? environment,
    NetLogSink? logSink,
    Future<void> Function()? onUnauthorized,
    Future<String?> Function()? refreshToken,
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
      AppCheckInterceptor(
        appCheckTokenSource ?? const NoopAppCheckTokenSource(),
      ),
      const ErrorInterceptor(),
      // Observabilidad (punto D): siempre se añade; el propio interceptor hace
      // no-op cuando `Environment.enableLogging` es false. Va justo DESPUÉS del
      // ErrorInterceptor para seguir leyendo `err.response.statusCode/data`
      // (ErrorInterceptor hace copyWith(error: failure) sin tocar `response`).
      LoggingInterceptor(environment: env, sink: logSink),
    ]);

    if (onUnauthorized != null) {
      dio.interceptors.add(
        UnauthorizedInterceptor(
          onUnauthorized: onUnauthorized,
          refreshToken: refreshToken,
          retryRequest: refreshToken == null
              ? null
              : (RequestOptions options) => dio.fetch<dynamic>(options),
        ),
      );
    }

    return dio;
  }
}
