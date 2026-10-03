// Widget test de HomePage (tareas 1.14/1.15).
//
// - Muestra los catálogos agrupados por proveedor (encabezados de sección).
// - El pull-to-refresh (RefreshIndicator) dispara una recarga, verificado con
//   un controlador fake que cuenta las recargas.
//
// Se sobreescribe el controlador con un fake en memoria (sin Hive ni red), de
// modo que el test se centra en la UI (agrupación + wiring del refresh) y no
// depende de IO de archivos ni del event loop asíncrono real.

import 'package:catalogos/features/shared_catalogs/domain/catalog.dart';
import 'package:catalogos/features/shared_catalogs/presentation/home_page.dart';
import 'package:catalogos/features/shared_catalogs/presentation/shared_catalogs_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Controlador fake: estado fijo (AsyncData) con 2 proveedores y recarga que
/// solo cuenta invocaciones.
class _FakeController extends SharedCatalogsController {
  int refreshCount = 0;

  static const List<Catalog> _catalogs = <Catalog>[
    Catalog(
      id: 'c1',
      displayName: 'Zapatos',
      providerId: 10,
      providerName: 'Proveedor A',
    ),
    Catalog(
      id: 'c2',
      displayName: 'Camisas',
      providerId: 20,
      providerName: 'Proveedor B',
    ),
  ];

  @override
  Future<SharedCatalogsState> build() async =>
      const SharedCatalogsState(catalogs: _catalogs);

  @override
  Future<void> refresh() async {
    refreshCount++;
  }
}

void main() {
  late _FakeController fake;

  Widget wrap() {
    fake = _FakeController();
    return ProviderScope(
      overrides: [
        sharedCatalogsControllerProvider.overrideWith(() => fake),
      ],
      child: const MaterialApp(home: HomePage()),
    );
  }

  testWidgets('muestra los catálogos agrupados por proveedor',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    // Encabezados de sección por proveedor.
    expect(find.text('Proveedor A'), findsWidgets);
    expect(find.text('Proveedor B'), findsWidgets);
    // Catálogos.
    expect(find.text('Zapatos'), findsOneWidget);
    expect(find.text('Camisas'), findsOneWidget);
  });

  testWidgets('el pull-to-refresh (RefreshIndicator.onRefresh) recarga',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    // La lista está envuelta por un RefreshIndicator (pull-to-refresh).
    final Finder indicatorFinder = find.byType(RefreshIndicator);
    expect(indicatorFinder, findsOneWidget);

    expect(fake.refreshCount, 0);

    // Invoca el callback de pull-to-refresh directamente (equivalente al gesto
    // de arrastre, pero sin su animación, que colgaría pumpAndSettle).
    final RefreshIndicator indicator = tester.widget(indicatorFinder);
    await indicator.onRefresh();

    expect(fake.refreshCount, 1);
  });

  testWidgets('la búsqueda filtra la lista por nombre',
      (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('shared_catalogs_search_field')),
      'zap',
    );
    await tester.pump();

    expect(find.text('Zapatos'), findsOneWidget);
    expect(find.text('Camisas'), findsNothing);
  });
}
