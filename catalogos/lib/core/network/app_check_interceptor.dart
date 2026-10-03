import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'app_check_token_source.dart';

/// Interceptor de App Check de Firebase (tarea 1.11).
///
/// Adjunta la cabecera `X-Firebase-AppCheck: <token>` a cada petición saliente,
/// obteniendo el token de un [AppCheckTokenSource] inyectable (la fuente real
/// usa `firebase_app_check`; los tests inyectan un fake).
///
/// RESILIENCIA (requisito de la tarea 1.11): si la obtención del token falla
/// (o devuelve vacío) la petición continúa SIN la cabecera y se registra una
/// advertencia, de modo que el desarrollo sin App Check configurado siga
/// funcionando. El backend decide si rechaza las peticiones sin App Check.
class AppCheckInterceptor extends Interceptor {
  AppCheckInterceptor(this._tokenSource);

  final AppCheckTokenSource _tokenSource;

  /// Nombre de la cabecera de App Check usada por el backend.
  static const String appCheckHeader = 'X-Firebase-AppCheck';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _tokenSource.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers[appCheckHeader] = token;
      } else {
        debugPrint(
          '[AppCheck] token no disponible; la petición continúa sin la '
          'cabecera $appCheckHeader.',
        );
      }
    } catch (error) {
      // No bloquear la petición si App Check falla (p. ej. dev sin config).
      debugPrint(
        '[AppCheck] fallo al obtener el token; la petición continúa sin la '
        'cabecera $appCheckHeader. Detalle: $error',
      );
    }
    handler.next(options);
  }
}
