// Fakes para el flujo de login revendedor por código WhatsApp (tareas
// 1.9/1.10/1.13a). NO tocan Firebase ni la red real.
//
// - [FakeAuthRepository]: simula los 3 endpoints (`request-code`,
//   `resend-code`, `verify-code`) en memoria, registrando llamadas para las
//   aserciones y permitiendo inyectar fallos (400/429/502) por caso.
// - [FakeAuthUserService]: simula `signInWithCustomToken` (y el resto de la
//   superficie de `AuthUserService`) para verificar que el controlador canjea
//   el `customToken` recibido.

import 'package:catalogos/core/result/failure.dart';
import 'package:catalogos/core/result/result.dart';
import 'package:catalogos/features/auth/domain/auth_repository.dart';
import 'package:catalogos/features/auth/domain/auth_user_service.dart';
import 'package:catalogos/shared/models/reseller.dart';

/// Fake de [AuthRepository] con control total sobre las respuestas.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.validCode = '123456',
    this.expiresInSeconds = 300,
    this.resendAvailableInSeconds = 60,
    this.customToken = 'custom-token-abc',
    this.isNewProfile = false,
    this.requestFailure,
    this.verifyFailure,
    Reseller? reseller,
  }) : reseller = reseller ??
            const Reseller(
              id: 7,
              telefonoE164: '+573001234567',
              countryCode: 'CO',
              nombre: 'Juan',
            );

  /// Código considerado correcto en [verifyCode].
  final String validCode;
  final int expiresInSeconds;
  final int resendAvailableInSeconds;
  final String customToken;
  final bool isNewProfile;
  final Reseller reseller;

  /// Si no es `null`, [requestCode]/[resendCode] devuelven este fallo.
  final Failure? requestFailure;

  /// Si no es `null`, [verifyCode] devuelve este fallo (ignora [validCode]).
  final Failure? verifyFailure;

  /// Registro de teléfonos pasados a [requestCode]/[resendCode].
  final List<String> requestCalls = <String>[];
  final List<String> resendCalls = <String>[];

  /// Registro de (phone, code) pasados a [verifyCode].
  final List<({String phone, String code})> verifyCalls =
      <({String phone, String code})>[];

  RequestCodeResult get _ok => RequestCodeResult(
        expiresInSeconds: expiresInSeconds,
        resendAvailableInSeconds: resendAvailableInSeconds,
      );

  @override
  Future<Result<RequestCodeResult>> requestCode({
    required String phoneNumber,
    String? countryCode,
  }) async {
    requestCalls.add(phoneNumber);
    if (requestFailure != null) {
      return Err<RequestCodeResult>(requestFailure!);
    }
    return Ok<RequestCodeResult>(_ok);
  }

  @override
  Future<Result<RequestCodeResult>> resendCode({
    required String phoneNumber,
    String? countryCode,
  }) async {
    resendCalls.add(phoneNumber);
    if (requestFailure != null) {
      return Err<RequestCodeResult>(requestFailure!);
    }
    return Ok<RequestCodeResult>(_ok);
  }

  @override
  Future<Result<VerifyCodeResult>> verifyCode({
    required String phoneNumber,
    required String code,
    String? countryCode,
  }) async {
    verifyCalls.add((phone: phoneNumber, code: code));
    if (verifyFailure != null) {
      return Err<VerifyCodeResult>(verifyFailure!);
    }
    if (code != validCode) {
      return Err<VerifyCodeResult>(
        const ValidationFailure(message: 'Código incorrecto'),
      );
    }
    return Ok<VerifyCodeResult>(
      VerifyCodeResult(
        customToken: customToken,
        reseller: reseller,
        isNewProfile: isNewProfile,
      ),
    );
  }
}

/// Fake de [AuthUserService] que simula `signInWithCustomToken`.
class FakeAuthUserService implements AuthUserService {
  FakeAuthUserService({
    this.uid = 'uid-123',
    this.idToken = 'id-token-abc',
    this.failSignIn = false,
  });

  final String uid;
  final String idToken;

  /// Si es `true`, [signInWithCustomToken] lanza.
  final bool failSignIn;

  /// Tokens pasados a [signInWithCustomToken] (para aserciones).
  final List<String> customTokens = <String>[];

  AuthUser? _current;
  bool signedOut = false;

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async =>
      _current == null ? null : idToken;

  @override
  Future<SignInResult> signInWithCustomToken(String customToken) async {
    customTokens.add(customToken);
    if (failSignIn) {
      throw const SignInWithCustomTokenException(
        'No se pudo validar la sesión. Inténtalo de nuevo.',
      );
    }
    _current = AuthUser(uid: uid, phoneNumber: '+573001234567');
    return SignInResult(
      uid: uid,
      idToken: idToken,
      phoneNumber: '+573001234567',
    );
  }

  @override
  Future<void> signOut() async {
    _current = null;
    signedOut = true;
  }
}
