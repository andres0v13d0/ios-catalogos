import 'package:firebase_auth/firebase_auth.dart';

import '../domain/phone_auth_service.dart';

/// Implementación de [PhoneAuthService] respaldada por `firebase_auth`.
///
/// Envuelve `FirebaseAuth.verifyPhoneNumber` y `signInWithCredential`. Es la
/// ÚNICA clase de la feature que conoce tipos de Firebase; el resto del código
/// (controlador, UI, tests) depende solo de [PhoneAuthService], por lo que en
/// tests se inyecta un fake y no se toca Firebase real.
class FirebasePhoneAuthService implements PhoneAuthService {
  FirebasePhoneAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCallbacks callbacks,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: resendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        final onAuto = callbacks.onAutoVerified;
        if (onAuto == null) return;
        try {
          final result = await _signInWithCredential(
            credential,
            fallbackPhone: phoneNumber,
          );
          onAuto(result);
        } on PhoneAuthFailure catch (failure) {
          callbacks.onError(failure);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        callbacks.onError(mapFirebaseAuthException(e));
      },
      codeSent: (String verificationId, int? forceResendingToken) {
        callbacks.onCodeSent(verificationId, forceResendingToken);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        callbacks.onAutoRetrievalTimeout?.call(verificationId);
      },
    );
  }

  @override
  Future<PhoneSignInResult> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _signInWithCredential(credential);
  }

  Future<PhoneSignInResult> _signInWithCredential(
    PhoneAuthCredential credential, {
    String? fallbackPhone,
  }) async {
    try {
      final cred = await _auth.signInWithCredential(credential);
      final user = cred.user;
      if (user == null) {
        throw const PhoneAuthFailure(
          code: 'no-user',
          message: 'No se pudo iniciar sesión. Inténtalo de nuevo.',
        );
      }
      final idToken = await user.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw const PhoneAuthFailure(
          code: 'no-id-token',
          message: 'No se pudo obtener el token de sesión. Inténtalo de nuevo.',
        );
      }
      return PhoneSignInResult(
        uid: user.uid,
        idToken: idToken,
        phoneNumber: user.phoneNumber ?? fallbackPhone,
      );
    } on FirebaseAuthException catch (e) {
      throw mapFirebaseAuthException(e);
    }
  }
}

/// Mapea un [FirebaseAuthException] a un [PhoneAuthFailure] con mensaje en
/// español apto para mostrar al usuario (tarea 1.10 "manejo de errores").
PhoneAuthFailure mapFirebaseAuthException(FirebaseAuthException e) {
  final message = switch (e.code) {
    'invalid-verification-code' =>
      'El código ingresado no es válido. Verifícalo e inténtalo de nuevo.',
    'invalid-verification-id' =>
      'La verificación expiró. Solicita un nuevo código.',
    'session-expired' =>
      'El código expiró. Solicita uno nuevo.',
    'invalid-phone-number' =>
      'El número de teléfono no es válido.',
    'missing-phone-number' =>
      'Ingresa un número de teléfono.',
    'too-many-requests' =>
      'Demasiados intentos. Espera un momento e inténtalo más tarde.',
    'quota-exceeded' =>
      'Se superó el límite de envíos. Inténtalo más tarde.',
    'network-request-failed' =>
      'No se pudo conectar. Revisa tu conexión e inténtalo de nuevo.',
    'app-not-authorized' =>
      'La app no está autorizada para usar autenticación por teléfono.',
    _ => 'No se pudo completar la verificación. Inténtalo de nuevo.',
  };
  return PhoneAuthFailure(code: e.code, message: message);
}
