import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/error_interceptor.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../domain/catalog_detail.dart';

/// Repositorio del detalle de catálogo (tarea 1.16).
///
/// Reutiliza las **vistas públicas** del backend (diseño §4, Fase 1):
/// - `GET /catalog/by-catalog/:id/products` → [getCatalogProducts] →
///   `Result<CatalogDetail>` (banner + metadatos + productos).
/// - `POST /catalog/products/previews` (body `{ ids, catalogId? }`) →
///   [getProductPreviews] → `Result<CatalogDetail>` (misma forma de respuesta).
///
/// Mismo estilo que `SharedCatalogsRepository`: `ref.watch(dioProvider)`,
/// devuelve `Result<T>` y mapea errores de Dio a [Failure] vía [_failureOf]
/// (el `AuthInterceptor`/`AppCheckInterceptor` del Dio inyectado adjuntan las
/// cabeceras; el `ErrorInterceptor` adjunta el [Failure]).
class CatalogDetailRepository {
  const CatalogDetailRepository(this._dio);

  final Dio _dio;

  static const String _previewsPath = '/catalog/products/previews';

  String _productsPath(String catalogId) =>
      '/catalog/by-catalog/$catalogId/products';

  /// `GET /catalog/by-catalog/:id/products` — detalle con productos.
  Future<Result<CatalogDetail>> getCatalogProducts(String catalogId) async {
    try {
      final response = await _dio.get<dynamic>(_productsPath(catalogId));
      return Ok<CatalogDetail>(_parseDetail(response.data, catalogId));
    } on DioException catch (e) {
      return Err<CatalogDetail>(_failureOf(e));
    } catch (e) {
      return Err<CatalogDetail>(UnknownFailure(cause: e));
    }
  }

  /// `POST /catalog/products/previews` — previews por ids (opcional, misma
  /// forma de respuesta que [getCatalogProducts]). `catalogId` se envía si está
  /// disponible para que el backend resuelva banner/metadatos.
  Future<Result<CatalogDetail>> getProductPreviews(
    List<String> ids, {
    String? catalogId,
  }) async {
    final body = <String, dynamic>{
      'ids': ids,
      'catalogId': ?catalogId,
    };
    try {
      final response = await _dio.post<dynamic>(_previewsPath, data: body);
      return Ok<CatalogDetail>(_parseDetail(response.data, catalogId));
    } on DioException catch (e) {
      return Err<CatalogDetail>(_failureOf(e));
    } catch (e) {
      return Err<CatalogDetail>(UnknownFailure(cause: e));
    }
  }

  CatalogDetail _parseDetail(dynamic data, String? fallbackId) {
    if (data is Map<String, dynamic>) {
      return CatalogDetail.fromJson(data, fallbackId: fallbackId);
    }
    if (data is Map) {
      return CatalogDetail.fromJson(
        Map<String, dynamic>.from(data),
        fallbackId: fallbackId,
      );
    }
    throw const FormatException(
      'Respuesta inesperada del detalle de catálogo',
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

/// Provider del [CatalogDetailRepository], construido con el [Dio] de la app.
final Provider<CatalogDetailRepository> catalogDetailRepositoryProvider =
    Provider<CatalogDetailRepository>(
  (Ref ref) => CatalogDetailRepository(ref.watch(dioProvider)),
);
