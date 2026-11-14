import 'package:catalogos/core/storage/storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catalogos/features/auth/presentation/auth_state_provider.dart';
import 'package:catalogos/features/buy/buy_page.dart';
import 'package:catalogos/features/shared_catalogs/domain/catalog.dart';
import 'package:catalogos/features/shared_catalogs/presentation/shared_catalogs_controller.dart';
import '../../helpers/memory_cache.dart';

class _OneAssigned extends SharedCatalogsController {
  @override
  Future<SharedCatalogsState> build() async => const SharedCatalogsState(
    catalogs: <Catalog>[
      Catalog(id: 'c-1', displayName: 'Catálogo Asignado', providerId: 1),
    ],
  );
}

void main() {
  testWidgets('con sesión, Comprar también muestra los catálogos asignados', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isSignedInProvider.overrideWithValue(true),
        localCacheProvider.overrideWithValue(MemoryCache()),
        sharedCatalogsControllerProvider.overrideWith(_OneAssigned.new),
      ],
      child: const MaterialApp(home: BuyPage()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Catálogo Asignado'), findsOneWidget);
  });

  testWidgets('Comprar de un revendedor también es el de catálogos guardados', (
    tester,
  ) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isSignedInProvider.overrideWithValue(true),
        localCacheProvider.overrideWithValue(MemoryCache()),
      ],
      child: const MaterialApp(home: BuyPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aquí verás tus catálogos guardados'), findsOneWidget);
    expect(find.text('Aún no tienes catálogos compartidos'), findsNothing);
  });

  testWidgets('Comprar de visitante no pide catálogos al servidor', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [localCacheProvider.overrideWithValue(MemoryCache())],
      child: const MaterialApp(home: BuyPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aquí verás tus catálogos guardados'), findsOneWidget);
  });
}
