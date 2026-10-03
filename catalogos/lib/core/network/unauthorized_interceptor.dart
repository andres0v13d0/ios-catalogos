import 'package:dio/dio.dart';

import '../result/failure.dart';

/// Interceptor que aplica la política "401 persistente → cerrar sesión"
/// (diseño §2.6 y tarea 1.12).
///
/// Se coloca DESPUÉS del [ErrorInterceptor] en la cadena, de modo que cuando
/// llega aquí el error ya está mapeado a un [Failure]. Si el fallo es un
/// [UnauthorizedFailure] (HTTP 401), invoca [onUnauthorized] (que en la app
/// dispara el `logout` de la sesión: Firebase signOut + limpieza de storage,
/// y el router redirige a `/login`).
///
/// Política de refresco: opcionalmente intenta UN refresco del token y reintenta
/// la petición una sola vez; si el 401 persiste, cierra sesión. El refresco se
/// delega a [refreshToken] (puede ser `null` para la política más simple
/// "401 → logout" sin reintento). El reintento se marca con una bandera en los
/// `extra` de la petición para evitar bucles.
class UnauthorizedInterceptor extends Interceptor {
  UnauthorizedInterceptor({
    required this.onUnauthorized,
    this.refreshToken,
    this.retryRequest,
  });

  /// Acción a ejecutar cuando un 401 persiste (cerrar sesión).
  final Future<void> Function() onUnauthorized;

  /// (Opcional) Intenta refrescar el token. Devuelve el nuevo token o `null`
  /// si no se pudo refrescar. Si es `null`, se aplica la política simple
  /// "401 → logout" sin reintento.
  final Future<String?> Function()? refreshToken;

  /// (Opcional) Reejecuta la petición original con el token refrescado.
  /// Normalmente lo provee `dioProvider` usando el propio `Dio`.
  final Future<Response<dynamic>> Function(RequestOptions options)?
      retryRequest;

  /// Clave en `extra` para marcar que la petición ya se reintentó.
  static const String retriedKey = 'unauthorized_retry_attempted';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.error is UnauthorizedFailure ||
        err.response?.statusCode == 401;

    if (!isUnauthorized) {
      handler.next(err);
      return;
    }

    final alreadyRetried = err.requestOptions.extra[retriedKey] == true;

    // Un único intento de refresco + reintento, si está configurado.
    if (!alreadyRetried && refreshToken != null && retryRequest != null) {
      final newToken = await refreshToken!.call();
      if (newToken != null && newToken.isNotEmpty) {
        final options = err.requestOptions
          ..extra[retriedKey] = true
          ..headers['Authorization'] = 'Bearer $newToken';
        try {
          final response = await retryRequest!.call(options);
          handler.resolve(response);
          return;
        } on DioException catch (retryErr) {
          // El reintento también falló; continúa a la política de logout si
          // sigue siendo 401.
          final retryUnauthorized = retryErr.error is UnauthorizedFailure ||
              retryErr.response?.statusCode == 401;
          if (retryUnauthorized) {
            await onUnauthorized();
          }
          handler.next(retryErr);
          return;
        }
      }
    }

    // 401 persistente (sin refresco posible o ya reintentado): cerrar sesión.
    await onUnauthorized();
    handler.next(err);
  }
}
