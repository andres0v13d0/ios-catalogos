import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../../../core/utils/phone.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/firebase_phone_auth_service.dart';
import '../domain/phone_auth_service.dart';
import 'auth_state_provider.dart';

/// Etapa del flujo de autenticación por OTP.
enum AuthFlowStage {
  /// Ingreso de teléfono (aún no se envió el código).
  phoneEntry,

  /// Enviando el OTP (verifyPhoneNumber en curso).
  sendingCode,

  /// Código enviado; esperando que el usuario ingrese el OTP.
  codeSent,

  /// Verificando el OTP (signInWithCredential en curso).
  verifying,

  /// Sesión iniciada con éxito.
  signedIn,
}

/// Estado inmutable del flujo de autenticación (teléfono + OTP).
class AuthFlowState {
  const AuthFlowState({
    this.stage = AuthFlowStage.phoneEntry,
    this.phoneNumberE164,
    this.verificationId,
    this.resendToken,
    this.errorMessage,
  });

  /// Etapa actual del flujo.
  final AuthFlowStage stage;

  /// Teléfono normalizado a E.164 al que se envió (o se enviará) el OTP.
  final String? phoneNumberE164;

  /// Identificador de verificación entregado por `codeSent`; necesario para
  /// construir la credencial al verificar el OTP.
  final String? verificationId;

  /// Token para reenviar el SMS reutilizando la sesión de verificación.
  final int? resendToken;

  /// Mensaje de error legible para la UI (o `null` si no hay error).
  final String? errorMessage;

  bool get isSending => stage == AuthFlowStage.sendingCode;
  bool get isVerifying => stage == AuthFlowStage.verifying;

  AuthFlowState copyWith({
    AuthFlowStage? stage,
    String? phoneNumberE164,
    String? verificationId,
    int? resendToken,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthFlowState(
      stage: stage ?? this.stage,
      phoneNumberE164: phoneNumberE164 ?? this.phoneNumberE164,
      verificationId: verificationId ?? this.verificationId,
      resendToken: resendToken ?? this.resendToken,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controlador del flujo de autenticación por OTP (tareas 1.9/1.10).
///
/// Orquesta [PhoneAuthService] (abstracción mockeable) y, al verificar con
/// éxito, eleva la sesión al [authStateProvider]. No conoce Firebase.
class AuthController extends Notifier<AuthFlowState> {
  @override
  AuthFlowState build() => const AuthFlowState();

  PhoneAuthService get _service => ref.read(phoneAuthServiceProvider);

  /// Envía el OTP al [rawPhone] usando [countryCode] como país por defecto.
  ///
  /// Valida y normaliza a E.164 con `normalizeToE164`. Devuelve el E.164
  /// enviado, o `null` si el número no es válido (en cuyo caso deja un
  /// `errorMessage` de formato en el estado).
  Future<String?> sendCode({
    required String rawPhone,
    String countryCode = defaultCountryCode,
  }) async {
    final e164 = normalizeToE164(rawPhone, countryCode: countryCode);
    if (e164 == null || !isValidE164(e164)) {
      state = state.copyWith(
        stage: AuthFlowStage.phoneEntry,
        errorMessage: 'Ingresa un número de teléfono válido.',
      );
      return null;
    }

    state = state.copyWith(
      stage: AuthFlowStage.sendingCode,
      phoneNumberE164: e164,
      clearError: true,
    );

    await _service.verifyPhoneNumber(
      phoneNumber: e164,
      callbacks: PhoneVerificationCallbacks(
        onCodeSent: (verificationId, resendToken) {
          state = state.copyWith(
            stage: AuthFlowStage.codeSent,
            verificationId: verificationId,
            resendToken: resendToken,
            clearError: true,
          );
        },
        onError: (failure) {
          state = state.copyWith(
            stage: AuthFlowStage.phoneEntry,
            errorMessage: failure.message,
          );
        },
        onAutoVerified: (result) {
          _promoteSession(result);
        },
      ),
    );

    return e164;
  }

  /// Reenvía el OTP al mismo número, reutilizando el `resendToken` si existe.
  Future<void> resendCode() async {
    final phone = state.phoneNumberE164;
    if (phone == null) return;

    state = state.copyWith(stage: AuthFlowStage.sendingCode, clearError: true);

    await _service.verifyPhoneNumber(
      phoneNumber: phone,
      resendToken: state.resendToken,
      callbacks: PhoneVerificationCallbacks(
        onCodeSent: (verificationId, resendToken) {
          state = state.copyWith(
            stage: AuthFlowStage.codeSent,
            verificationId: verificationId,
            resendToken: resendToken,
            clearError: true,
          );
        },
        onError: (failure) {
          state = state.copyWith(
            stage: AuthFlowStage.codeSent,
            errorMessage: failure.message,
          );
        },
        onAutoVerified: (result) {
          _promoteSession(result);
        },
      ),
    );
  }

  /// Verifica el [smsCode] contra el `verificationId` actual. En caso de éxito
  /// eleva la sesión; en caso de error deja un `errorMessage` en el estado.
  ///
  /// Devuelve `true` si el inicio de sesión fue exitoso.
  Future<bool> verifyCode(String smsCode) async {
    final verificationId = state.verificationId;
    if (verificationId == null) {
      state = state.copyWith(
        errorMessage: 'La verificación expiró. Solicita un nuevo código.',
      );
      return false;
    }

    state = state.copyWith(stage: AuthFlowStage.verifying, clearError: true);

    try {
      final result = await _service.signInWithSmsCode(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      _promoteSession(result);
      return true;
    } on PhoneAuthFailure catch (failure) {
      state = state.copyWith(
        stage: AuthFlowStage.codeSent,
        errorMessage: failure.message,
      );
      return false;
    }
  }

  /// Reinicia el flujo al ingreso de teléfono (p. ej. al salir de la pantalla
  /// de OTP para corregir el número).
  void reset() => state = const AuthFlowState();

  void _promoteSession(PhoneSignInResult result) {
    ref.read(authStateProvider.notifier).signInWithToken(
          uid: result.uid,
          idToken: result.idToken,
          phoneNumber: result.phoneNumber,
        );
    state = state.copyWith(stage: AuthFlowStage.signedIn, clearError: true);
    // Tras el login, carga el perfil (`GET /reseller/me`) para que el guard de
    // "perfil incompleto" (tarea 1.13) decida si hay que completar el nombre.
    // No bloqueamos el flujo de OTP: se dispara en segundo plano.
    unawaited(ref.read(profileControllerProvider.notifier).loadProfile());
  }
}

/// Provider del [PhoneAuthService]. Por defecto usa la implementación real de
/// Firebase; los tests lo sobreescriben con un fake.
final Provider<PhoneAuthService> phoneAuthServiceProvider =
    Provider<PhoneAuthService>((Ref ref) => FirebasePhoneAuthService());

/// Provider del controlador del flujo de autenticación.
final NotifierProvider<AuthController, AuthFlowState> authControllerProvider =
    NotifierProvider<AuthController, AuthFlowState>(AuthController.new);
