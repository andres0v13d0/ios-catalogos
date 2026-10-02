import 'package:dio/dio.dart';

import 'token_provider.dart';

/// Interceptor que adjunta el `idToken` de Firebase a las peticiones salientes.
///
/// Equivalente móvil de `secureFetch.ts` del frontend web (diseño §2.4):
/// inyecta `Authorization: Bearer <idToken>` cuando hay sesión. El token se
/// obtiene de un [TokenProvider] inyectable, de modo que la fuente real
/// (Firebase) se enchufa en la tarea 1.12 y puede stubearse en tests.
///
/// El refresco automático y el reintento único ante 401 se abordan junto con
/// la sesión real (tarea 1.12); aquí solo se adjunta el token disponible.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._tokenProvider);

  final TokenProvider _tokenProvider;

  /// Nombre de la cabecera de autorización.
  static const String authorizationHeader = 'Authorization';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Si no hay token (o falla su obtención), la petición continúa sin la
    // cabecera; el backend responderá 401 y el ErrorInterceptor lo mapeará.
    final token = await _tokenProvider.getIdToken();
    if (token != null && token.isNotEmpty) {
      options.headers[authorizationHeader] = 'Bearer $token';
    }
    handler.next(options);
  }
}
