import 'package:catalogos/core/storage/storage.dart';
import 'package:catalogos/features/visitor/visitor_catalogs.dart';
import 'package:catalogos/features/visitor/visitor_orders.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/memory_cache.dart';

class _Api extends VisitorCatalogApi {
  _Api() : super(Dio());

  @override
  Future<PublicOrderView> publicOrder(String id) async => PublicOrderView(
    number: 1002,
    status: 'confirmed',
    createdAt: DateTime(2026, 11, 14, 10, 30),
    catalogName: 'FlyStock',
    providerName: 'Distribuidora FLEXRUN',
    total: 100000,
    items: const <PublicOrderItem>[
      PublicOrderItem(
        name: 'Tenis running',
        quantity: 6,
        color: 'Negro',
        size: '32',
        totalPrice: 100000,
      ),
    ],
  );
}

Future<ProviderContainer> _pump(WidgetTester tester, MemoryCache cache) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final ProviderContainer c = ProviderContainer(
    overrides: [
      localCacheProvider.overrideWithValue(cache),
      visitorCatalogApiProvider.overrideWithValue(_Api()),
    ],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: VisitorOrdersPage()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return c;
}

void main() {
  testWidgets('sin pedidos muestra el mensaje vacío', (tester) async {
    await _pump(tester, MemoryCache());
    expect(find.textContaining('Aún no has hecho pedidos'), findsOneWidget);
  });

  testWidgets(
    'con pedidos guardados muestra número, proveedor y estado actualizado',
    (tester) async {
      final MemoryCache cache = MemoryCache();
      final ProviderContainer c = await _pump(tester, cache);
      await c
          .read(visitorOrdersProvider.notifier)
          .add(
            SavedOrder(
              id: 'o1',
              number: 1002,
              total: 100000,
              catalogName: 'FlyStock',
              providerName: 'Distribuidora FLEXRUN',
              createdAt: DateTime(2026, 11, 14, 10, 30),
            ),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Pedido #1002'), findsOneWidget);
      expect(
        find.text('Confirmado'),
        findsOneWidget,
      ); // estado leído del servidor
      // Persistió en el celular.
      expect(cache.get('visitor_orders'), contains('o1'));
    },
  );

  testWidgets('el historial se recupera al reabrir la app', (tester) async {
    final MemoryCache cache = MemoryCache();
    final ProviderContainer first = ProviderContainer(
      overrides: [localCacheProvider.overrideWithValue(cache)],
    );
    await first
        .read(visitorOrdersProvider.notifier)
        .add(
          SavedOrder(
            id: 'o9',
            number: 5,
            total: 1,
            catalogName: 'X',
            createdAt: DateTime(2026),
          ),
        );
    first.dispose();
    final ProviderContainer second = ProviderContainer(
      overrides: [localCacheProvider.overrideWithValue(cache)],
    );
    addTearDown(second.dispose);
    expect(second.read(visitorOrdersProvider).single.id, 'o9');
  });

  testWidgets('el tope del historial es de 50 pedidos', (tester) async {
    final ProviderContainer c = ProviderContainer(
      overrides: [localCacheProvider.overrideWithValue(MemoryCache())],
    );
    addTearDown(c.dispose);
    for (int i = 0; i < 55; i++) {
      await c
          .read(visitorOrdersProvider.notifier)
          .add(
            SavedOrder(
              id: 'o$i',
              number: i,
              total: 1,
              catalogName: 'X',
              createdAt: DateTime(2026),
            ),
          );
    }
    expect(c.read(visitorOrdersProvider), hasLength(50));
    expect(c.read(visitorOrdersProvider).first.id, 'o54');
  });
}
