// Fake de [PhoneAuthService] para los tests de autenticación (tareas 1.9/1.10).
//
// NO toca Firebase ni la red: simula el flujo de OTP en memoria para poder
// verificar que la UI/controlador llaman a `verifyPhoneNumber` con el número
// E.164 correcto, que un código correcto inicia sesión, y que un código
// incorrecto surfacea un error.

import 'package:catalogos/features/auth/domain/phone_auth_service.dart';

class FakePhoneAuthService implements PhoneAuthService {
  FakePhoneAuthService({
    this.validCode = '123456',
    this.verificationId = 'verif-id-1',
    this.failVerifyWith,
  });

  /// Código que se considera correcto en [signInWithSmsCode].
  final String validCode;

  /// `verificationId` que se entrega en `onCodeSent`.
  final String verificationId;

  /// Si no es `null`, [verifyPhoneNumber] reporta este error en vez de enviar.
  final PhoneAuthFailure? failVerifyWith;

  /// Registro de los números a los que se "envió" OTP (para aserciones).
  final List<String> verifyCalls = <String>[];

  /// Número de veces que se llamó a [verifyPhoneNumber] (incluye reenvíos).
  int get verifyCount => verifyCalls.length;

  /// Último `resendToken` recibido.
  int? lastResendToken;

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCallbacks callbacks,
    int? resendToken,
  }) async {
    verifyCalls.add(phoneNumber);
    lastResendToken = resendToken;
    if (failVerifyWith != null) {
      callbacks.onError(failVerifyWith!);
      return;
    }
    // Entrega un verificationId y un resendToken incremental.
    callbacks.onCodeSent(verificationId, verifyCalls.length);
  }

  @override
  Future<PhoneSignInResult> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    if (smsCode != validCode) {
      throw const PhoneAuthFailure(
        code: 'invalid-verification-code',
        message:
            'El código ingresado no es válido. Verifícalo e inténtalo de nuevo.',
      );
    }
    return const PhoneSignInResult(
      uid: 'uid-123',
      idToken: 'id-token-abc',
      phoneNumber: '+573001234567',
    );
  }
}
