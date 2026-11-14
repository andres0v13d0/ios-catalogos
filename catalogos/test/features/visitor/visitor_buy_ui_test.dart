import 'dart:convert';

import 'package:catalogos/core/storage/storage.dart';
import 'package:catalogos/features/account/account_tab.dart';
import 'package:catalogos/features/auth/presentation/auth_state_provider.dart';
import 'package:catalogos/features/visitor/visitor_buy_page.dart';
import 'package:catalogos/features/visitor/visitor_catalogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/memory_cache.dart';

MemoryCache _cacheWithCatalog() {
  final MemoryCache c = MemoryCache();
  c.put(
    'visitor_catalogs',
    jsonEncode(<Map<String, dynamic>>[
      const VisitorCatalog(
        shortUuid: 'ab12cd34',
        catalogId: 'ab12cd34-0000-0000-0000-000000000000',
        name: 'Catálogo Prueba',
        providerName: 'Distribuidora Prueba',
        bannerUrl: 'https://example.com/b.webp',
      ).toJson(),
    ]),
  );
  return c;
}

Future<void> _pump(
  WidgetTester tester, {
  required List<(VisitorCatalog, VisitorProduct)> feed,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localCacheProvider.overrideWithValue(_cacheWithCatalog()),
        visitorFeedProvider.overrideWith((ref) async => feed),
      ],
      child: const MaterialApp(home: VisitorBuyPage()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('Comprar muestra el catálogo guardado como tarjeta de carrusel', (
    tester,
  ) async {
    await _pump(tester, feed: const []);
    expect(find.text('Comprar'), findsOneWidget);
    expect(find.text('Catálogo Prueba'), findsOneWidget);
    expect(find.text('Distribuidora Prueba'), findsOneWidget);
    // Sin productos nuevos no se deja el hueco: hay un aviso amable.
    expect(find.text('Productos nuevos'), findsOneWidget);
    expect(
      find.textContaining('Aquí verás los productos nuevos'),
      findsOneWidget,
    );
  });

  testWidgets('con productos nuevos aparece la sección "Productos nuevos"', (
    tester,
  ) async {
    const VisitorCatalog cat = VisitorCatalog(
      shortUuid: 'ab12cd34',
      catalogId: 'ab12cd34-0000-0000-0000-000000000000',
      name: 'Catálogo Prueba',
    );
    await _pump(
      tester,
      feed: const [
        (
          cat,
          VisitorProduct(id: 'p1', name: 'Tenis', prices: <int, int>{1: 1000}),
        ),
      ],
    );
    expect(find.text('Productos nuevos'), findsOneWidget);
    expect(find.text('Estados'), findsNothing);
  });

  testWidgets('pantalla corta (360x640) con productos nuevos no desborda', (
    tester,
  ) async {
    const VisitorCatalog cat = VisitorCatalog(
      shortUuid: 'ab12cd34',
      catalogId: 'ab12cd34-0000-0000-0000-000000000000',
      name: 'Catálogo Prueba',
    );
    await _pump(
      tester,
      size: const Size(360, 640),
      feed: const [
        (
          cat,
          VisitorProduct(id: 'p1', name: 'Tenis', prices: <int, int>{1: 1000}),
        ),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Catálogo Prueba'), findsWidgets);
  });

  testWidgets('Cuenta sin sesión trae los enlaces legales y de soporte', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isSignedInProvider.overrideWithValue(false)],
        child: const MaterialApp(home: AccountTab()),
      ),
    );
    await tester.pump();
    for (final String t in <String>[
      'Soporte',
      'Términos y condiciones',
      'Política de privacidad',
      'Tratamiento de datos',
    ]) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text('Datos personales'), findsNothing);
  });

  testWidgets(
    'el catálogo compartido por un proveedor trae "Personalizar"; el guardado no',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localCacheProvider.overrideWithValue(_cacheWithCatalog()),
            visitorFeedProvider.overrideWith((ref) async => const []),
            sharedBuyCatalogsProvider.overrideWithValue(<VisitorCatalog>[
              const VisitorCatalog(
                shortUuid: 'cccccccc-0000-4000-8000-000000000000',
                catalogId: 'cccccccc-0000-4000-8000-000000000000',
                name: 'Catálogo del Proveedor',
                providerName: 'Proveedor SA',
              ),
            ]),
          ],
          child: const MaterialApp(home: VisitorBuyPage()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Catálogo del Proveedor'), findsOneWidget);
      expect(find.text('Personalizar'), findsOneWidget);
    },
  );
}
