/// Jerarquía sellada de fallos de la capa de datos/red.
///
/// Ver diseño §2.4 "Capa de datos y red" y §2.6 "Manejo de errores":
/// la red mapea los errores HTTP a estos tipos y los repos los exponen vía
/// [Result]. La UI consume luego estos fallos para mostrar estados de error
/// consistentes.
///
/// Es `sealed`, de modo que un `switch` exhaustivo sobre un [Failure] obliga a
/// cubrir todos los casos en tiempo de compilación.
sealed class Failure {
  const Failure({required this.message, this.statusCode, this.cause});

  /// Mensaje legible y seguro para mostrar/registrar (sin datos sensibles).
  final String message;

  /// Código HTTP asociado cuando aplica (p. ej. 401, 429, 500). `null` para
  /// fallos sin respuesta del servidor (p. ej. timeouts o falta de red).
  final int? statusCode;

  /// Causa subyacente (p. ej. la `DioException` original) para diagnóstico.
  /// No debe exponerse directamente en la UI.
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType(statusCode: $statusCode, message: $message)';
}

/// Fallo de conectividad/transporte: timeouts, conexión rechazada, cancelación,
/// o cualquier error sin una respuesta HTTP del servidor.
final class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.',
    super.cause,
  });
}

/// Autenticación/credenciales inválidas o expiradas (HTTP 401).
///
/// Según diseño §2.6, un 401 persistente debe terminar en cierre de sesión;
/// esa política vive en una capa superior (ver tarea 1.12).
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({
    super.message = 'Tu sesión no es válida o expiró.',
    super.cause,
  }) : super(statusCode: 401);
}

/// Se superó el límite de peticiones (HTTP 429).
///
/// La UI debería aplicar backoff y un mensaje al usuario (diseño §2.6).
final class RateLimitFailure extends Failure {
  const RateLimitFailure({
    super.message = 'Demasiadas solicitudes. Espera un momento e inténtalo de nuevo.',
    this.retryAfter,
    super.cause,
  }) : super(statusCode: 429);

  /// Tiempo sugerido de espera antes de reintentar, si el servidor lo indicó
  /// mediante la cabecera `Retry-After`.
  final Duration? retryAfter;
}

/// Bloqueo/throttle del login por código WhatsApp (HTTP 429).
///
/// Se diferencia de [RateLimitFailure] porque transporta explícitamente los
/// segundos de cooldown/espera que el backend del login revendedor devuelve en
/// el body (`resendAvailableInSeconds` / `retryAfterSeconds`) para que la UI
/// pueda mostrar la cuenta regresiva o deshabilitar el reenvío. Se usa tanto
/// para el cooldown de reenvío como para el lockout por intentos fallidos.
final class LockedFailure extends Failure {
  const LockedFailure({
    super.message =
        'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
    this.retryAfterSeconds,
    super.cause,
  }) : super(statusCode: 429);

  /// Segundos sugeridos de espera antes de reintentar, si el backend los
  /// indicó (`resendAvailableInSeconds` o `retryAfterSeconds`).
  final int? retryAfterSeconds;
}

/// Error de validación del lado del servidor (HTTP 400) con un mensaje legible
/// provisto por el backend (p. ej. "Código incorrecto", "El código expiró",
/// "número de teléfono inválido"). La UI muestra [message] tal cual.
final class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.statusCode = 400,
    super.cause,
  });
}

/// Error del lado del servidor (HTTP 5xx) u otras respuestas de error no
/// mapeadas a un caso más específico (p. ej. 4xx de validación).
final class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Ocurrió un error en el servidor. Inténtalo más tarde.',
    super.statusCode,
    super.cause,
  });
}

/// Fallo no clasificado: cualquier error inesperado que no encaja en los
/// casos anteriores.
final class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'Ocurrió un error inesperado.',
    super.statusCode,
    super.cause,
  });
}
