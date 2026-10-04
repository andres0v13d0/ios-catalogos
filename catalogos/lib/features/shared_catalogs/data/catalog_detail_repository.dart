import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/error_interceptor.dart';
import '../../../core/network/logging_interceptor.dart';
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
  const CatalogDetailRepository(this._dio, {NetLogSink? logSink})
      // ignore: prefer_initializing_formals -- `logSink` es el nombre público.
      : _logSink = logSink;

  final Dio _dio;

  /// Sink de logging inyectable para tests (captura de `[PARSE-ERR]`). En
  /// producción es `null` y se usa el [netLogSink] global.
  final NetLogSink? _logSink;

  static const String _previewsPath = '/catalog/products/previews';

  String _productsPath(String catalogId) =>
      '/catalog/by-catalog/$catalogId/products';

  /// `GET /catalog/by-catalog/:id/products` — detalle con productos.
  Future<Result<CatalogDetail>> getCatalogProducts(String catalogId) async {
    final path = _productsPath(catalogId);
    dynamic rawBody;
    try {
      final response = await _dio.get<dynamic>(path);
      rawBody = response.data;
      return Ok<CatalogDetail>(_parseDetail(rawBody, catalogId));
    } on DioException catch (e) {
      // El LoggingInterceptor ya registró el `[NET-ERR]` (observabilidad).
      return Err<CatalogDetail>(_failureOf(e));
    } catch (e) {
      // 200 OK con cuerpo mal formado: no es DioException, por lo que el
      // LoggingInterceptor.onError nunca se dispara. Hacemos visible el caso
      // sin cambiar el Result devuelto.
      logNetworkParseError(path, e, rawBody: rawBody, sink: _logSink);
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
    dynamic rawBody;
    try {
      final response = await _dio.post<dynamic>(_previewsPath, data: body);
      rawBody = response.data;
      return Ok<CatalogDetail>(_parseDetail(rawBody, catalogId));
    } on DioException catch (e) {
      return Err<CatalogDetail>(_failureOf(e));
    } catch (e) {
      logNetworkParseError(_previewsPath, e, rawBody: rawBody, sink: _logSink);
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
