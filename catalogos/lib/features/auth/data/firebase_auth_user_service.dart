import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_user_service.dart';

/// Implementación de [AuthUserService] respaldada por `firebase_auth`
/// (tarea 1.12).
///
/// Es una de las pocas clases que conocen tipos de Firebase; el resto del
/// código (SessionController, TokenProvider, UI, tests) depende solo de
/// [AuthUserService], por lo que en tests se inyecta un fake y no se toca
/// Firebase real.
class FirebaseAuthUserService implements AuthUserService {
  FirebaseAuthUserService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  AuthUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    return AuthUser(uid: user.uid, phoneNumber: user.phoneNumber);
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken(forceRefresh);
    } catch (_) {
      // No lanzamos: la red saldrá sin cabecera y el backend responderá 401,
      // que la política de 401 → logout gestionará.
      return null;
    }
  }

  @override
  Future<SignInResult> signInWithCustomToken(String customToken) async {
    try {
      final cred = await _auth.signInWithCustomToken(customToken);
      final user = cred.user;
      if (user == null) {
        throw const SignInWithCustomTokenException(
          'No se pudo iniciar sesión. Inténtalo de nuevo.',
        );
      }
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw const SignInWithCustomTokenException(
          'No se pudo obtener el token de sesión. Inténtalo de nuevo.',
        );
      }
      return SignInResult(
        uid: user.uid,
        idToken: idToken,
        phoneNumber: user.phoneNumber,
      );
    } on SignInWithCustomTokenException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw SignInWithCustomTokenException(
        'No se pudo validar la sesión. Inténtalo de nuevo.',
        cause: e,
      );
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
