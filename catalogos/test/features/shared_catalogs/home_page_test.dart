// Widget test de HomePage (rediseño UX: el catálogo es el protagonista).
//
// - Muestra una lista plana de TARJETAS de catálogo (sin secciones por
//   proveedor). Cada tarjeta expone el nombre público del catálogo (título),
//   el nombre del proveedor (fila secundaria) y una insignia "Sin precios"
//   cuando priceField == 'none'.
// - La key de la tarjeta es Key('catalog_<uuid>') para la navegación.
// - El buscador por nombre y el filtro por proveedor siguen funcionando.
// - El pull-to-refresh (RefreshIndicator) dispara una recarga.
//
// Se sobreescribe el controlador con un fake en memoria (sin Hive ni red).

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
      id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      displayName: 'Zapatos',
      providerId: 10,
      providerName: 'Proveedor A',
      providerLogoUrl: 'https://cdn/logo-a.webp',
      priceField: 'none', // catálogo sin precios → insignia
    ),
    Catalog(
      id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      displayName: 'Camisas',
      providerId: 20,
      providerName: 'Proveedor B',
      priceField: 'mayorista',
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

  // Superficie alta: las tarjetas tienen portada 16/9, de modo que en una
  // ventana pequeña el ListView (perezoso) no construiría la segunda tarjeta.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget wrap() {
    fake = _FakeController();
    return ProviderScope(
      overrides: [
        sharedCatalogsControllerProvider.overrideWith(() => fake),
      ],
      child: const MaterialApp(home: HomePage()),
    );
  }

  testWidgets(
      'cada tarjeta muestra el nombre público del catálogo y el del proveedor',
      (WidgetTester tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap());
    await tester.pump();

    // Títulos = nombres públicos de catálogo.
    expect(find.text('Zapatos'), findsOneWidget);
    expect(find.text('Camisas'), findsOneWidget);

    // Nombre del proveedor presente (en la fila secundaria de la tarjeta y,
    // además, en el chip del filtro por proveedor). NUNCA "Proveedor <id>".
    expect(find.text('Proveedor A'), findsWidgets);
    expect(find.text('Proveedor B'), findsWidgets);
    expect(find.textContaining('Proveedor 10'), findsNothing);
    expect(find.textContaining('Proveedor 20'), findsNothing);
  });

  testWidgets('la insignia "Sin precios" aparece solo para priceField==none',
      (WidgetTester tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap());
    await tester.pump();

    // Solo un catálogo ('Zapatos') está en modo sin precios.
    expect(find.text('Sin precios'), findsOneWidget);
    expect(find.byKey(const Key('catalog_no_price_badge')), findsOneWidget);
  });

  testWidgets('la tarjeta usa Key(catalog_<uuid>) para la navegación',
      (WidgetTester tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(
      find.byKey(const Key('catalog_aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('catalog_bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')),
      findsOneWidget,
    );
  });

  testWidgets('renderiza el avatar del proveedor (iniciales como fallback)',
      (WidgetTester tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(CircleAvatar), findsWidgets);
    // El proveedor sin logo muestra iniciales 'PB' (Proveedor B).
    expect(find.text('PB'), findsOneWidget);
  });

  testWidgets('el pull-to-refresh (RefreshIndicator.onRefresh) recarga',
      (WidgetTester tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap());
    await tester.pump();

    final Finder indicatorFinder = find.byType(RefreshIndicator);
    expect(indicatorFinder, findsOneWidget);

    expect(fake.refreshCount, 0);

    final RefreshIndicator indicator = tester.widget(indicatorFinder);
    await indicator.onRefresh();

    expect(fake.refreshCount, 1);
  });

  testWidgets('la búsqueda filtra la lista por nombre de catálogo',
      (WidgetTester tester) async {
    useTallSurface(tester);
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

  testWidgets('el filtro por proveedor estrecha la lista',
      (WidgetTester tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(wrap());
    await tester.pump();

    // Hay más de un proveedor → se muestra la barra de filtro.
    expect(
      find.byKey(const Key('shared_catalogs_provider_filter')),
      findsOneWidget,
    );

    // Seleccionar el chip del Proveedor B (id 20) deja solo sus catálogos.
    await tester.tap(find.byKey(const Key('provider_chip_20')));
    await tester.pump();

    expect(find.text('Camisas'), findsOneWidget);
    expect(find.text('Zapatos'), findsNothing);
  });
}
