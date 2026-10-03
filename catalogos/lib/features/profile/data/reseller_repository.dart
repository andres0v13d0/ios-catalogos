import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/error_interceptor.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../shared/models/reseller.dart';

/// Repositorio del perfil del revendedor (tarea 1.13).
///
/// Habla con el backend real (contratos camelCase):
/// - `GET /reseller/me`   → [getMe]      → `Result<Reseller>`
/// - `PATCH /reseller/me` → [updateMe]   → `Result<Reseller>` (body camelCase)
///
/// La cabecera `Authorization: Bearer <idToken>` la adjunta el `AuthInterceptor`
/// del [Dio] inyectado (ver `dioProvider`); el repositorio no gestiona tokens.
/// Devuelve `Result<T>` en vez de lanzar: mapea errores de Dio a [Failure].
class ResellerRepository {
  const ResellerRepository(this._dio);

  final Dio _dio;

  static const String _path = '/reseller/me';

  /// `GET /reseller/me` — perfil del revendedor autenticado.
  Future<Result<Reseller>> getMe() async {
    try {
      final response = await _dio.get<dynamic>(_path);
      return Ok<Reseller>(_parse(response.data));
    } on DioException catch (e) {
      return Err<Reseller>(_failureOf(e));
    } catch (e) {
      return Err<Reseller>(UnknownFailure(cause: e));
    }
  }

  /// `PATCH /reseller/me` — actualiza el perfil. El body usa camelCase
  /// (`nombre`, `countryCode`); solo se envían los campos no nulos.
  Future<Result<Reseller>> updateMe({
    String? nombre,
    String? countryCode,
  }) async {
    final body = <String, dynamic>{};
    if (nombre != null) {
      body['nombre'] = nombre;
    }
    if (countryCode != null) {
      body['countryCode'] = countryCode;
    }
    try {
      final response = await _dio.patch<dynamic>(_path, data: body);
      return Ok<Reseller>(_parse(response.data));
    } on DioException catch (e) {
      return Err<Reseller>(_failureOf(e));
    } catch (e) {
      return Err<Reseller>(UnknownFailure(cause: e));
    }
  }

  Reseller _parse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return Reseller.fromJson(data);
    }
    if (data is Map) {
      return Reseller.fromJson(Map<String, dynamic>.from(data));
    }
    throw const FormatException('Respuesta inesperada de /reseller/me');
  }

  /// Recupera el [Failure] que el `ErrorInterceptor` adjuntó a `error`, o lo
  /// mapea directamente si no estuviera presente.
  Failure _failureOf(DioException e) {
    final attached = e.error;
    if (attached is Failure) return attached;
    return mapDioExceptionToFailure(e);
  }
}

/// Provider del [ResellerRepository], construido con el [Dio] de la app.
final Provider<ResellerRepository> resellerRepositoryProvider =
    Provider<ResellerRepository>(
  (Ref ref) => ResellerRepository(ref.watch(dioProvider)),
);
