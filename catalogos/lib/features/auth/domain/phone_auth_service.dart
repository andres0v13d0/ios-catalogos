/// Abstracción del servicio de autenticación telefónica de Firebase.
///
/// La UI y el controlador (tareas 1.9/1.10) dependen de esta interfaz, NO de
/// `FirebaseAuth` directamente, para poder:
/// - inyectar la implementación real respaldada por `firebase_auth`
///   ([FirebasePhoneAuthService]) en la app, y
/// - inyectar un fake en los tests (sin tocar Firebase ni la red real).
///
/// Cubre el flujo de OTP:
/// 1. [verifyPhoneNumber] envía el SMS (callbacks de codeSent / verificación
///    automática / error).
/// 2. [signInWithSmsCode] crea la credencial con el `verificationId` + el
///    código ingresado y hace `signInWithCredential`, devolviendo el `idToken`.
library;

/// Resultado de un inicio de sesión exitoso con OTP.
class PhoneSignInResult {
  const PhoneSignInResult({
    required this.uid,
    required this.idToken,
    this.phoneNumber,
  });

  /// UID de Firebase del usuario autenticado.
  final String uid;

  /// `idToken` de Firebase (JWT) a enviar como `Authorization: Bearer <token>`.
  final String idToken;

  /// Teléfono E.164 asociado al usuario, si Firebase lo expone.
  final String? phoneNumber;
}

/// Callbacks del flujo [PhoneAuthService.verifyPhoneNumber].
///
/// Reflejan la superficie de `FirebaseAuth.verifyPhoneNumber` pero sin exponer
/// tipos de Firebase, de modo que la capa de presentación quede desacoplada.
class PhoneVerificationCallbacks {
  const PhoneVerificationCallbacks({
    required this.onCodeSent,
    required this.onError,
    this.onAutoVerified,
    this.onAutoRetrievalTimeout,
  });

  /// Se invoca cuando el SMS con el código fue enviado. Entrega el
  /// `verificationId` (necesario para construir la credencial) y, si está
  /// disponible, el `resendToken` para reenvíos.
  final void Function(String verificationId, int? resendToken) onCodeSent;

  /// Se invoca ante un error de envío/verificación. Entrega un
  /// [PhoneAuthFailure] con un mensaje apto para la UI.
  final void Function(PhoneAuthFailure failure) onError;

  /// (Opcional) Verificación automática (p. ej. Android auto-retrieval): el
  /// dispositivo resolvió el OTP y ya hay sesión; entrega el resultado.
  final void Function(PhoneSignInResult result)? onAutoVerified;

  /// (Opcional) Expiró el tiempo de auto-recuperación del SMS; entrega el
  /// `verificationId` vigente.
  final void Function(String verificationId)? onAutoRetrievalTimeout;
}

/// Fallo de autenticación telefónica con un mensaje seguro para la UI.
///
/// [code] conserva el código original de Firebase (p. ej.
/// `invalid-verification-code`, `invalid-phone-number`) para que la UI pueda
/// ramificar o registrar sin acoplarse a excepciones de Firebase.
class PhoneAuthFailure implements Exception {
  const PhoneAuthFailure({required this.code, required this.message});

  /// Código estable del error (de Firebase o `unknown`).
  final String code;

  /// Mensaje legible en español para mostrar al usuario.
  final String message;

  @override
  String toString() => 'PhoneAuthFailure($code): $message';
}

/// Interfaz de autenticación telefónica (OTP) desacoplada de Firebase.
abstract interface class PhoneAuthService {
  /// Envía el OTP al [phoneNumber] (en formato E.164, p. ej. `+573001234567`).
  ///
  /// Las implementaciones NO deben lanzar: cualquier error se reporta vía
  /// [PhoneVerificationCallbacks.onError]. [resendToken] permite reenviar el
  /// SMS reutilizando el token entregado por un `onCodeSent` previo.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCallbacks callbacks,
    int? resendToken,
  });

  /// Crea la credencial con [verificationId] + [smsCode], inicia sesión y
  /// devuelve el [PhoneSignInResult] (incluye el `idToken`).
  ///
  /// Lanza [PhoneAuthFailure] si el código es inválido/expiró o falla el login.
  Future<PhoneSignInResult> signInWithSmsCode({
    required String verificationId,
    required String smsCode,
  });
}
