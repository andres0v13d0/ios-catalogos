import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/network/error_interceptor.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../domain/reseller_order.dart';

/// Pedidos que los clientes hacen en los catálogos del revendedor
/// (`/reseller/app/orders`, `ResellerGuard`).
class ResellerOrdersRepository {
  const ResellerOrdersRepository(this._dio);

  final Dio _dio;

  Future<Result<List<ResellerOrder>>> list({OrderStatus? status}) async {
    try {
      final Response<dynamic> r = await _dio.get<dynamic>(
        '/reseller/app/orders',
        queryParameters: <String, dynamic>{
          'limit': 50,
          if (status != null) 'status': status.wire,
        },
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

  /// El revendedor solo puede confirmar o anular.
  Future<Result<ResellerOrder>> setStatus(String id, OrderStatus status) async {
    try {
      final Response<dynamic> r = await _dio.patch<dynamic>(
        '/reseller/app/orders/$id/status',
        data: <String, dynamic>{'status': status.wire},
      );
      return Ok<ResellerOrder>(
        ResellerOrder.fromJson(Map<String, dynamic>.from(r.data as Map)),
      );
    } on DioException catch (e) {
      return Err<ResellerOrder>(_failureOf(e));
    } catch (e) {
      return Err<ResellerOrder>(UnknownFailure(cause: e));
    }
  }

  /// Nota privada del revendedor; texto vacío la borra.
  Future<Result<ResellerOrder>> setNote(String id, String notes) async {
    try {
      final Response<dynamic> r = await _dio.patch<dynamic>(
        '/reseller/app/orders/$id/notes',
        data: <String, dynamic>{'notes': notes},
      );
      return Ok<ResellerOrder>(
        ResellerOrder.fromJson(Map<String, dynamic>.from(r.data as Map)),
      );
    } on DioException catch (e) {
      return Err<ResellerOrder>(_failureOf(e));
    } catch (e) {
      return Err<ResellerOrder>(UnknownFailure(cause: e));
    }
  }

  Failure _failureOf(DioException e) {
    final Object? attached = e.error;
    if (attached is Failure) return attached;
    return mapDioExceptionToFailure(e);
  }
}

final Provider<ResellerOrdersRepository> resellerOrdersRepositoryProvider =
    Provider<ResellerOrdersRepository>(
      (Ref ref) => ResellerOrdersRepository(ref.watch(dioProvider)),
    );
