// Tests del AuthController (tareas 1.9/1.10).
//
// Cubren los CA:
// - 1.9: envío de OTP normaliza a E.164 y llama a verifyPhoneNumber con ese
//   número; un número inválido deja un error de formato (no envía).
// - 1.10: código correcto autentica (transición a signedIn + sesión con
//   idToken); código incorrecto surfacea un error; el reenvío reutiliza el
//   resendToken.
//
// Usa un FakePhoneAuthService (sin Firebase ni red real).

import 'package:catalogos/features/auth/domain/phone_auth_service.dart';
import 'package:catalogos/features/auth/presentation/auth_controller.dart';
import 'package:catalogos/features/auth/presentation/auth_state_provider.dart';
import 'package:catalogos/features/profile/presentation/profile_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_phone_auth_service.dart';
import 'fake_profile_controller.dart';

void main() {
  late ProviderContainer container;
  late FakePhoneAuthService fake;

  ProviderContainer buildContainer(FakePhoneAuthService service) {
    final c = ProviderContainer(
      overrides: [
        phoneAuthServiceProvider.overrideWithValue(service),
        // Tras el login, `_promoteSession` dispara `loadProfile()` en segundo
        // plano; aislamos el test de la capa de datos (Dio/Firebase reales).
        profileControllerProvider.overrideWith(FakeProfileController.new),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('AuthController.sendCode (tarea 1.9)', () {
    test('normaliza el número a E.164 y llama a verifyPhoneNumber con él',
        () async {
      fake = FakePhoneAuthService();
      container = buildContainer(fake);
      final controller = container.read(authControllerProvider.notifier);

      final sent = await controller.sendCode(rawPhone: '300 123 4567');

      expect(sent, '+573001234567');
      expect(fake.verifyCalls, <String>['+573001234567']);
      final state = container.read(authControllerProvider);
      expect(state.stage, AuthFlowStage.codeSent);
      expect(state.verificationId, 'verif-id-1');
      expect(state.errorMessage, isNull);
    });

    test('un número inválido deja error de formato y NO envía', () async {
      fake = FakePhoneAuthService();
      container = buildContainer(fake);
      final controller = container.read(authControllerProvider.notifier);

      final sent = await controller.sendCode(rawPhone: 'abc');

      expect(sent, isNull);
      expect(fake.verifyCount, 0);
      final state = container.read(authControllerProvider);
      expect(state.stage, AuthFlowStage.phoneEntry);
      expect(state.errorMessage, isNotNull);
    });

    test('propaga el error cuando verifyPhoneNumber falla', () async {
      fake = FakePhoneAuthService(
        failVerifyWith: const PhoneAuthFailure(
          code: 'invalid-phone-number',
          message: 'número no permitido',
        ),
      );
      container = buildContainer(fake);
      final controller = container.read(authControllerProvider.notifier);

      await controller.sendCode(rawPhone: '3001234567');

      final state = container.read(authControllerProvider);
      expect(state.stage, AuthFlowStage.phoneEntry);
      expect(state.errorMessage, 'número no permitido');
    });
  });

  group('AuthController.verifyCode (tarea 1.10)', () {
    test('código correcto autentica y guarda la sesión con idToken', () async {
      fake = FakePhoneAuthService(validCode: '123456');
      container = buildContainer(fake);
      final controller = container.read(authControllerProvider.notifier);

      await controller.sendCode(rawPhone: '3001234567');
      final ok = await controller.verifyCode('123456');

      expect(ok, isTrue);
      expect(container.read(authControllerProvider).stage,
          AuthFlowStage.signedIn);
      expect(container.read(authStateProvider), AuthStatus.signedIn);

      final session = container.read(authStateProvider.notifier).session;
      expect(session, isNotNull);
      expect(session!.idToken, 'id-token-abc');
      expect(session.uid, 'uid-123');
    });

    test('código incorrecto surfacea un error y NO autentica', () async {
      fake = FakePhoneAuthService(validCode: '123456');
      container = buildContainer(fake);
      final controller = container.read(authControllerProvider.notifier);

      await controller.sendCode(rawPhone: '3001234567');
      final ok = await controller.verifyCode('000000');

      expect(ok, isFalse);
      expect(container.read(authStateProvider), AuthStatus.signedOut);
      final state = container.read(authControllerProvider);
      expect(state.stage, AuthFlowStage.codeSent);
      expect(state.errorMessage, contains('código'));
    });
  });

  group('AuthController.resendCode (tarea 1.10)', () {
    test('reenvía reutilizando el resendToken del envío previo', () async {
      fake = FakePhoneAuthService();
      container = buildContainer(fake);
      final controller = container.read(authControllerProvider.notifier);

      await controller.sendCode(rawPhone: '3001234567');
      await controller.resendCode();

      expect(fake.verifyCount, 2);
      // El fake entrega resendToken = número de llamadas; el reenvío debe
      // haber recibido el token del primer envío (1).
      expect(fake.lastResendToken, 1);
    });
  });
}
