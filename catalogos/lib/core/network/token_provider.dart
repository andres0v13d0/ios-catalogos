/// Abstracción de la fuente del `idToken` de Firebase para la capa de red.
///
/// El [AuthInterceptor] depende de esta interfaz (no de Firebase directamente)
/// para poder:
/// - inyectar una implementación real respaldada por `firebase_auth` en la
///   tarea 1.12 (sesión real),
/// - y stubear el token en tests unitarios sin dependencias externas.
abstract interface class TokenProvider {
  /// Devuelve el `idToken` actual, o `null` si no hay sesión activa.
  ///
  /// La implementación real refrescará el token de Firebase cuando sea
  /// necesario (ver diseño §2.4). Las implementaciones no deben lanzar: ante un
  /// fallo al obtener el token, devuelven `null` y la petición saldrá sin
  /// cabecera `Authorization`.
  Future<String?> getIdToken();
}

/// Implementación simple e inyectable de [TokenProvider].
///
/// Útil como placeholder hasta integrar Firebase (tarea 1.12) y en tests.
/// El token puede fijarse de antemano o resolverse perezosamente mediante
/// [resolver].
class StaticTokenProvider implements TokenProvider {
  StaticTokenProvider({String? token, Future<String?> Function()? resolver})
      : _token = token,
        _resolver = resolver;

  String? _token;
  final Future<String?> Function()? _resolver;

  // Nota: no se usan initializing formals (`this._token`) a propósito, para
  // mantener los nombres de parámetro públicos (`token`, `resolver`).
  // ignore_for_file: prefer_initializing_formals

  /// Actualiza el token almacenado (p. ej. tras un login).
  void setToken(String? token) => _token = token;

  @override
  Future<String?> getIdToken() async {
    if (_resolver != null) {
      return _resolver();
    }
    return _token;
  }
}
