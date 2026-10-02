import 'package:dio/dio.dart';

import '../result/failure.dart';

/// Mapea errores de Dio / códigos HTTP a la jerarquía sellada [Failure].
///
/// Ver diseño §2.4 y §2.6:
/// - sin respuesta (timeouts, conexión, cancelación) → [NetworkFailure]
/// - 401 → [UnauthorizedFailure]
/// - 429 → [RateLimitFailure]
/// - 5xx → [ServerFailure]
/// - otros 4xx / casos no clasificados → [ServerFailure]/[UnknownFailure]
///
/// La función de mapeo [mapDioExceptionToFailure] es pura y reutilizable por
/// repos y tests. El interceptor adjunta el [Failure] resultante a
/// `DioException.error`, de modo que las capas superiores puedan recuperarlo y
/// construir un `Result<T>` consistente.
class ErrorInterceptor extends Interceptor {
  const ErrorInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final failure = mapDioExceptionToFailure(err);
    // Reemplaza el error crudo por el Failure mapeado conservando el resto del
    // contexto de la excepción.
    handler.next(err.copyWith(error: failure));
  }
}

/// Convierte una [DioException] en el [Failure] correspondiente.
///
/// Pura y sin efectos secundarios: segura de usar en repos y en tests.
Failure mapDioExceptionToFailure(DioException err) {
  switch (err.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return NetworkFailure(cause: err);
    case DioExceptionType.cancel:
      return NetworkFailure(
        message: 'La solicitud fue cancelada.',
        cause: err,
      );
    case DioExceptionType.badCertificate:
      return NetworkFailure(
        message: 'No se pudo establecer una conexión segura.',
        cause: err,
      );
    case DioExceptionType.transformTimeout:
      return NetworkFailure(cause: err);
    case DioExceptionType.badResponse:
      return _mapStatusCode(err);
    case DioExceptionType.unknown:
      // Un error sin respuesta suele ser de transporte (p. ej. socket).
      if (err.response == null) {
        return NetworkFailure(cause: err);
      }
      return _mapStatusCode(err);
  }
}

/// Mapea el código de estado HTTP de una respuesta de error a un [Failure].
Failure _mapStatusCode(DioException err) {
  final response = err.response;
  final statusCode = response?.statusCode;

  switch (statusCode) {
    case 401:
      return UnauthorizedFailure(cause: err);
    case 429:
      return RateLimitFailure(
        retryAfter: _parseRetryAfter(response),
        cause: err,
      );
  }

  if (statusCode != null && statusCode >= 500) {
    return ServerFailure(statusCode: statusCode, cause: err);
  }

  if (statusCode != null && statusCode >= 400) {
    // Otros errores de cliente (400/403/404/409/422, etc.). Se tratan como
    // fallo de servidor genérico con su código; casos específicos (p. ej.
    // validación) pueden refinarse en fases posteriores.
    return ServerFailure(
      message: 'La solicitud no se pudo procesar.',
      statusCode: statusCode,
      cause: err,
    );
  }

  return UnknownFailure(statusCode: statusCode, cause: err);
}

/// Interpreta la cabecera `Retry-After` (solo el formato en segundos).
Duration? _parseRetryAfter(Response<dynamic>? response) {
  final raw = response?.headers.value('retry-after');
  if (raw == null) {
    return null;
  }
  final seconds = int.tryParse(raw.trim());
  if (seconds == null) {
    return null;
  }
  return Duration(seconds: seconds);
}
