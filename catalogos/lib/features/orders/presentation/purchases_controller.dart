import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../buy/cart_controller.dart';
import '../data/purchases_repository.dart';
import '../domain/reseller_order.dart';

/// Pedidos enviados por el revendedor a sus proveedores ("Mis compras").
class PurchasesController extends AsyncNotifier<List<ResellerOrder>> {
  PurchasesRepository get _repo => ref.read(purchasesRepositoryProvider);

  // Mismo id mientras el envío falle con el MISMO carrito: el reintento no duplica pedidos.
  String? _pendingGroupId;
  String? _pendingSig;

  @override
  Future<List<ResellerOrder>> build() => _load();

  Future<List<ResellerOrder>> _load() async => switch (await _repo.list()) {
    Ok<List<ResellerOrder>>(:final value) => value,
    Err<List<ResellerOrder>>(:final failure) => throw Exception(
      failure.message,
    ),
  };

  Future<void> refresh() async => state = await AsyncValue.guard(_load);

  /// Envía el carrito; devuelve el mensaje de error o `null` si salió bien
  /// (en cuyo caso vacía el carrito y recarga la lista).
  Future<String?> submitCart() async {
    final List<CartLine> lines = ref.read(cartControllerProvider);
    if (lines.isEmpty) return null;
    final String sig = lines
        .map((CartLine l) => '${l.key}x${l.quantity}')
        .join(',');
    if (_pendingGroupId == null || _pendingSig != sig) {
      _pendingGroupId = newUuidV4();
      _pendingSig = sig;
    }
    final Result<void> res = await _repo.submit(_pendingGroupId!, lines);
    switch (res) {
      case Ok<void>():
        _pendingGroupId = null;
        ref.read(cartControllerProvider.notifier).clear();
        await refresh();
        return null;
      case Err<void>(:final failure):
        return failure.message;
    }
  }
}

final AsyncNotifierProvider<PurchasesController, List<ResellerOrder>>
purchasesControllerProvider =
    AsyncNotifierProvider<PurchasesController, List<ResellerOrder>>(
      PurchasesController.new,
    );
