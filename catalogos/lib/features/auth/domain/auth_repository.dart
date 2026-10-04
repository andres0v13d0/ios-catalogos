import '../../../core/result/result.dart';
import '../../../shared/models/reseller.dart';

/// Interfaz del flujo de login revendedor por código WhatsApp (tarea 1.13a).
///
/// Reemplaza a `PhoneAuthService` (Firebase Phone Auth) por el flujo aprobado
/// (ver `design.md` §4.0.10): el backend envía el código por WhatsApp y, tras
/// verificarlo, devuelve un `customToken` de Firebase que la app canjea con
/// `signInWithCustomToken` (ver [AuthUserService]).
///
/// Cubre los 3 endpoints PÚBLICOS (protegidos por App Check) en camelCase:
/// - `POST /auth/reseller/request-code`
/// - `POST /auth/reseller/resend-code`
/// - `POST /auth/reseller/verify-code`
///
/// La capa de presentación ([AuthController]) y los tests dependen de esta
/// interfaz, NO de Dio ni de contratos HTTP, para poder inyectar un fake.
/// Las implementaciones NO lanzan: devuelven `Result<T>` (`Err` con un
/// [Failure] mapeado: 400 → validación, 429 → bloqueo/cooldown, 502/503 →
/// fallo de envío).
abstract interface class AuthRepository {
  /// `POST /auth/reseller/request-code` — solicita el envío del código por
  /// WhatsApp al [phoneNumber] (E.164). [countryCode] es opcional (ISO).
  ///
  /// Devuelve [RequestCodeResult] con los tiempos de expiración/reenvío. NUNCA
  /// devuelve el código.
  Future<Result<RequestCodeResult>> requestCode({
    required String phoneNumber,
    String? countryCode,
  });

  /// `POST /auth/reseller/resend-code` — reenvía el código. El backend aplica
  /// un cooldown de 60s (429 con `resendAvailableInSeconds` si está activo).
  Future<Result<RequestCodeResult>> resendCode({
    required String phoneNumber,
    String? countryCode,
  });

  /// `POST /auth/reseller/verify-code` — verifica el [code] para el
  /// [phoneNumber]. En éxito devuelve [VerifyCodeResult] con el `customToken`,
  /// el reseller y `isNewProfile`.
  ///
  /// 400 → código incorrecto/expirado (mensaje del backend); 429 → lockout.
  Future<Result<VerifyCodeResult>> verifyCode({
    required String phoneNumber,
    required String code,
    String? countryCode,
  });
}

/// Resultado de `request-code` / `resend-code`.
class RequestCodeResult {
  const RequestCodeResult({
    required this.expiresInSeconds,
    required this.resendAvailableInSeconds,
  });

  /// Segundos hasta que el código expira (p. ej. 300 = 5 min).
  final int expiresInSeconds;

  /// Segundos hasta que se puede volver a solicitar/reenviar el código
  /// (cooldown, p. ej. 60).
  final int resendAvailableInSeconds;

  /// Parsea el JSON del backend (camelCase). Tolera campos ausentes con 0.
  factory RequestCodeResult.fromJson(Map<String, dynamic> json) {
    return RequestCodeResult(
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 0,
      resendAvailableInSeconds:
          (json['resendAvailableInSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Resultado de `verify-code` en caso de éxito.
class VerifyCodeResult {
  const VerifyCodeResult({
    required this.customToken,
    required this.reseller,
    required this.isNewProfile,
  });

  /// Custom token de Firebase a canjear con `signInWithCustomToken`.
  final String customToken;

  /// Reseller resuelto/creado por el backend (sin `firebaseUid`).
  final Reseller reseller;

  /// `true` si el reseller se creó en este login (perfil nuevo); la UI lo usa
  /// para decidir si enruta a completar perfil (tarea 1.13).
  final bool isNewProfile;

  /// Parsea el JSON del backend (camelCase):
  /// `{ customToken, reseller:{...}, isNewProfile }`.
  factory VerifyCodeResult.fromJson(Map<String, dynamic> json) {
    final resellerJson = json['reseller'];
    final map = resellerJson is Map
        ? Map<String, dynamic>.from(resellerJson)
        : <String, dynamic>{};
    return VerifyCodeResult(
      customToken: json['customToken'] as String,
      reseller: Reseller.fromJson(map),
      isNewProfile: json['isNewProfile'] as bool? ?? false,
    );
  }
}
