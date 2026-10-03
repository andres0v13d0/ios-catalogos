import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_auth_user_service.dart';
import '../data/session_store.dart';
import '../domain/auth_user_service.dart';

/// Estado de autenticación de la sesión.
///
/// Fase 0.5 lo introdujo como placeholder (solo `signedOut`/`signedIn`).
/// Fase 1 (tareas 1.9–1.10) lo convirtió en un estado de sesión real.
///
/// Tarea 1.12 — sesión persistente REAL:
/// `firebase_auth` ya persiste su propio usuario entre reinicios y el `idToken`
/// se deriva on-demand de `currentUser.getIdToken()`. Por eso la sesión ya no
/// vive en memoria como fuente de verdad: al arrancar, [restoreSession]
/// consulta Firebase (vía [AuthUserService]) y restaura `signedIn` si hay
/// usuario. El [logout] cierra sesión en Firebase y limpia el almacenamiento
/// seguro de metadatos. Una política de 401 persistente invoca [logout]
/// (ver `dioProvider`).
enum AuthStatus {
  /// No hay sesión activa.
  signedOut,

  /// Hay una sesión activa.
  signedIn,
}

/// Sesión del revendedor autenticado.
class AuthSession {
  const AuthSession({
    required this.uid,
    this.idToken,
    this.phoneNumber,
  });

  /// UID de Firebase.
  final String uid;

  /// `idToken` de Firebase, si se capturó en el flujo de login.
  ///
  /// NOTA: ya no es la fuente de verdad para la cabecera `Authorization`; esa
  /// la provee `FirebaseTokenProvider` (que lo deriva de Firebase y refresca).
  /// Se conserva por compatibilidad con el flujo de OTP y los tests.
  final String? idToken;

  /// Teléfono E.164 asociado, si está disponible.
  final String? phoneNumber;
}

/// Notifier de la sesión.
///
/// Mantiene el estado derivado ([AuthStatus]) y la [AuthSession] actual.
class AuthStateNotifier extends Notifier<AuthStatus> {
  AuthSession? _session;

  /// Sesión actual, o `null` si no hay sesión.
  AuthSession? get session => _session;

  AuthUserService get _authUserService => ref.read(authUserServiceProvider);
  SessionStore get _sessionStore => ref.read(sessionStoreProvider);

  @override
  AuthStatus build() => AuthStatus.signedOut;

  /// Restaura la sesión al arrancar la app (tarea 1.12).
  ///
  /// Si `firebase_auth` tiene un `currentUser` persistido, marca la sesión como
  /// `signedIn` (para que el router no rebote a `/login`). Si no, `signedOut`.
  Future<void> restoreSession() async {
    final user = _authUserService.currentUser;
    if (user != null) {
      _session = AuthSession(uid: user.uid, phoneNumber: user.phoneNumber);
      state = AuthStatus.signedIn;
    } else {
      _session = null;
      state = AuthStatus.signedOut;
    }
  }

  /// Marca la sesión como autenticada con las credenciales reales obtenidas
  /// del flujo OTP (tarea 1.10).
  void signInWithToken({
    required String uid,
    required String idToken,
    String? phoneNumber,
  }) {
    _session = AuthSession(
      uid: uid,
      idToken: idToken,
      phoneNumber: phoneNumber,
    );
    state = AuthStatus.signedIn;
  }

  /// Atajo de compatibilidad: marca la sesión como autenticada sin credenciales
  /// (solo para pruebas/placeholder; no establece [session]).
  void signIn() => state = AuthStatus.signedIn;

  /// Cierra la sesión SOLO en el estado local (vuelve a `signedOut` y descarta
  /// la sesión). No toca Firebase ni el almacenamiento; para el cierre completo
  /// usar [logout].
  void signOut() {
    _session = null;
    state = AuthStatus.signedOut;
  }

  /// Cierre de sesión COMPLETO (tarea 1.12):
  /// `FirebaseAuth.signOut()` + limpieza del almacenamiento seguro de
  /// metadatos + estado local a `signedOut`. Lo usa tanto la acción de logout
  /// de la UI como la política de 401 persistente.
  Future<void> logout() async {
    try {
      await _authUserService.signOut();
    } finally {
      await _sessionStore.clear();
      signOut();
    }
  }
}

/// Provider del estado de autenticación. Por defecto: [AuthStatus.signedOut].
final NotifierProvider<AuthStateNotifier, AuthStatus> authStateProvider =
    NotifierProvider<AuthStateNotifier, AuthStatus>(AuthStateNotifier.new);

/// Conveniencia: `true` si hay sesión activa.
final Provider<bool> isSignedInProvider = Provider<bool>(
  (Ref ref) => ref.watch(authStateProvider) == AuthStatus.signedIn,
);

/// Provider del [AuthUserService] (Firebase). Los tests lo sobreescriben con un
/// fake para no tocar Firebase real.
final Provider<AuthUserService> authUserServiceProvider =
    Provider<AuthUserService>((Ref ref) => FirebaseAuthUserService());

/// Provider del [SessionStore] (secure storage). Los tests lo sobreescriben.
final Provider<SessionStore> sessionStoreProvider =
    Provider<SessionStore>((Ref ref) => SecureSessionStore());
