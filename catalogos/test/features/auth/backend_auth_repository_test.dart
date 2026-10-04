// Tests del BackendAuthRepository (tarea 1.13a).
//
// Mock de Dio con http_mock_adapter usando las respuestas EXACTAS del contrato
// aprobado (camelCase). Sin red ni Firebase reales.
//
// Cubre:
// - request-code parsea { expiresInSeconds, resendAvailableInSeconds } y NUNCA
//   espera un código en la respuesta;
// - verify-code parsea { customToken, reseller, isNewProfile } (reseller sin
//   firebaseUid);
// - 429 → LockedFailure con los segundos (resendAvailableInSeconds /
//   retryAfterSeconds);
// - 400 → ValidationFailure con el mensaje en español del backend;
// - 502/503 → ServerFailure (fallo de envío de WhatsApp).

import 'package:catalogos/core/network/error_interceptor.dart';
import 'package:catalogos/core/result/failure.dart';
import 'package:catalogos/core/result/result.dart';
import 'package:catalogos/features/auth/data/backend_auth_repository.dart';
import 'package:catalogos/features/auth/domain/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

void main() {
  late Dio dio;
  late DioAdapter adapter;
  late BackendAuthRepository repo;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'));
    dio.interceptors.add(const ErrorInterceptor());
    adapter = DioAdapter(dio: dio);
    repo = BackendAuthRepository(dio);
  });

  group('requestCode (POST /auth/reseller/request-code)', () {
    test('parsea { expiresInSeconds, resendAvailableInSeconds }', () async {
      adapter.onPost(
        '/auth/reseller/request-code',
        (server) => server.reply(200, <String, dynamic>{
          'ok': true,
          'expiresInSeconds': 300,
          'resendAvailableInSeconds': 60,
        }),
        data: <String, dynamic>{
          'phoneNumber': '+573001234567',
          'countryCode': '57',
        },
      );

      final result = await repo.requestCode(
        phoneNumber: '+573001234567',
        countryCode: '57',
      );

      expect(result, isA<Ok<RequestCodeResult>>());
      final value = (result as Ok<RequestCodeResult>).value;
      expect(value.expiresInSeconds, 300);
      expect(value.resendAvailableInSeconds, 60);
    });

    test('la respuesta NO transporta el código (no hay campo code)', () async {
      adapter.onPost(
        '/auth/reseller/request-code',
        (server) => server.reply(200, <String, dynamic>{
          'ok': true,
          'expiresInSeconds': 300,
          'resendAvailableInSeconds': 60,
        }),
        data: <String, dynamic>{'phoneNumber': '+573001234567'},
      );

      final result = await repo.requestCode(phoneNumber: '+573001234567');

      // El modelo no expone ningún código: solo tiempos.
      expect(result, isA<Ok<RequestCodeResult>>());
      final value = (result as Ok<RequestCodeResult>).value;
      expect(value.expiresInSeconds, isPositive);
    });

    test('400 teléfono inválido → ValidationFailure con mensaje del backend',
        () async {
      adapter.onPost(
        '/auth/reseller/request-code',
        (server) => server.reply(400, <String, dynamic>{
          'message': 'Número de teléfono inválido',
        }),
        data: <String, dynamic>{'phoneNumber': '+57300'},
      );

      final result = await repo.requestCode(phoneNumber: '+57300');

      expect(result, isA<Err<RequestCodeResult>>());
      final failure = (result as Err<RequestCodeResult>).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Número de teléfono inválido');
    });

    test('429 throttle → LockedFailure con resendAvailableInSeconds', () async {
      adapter.onPost(
        '/auth/reseller/request-code',
        (server) => server.reply(429, <String, dynamic>{
          'message': 'Espera antes de solicitar otro código.',
          'resendAvailableInSeconds': 45,
        }),
        data: <String, dynamic>{'phoneNumber': '+573001234567'},
      );

      final result = await repo.requestCode(phoneNumber: '+573001234567');

      final failure = (result as Err<RequestCodeResult>).failure;
      expect(failure, isA<LockedFailure>());
      expect((failure as LockedFailure).retryAfterSeconds, 45);
      expect(failure.message, 'Espera antes de solicitar otro código.');
    });

    test('502 → ServerFailure (fallo de envío de WhatsApp)', () async {
      adapter.onPost(
        '/auth/reseller/request-code',
        (server) => server.reply(502, <String, dynamic>{'error': 'whatsapp'}),
        data: <String, dynamic>{'phoneNumber': '+573001234567'},
      );

      final result = await repo.requestCode(phoneNumber: '+573001234567');

      final failure = (result as Err<RequestCodeResult>).failure;
      expect(failure, isA<ServerFailure>());
      expect(failure.statusCode, 502);
      expect(failure.message, contains('WhatsApp'));
    });

    test('503 → ServerFailure (fallo de envío de WhatsApp)', () async {
      adapter.onPost(
        '/auth/reseller/request-code',
        (server) => server.reply(503, <String, dynamic>{'error': 'down'}),
        data: <String, dynamic>{'phoneNumber': '+573001234567'},
      );

      final result = await repo.requestCode(phoneNumber: '+573001234567');

      final failure = (result as Err<RequestCodeResult>).failure;
      expect(failure, isA<ServerFailure>());
      expect(failure.statusCode, 503);
    });
  });

  group('resendCode (POST /auth/reseller/resend-code)', () {
    test('éxito parsea tiempos', () async {
      adapter.onPost(
        '/auth/reseller/resend-code',
        (server) => server.reply(200, <String, dynamic>{
          'ok': true,
          'expiresInSeconds': 300,
          'resendAvailableInSeconds': 60,
        }),
        data: <String, dynamic>{'phoneNumber': '+573001234567'},
      );

      final result = await repo.resendCode(phoneNumber: '+573001234567');

      expect(result, isA<Ok<RequestCodeResult>>());
    });

    test('429 dentro del cooldown → LockedFailure con segundos', () async {
      adapter.onPost(
        '/auth/reseller/resend-code',
        (server) => server.reply(429, <String, dynamic>{
          'message': 'Aún no puedes reenviar.',
          'resendAvailableInSeconds': 60,
        }),
        data: <String, dynamic>{'phoneNumber': '+573001234567'},
      );

      final result = await repo.resendCode(phoneNumber: '+573001234567');

      final failure = (result as Err<RequestCodeResult>).failure;
      expect(failure, isA<LockedFailure>());
      expect((failure as LockedFailure).retryAfterSeconds, 60);
    });
  });

  group('verifyCode (POST /auth/reseller/verify-code)', () {
    test('parsea { customToken, reseller, isNewProfile }', () async {
      adapter.onPost(
        '/auth/reseller/verify-code',
        (server) => server.reply(200, <String, dynamic>{
          'customToken': 'ct-xyz',
          'reseller': <String, dynamic>{
            'id': 7,
            'telefonoE164': '+573001234567',
            'nombre': null,
            'countryCode': 'CO',
          },
          'isNewProfile': true,
        }),
        data: <String, dynamic>{
          'phoneNumber': '+573001234567',
          'code': '123456',
        },
      );

      final result = await repo.verifyCode(
        phoneNumber: '+573001234567',
        code: '123456',
      );

      expect(result, isA<Ok<VerifyCodeResult>>());
      final value = (result as Ok<VerifyCodeResult>).value;
      expect(value.customToken, 'ct-xyz');
      expect(value.isNewProfile, isTrue);
      // El reseller de verify-code NO trae firebaseUid.
      expect(value.reseller.id, 7);
      expect(value.reseller.firebaseUid, isNull);
      expect(value.reseller.telefonoE164, '+573001234567');
      expect(value.reseller.nombre, isNull);
    });

    test('400 código incorrecto → ValidationFailure "Código incorrecto"',
        () async {
      adapter.onPost(
        '/auth/reseller/verify-code',
        (server) => server.reply(400, <String, dynamic>{
          'message': 'Código incorrecto',
        }),
        data: <String, dynamic>{
          'phoneNumber': '+573001234567',
          'code': '000000',
        },
      );

      final result = await repo.verifyCode(
        phoneNumber: '+573001234567',
        code: '000000',
      );

      final failure = (result as Err<VerifyCodeResult>).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'Código incorrecto');
    });

    test('400 código expirado → ValidationFailure "El código expiró"',
        () async {
      adapter.onPost(
        '/auth/reseller/verify-code',
        (server) => server.reply(400, <String, dynamic>{
          'message': 'El código expiró',
        }),
        data: <String, dynamic>{
          'phoneNumber': '+573001234567',
          'code': '123456',
        },
      );

      final result = await repo.verifyCode(
        phoneNumber: '+573001234567',
        code: '123456',
      );

      final failure = (result as Err<VerifyCodeResult>).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, 'El código expiró');
    });

    test('429 lockout → LockedFailure con mensaje de demasiados intentos',
        () async {
      adapter.onPost(
        '/auth/reseller/verify-code',
        (server) => server.reply(429, <String, dynamic>{
          'message': 'Demasiados intentos. Inténtalo más tarde.',
          'retryAfterSeconds': 900,
        }),
        data: <String, dynamic>{
          'phoneNumber': '+573001234567',
          'code': '000000',
        },
      );

      final result = await repo.verifyCode(
        phoneNumber: '+573001234567',
        code: '000000',
      );

      final failure = (result as Err<VerifyCodeResult>).failure;
      expect(failure, isA<LockedFailure>());
      expect((failure as LockedFailure).retryAfterSeconds, 900);
      expect(failure.message, contains('Demasiados intentos'));
    });
  });
}
