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
  Future<void> signOut() => _auth.signOut();
}
