import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/phone.dart';
import '../../profile/presentation/profile_controller.dart';
import '../data/backend_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user_service.dart';
import 'auth_state_provider.dart';

/// Etapa del flujo de autenticación por código WhatsApp (tareas 1.9/1.10).
///
/// Se conservan las mismas etapas que el flujo anterior (Phone Auth); solo
/// cambia QUÉ hace cada una: ahora el código lo envía el backend por WhatsApp
/// (`request-code`) y la verificación (`verify-code`) devuelve un `customToken`
/// que se canjea con `signInWithCustomToken`.
enum AuthFlowStage {
  /// Ingreso de teléfono (aún no se solicitó el código).
  phoneEntry,

  /// Solicitando el envío del código (`request-code`/`resend-code` en curso).
  sendingCode,

  /// Código enviado por WhatsApp; esperando que el usuario lo ingrese.
  codeSent,

  /// Verificando el código (`verify-code` + `signInWithCustomToken` en curso).
  verifying,

  /// Sesión iniciada con éxito.
  signedIn,
}

/// Estado inmutable del flujo de autenticación (teléfono + código WhatsApp).
class AuthFlowState {
  const AuthFlowState({
    this.stage = AuthFlowStage.phoneEntry,
    this.phoneNumberE164,
    this.countryCode,
    this.resendAvailableInSeconds,
    this.isNewProfile = false,
    this.errorMessage,
  });

  /// Etapa actual del flujo.
  final AuthFlowStage stage;

  /// Teléfono normalizado a E.164 al que se envió (o se enviará) el código.
  final String? phoneNumberE164;

  /// Código de país (dial code, p. ej. `57`) usado al enviar la solicitud.
  final String? countryCode;

  /// Segundos de cooldown de reenvío informados por el backend
  /// (`resendAvailableInSeconds`, también presente en los 429). La UI puede
  /// usarlo para la cuenta regresiva del botón "Reenviar".
  final int? resendAvailableInSeconds;

  /// `true` si `verify-code` indicó que el perfil es nuevo (tarea 1.13).
  final bool isNewProfile;

  /// Mensaje de error legible para la UI (o `null` si no hay error).
  final String? errorMessage;

  bool get isSending => stage == AuthFlowStage.sendingCode;
  bool get isVerifying => stage == AuthFlowStage.verifying;

  AuthFlowState copyWith({
    AuthFlowStage? stage,
    String? phoneNumberE164,
    String? countryCode,
    int? resendAvailableInSeconds,
    bool? isNewProfile,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthFlowState(
      stage: stage ?? this.stage,
      phoneNumberE164: phoneNumberE164 ?? this.phoneNumberE164,
      countryCode: countryCode ?? this.countryCode,
      resendAvailableInSeconds:
          resendAvailableInSeconds ?? this.resendAvailableInSeconds,
      isNewProfile: isNewProfile ?? this.isNewProfile,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controlador del flujo de login revendedor por código WhatsApp
/// (tareas 1.9/1.10/1.13a).
///
/// Orquesta [AuthRepository] (los 3 endpoints del backend) y, al verificar con
/// éxito, canjea el `customToken` con [AuthUserService.signInWithCustomToken]
/// y eleva la sesión al [authStateProvider]. No conoce Firebase ni Dio
/// directamente (ambos están tras interfaces mockeables).
class AuthController extends Notifier<AuthFlowState> {
  @override
  AuthFlowState build() => const AuthFlowState();

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  AuthUserService get _authUserService => ref.read(authUserServiceProvider);

  /// Solicita el envío del código al [rawPhone] usando [countryCode] (dial
  /// code) como país por defecto (`57` = Colombia).
  ///
  /// Valida/normaliza a E.164. Devuelve el E.164 enviado, o `null` si el número
  /// no es válido (deja un `errorMessage` de formato) o si `request-code` falla
  /// (deja el `errorMessage` mapeado, p. ej. 429 con cooldown).
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
      countryCode: countryCode,
      clearError: true,
    );

    final result = await _repo.requestCode(
      phoneNumber: e164,
      countryCode: countryCode,
    );

    switch (result) {
      case Ok<RequestCodeResult>(:final value):
        state = state.copyWith(
          stage: AuthFlowStage.codeSent,
          resendAvailableInSeconds: value.resendAvailableInSeconds,
          clearError: true,
        );
        return e164;
      case Err<RequestCodeResult>(:final failure):
        state = state.copyWith(
          stage: AuthFlowStage.phoneEntry,
          resendAvailableInSeconds: _secondsOf(failure),
          errorMessage: failure.message,
        );
        return null;
    }
  }

  /// Reenvía el código al mismo número (`resend-code`). Respeta el cooldown de
  /// 60s del backend: si está activo responde 429 → [LockedFailure] y la UI
  /// muestra el error + `resendAvailableInSeconds`.
  Future<void> resendCode() async {
    final phone = state.phoneNumberE164;
    if (phone == null) return;

    state = state.copyWith(stage: AuthFlowStage.sendingCode, clearError: true);

    final result = await _repo.resendCode(
      phoneNumber: phone,
      countryCode: state.countryCode,
    );

    switch (result) {
      case Ok<RequestCodeResult>(:final value):
        state = state.copyWith(
          stage: AuthFlowStage.codeSent,
          resendAvailableInSeconds: value.resendAvailableInSeconds,
          clearError: true,
        );
      case Err<RequestCodeResult>(:final failure):
        state = state.copyWith(
          stage: AuthFlowStage.codeSent,
          resendAvailableInSeconds: _secondsOf(failure),
          errorMessage: failure.message,
        );
    }
  }

  /// Verifica el [code] contra el teléfono actual (`verify-code`). En éxito
  /// canjea el `customToken` con `signInWithCustomToken` y eleva la sesión; en
  /// error deja un `errorMessage` (400 código incorrecto/expirado, 429
  /// lockout).
  ///
  /// Devuelve `true` si el inicio de sesión fue exitoso.
  Future<bool> verifyCode(String code) async {
    final phone = state.phoneNumberE164;
    if (phone == null) {
      state = state.copyWith(
        errorMessage: 'La verificación expiró. Solicita un nuevo código.',
      );
      return false;
    }

    state = state.copyWith(stage: AuthFlowStage.verifying, clearError: true);

    final result = await _repo.verifyCode(
      phoneNumber: phone,
      code: code.trim(),
      countryCode: state.countryCode,
    );

    switch (result) {
      case Ok<VerifyCodeResult>(:final value):
        try {
          final signIn =
              await _authUserService.signInWithCustomToken(value.customToken);
          _promoteSession(signIn, isNewProfile: value.isNewProfile);
          return true;
        } on SignInWithCustomTokenException catch (e) {
          state = state.copyWith(
            stage: AuthFlowStage.codeSent,
            errorMessage: e.message,
          );
          return false;
        }
      case Err<VerifyCodeResult>(:final failure):
        state = state.copyWith(
          stage: AuthFlowStage.codeSent,
          resendAvailableInSeconds: _secondsOf(failure),
          errorMessage: failure.message,
        );
        return false;
    }
  }

  /// Reinicia el flujo al ingreso de teléfono (p. ej. al salir de la pantalla
  /// de código para corregir el número).
  void reset() => state = const AuthFlowState();

  /// Segundos de cooldown transportados por un [LockedFailure], si aplica.
  int? _secondsOf(Failure failure) =>
      failure is LockedFailure ? failure.retryAfterSeconds : null;

  void _promoteSession(SignInResult result, {required bool isNewProfile}) {
    ref.read(authStateProvider.notifier).signInWithToken(
          uid: result.uid,
          idToken: result.idToken,
          phoneNumber: result.phoneNumber ?? state.phoneNumberE164,
        );
    state = state.copyWith(
      stage: AuthFlowStage.signedIn,
      isNewProfile: isNewProfile,
      clearError: true,
    );
    // Tras el login, carga el perfil (`GET /reseller/me`) para que el guard de
    // "perfil incompleto" (tarea 1.13) decida si hay que completar el nombre.
    // `isNewProfile` ya es una señal temprana; `loadProfile` lo confirma contra
    // el backend. No bloqueamos el flujo: se dispara en segundo plano.
    unawaited(ref.read(profileControllerProvider.notifier).loadProfile());
  }
}

/// Provider del controlador del flujo de autenticación.
final NotifierProvider<AuthController, AuthFlowState> authControllerProvider =
    NotifierProvider<AuthController, AuthFlowState>(AuthController.new);
