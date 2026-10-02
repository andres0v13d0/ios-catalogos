import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado de autenticación de la sesión (placeholder de Fase 0.5).
///
/// En Fase 1 (tareas 1.9–1.12) este estado lo alimentará Firebase Phone Auth
/// + secure storage. Por ahora es un simple booleano que arranca en
/// "no autenticado" (`signedOut`), suficiente para que el guard de navegación
/// (`go_router`) redirija a `/login` cuando no hay sesión.
enum AuthStatus {
  /// No hay sesión activa.
  signedOut,

  /// Hay una sesión activa.
  signedIn,
}

/// Notifier placeholder de la sesión.
///
/// Expone [signIn]/[signOut] para que las pantallas (y los tests) puedan
/// alternar el estado. La integración real con Firebase reemplazará esta clase
/// manteniendo la misma superficie pública (`AuthStatus`).
class AuthStateNotifier extends Notifier<AuthStatus> {
  @override
  AuthStatus build() => AuthStatus.signedOut;

  /// Marca la sesión como autenticada (placeholder; sin credenciales reales).
  void signIn() => state = AuthStatus.signedIn;

  /// Cierra la sesión (vuelve a `signedOut`).
  void signOut() => state = AuthStatus.signedOut;
}

/// Provider del estado de autenticación. Por defecto: [AuthStatus.signedOut].
final NotifierProvider<AuthStateNotifier, AuthStatus> authStateProvider =
    NotifierProvider<AuthStateNotifier, AuthStatus>(AuthStateNotifier.new);

/// Conveniencia: `true` si hay sesión activa.
final Provider<bool> isSignedInProvider = Provider<bool>(
  (Ref ref) => ref.watch(authStateProvider) == AuthStatus.signedIn,
);
