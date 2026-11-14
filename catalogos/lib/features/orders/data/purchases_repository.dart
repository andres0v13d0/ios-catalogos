import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/error_interceptor.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../buy/cart_controller.dart';
import '../domain/reseller_order.dart';

/// UUID v4 para la idempotencia del carrito (sin dependencia nueva).
String newUuidV4() {
  final Random r = Random.secure();
  final List<int> b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final String h = b.map((int x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Compras del revendedor a sus proveedores (`/reseller/app/purchases`).
class PurchasesRepository {
  const PurchasesRepository(this._dio);

  final Dio _dio;

  Future<Result<List<ResellerOrder>>> list() async {
    try {
      final Response<dynamic> r = await _dio.get<dynamic>(
        '/reseller/app/purchases',
        queryParameters: <String, dynamic>{'limit': 50},
      );
      final List<dynamic> data = (r.data as Map)['data'] as List<dynamic>;
      return Ok<List<ResellerOrder>>(
        data
            .map(
              (e) =>
                  ResellerOrder.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
      );
    } on DioException catch (e) {
      return Err<List<ResellerOrder>>(_failureOf(e));
    } catch (e) {
      return Err<List<ResellerOrder>>(UnknownFailure(cause: e));
    }
  }

  /// Envía el carrito: el backend crea un pedido por catálogo/proveedor.
  /// [groupId] se reutiliza al reintentar para no duplicar pedidos.
  Future<Result<void>> submit(String groupId, List<CartLine> lines) async {
    try {
      await _dio.post<dynamic>(
        '/reseller/app/purchases',
        data: <String, dynamic>{
          'clientGroupId': groupId,
          'items': <Map<String, dynamic>>[
            for (final CartLine l in lines)
              <String, dynamic>{
                'catalogId': l.catalogId,
                'productId': l.productId,
                'quantity': l.quantity,
                if (l.color != null) 'color': l.color,
                if (l.size != null) 'size': l.size,
              },
          ],
        },
      );
      return const Ok<void>(null);
    } on DioException catch (e) {
      final Object? body = e.response?.data;
      final Object? m = body is Map ? body['message'] : null;
      final String? msg = m is String
          ? m
          : (m is List && m.isNotEmpty ? '${m.first}' : null);
      return Err<void>(
        msg != null
            ? ServerFailure(
                message: msg,
                statusCode: e.response?.statusCode,
                cause: e,
              )
            : _failureOf(e),
      );
    } catch (e) {
      return Err<void>(UnknownFailure(cause: e));
    }
  }

  Failure _failureOf(DioException e) {
    final Object? attached = e.error;
    if (attached is Failure) return attached;
    return mapDioExceptionToFailure(e);
  }
}

final Provider<PurchasesRepository> purchasesRepositoryProvider =
    Provider<PurchasesRepository>(
      (Ref ref) => PurchasesRepository(ref.watch(dioProvider)),
    );
