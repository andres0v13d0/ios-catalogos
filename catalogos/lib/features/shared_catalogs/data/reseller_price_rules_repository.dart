import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/error_interceptor.dart';
import '../../../core/network/logging_interceptor.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../domain/price_rule_calculator.dart';
import '../domain/price_rules_contract.dart';

/// Repositorio del backend de "Ajustar precios" del revendedor.
///
/// Consume `/reseller/app/catalogs/:catalogId/...` (`ResellerGuard`, ver
/// `reseller-price-rules.controller.ts`/`.service.ts` del backend real — PASO
/// 0 de la tarea). Mismo estilo que [CatalogDetailRepository]/
/// `BackendAuthRepository`: `Result<T>`, `_failureOf` afina el mapeo genérico
/// del `ErrorInterceptor` para los códigos propios de este contrato:
/// - 400 → [ValidationFailure] (valor fuera de rango o no entero).
/// - 401 → delegado al `ErrorInterceptor`/`UnauthorizedInterceptor` (política
///   global de sesión expirada, sin cambios aquí).
/// - 403 → catálogo ajeno/no compartido con este revendedor.
/// - 404 → producto que no pertenece a este catálogo.
/// - 409 → catálogo "sin precios" (no se pueden ajustar).
class ResellerPriceRulesRepository {
  const ResellerPriceRulesRepository(this._dio, {NetLogSink? logSink})
    // ignore: prefer_initializing_formals -- `logSink` es el nombre público.
    : _logSink = logSink;

  final Dio _dio;
  final NetLogSink? _logSink;

  /// Tope de productos por página que soporta el backend
  /// (`Math.min(100, ...)` en el controller).
  static const int maxPageSize = 100;

  String _rulesPath(String catalogId) => '/reseller/app/catalogs/$catalogId/price-rules';
  String _productRulePath(String catalogId, String productId) =>
      '/reseller/app/catalogs/$catalogId/products/$productId/price-rule';

  Future<Result<PriceRulesProductsPage>> getCatalogProducts(
    String catalogId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final path = '/reseller/app/catalogs/$catalogId/products';
    dynamic rawBody;
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: <String, dynamic>{'page': page, 'pageSize': pageSize},
      );
      rawBody = response.data;
      return Ok<PriceRulesProductsPage>(PriceRulesProductsPage.fromJson(_asMap(rawBody)));
    } on DioException catch (e) {
      return Err<PriceRulesProductsPage>(_failureOf(e));
    } catch (e) {
      logNetworkParseError(path, e, rawBody: rawBody, sink: _logSink);
      return Err<PriceRulesProductsPage>(UnknownFailure(cause: e));
    }
  }

  Future<Result<PriceRulesSummary>> getRulesSummary(String catalogId) async {
    final path = _rulesPath(catalogId);
    dynamic rawBody;
    try {
      final response = await _dio.get<dynamic>(path);
      rawBody = response.data;
      return Ok<PriceRulesSummary>(PriceRulesSummary.fromJson(_asMap(rawBody)));
    } on DioException catch (e) {
      return Err<PriceRulesSummary>(_failureOf(e));
    } catch (e) {
      logNetworkParseError(path, e, rawBody: rawBody, sink: _logSink);
      return Err<PriceRulesSummary>(UnknownFailure(cause: e));
    }
  }

  Future<Result<SavedCatalogRuleResult>> upsertCatalogRule(
    String catalogId,
    PriceRule rule,
  ) async {
    final path = _rulesPath(catalogId);
    dynamic rawBody;
    try {
      final response = await _dio.put<dynamic>(path, data: rule.toJson());
      rawBody = response.data;
      return Ok<SavedCatalogRuleResult>(SavedCatalogRuleResult.fromJson(_asMap(rawBody)));
    } on DioException catch (e) {
      return Err<SavedCatalogRuleResult>(_failureOf(e));
    } catch (e) {
      logNetworkParseError(path, e, rawBody: rawBody, sink: _logSink);
      return Err<SavedCatalogRuleResult>(UnknownFailure(cause: e));
    }
  }

  Future<Result<void>> deleteCatalogRule(String catalogId) async {
    try {
      await _dio.delete<dynamic>(_rulesPath(catalogId));
      return const Ok<void>(null);
    } on DioException catch (e) {
      return Err<void>(_failureOf(e));
    }
  }

  Future<Result<SavedProductRuleResult>> upsertProductRule(
    String catalogId,
    String productId,
    PriceRule rule,
  ) async {
    final path = _productRulePath(catalogId, productId);
    dynamic rawBody;
    try {
      final response = await _dio.put<dynamic>(path, data: rule.toJson());
      rawBody = response.data;
      return Ok<SavedProductRuleResult>(SavedProductRuleResult.fromJson(_asMap(rawBody)));
    } on DioException catch (e) {
      return Err<SavedProductRuleResult>(_failureOf(e));
    } catch (e) {
      logNetworkParseError(path, e, rawBody: rawBody, sink: _logSink);
      return Err<SavedProductRuleResult>(UnknownFailure(cause: e));
    }
  }

  Future<Result<void>> deleteProductRule(String catalogId, String productId) async {
    try {
      await _dio.delete<dynamic>(_productRulePath(catalogId, productId));
      return const Ok<void>(null);
    } on DioException catch (e) {
      return Err<void>(_failureOf(e));
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('Respuesta inesperada de "Ajustar precios"');
  }

  /// Afina el mapeo genérico del `ErrorInterceptor` para 400/403/404/409 con
  /// mensajes en español específicos de este contrato; delega el resto (401,
  /// 429, red, 5xx) al mapeo global ya probado.
  Failure _failureOf(DioException e) {
    final response = e.response;
    final statusCode = response?.statusCode;
    final data = response?.data;
    final body = data is Map ? Map<String, dynamic>.from(data) : null;

    switch (statusCode) {
      case 400:
        return ValidationFailure(
          message: _backendMessage(body) ?? 'El valor ingresado no es válido.',
          cause: e,
        );
      case 403:
        return ServerFailure(
          message: 'Este catálogo no está disponible para tu cuenta.',
          statusCode: 403,
          cause: e,
        );
      case 404:
        return ServerFailure(
          message: 'Este producto no pertenece a este catálogo.',
          statusCode: 404,
          cause: e,
        );
      case 409:
        return ServerFailure(
          message: 'Este catálogo no muestra precios: no hay nada que ajustar.',
          statusCode: 409,
          cause: e,
        );
    }

    final attached = e.error;
    if (attached is Failure) return attached;
    return mapDioExceptionToFailure(e);
  }

  String? _backendMessage(Map<String, dynamic>? body) {
    if (body == null) return null;
    final message = body['message'];
    if (message is String && message.trim().isNotEmpty) return message;
    if (message is List && message.isNotEmpty) return message.first.toString();
    return null;
  }
}

final Provider<ResellerPriceRulesRepository> resellerPriceRulesRepositoryProvider =
    Provider<ResellerPriceRulesRepository>(
      (Ref ref) => ResellerPriceRulesRepository(ref.watch(dioProvider)),
    );
