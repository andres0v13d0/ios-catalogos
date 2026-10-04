import 'dart:convert';

import 'package:dio/dio.dart';

import '../../app/env/environment.dart';

/// Sink de logging de red.
///
/// Es una función de nivel superior **inyectable** para que los tests capturen
/// la salida sin depender de `stdout` real ni de zonas (`runZoned`). Por
/// defecto apunta a [print].
///
/// Se usa [print] y NO [debugPrint] a propósito:
/// - `debugPrint` está limitado por tasa (rate-limited): descarta/trocea líneas
///   cuando llegan muchas seguidas, por lo que un error de red puede no llegar
///   nunca a `adb logcat` / `flutter run`.
/// - `debugPrint` puede además quedar reducido a un no-op fuera de debug.
/// El objetivo de "punto D" es que el error SIEMPRE sea visible en el flavor
/// dev (incluso en profile/release-ish), así que necesitamos una salida sin
/// recortes ni límites: `print`.
typedef NetLogSink = void Function(String message);

/// Sink por defecto: imprime sin límite de tasa.
void _defaultNetLogSink(String message) {
  // ignore: avoid_print
  print(message);
}

/// Sink global sobreescribible (principalmente en tests).
NetLogSink netLogSink = _defaultNetLogSink;

/// Longitud máxima del cuerpo de respuesta que se vuelca en los logs.
///
/// Mantener acotado evita volcar payloads enormes a `logcat`. Al truncar se
/// anexa la longitud original para no perder esa señal.
const int kNetLogBodyMaxChars = 500;

/// Prefijo (tag) de los errores de red mapeados por el interceptor.
const String kNetErrorTag = '[NET-ERR]';

/// Prefijo (tag) de los errores de parseo (200 OK con cuerpo mal formado).
const String kParseErrorTag = '[PARSE-ERR]';

/// Interceptor de observabilidad de red (punto D).
///
/// SOLO observa; nunca altera el comportamiento: siempre reenvía con
/// `handler.next(...)`, de modo que el `Failure` mapeado por el
/// `ErrorInterceptor` sigue propagándose igual que antes.
///
/// Se coloca DESPUÉS del `ErrorInterceptor` en la cadena: como
/// `ErrorInterceptor` hace `err.copyWith(error: failure)` conservando
/// `err.response`, aquí seguimos leyendo `statusCode`/`data` reales.
///
/// Gating por entorno (NO por `kDebugMode`): registra únicamente cuando
/// `Environment.enableLogging` es `true` (true en el flavor dev según
/// `env/dev.json`). Así el log aparece en dev independientemente del modo de
/// compilación.
class LoggingInterceptor extends Interceptor {
  // Nombres de parámetro públicos (`environment`/`sink`) distintos de los
  // campos privados, por eso no se usan initializing formals.
  // ignore_for_file: prefer_initializing_formals
  LoggingInterceptor({Environment? environment, NetLogSink? sink})
      : _environment = environment,
        _sink = sink;

  /// Entorno inyectable para tests; si es `null` se resuelve en caliente a
  /// [Environment.current] para no capturar el valor en el constructor.
  final Environment? _environment;

  /// Sink inyectable para tests; si es `null` se usa el [netLogSink] global.
  final NetLogSink? _sink;

  bool get _enabled => (_environment ?? Environment.current).enableLogging;

  void _emit(String message) => (_sink ?? netLogSink)(message);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_enabled) {
      _emit(formatNetError(err));
    }
    // No-op sobre el comportamiento: reenviar el error tal cual.
    handler.next(err);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    // Deliberadamente NO se vuelca el cuerpo de las respuestas correctas (ruido).
    // Solo una línea mínima a modo de traza, también gated por entorno.
    if (_enabled) {
      final req = response.requestOptions;
      _emit('[NET] <-- ${response.statusCode ?? 'n/a'} ${req.method} ${req.uri}');
    }
    handler.next(response);
  }
}

/// Construye la línea/bloque de log de un error de red.
///
/// Formato (una línea de cabecera + opcionalmente el cuerpo truncado):
/// `[NET-ERR] METHOD <uri> status=<code|n/a> type=<DioExceptionType> body=<...>`
/// y cuando no hay respuesta (error de transporte) añade `message=<...>`.
String formatNetError(DioException err) {
  final req = err.requestOptions;
  final status = err.response?.statusCode?.toString() ?? 'n/a';
  final buffer = StringBuffer()
    ..write('$kNetErrorTag ${req.method} ${req.uri} ')
    ..write('status=$status ')
    ..write('type=${err.type}');

  final response = err.response;
  if (response != null) {
    buffer.write(' body=${truncateBody(response.data)}');
  } else {
    // Error de transporte (timeouts, conexión, socket): no hay cuerpo.
    buffer.write(' message=${err.message ?? err.error ?? 'sin detalle'}');
  }
  return buffer.toString();
}

/// Construye la línea de log de un error de parseo (200 OK con cuerpo que no
/// casa con la forma esperada → el repo lanza fuera de una `DioException`).
///
/// Formato: `[PARSE-ERR] <path> error=<error> body=<... truncado ...>`
String formatParseError(String path, Object error, {dynamic rawBody}) {
  final buffer = StringBuffer()
    ..write('$kParseErrorTag $path ')
    ..write('error=$error');
  if (rawBody != null) {
    buffer.write(' body=${truncateBody(rawBody)}');
  }
  return buffer.toString();
}

/// Registra un error de parseo si el logging está habilitado para el entorno.
///
/// DRY: lo usan los repositorios en su `catch (e)` genérico para hacer visible
/// el caso 200-OK-pero-cuerpo-mal-formado (que nunca pasa por `onError`).
/// NO cambia ningún `Result`: solo emite el log antes de que el repo devuelva
/// su `Err` habitual.
void logNetworkParseError(
  String path,
  Object error, {
  dynamic rawBody,
  Environment? environment,
  NetLogSink? sink,
}) {
  final enabled = (environment ?? Environment.current).enableLogging;
  if (!enabled) return;
  (sink ?? netLogSink)(formatParseError(path, error, rawBody: rawBody));
}

/// Convierte un cuerpo arbitrario a texto y lo trunca a [kNetLogBodyMaxChars].
///
/// - `Map`/`List` → `jsonEncode` (con fallback a `toString()` si no es
///   serializable).
/// - cualquier otro → `toString()`.
/// Al truncar, anexa `…(<N> chars)` con la longitud original.
String truncateBody(dynamic data) {
  if (data == null) return 'null';
  String text;
  if (data is String) {
    text = data;
  } else if (data is Map || data is List) {
    try {
      text = jsonEncode(data);
    } catch (_) {
      text = data.toString();
    }
  } else {
    text = data.toString();
  }

  if (text.length <= kNetLogBodyMaxChars) {
    return text;
  }
  final original = text.length;
  return '${text.substring(0, kNetLogBodyMaxChars)}…(truncado de $original chars)';
}
