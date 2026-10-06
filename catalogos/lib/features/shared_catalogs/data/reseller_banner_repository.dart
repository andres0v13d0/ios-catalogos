import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/error_interceptor.dart';
import '../../../core/network/logging_interceptor.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';

/// Resultado de una subida/borrado de banner del revendedor: el backend
/// devuelve el `ogImageUrl` propio resultante (null tras borrar) y el enlace.
class ResellerBannerResult {
  const ResellerBannerResult({this.ogImageUrl, this.enlace});

  final String? ogImageUrl;
  final String? enlace;

  factory ResellerBannerResult.fromJson(Map<String, dynamic> json) {
    return ResellerBannerResult(
      ogImageUrl: _str(json['ogImageUrl']),
      enlace: _str(json['enlace']),
    );
  }
}

/// Repositorio del backend "Banner del catálogo" del revendedor.
///
/// Consume `/reseller/app/catalogs/:catalogId/banner` (`ResellerGuard`, ver
/// `reseller-price-rules.controller.ts`):
/// - `PUT` (multipart, campo `image`) → sube el banner propio (og:image).
/// - `DELETE` → quita el banner propio (vuelve a verse la imagen del proveedor).
///
/// Mismo estilo que [ResellerPriceRulesRepository]: `Result<T>`, auth vía los
/// interceptores del Dio inyectado, y `_failureOf` con mensajes en español para
/// los códigos propios (400 tipo/tamaño inválido, 404 catálogo ajeno).
class ResellerBannerRepository {
  const ResellerBannerRepository(this._dio, {NetLogSink? logSink})
    // ignore: prefer_initializing_formals
    : _logSink = logSink;

  final Dio _dio;
  final NetLogSink? _logSink;

  String _bannerPath(String catalogId) => '/reseller/app/catalogs/$catalogId/banner';

  /// `PUT .../banner` — sube el archivo [filePath] como banner propio.
  /// El servidor valida tipo (magic bytes) y tamaño (≤5MB) y reprocesa.
  Future<Result<ResellerBannerResult>> uploadBanner(
    String catalogId,
    String filePath,
  ) async {
    final path = _bannerPath(catalogId);
    dynamic rawBody;
    try {
      final formData = FormData.fromMap(<String, dynamic>{
        'image': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.put<dynamic>(path, data: formData);
      rawBody = response.data;
      return Ok<ResellerBannerResult>(ResellerBannerResult.fromJson(_asMap(rawBody)));
    } on DioException catch (e) {
      return Err<ResellerBannerResult>(_failureOf(e));
    } catch (e) {
      logNetworkParseError(path, e, rawBody: rawBody, sink: _logSink);
      return Err<ResellerBannerResult>(UnknownFailure(cause: e));
    }
  }

  /// `DELETE .../banner` — quita el banner propio del revendedor.
  Future<Result<ResellerBannerResult>> deleteBanner(String catalogId) async {
    final path = _bannerPath(catalogId);
    dynamic rawBody;
    try {
      final response = await _dio.delete<dynamic>(path);
      rawBody = response.data;
      return Ok<ResellerBannerResult>(ResellerBannerResult.fromJson(_asMap(rawBody)));
    } on DioException catch (e) {
      return Err<ResellerBannerResult>(_failureOf(e));
    } catch (e) {
      logNetworkParseError(path, e, rawBody: rawBody, sink: _logSink);
      return Err<ResellerBannerResult>(UnknownFailure(cause: e));
    }
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('Respuesta inesperada del banner del revendedor');
  }

  /// Afina el mapeo del `ErrorInterceptor` para los códigos propios del banner;
  /// delega el resto (401, red, 5xx) al mapeo global ya probado.
  Failure _failureOf(DioException e) {
    final response = e.response;
    final statusCode = response?.statusCode;
    final data = response?.data;
    final body = data is Map ? Map<String, dynamic>.from(data) : null;

    switch (statusCode) {
      case 400:
        return ValidationFailure(
          message: _backendMessage(body) ?? 'La imagen no es válida. Usa JPG, PNG o WebP de hasta 5 MB.',
          cause: e,
        );
      case 404:
        return ServerFailure(
          message: 'Este catálogo no está disponible para tu cuenta.',
          statusCode: 404,
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

String? _str(dynamic value) {
  if (value == null) return null;
  final s = value.toString().trim();
  return s.isEmpty ? null : s;
}

final Provider<ResellerBannerRepository> resellerBannerRepositoryProvider =
    Provider<ResellerBannerRepository>(
      (Ref ref) => ResellerBannerRepository(ref.watch(dioProvider)),
    );
