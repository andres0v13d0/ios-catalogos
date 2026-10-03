import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/error_interceptor.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../domain/catalog.dart';

/// Repositorio de catálogos compartidos (tareas 1.14/1.15).
///
/// Habla con el backend real (contratos camelCase):
/// - `POST /reseller/sync-shared-catalogs` (body `{}`) → [syncSharedCatalogs]
///   → `Result<SyncResult>` (parsea `{ linked, catalogs }`). Idempotente: una
///   segunda llamada devuelve `linked: 0`.
/// - `GET /reseller/me/shared-catalogs?providerId=&search=` →
///   [getSharedCatalogs] → `Result<List<Catalog>>` (parsea `{ catalogs }`).
///
/// La cabecera `Authorization: Bearer <idToken>` la adjunta el `AuthInterceptor`
/// del [Dio] inyectado (ver `dioProvider`). Devuelve `Result<T>` en vez de
/// lanzar: mapea errores de Dio a [Failure] (mismo patrón que `ResellerRepository`).
class SharedCatalogsRepository {
  const SharedCatalogsRepository(this._dio);

  final Dio _dio;

  static const String _syncPath = '/reseller/sync-shared-catalogs';
  static const String _listPath = '/reseller/me/shared-catalogs';

  /// `POST /reseller/sync-shared-catalogs` — vincula catálogos por teléfono del
  /// token (idempotente). Parsea `{ linked, catalogs }`.
  Future<Result<SyncResult>> syncSharedCatalogs() async {
    try {
      final response = await _dio.post<dynamic>(
        _syncPath,
        data: const <String, dynamic>{},
      );
      return Ok<SyncResult>(_parseSync(response.data));
    } on DioException catch (e) {
      return Err<SyncResult>(_failureOf(e));
    } catch (e) {
      return Err<SyncResult>(UnknownFailure(cause: e));
    }
  }

  /// `GET /reseller/me/shared-catalogs` — catálogos del revendedor autenticado.
  ///
  /// Admite filtros opcionales de servidor [providerId] (int) y [search]
  /// (string, por nombre de catálogo); solo se envían si no son nulos/vacíos.
  Future<Result<List<Catalog>>> getSharedCatalogs({
    int? providerId,
    String? search,
  }) async {
    final query = <String, dynamic>{};
    if (providerId != null) {
      query['providerId'] = providerId;
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    try {
      final response = await _dio.get<dynamic>(
        _listPath,
        queryParameters: query.isEmpty ? null : query,
      );
      return Ok<List<Catalog>>(_parseList(response.data));
    } on DioException catch (e) {
      return Err<List<Catalog>>(_failureOf(e));
    } catch (e) {
      return Err<List<Catalog>>(UnknownFailure(cause: e));
    }
  }

  SyncResult _parseSync(dynamic data) {
    if (data is Map<String, dynamic>) {
      return SyncResult.fromJson(data);
    }
    if (data is Map) {
      return SyncResult.fromJson(Map<String, dynamic>.from(data));
    }
    throw const FormatException(
      'Respuesta inesperada de /reseller/sync-shared-catalogs',
    );
  }

  List<Catalog> _parseList(dynamic data) {
    if (data is Map<String, dynamic>) {
      return parseCatalogList(data['catalogs']);
    }
    if (data is Map) {
      return parseCatalogList(Map<String, dynamic>.from(data)['catalogs']);
    }
    // Tolerante: algunos backends devuelven la lista directamente.
    if (data is List) {
      return parseCatalogList(data);
    }
    throw const FormatException(
      'Respuesta inesperada de /reseller/me/shared-catalogs',
    );
  }

  /// Recupera el [Failure] que el `ErrorInterceptor` adjuntó a `error`, o lo
  /// mapea directamente si no estuviera presente.
  Failure _failureOf(DioException e) {
    final attached = e.error;
    if (attached is Failure) return attached;
    return mapDioExceptionToFailure(e);
  }
}

/// Provider del [SharedCatalogsRepository], construido con el [Dio] de la app.
final Provider<SharedCatalogsRepository> sharedCatalogsRepositoryProvider =
    Provider<SharedCatalogsRepository>(
  (Ref ref) => SharedCatalogsRepository(ref.watch(dioProvider)),
);
