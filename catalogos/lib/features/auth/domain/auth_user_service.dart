/// Abstracción del estado de usuario/sesión de Firebase (tarea 1.12).
///
/// La capa de presentación (SessionController) y la de red (TokenProvider)
/// dependen de esta interfaz, NO de `FirebaseAuth` directamente, para poder:
/// - inyectar la implementación real respaldada por `firebase_auth`
///   ([FirebaseAuthUserService]) en la app, y
/// - inyectar un fake en los tests (sin tocar Firebase ni la red real).
///
/// Decisión de diseño (persistencia de sesión):
/// `firebase_auth` YA persiste su propio usuario entre reinicios de la app, y
/// el `idToken` es efímero (expira en ~1h). Por eso NO guardamos el `idToken`
/// en almacenamiento seguro: lo derivamos on-demand con [getIdToken]
/// (que refresca cuando hace falta). El `flutter_secure_storage` solo se usa
/// para metadatos del lado de la app (ver `SessionStore`).
library;

/// Usuario autenticado mínimo expuesto a las capas superiores, sin tipos de
/// Firebase.
class AuthUser {
  const AuthUser({required this.uid, this.phoneNumber});

  /// UID de Firebase.
  final String uid;

  /// Teléfono E.164 asociado, si Firebase lo expone.
  final String? phoneNumber;
}

/// Servicio de estado de usuario/sesión desacoplado de Firebase.
abstract interface class AuthUserService {
  /// Usuario actualmente autenticado según Firebase, o `null` si no hay
  /// sesión (p. ej. tras un reinicio sin usuario persistido).
  AuthUser? get currentUser;

  /// Devuelve el `idToken` del usuario actual (refrescándolo si [forceRefresh]
  /// es `true` o si Firebase determina que está por expirar), o `null` si no
  /// hay sesión. No debe lanzar: ante un fallo devuelve `null`.
  Future<String?> getIdToken({bool forceRefresh = false});

  /// Cierra la sesión de Firebase.
  Future<void> signOut();
}
