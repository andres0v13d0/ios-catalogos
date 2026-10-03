import '../../../core/network/token_provider.dart';
import '../domain/auth_user_service.dart';

/// [TokenProvider] respaldado por Firebase a través de [AuthUserService]
/// (tarea 1.12).
///
/// Fuente de verdad del `idToken` para la cadena de red (AuthInterceptor):
/// pide el token al [AuthUserService] actual, que lo deriva de
/// `FirebaseAuth.currentUser.getIdToken()` (refrescando cuando hace falta).
///
/// Reemplaza al [StaticTokenProvider]/`SessionTokenProvider` en memoria: ya no
/// guardamos el token en el estado de la sesión, sino que lo obtenemos
/// on-demand de Firebase (que lo persiste y refresca por nosotros).
class FirebaseTokenProvider implements TokenProvider {
  const FirebaseTokenProvider(this._authUserService);

  final AuthUserService _authUserService;

  @override
  Future<String?> getIdToken() => _authUserService.getIdToken();
}
