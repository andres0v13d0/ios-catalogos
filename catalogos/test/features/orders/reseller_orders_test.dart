import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catalogos/core/result/failure.dart';
import 'package:catalogos/core/result/result.dart';
import 'package:catalogos/features/orders/data/reseller_orders_repository.dart';
import 'package:catalogos/features/orders/domain/reseller_order.dart';
import 'package:catalogos/features/orders/presentation/orders_controller.dart';

class _FakeRepo implements ResellerOrdersRepository {
  _FakeRepo(this.fail);
  final bool fail;

  static ResellerOrder order(OrderStatus s) =>
      ResellerOrder.fromJson(<String, dynamic>{
        'id': 'o1',
        'providerOrderNumber': 1001,
        'status': s.wire,
        'totalAmount': '80000.00',
        'saleTotalAmount': '100000.00',
        'createdAt': '2026-11-10T10:00:00Z',
        'items': <dynamic>[],
      });

  @override
  Future<Result<List<ResellerOrder>>> list({OrderStatus? status}) async =>
      Ok<List<ResellerOrder>>(<ResellerOrder>[order(OrderStatus.pending)]);

  @override
  Future<Result<ResellerOrder>> setNote(String id, String notes) async => fail
      ? const Err<ResellerOrder>(
          ServerFailure(message: 'No se pudo guardar', statusCode: 500),
        )
      : Ok<ResellerOrder>(
          ResellerOrder.fromJson(<String, dynamic>{
            'id': 'o1',
            'providerOrderNumber': 1001,
            'status': 'pending',
            'totalAmount': '80000.00',
            'saleTotalAmount': '100000.00',
            'createdAt': '2026-11-10T10:00:00Z',
            'items': <dynamic>[],
            'buyerNombre': 'Laura',
            'notes': 'Llamar antes',
            'resellerNotes': notes.isEmpty ? null : notes,
          }),
        );

  @override
  Future<Result<ResellerOrder>> setStatus(
    String id,
    OrderStatus status,
  ) async => fail
      ? const Err<ResellerOrder>(
          ServerFailure(message: 'Ya está en preparación', statusCode: 400),
        )
      : Ok<ResellerOrder>(order(status));
}

void main() {
  test('la ganancia es precio al cliente menos costo del proveedor', () {
    expect(_FakeRepo.order(OrderStatus.pending).profit, 20000);
  });

  test('confirmar actualiza el estado en la lista', () async {
    final c = ProviderContainer(
      overrides: [
        resellerOrdersRepositoryProvider.overrideWithValue(_FakeRepo(false)),
      ],
    );
    addTearDown(c.dispose);
    await c.read(resellerOrdersControllerProvider.future);
    final err = await c
        .read(resellerOrdersControllerProvider.notifier)
        .setStatus('o1', OrderStatus.confirmed);
    expect(err, isNull);
    expect(
      c.read(resellerOrdersControllerProvider).value!.single.status,
      OrderStatus.confirmed,
    );
  });

  test(
    'si el backend rechaza, devuelve el mensaje y no cambia la lista',
    () async {
      final c = ProviderContainer(
        overrides: [
          resellerOrdersRepositoryProvider.overrideWithValue(_FakeRepo(true)),
        ],
      );
      addTearDown(c.dispose);
      await c.read(resellerOrdersControllerProvider.future);
      final err = await c
          .read(resellerOrdersControllerProvider.notifier)
          .setStatus('o1', OrderStatus.canceled);
      expect(err, 'Ya está en preparación');
      expect(
        c.read(resellerOrdersControllerProvider).value!.single.status,
        OrderStatus.pending,
      );
    },
  );

  test(
    'la nota privada se guarda y se ve junto al nombre y la nota del cliente',
    () async {
      final c = ProviderContainer(
        overrides: [
          resellerOrdersRepositoryProvider.overrideWithValue(_FakeRepo(false)),
        ],
      );
      addTearDown(c.dispose);
      await c.read(resellerOrdersControllerProvider.future);
      final err = await c
          .read(resellerOrdersControllerProvider.notifier)
          .setNote('o1', 'Entregar a Laura');
      expect(err, isNull);
      final o = c.read(resellerOrdersControllerProvider).value!.single;
      expect(o.resellerNote, 'Entregar a Laura');
      expect(o.buyerName, 'Laura');
      expect(o.buyerNote, 'Llamar antes');
    },
  );

  test('si falla guardar la nota devuelve el mensaje', () async {
    final c = ProviderContainer(
      overrides: [
        resellerOrdersRepositoryProvider.overrideWithValue(_FakeRepo(true)),
      ],
    );
    addTearDown(c.dispose);
    await c.read(resellerOrdersControllerProvider.future);
    expect(
      await c
          .read(resellerOrdersControllerProvider.notifier)
          .setNote('o1', 'x'),
      'No se pudo guardar',
    );
  });
}
