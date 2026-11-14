import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../data/reseller_orders_repository.dart';
import '../domain/reseller_order.dart';

/// Lista de pedidos recibidos (todos los estados; el filtro se aplica en la UI).
class ResellerOrdersController extends AsyncNotifier<List<ResellerOrder>> {
  ResellerOrdersRepository get _repo =>
      ref.read(resellerOrdersRepositoryProvider);

  @override
  Future<List<ResellerOrder>> build() => _load();

  Future<List<ResellerOrder>> _load() async => switch (await _repo.list()) {
    Ok<List<ResellerOrder>>(:final value) => value,
    Err<List<ResellerOrder>>(:final failure) => throw Exception(
      failure.message,
    ),
  };

  Future<void> refresh() async => state = await AsyncValue.guard(_load);

  /// Guarda la nota privada del pedido; devuelve el error o `null` si salió bien.
  Future<String?> setNote(String id, String notes) async {
    final Result<ResellerOrder> res = await _repo.setNote(id, notes);
    switch (res) {
      case Ok<ResellerOrder>(:final value):
        state = AsyncData<List<ResellerOrder>>(
          (state.value ?? const <ResellerOrder>[])
              .map((ResellerOrder o) => o.id == id ? value : o)
              .toList(),
        );
        return null;
      case Err<ResellerOrder>(:final failure):
        return failure.message;
    }
  }

  /// Confirma o anula; devuelve el mensaje de error o `null` si salió bien.
  Future<String?> setStatus(String id, OrderStatus status) async {
    final Result<ResellerOrder> res = await _repo.setStatus(id, status);
    switch (res) {
      case Ok<ResellerOrder>(:final value):
        state = AsyncData<List<ResellerOrder>>(
          (state.value ?? const <ResellerOrder>[])
              .map((ResellerOrder o) => o.id == id ? value : o)
              .toList(),
        );
        return null;
      case Err<ResellerOrder>(:final failure):
        return failure.message;
    }
  }
}

final AsyncNotifierProvider<ResellerOrdersController, List<ResellerOrder>>
resellerOrdersControllerProvider =
    AsyncNotifierProvider<ResellerOrdersController, List<ResellerOrder>>(
      ResellerOrdersController.new,
    );
