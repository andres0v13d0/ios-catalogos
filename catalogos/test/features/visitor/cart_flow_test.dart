import 'dart:convert';

import 'package:catalogos/core/storage/storage.dart';
import 'package:catalogos/features/buy/cart_controller.dart';
import 'package:catalogos/features/visitor/cart_flow.dart';
import 'package:catalogos/features/visitor/catalog_access.dart';
import 'package:catalogos/core/result/result.dart';
import 'package:catalogos/features/auth/presentation/auth_state_provider.dart';
import 'package:catalogos/features/orders/data/purchases_repository.dart';
import 'package:catalogos/features/orders/domain/reseller_order.dart';
import 'package:catalogos/features/visitor/order_message.dart';
import 'package:catalogos/features/visitor/visitor_catalog_page.dart';
import 'package:catalogos/features/visitor/visitor_orders.dart';
import 'package:catalogos/features/visitor/visitor_catalogs.dart';
import 'package:catalogos/features/visitor/visitor_product_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:catalogos/features/visitor/image_gallery.dart';

import '../../helpers/memory_cache.dart';

const VisitorCatalog _cat = VisitorCatalog(
  shortUuid: 'ab12cd34',
  catalogId: 'ab12cd34-0000-0000-0000-000000000000',
  name: 'FlyStock',
  providerName: 'Distribuidora FLEXRUN',
  phone: '+573016643479',
);
const VisitorCatalog _cat2 = VisitorCatalog(
  shortUuid: 'ef56ab78',
  catalogId: 'ef56ab78-0000-0000-0000-000000000000',
  name: 'Moda Norte Mayorista',
  providerName: 'Moda Norte',
);

const VisitorProduct _plain = VisitorProduct(
  id: 'p1',
  name: 'Sandalia deportiva',
  prices: <int, int>{6: 34500, 12: 32000},
);
const VisitorProduct _variant = VisitorProduct(
  id: 'p2',
  name: 'Tenis running niño',
  prices: <int, int>{6: 48900, 12: 46500, 24: 44000},
  colors: <String>['Negro', 'Azul'],
  sizes: <String>['30', '32'],
);

class _FakePurchases implements PurchasesRepository {
  final List<String> groups = <String>[];
  String? notes;

  @override
  Future<Result<List<ResellerOrder>>> list() async =>
      const Ok<List<ResellerOrder>>(<ResellerOrder>[]);

  @override
  Future<Result<void>> submit(String groupId, List<CartLine> lines) async =>
      const Ok<void>(null);

  @override
  Future<Result<SubmittedOrder>> submitOne(
    String groupId,
    List<CartLine> lines, {
    String? notes,
  }) async {
    groups.add(groupId);
    this.notes = notes;
    return const Ok<SubmittedOrder>(
      SubmittedOrder(orderId: 'p-1', number: 1003, total: 50000),
    );
  }
}

class _FakeApi extends VisitorCatalogApi {
  _FakeApi({this.withId = false}) : super(Dio());

  final bool withId;

  final List<Map<String, Object?>> sent = <Map<String, Object?>>[];

  /// Sin red en las pruebas: el catálogo guardado se devuelve tal cual.
  @override
  Future<CatalogPage> fetchPage(
    String shortUuid, {
    String? search,
    String? categoryId,
    String? subcategoryId,
  }) async => CatalogPage(
    catalog: <VisitorCatalog>[_cat, _cat2].firstWhere(
      (VisitorCatalog c) => c.shortUuid == shortUuid,
      orElse: () => _cat,
    ),
    newIds: const <String>[],
    ids: const <String>[],
  );

  @override
  Future<String> createOrderShare({
    required String title,
    required String description,
    required String redirectUrl,
  }) async => 'https://share.minymol.com/abc123';

  @override
  Future<SubmittedOrder> submitOrder({
    required String clientOrderId,
    required String shortUuid,
    required List<CartLine> lines,
    required BuyerInfo buyer,
    String? notes,
  }) async {
    sent.add(<String, Object?>{
      'shortUuid': shortUuid,
      'lines': lines.length,
      'nombre': buyer.nombre,
      'notes': notes,
    });
    return SubmittedOrder(
      orderId: withId ? 'order-uuid-1' : null,
      number: 7,
      total: 100000,
    );
  }
}

/// Enlaces de WhatsApp que la app intentó abrir en la prueba actual.
final List<Uri> opened = <Uri>[];

MemoryCache _cache() {
  final MemoryCache c = MemoryCache();
  c.put(
    'visitor_catalogs',
    jsonEncode(<Object>[_cat.toJson(), _cat2.toJson()]),
  );
  return c;
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget home, {
  _FakeApi? api,
  List<Override> extra = const <Override>[],
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final ProviderContainer c = ProviderContainer(
    overrides: [
      localCacheProvider.overrideWithValue(_cache()),
      visitorCatalogApiProvider.overrideWithValue(api ?? _FakeApi()),
      whatsappLauncherProvider.overrideWithValue((Uri u) async {
        opened.add(u);
        return true;
      }),
      ...extra,
    ],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(home: home),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return c;
}

void main() {
  setUp(opened.clear);

  testWidgets('catálogo: el + agrega directo si no hay color ni talla', (
    tester,
  ) async {
    final ProviderContainer c = await _pump(
      tester,
      const VisitorCatalogPage(code: 'ab12cd34'),
      extra: [
        visitorCatalogQueryProvider((
          code: 'ab12cd34',
          search: '',
          byCategory: false,
          chipId: null,
        )).overrideWith(
          (ref) async => (
            catalog: _cat,
            products: <VisitorProduct>[_plain, _variant],
            categories: <CatalogCategory>[],
            subcategories: <CatalogChip>[],
          ),
        ),
      ],
    );
    expect(find.text('Distribuidora FLEXRUN'), findsWidgets);
    expect(find.text('2 productos'), findsOneWidget);
    await tester.tap(
      find.bySemanticsLabel('Añadir Sandalia deportiva al carrito'),
    );
    await tester.pump();
    final List<CartLine> cart = c.read(cartControllerProvider);
    expect(cart, hasLength(1));
    expect(cart.single.quantity, 6); // la primera cantidad del proveedor
    expect(cart.single.unitPrice, 34500);
  });

  testWidgets('catálogo: con color y talla el + abre el detalle', (
    tester,
  ) async {
    await _pump(
      tester,
      const VisitorCatalogPage(code: 'ab12cd34'),
      extra: [
        visitorCatalogQueryProvider((
          code: 'ab12cd34',
          search: '',
          byCategory: false,
          chipId: null,
        )).overrideWith(
          (ref) async => (
            catalog: _cat,
            products: <VisitorProduct>[_variant],
            categories: <CatalogCategory>[],
            subcategories: <CatalogChip>[],
          ),
        ),
      ],
    );
    await tester.tap(
      find.bySemanticsLabel('Añadir Tenis running niño al carrito'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VisitorProductPage), findsOneWidget);
    expect(find.text('Elige color y talla'), findsOneWidget);
  });

  testWidgets('producto: elige variante y cantidad del proveedor y añade', (
    tester,
  ) async {
    final ProviderContainer c = await _pump(
      tester,
      const VisitorProductPage(catalog: _cat, product: _variant),
    );
    // Pantalla alta para que se construyan todas las cantidades (lista perezosa).
    tester.view.physicalSize = const Size(390, 2400);
    await tester.pump();
    // Solo el número de cada cantidad: sin "und" ni precio por unidad.
    expect(find.text('6'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.textContaining('und'), findsNothing);
    for (final String t in <String>['Negro', '32', '12']) {
      await tester.ensureVisible(find.text(t));
      await tester.pump();
      await tester.tap(find.text(t));
      await tester.pump();
    }
    await tester.tap(find.text('Añadir al carrito'));
    await tester.pump();
    final CartLine l = c.read(cartControllerProvider).single;
    expect(
      (l.color, l.size, l.quantity, l.unitPrice),
      ('Negro', '32', 12, 46500),
    );
    // Sigue en el detalle, sin aviso aparte, y el botón del carrito está ahí.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(VisitorProductPage), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(FloatingCartButton), findsOneWidget);
    expect(find.byIcon(LucideIcons.shoppingCart), findsOneWidget);
  });

  testWidgets(
    'pedido: resumen por catálogo, cambia cantidad y envía solo ese catálogo',
    (tester) async {
      final _FakeApi api = _FakeApi();
      final ProviderContainer c = await _pump(
        tester,
        const OrderSummaryPage(
          catalogId: 'ab12cd34-0000-0000-0000-000000000000',
        ),
        api: api,
      );
      final CartController n = c.read(cartControllerProvider.notifier);
      n.add(cartLineFor(_cat, _variant, 6, color: 'Negro', size: '32'));
      n.add(cartLineFor(_cat2, _plain, 6));
      await tester.pump();
      expect(find.text('Tu pedido'), findsOneWidget);
      expect(find.text('Tenis running niño'), findsOneWidget);
      expect(find.text('Sandalia deportiva'), findsNothing); // otro catálogo

      await tester.enterText(
        find.widgetWithText(TextField, 'Ej.: entregar a Laura'),
        'Entregar a Laura',
      );
      await tester.ensureVisible(find.text('Enviar pedido'));
      await tester.tap(find.text('Enviar pedido'));
      await tester.pumpAndSettle();

      expect(api.sent, hasLength(1));
      expect(api.sent.single['shortUuid'], 'ab12cd34');
      expect(api.sent.single['nombre'], ''); // el nombre es opcional
      expect(api.sent.single['notes'], 'Entregar a Laura');
      // Solo salió el pedido de ese catálogo; el otro sigue en el carrito.
      final List<CartLine> left = c.read(cartControllerProvider);
      expect(left, hasLength(1));
      expect(left.single.catalogId, _cat2.catalogId);
    },
  );

  testWidgets(
    'sin cuenta, el pedido enviado queda en el historial del celular',
    (tester) async {
      final _FakeApi api = _FakeApi(withId: true);
      final ProviderContainer c = await _pump(
        tester,
        const OrderSummaryPage(
          catalogId: 'ab12cd34-0000-0000-0000-000000000000',
        ),
        api: api,
      );
      c
          .read(cartControllerProvider.notifier)
          .add(cartLineFor(_cat, _variant, 6, color: 'Negro', size: '32'));
      await tester.pump();
      await tester.ensureVisible(find.text('Enviar pedido'));
      await tester.tap(find.text('Enviar pedido'));
      await tester.pumpAndSettle();

      final List<SavedOrder> saved = c.read(visitorOrdersProvider);
      expect(saved, hasLength(1));
      expect(saved.single.id, 'order-uuid-1');
      expect(saved.single.number, 7);
      expect(saved.single.providerName, 'Distribuidora FLEXRUN');
    },
  );

  testWidgets(
    'con sesión de revendedor el pedido va a "Mis compras" y no al historial del visitante',
    (tester) async {
      final _FakeApi api = _FakeApi(withId: true);
      final _FakePurchases purchases = _FakePurchases();
      final ProviderContainer c = await _pump(
        tester,
        const OrderSummaryPage(
          catalogId: 'ab12cd34-0000-0000-0000-000000000000',
        ),
        api: api,
        extra: [
          isSignedInProvider.overrideWithValue(true),
          purchasesRepositoryProvider.overrideWithValue(purchases),
        ],
      );
      c
          .read(cartControllerProvider.notifier)
          .add(cartLineFor(_cat, _variant, 6, color: 'Negro', size: '32'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Ej.: entregar a Laura'),
        'Para Laura',
      );
      await tester.ensureVisible(find.text('Enviar pedido'));
      await tester.tap(find.text('Enviar pedido'));
      await tester.pumpAndSettle();

      expect(purchases.groups, hasLength(1));
      expect(purchases.notes, 'Para Laura');
      expect(api.sent, isEmpty); // no pasó por el endpoint anónimo
      expect(c.read(visitorOrdersProvider), isEmpty);
      expect(c.read(cartControllerProvider), isEmpty);
    },
  );

  testWidgets('catálogo pendiente de aprobación: no deja pedir y lo explica', (
    tester,
  ) async {
    final _FakeApi api = _FakeApi(withId: true);
    final _FakePurchases purchases = _FakePurchases();
    final ProviderContainer c = await _pump(
      tester,
      const OrderSummaryPage(catalogId: 'ab12cd34-0000-0000-0000-000000000000'),
      api: api,
      extra: [
        isSignedInProvider.overrideWithValue(true),
        purchasesRepositoryProvider.overrideWithValue(purchases),
        catalogAccessProvider.overrideWith(
          (ref, id) async => CatalogAccess.pending,
        ),
      ],
    );
    c
        .read(cartControllerProvider.notifier)
        .add(cartLineFor(_cat, _variant, 6, color: 'Negro', size: '32'));
    await tester.pump();
    await tester.ensureVisible(find.text('Enviar pedido'));
    await tester.tap(find.text('Enviar pedido'));
    await tester.pumpAndSettle();

    expect(purchases.groups, isEmpty);
    expect(api.sent, isEmpty);
    expect(
      find.text('El proveedor aún no ha aceptado tu solicitud.'),
      findsOneWidget,
    );
    expect(c.read(cartControllerProvider), isNotEmpty);
  });

  testWidgets('producto de un catálogo bloqueado: sin añadir y con el aviso', (
    tester,
  ) async {
    await _pump(
      tester,
      VisitorProductPage(catalog: _cat, product: _variant),
      extra: [
        isSignedInProvider.overrideWithValue(true),
        catalogAccessProvider.overrideWith(
          (ref, id) async => CatalogAccess.blocked,
        ),
      ],
    );
    expect(find.text('No tienes acceso a este catálogo.'), findsOneWidget);
    expect(find.text('Añadir al carrito'), findsNothing);
  });

  test('sin precios: el producto conserva todo menos los precios', () {
    final VisitorProduct p = _variant.withoutPrices();
    expect(p.priceFrom, 0);
    expect(p.id, _variant.id);
    expect(p.colors, _variant.colors);
  });

  testWidgets(
    'se puede enviar el pedido aunque el catálogo ya no esté en los guardados',
    (tester) async {
      final _FakeApi api = _FakeApi();
      const VisitorCatalog ghost = VisitorCatalog(
        shortUuid: 'zz99aa00',
        catalogId: 'zz99aa00-0000-0000-0000-000000000000',
        name: 'Catálogo DEMO',
      );
      final ProviderContainer c = await _pump(
        tester,
        const OrderSummaryPage(
          catalogId: 'zz99aa00-0000-0000-0000-000000000000',
        ),
        api: api,
      );
      c
          .read(cartControllerProvider.notifier)
          .add(cartLineFor(ghost, _plain, 6));
      await tester.pump();
      expect(find.text('Este pedido ya no tiene productos.'), findsNothing);
      await tester.ensureVisible(find.text('Enviar pedido'));
      await tester.tap(find.text('Enviar pedido'));
      await tester.pumpAndSettle();

      // Antes fallaba con "Un catálogo del carrito ya no está guardado".
      expect(api.sent, hasLength(1));
      expect(api.sent.single['shortUuid'], 'zz99aa00');
      expect(c.read(cartControllerProvider), isEmpty);
    },
  );

  testWidgets(
    'al enviar el pedido se guarda y se abre WhatsApp con el mensaje y el enlace',
    (tester) async {
      final _FakeApi api = _FakeApi(withId: true);
      final ProviderContainer c = await _pump(
        tester,
        const OrderSummaryPage(
          catalogId: 'ab12cd34-0000-0000-0000-000000000000',
        ),
        api: api,
      );
      c
          .read(cartControllerProvider.notifier)
          .add(cartLineFor(_cat, _variant, 6, color: 'Negro', size: '32'));
      await tester.pump();
      await tester.ensureVisible(find.text('Enviar pedido'));
      await tester.tap(find.text('Enviar pedido'));
      await tester.pumpAndSettle();

      expect(api.sent, hasLength(1)); // primero se guarda
      expect(opened, hasLength(1)); // y luego se abre WhatsApp
      final Uri u = opened.single;
      expect(u.host, 'wa.me');
      expect(u.path, '/573016643479');
      final String text = u.queryParameters['text']!;
      expect(text, contains('Tenis running niño'));
      expect(text, contains('Color: Negro, Talla: 32, Cantidad: 6'));
      expect(text, contains('https://share.minymol.com/abc123'));
      expect(text, contains('Total estimado: \$ 100.000'));
    },
  );

  testWidgets(
    'si el catálogo no tiene WhatsApp, el pedido se guarda y no se abre nada',
    (tester) async {
      final _FakeApi api = _FakeApi(withId: true);
      final ProviderContainer c = await _pump(
        tester,
        const OrderSummaryPage(
          catalogId: 'ef56ab78-0000-0000-0000-000000000000',
        ),
        api: api,
      );
      c
          .read(cartControllerProvider.notifier)
          .add(cartLineFor(_cat2, _plain, 6));
      await tester.pump();
      await tester.ensureVisible(find.text('Enviar pedido'));
      await tester.tap(find.text('Enviar pedido'));
      await tester.pumpAndSettle();

      expect(api.sent, hasLength(1));
      expect(opened, isEmpty);
    },
  );

  testWidgets('el botón del carrito salta al agregar y queda centrado', (
    tester,
  ) async {
    final ProviderContainer c = await _pump(
      tester,
      const Scaffold(floatingActionButton: FloatingCartButton()),
    );
    expect(find.byType(FloatingCartButton), findsOneWidget);
    expect(
      find.byIcon(LucideIcons.shoppingCart),
      findsNothing,
    ); // vacío: oculto
    c.read(cartControllerProvider.notifier).add(cartLineFor(_cat2, _plain, 6));
    await tester.pump();
    await tester.pump(
      const Duration(milliseconds: 260),
    ); // a mitad de la animación
    double scale() => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(FloatingCartButton),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .storage[0];
    expect(find.byIcon(LucideIcons.shoppingCart), findsOneWidget);
    expect(scale(), greaterThan(1.05)); // el botón está "saltando"
    await tester.pump(const Duration(milliseconds: 400));
    expect(scale(), closeTo(1, 0.001));
    // El ícono está en el centro del botón de 60x60.
    final Offset icon = tester.getCenter(find.byIcon(LucideIcons.shoppingCart));
    final Offset button = tester.getCenter(find.byType(InkWell).first);
    expect((icon - button).distance, lessThan(1));
  });

  testWidgets('la galería ampliada se desliza entre todas las fotos', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext c) => TextButton(
            onPressed: () => showImageGallery(c, const <String>['a', 'b', 'c']),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('2 / 3'), findsOneWidget);
  });
}
