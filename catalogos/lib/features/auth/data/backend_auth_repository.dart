import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/error_interceptor.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../domain/auth_repository.dart';

/// Implementación de [AuthRepository] respaldada por el backend real vía Dio
/// (tarea 1.13a).
///
/// POSTea los 3 endpoints públicos del login revendedor (protegidos por App
/// Check — la cabecera `X-Firebase-AppCheck` la adjunta el `AppCheckInterceptor`
/// del [Dio] inyectado). Devuelve `Result<T>` en vez de lanzar, mapeando los
/// errores de Dio a [Failure]:
/// - 400 → [ValidationFailure] con el mensaje en español del backend
///   ("Código incorrecto" / "El código expiró" / teléfono inválido).
/// - 429 → [LockedFailure] con los segundos de cooldown/lockout
///   (`resendAvailableInSeconds` o `retryAfterSeconds`).
/// - 502/503 → [ServerFailure] con un mensaje de fallo de envío de WhatsApp.
class BackendAuthRepository implements AuthRepository {
  const BackendAuthRepository(this._dio);

  final Dio _dio;

  static const String _requestPath = '/auth/reseller/request-code';
  static const String _resendPath = '/auth/reseller/resend-code';
  static const String _verifyPath = '/auth/reseller/verify-code';

  @override
  Future<Result<RequestCodeResult>> requestCode({
    required String phoneNumber,
    String? countryCode,
  }) {
    return _requestCode(_requestPath, phoneNumber, countryCode);
  }

  @override
  Future<Result<RequestCodeResult>> resendCode({
    required String phoneNumber,
    String? countryCode,
  }) {
    return _requestCode(_resendPath, phoneNumber, countryCode);
  }

  Future<Result<RequestCodeResult>> _requestCode(
    String path,
    String phoneNumber,
    String? countryCode,
  ) async {
    try {
      final response = await _dio.post<dynamic>(
        path,
        data: _body(phoneNumber: phoneNumber, countryCode: countryCode),
      );
      return Ok<RequestCodeResult>(
        RequestCodeResult.fromJson(_asMap(response.data)),
      );
    } on DioException catch (e) {
      return Err<RequestCodeResult>(_failureOf(e));
    } catch (e) {
      return Err<RequestCodeResult>(UnknownFailure(cause: e));
    }
  }

  @override
  Future<Result<VerifyCodeResult>> verifyCode({
    required String phoneNumber,
    required String code,
    String? countryCode,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        _verifyPath,
        data: _body(
          phoneNumber: phoneNumber,
          countryCode: countryCode,
          code: code,
        ),
      );
      return Ok<VerifyCodeResult>(
        VerifyCodeResult.fromJson(_asMap(response.data)),
      );
    } on DioException catch (e) {
      return Err<VerifyCodeResult>(_failureOf(e));
    } catch (e) {
      return Err<VerifyCodeResult>(UnknownFailure(cause: e));
    }
  }

  Map<String, dynamic> _body({
    required String phoneNumber,
    String? countryCode,
    String? code,
  }) {
    final body = <String, dynamic>{'phoneNumber': phoneNumber};
    if (code != null) {
      body['code'] = code;
    }
    if (countryCode != null) {
      body['countryCode'] = countryCode;
    }
    return body;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  /// Mapea la [DioException] a un [Failure] específico del login revendedor.
  ///
  /// Afina el mapeo genérico del `ErrorInterceptor` para los casos del
  /// contrato: 400 (validación con mensaje del backend), 429 (bloqueo/cooldown
  /// con segundos) y 502/503 (fallo de envío de WhatsApp).
  Failure _failureOf(DioException e) {
    final response = e.response;
    final statusCode = response?.statusCode;
    final data = response?.data;
    final body = data is Map ? Map<String, dynamic>.from(data) : null;

    switch (statusCode) {
      case 400:
        return ValidationFailure(
          message: _backendMessage(body) ??
              'El código ingresado no es válido. Verifícalo e inténtalo de nuevo.',
          cause: e,
        );
      case 429:
        return LockedFailure(
          message: _backendMessage(body) ??
              'Demasiados intentos. Espera un momento e inténtalo de nuevo.',
          retryAfterSeconds: _secondsFrom(body),
          cause: e,
        );
      case 502:
      case 503:
        return ServerFailure(
          message:
              'No se pudo enviar el código por WhatsApp. Inténtalo de nuevo en '
              'unos minutos.',
          statusCode: statusCode,
          cause: e,
        );
    }

    // Resto de casos: reutiliza el Failure que el ErrorInterceptor adjuntó, o
    // mapea con la función pura del interceptor.
    final attached = e.error;
    if (attached is Failure) return attached;
    return mapDioExceptionToFailure(e);
  }

  /// Extrae un mensaje legible del body del backend (`message` o `error`).
  String? _backendMessage(Map<String, dynamic>? body) {
    if (body == null) return null;
    final message = body['message'] ?? body['error'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
    return null;
  }

  /// Extrae los segundos de cooldown/espera del body de un 429
  /// (`resendAvailableInSeconds` o `retryAfterSeconds`).
  int? _secondsFrom(Map<String, dynamic>? body) {
    if (body == null) return null;
    final value = body['resendAvailableInSeconds'] ?? body['retryAfterSeconds'];
    if (value is num) return value.toInt();
    return null;
  }
}

/// Provider del [AuthRepository] real, construido con el [Dio] de la app.
/// Los tests lo sobreescriben con un fake (o con un Dio + DioAdapter mock).
final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
  (Ref ref) => BackendAuthRepository(ref.watch(dioProvider)),
);
