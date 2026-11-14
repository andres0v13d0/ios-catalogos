import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/storage/storage.dart';
import '../auth/presentation/auth_state_provider.dart';
import '../buy/cart_controller.dart';
import '../shared_catalogs/domain/catalog.dart';
import '../shared_catalogs/presentation/shared_catalogs_controller.dart';

/// Catálogo guardado por un visitante (sin cuenta). Vive solo en el celular.
class VisitorCatalog {
  const VisitorCatalog({
    required this.shortUuid,
    required this.catalogId,
    required this.name,
    this.logoUrl,
    this.providerName,
    this.bannerUrl,
    this.priceField,
    this.phone,
  });

  final String shortUuid;
  final String catalogId;
  final String name;
  final String? logoUrl;
  final String? providerName;
  final String? bannerUrl;
  final String? priceField;

  /// WhatsApp del catálogo (proveedor o, en un canal, revendedor): ahí se envía el pedido.
  final String? phone;

  /// Forma que entiende la tarjeta del carrusel (la misma de los catálogos compartidos).
  Catalog toCatalog() => Catalog(
    id: catalogId,
    displayName: name,
    providerId: 0,
    providerName: providerName,
    providerLogoUrl: logoUrl,
    bannerUrl: bannerUrl,
    priceField: priceField,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'shortUuid': shortUuid,
    'catalogId': catalogId,
    'name': name,
    'logoUrl': logoUrl,
    'providerName': providerName,
    'bannerUrl': bannerUrl,
    'priceField': priceField,
    'phone': phone,
  };

  factory VisitorCatalog.fromJson(Map<String, dynamic> j) => VisitorCatalog(
    shortUuid: j['shortUuid'] as String,
    catalogId: j['catalogId'] as String,
    name: j['name'] as String,
    logoUrl: j['logoUrl'] as String?,
    providerName: j['providerName'] as String?,
    bannerUrl: j['bannerUrl'] as String?,
    priceField: j['priceField'] as String?,
    phone: j['phone'] as String?,
  );
}

/// Tarjeta de producto para el chat (lo que espera `PRODUCT` en el backend).
Map<String, dynamic> productChatPayload(VisitorCatalog c, VisitorProduct p) =>
    <String, dynamic>{
      'productId': p.id,
      'name': p.name,
      if (p.priceFrom > 0) 'price': p.priceFrom,
      'currency': 'COP',
      'imageUrl': ?p.image,
      'shortUuid': c.shortUuid,
      'catalogId': c.catalogId,
    };

/// Producto de `POST /catalog/products/previews`. `prices` es cantidad→precio.
class VisitorProduct {
  const VisitorProduct({
    required this.id,
    required this.name,
    required this.prices,
    this.image,
    this.images = const <String>[],
    this.description,
    this.minTotal = 1,
    this.colors = const <String>[],
    this.sizes = const <String>[],
  });

  final String id;
  final String name;

  /// Portada (primera imagen) para tarjetas y cuadrículas.
  final String? image;

  /// Todas las imágenes del producto, la portada primero (galería).
  final List<String> images;
  final String? description;
  final Map<int, int> prices;
  final int minTotal;
  final List<String> colors;
  final List<String> sizes;

  /// Cantidades que ofrece el proveedor: las claves del mapa de precios que
  /// alcanzan el mínimo. Sin precios, solo el mínimo.
  List<int> get quantityOptions {
    final List<int> o = prices.keys.where((int q) => q >= minTotal).toList()
      ..sort();
    return o.isEmpty ? <int>[minTotal] : o;
  }

  int get priceFrom {
    final Iterable<int> p = prices.values.where((int v) => v > 0);
    return p.isEmpty ? 0 : p.reduce((int a, int b) => a < b ? a : b);
  }

  /// Precio unitario: el del mayor umbral que no supere [qty].
  int priceFor(int qty) {
    final List<MapEntry<int, int>> e = prices.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    int chosen = e.isEmpty ? 0 : e.first.value;
    for (final MapEntry<int, int> x in e) {
      if (qty >= x.key) chosen = x.value;
    }
    return chosen;
  }

  factory VisitorProduct.fromJson(Map<String, dynamic> j) {
    String? image;
    final List<String> gallery = <String>[];
    for (final Object? i in (j['imagenes'] as List<dynamic>?) ?? const []) {
      final Map<String, dynamic>? m = (i as Map?)?.cast<String, dynamic>();
      final String? u = (m?['mediumUrl'] ?? m?['imageUrl']) as String?;
      final String? full = (m?['fullUrl'] ?? m?['imageUrl'] ?? u) as String?;
      if (u != null && u.isNotEmpty) image ??= u;
      if (full != null && full.isNotEmpty) gallery.add(full);
    }
    final Map<int, int> prices = <int, int>{};
    ((j['precios'] as Map?)?.cast<String, dynamic>() ?? const {}).forEach((
      String k,
      dynamic v,
    ) {
      final int? q = int.tryParse(k);
      final int p = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
      if (q != null && q > 0 && p > 0) prices[q] = p;
    });
    List<String> strs(Object? o) => o is List
        ? o.map((e) => '$e'.trim()).where((s) => s.isNotEmpty).toSet().toList()
        : const <String>[];
    return VisitorProduct(
      id: j['id'] as String? ?? '',
      name: (j['nombre'] as String?)?.trim() ?? '',
      image: image,
      images: gallery,
      description: (j['descripcion'] as String?)?.trim(),
      prices: prices,
      minTotal: (j['minTotalProduct'] as num?)?.toInt() ?? 1,
      colors: strs(j['colores']),
      sizes: strs(j['tallas']),
    );
  }
}

/// Extrae el código corto (≥ 8 caracteres) de un enlace o código pegado.
/// Los enlaces `share.minymol.com` son redirects y se resuelven en [lookup].
String? parseCatalogCode(String raw) {
  final String input = raw.trim();
  if (input.isEmpty) return null;
  final Uri? uri = input.contains('/') || input.contains('.')
      ? Uri.tryParse(input.contains('://') ? input : 'https://$input')
      : null;
  final String last = uri == null
      ? input
      : uri.pathSegments.where((String s) => s.isNotEmpty).lastOrNull ?? '';
  final String code = last.replaceAll(RegExp(r'[^A-Za-z0-9-]'), '');
  return code.length >= 8 ? code : null;
}

/// Acceso a los endpoints públicos (no requieren sesión).
class VisitorCatalogApi {
  VisitorCatalogApi(this._dio, {bool Function(String id)? isReseller})
    : _isReseller = isReseller ?? ((_) => false);

  final Dio _dio;

  /// `true` si el id (catálogo o código) es un catálogo que un proveedor le
  /// compartió al revendedor: se lee con su sesión y a precio del proveedor.
  final bool Function(String id) _isReseller;

  /// Resuelve lo que pegó el usuario a un [VisitorCatalog]; `null` si no existe.
  Future<VisitorCatalog?> lookup(String raw) async =>
      (await lookupPage(raw))?.catalog;

  /// Igual que [lookup] pero con la página completa (cantidad de productos).
  Future<CatalogPage?> lookupPage(String raw) async {
    String? code = parseCatalogCode(raw);
    final Uri? uri = Uri.tryParse(
      raw.trim().contains('://') ? raw.trim() : 'https://${raw.trim()}',
    );
    if (uri != null && uri.host == 'share.minymol.com') {
      final Response<dynamic> r = await _dio.get<dynamic>(
        uri.replace(query: '').toString(),
        options: Options(
          followRedirects: false,
          validateStatus: (int? s) => s != null && s < 500,
          headers: const <String, String>{
            'User-Agent':
                'Mozilla/5.0 (Linux; Android) AppleWebKit/537.36 Flimas/1.0',
          },
        ),
      );
      final String? loc = r.headers.value('location');
      code = loc == null ? null : parseCatalogCode(loc);
    }
    if (code == null) return null;
    try {
      return await fetchPage(code);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<CatalogPage> fetchPage(String shortUuid) async {
    final Response<Map<String, dynamic>> r = await _dio
        .get<Map<String, dynamic>>(
          _isReseller(shortUuid)
              ? '/reseller/app/catalogs/$shortUuid/page'
              : '/catalog/short/$shortUuid',
        );
    final Map<String, dynamic> d = r.data ?? const <String, dynamic>{};
    final Map<String, dynamic>? c = (d['catalog'] as Map?)
        ?.cast<String, dynamic>();
    String? first(List<Object?> v) => v
        .whereType<String>()
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .firstOrNull;
    List<String> ids(Object? o) =>
        ((o as List<dynamic>?) ?? const []).whereType<String>().toList();
    return CatalogPage(
      catalog: VisitorCatalog(
        shortUuid: shortUuid,
        catalogId: c?['id'] as String? ?? shortUuid,
        name:
            first(<Object?>[
              c?['publicName'],
              c?['name'],
              d['nombre_empresa'],
            ]) ??
            'Catálogo',
        logoUrl: first(<Object?>[d['logo_optimized_url'], d['logo_url']]),
        providerName: first(<Object?>[d['nombre_empresa']]),
        bannerUrl: first(<Object?>[
          c?['banner_url'],
          c?['bannerUrl'],
          d['banner_url'],
        ]),
        priceField: c?['priceField'] as String?,
        phone: first(<Object?>[d['telefono'], c?['telefono']]),
      ),
      newIds: ids(d['newProductIds']),
      ids: ids(d['productIds']),
    );
  }

  /// `POST /catalog-orders` (público, App Check). Un pedido por catálogo.
  /// Reenviar con el mismo [clientOrderId] devuelve el mismo pedido.
  Future<SubmittedOrder> submitOrder({
    required String clientOrderId,
    required String shortUuid,
    required List<CartLine> lines,
    required BuyerInfo buyer,
    String? notes,
  }) async {
    String? clean(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    final Response<Map<String, dynamic>> r = await _dio
        .post<Map<String, dynamic>>(
          '/catalog-orders',
          data: <String, dynamic>{
            'clientOrderId': clientOrderId,
            'shortUuid': shortUuid,
            'buyer': <String, dynamic>{
              'nombre': ?clean(buyer.nombre),
              'celular': ?clean(buyer.celular),
              'ciudad': ?clean(buyer.ciudad),
              'direccion': ?clean(buyer.direccion),
            },
            'items': <Map<String, dynamic>>[
              for (final CartLine l in lines)
                <String, dynamic>{
                  'productId': l.productId,
                  'quantity': l.quantity,
                  'color': ?l.color,
                  'size': ?l.size,
                },
            ],
            'notes': ?clean(notes),
          },
        );
    final Map<String, dynamic> d = r.data ?? const <String, dynamic>{};
    return SubmittedOrder(
      orderId: d['orderId'] as String?,
      number: (d['providerOrderNumber'] as num?)?.toInt() ?? 0,
      total: (d['total'] as num?) ?? 0,
    );
  }

  /// Enlace compartible del pedido (título con el número, resumen y SIN imagen).
  /// Si el servidor no lo puede crear, se usa el enlace directo del pedido.
  Future<String> createOrderShare({
    required String title,
    required String description,
    required String redirectUrl,
  }) async {
    try {
      final Response<Map<String, dynamic>> r = await _dio
          .post<Map<String, dynamic>>(
            '/share',
            data: <String, dynamic>{
              'title': title,
              'description': description,
              'redirectUrl': redirectUrl,
            },
          );
      final Object? url = r.data?['shareUrl'];
      return url is String && url.isNotEmpty ? url : redirectUrl;
    } on DioException {
      return redirectUrl;
    }
  }

  /// Vista pública de un pedido (`GET /catalog-orders/public/:id`): estado
  /// actualizado y productos, sin datos de contacto.
  Future<PublicOrderView> publicOrder(String id) async {
    final Response<Map<String, dynamic>> r = await _dio
        .get<Map<String, dynamic>>('/catalog-orders/public/$id');
    return PublicOrderView.fromJson(r.data ?? const <String, dynamic>{});
  }

  Future<List<VisitorProduct>> previews(
    List<String> ids,
    String catalogId,
  ) async {
    if (ids.isEmpty) return const <VisitorProduct>[];
    // Catálogo compartido por un proveedor: precio del proveedor (no el de venta).
    final Response<List<dynamic>> r = await _dio.post<List<dynamic>>(
      _isReseller(catalogId)
          ? '/reseller/app/catalogs/$catalogId/previews'
          : '/catalog/products/previews',
      data: <String, dynamic>{
        'ids': ids,
        if (!_isReseller(catalogId)) 'catalogId': catalogId,
      },
    );
    return (r.data ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> e) =>
              VisitorProduct.fromJson(e.cast<String, dynamic>()),
        )
        .toList();
  }
}

/// Datos del comprador visitante. Solo el nombre es obligatorio.
class BuyerInfo {
  const BuyerInfo({this.nombre, this.celular, this.ciudad, this.direccion});

  final String? nombre;
  final String? celular;
  final String? ciudad;
  final String? direccion;
}

/// UUID v4 para la idempotencia del pedido (`clientOrderId`).
String newUuid() {
  final Random r = Random.secure();
  final List<int> b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

/// Resultado de enviar un pedido (total calculado por el servidor).
class SubmittedOrder {
  const SubmittedOrder({
    this.orderId,
    required this.number,
    required this.total,
  });

  final String? orderId;
  final int number;
  final num total;
}

class PublicOrderItem {
  const PublicOrderItem({
    required this.name,
    required this.quantity,
    this.imageUrl,
    this.color,
    this.size,
    this.totalPrice,
  });

  final String name;
  final int quantity;
  final String? imageUrl;
  final String? color;
  final String? size;
  final num? totalPrice;
}

/// Estado y contenido de un pedido tal como lo ve quien lo hizo.
class PublicOrderView {
  const PublicOrderView({
    required this.number,
    required this.status,
    required this.createdAt,
    this.catalogName,
    this.providerName,
    this.notes,
    this.total,
    this.items = const <PublicOrderItem>[],
  });

  final int number;
  final String status;
  final DateTime createdAt;
  final String? catalogName;
  final String? providerName;
  final String? notes;
  final num? total;
  final List<PublicOrderItem> items;

  /// Texto para el comprador (el pedido nuevo se ve como "Recibido").
  String get statusLabel => switch (status) {
    'confirmed' => 'Confirmado',
    'preparing' => 'En preparación',
    'delivered' => 'Entregado',
    'canceled' => 'Anulado',
    _ => 'Recibido',
  };

  factory PublicOrderView.fromJson(Map<String, dynamic> j) => PublicOrderView(
    number: (j['number'] as num?)?.toInt() ?? 0,
    status: '${j['status']}',
    createdAt:
        DateTime.tryParse('${j['createdAt']}')?.toLocal() ?? DateTime.now(),
    catalogName: j['catalogName'] as String?,
    providerName: j['providerName'] as String?,
    notes: j['notes'] as String?,
    total: j['total'] as num?,
    items: ((j['items'] as List?) ?? const <dynamic>[]).map((dynamic e) {
      final Map<String, dynamic> m = Map<String, dynamic>.from(e as Map);
      return PublicOrderItem(
        name: '${m['productName']}',
        quantity: (m['quantity'] as num?)?.toInt() ?? 0,
        imageUrl: m['imageUrl'] as String?,
        color: m['color'] as String?,
        size: m['size'] as String?,
        totalPrice: m['totalPrice'] as num?,
      );
    }).toList(),
  );
}

class CatalogPage {
  const CatalogPage({
    required this.catalog,
    required this.newIds,
    required this.ids,
  });

  final VisitorCatalog catalog;
  final List<String> newIds;
  final List<String> ids;
}

final Provider<VisitorCatalogApi> visitorCatalogApiProvider =
    Provider<VisitorCatalogApi>(
      (Ref ref) => VisitorCatalogApi(
        ref.watch(dioProvider),
        isReseller: (String id) =>
            ref.read(sharedCatalogIdsProvider).contains(id),
      ),
    );

/// Catálogos que los proveedores le compartieron al revendedor, con la forma de
/// los de Comprar. `shortUuid` = id del catálogo (se abren por id, no por enlace).
final Provider<List<VisitorCatalog>> sharedBuyCatalogsProvider =
    Provider<List<VisitorCatalog>>((Ref ref) {
      if (!ref.watch(isSignedInProvider)) return const <VisitorCatalog>[];
      final List<Catalog> shared =
          ref.watch(sharedCatalogsControllerProvider).value?.catalogs ??
          const <Catalog>[];
      return <VisitorCatalog>[
        for (final Catalog c in shared)
          VisitorCatalog(
            shortUuid: c.id,
            catalogId: c.id,
            name: c.displayName,
            logoUrl: c.providerLogoUrl,
            providerName: c.providerName,
            bannerUrl: c.bannerUrl ?? c.ogImageUrl ?? c.providerBannerUrl,
            priceField: c.priceField,
          ),
      ];
    });

final Provider<Set<String>> sharedCatalogIdsProvider = Provider<Set<String>>(
  (Ref ref) => <String>{
    for (final VisitorCatalog c in ref.watch(sharedBuyCatalogsProvider))
      c.catalogId,
  },
);

/// Lo que muestra Comprar: los compartidos por proveedores y los que el usuario
/// guardó por enlace (sin repetir).
final Provider<List<VisitorCatalog>> buyCatalogsProvider =
    Provider<List<VisitorCatalog>>((Ref ref) {
      final List<VisitorCatalog> shared = ref.watch(sharedBuyCatalogsProvider);
      final Set<String> sharedIds = ref.watch(sharedCatalogIdsProvider);
      return <VisitorCatalog>[
        ...shared,
        ...ref
            .watch(visitorCatalogsProvider)
            .where((VisitorCatalog c) => !sharedIds.contains(c.catalogId)),
      ];
    });

const String _cacheKey = 'visitor_catalogs';

/// Catálogos guardados por enlace, en el celular (más reciente primero).
class VisitorCatalogsController extends Notifier<List<VisitorCatalog>> {
  @override
  List<VisitorCatalog> build() {
    final String? raw = ref.read(localCacheProvider).get(_cacheKey);
    if (raw == null) return const <VisitorCatalog>[];
    try {
      final List<VisitorCatalog> saved = (jsonDecode(raw) as List<dynamic>)
          .map(
            (dynamic e) =>
                VisitorCatalog.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList();
      Future<void>.microtask(_fillMissing);
      return saved;
    } catch (_) {
      return const <VisitorCatalog>[];
    }
  }

  /// Catálogos guardados antes de que se guardara banner/proveedor: se
  /// completan en segundo plano (si falla la red, se reintenta al reabrir).
  Future<void> _fillMissing() async {
    for (final VisitorCatalog c in state.toList()) {
      if ((c.bannerUrl != null || c.providerName != null) && c.phone != null) {
        continue;
      }
      try {
        final CatalogPage p = await ref
            .read(visitorCatalogApiProvider)
            .fetchPage(c.shortUuid);
        await _save(<VisitorCatalog>[
          for (final VisitorCatalog x in state)
            x.shortUuid == c.shortUuid ? p.catalog : x,
        ]);
      } catch (_) {}
    }
  }

  Future<void> _save(List<VisitorCatalog> next) async {
    state = next;
    await ref
        .read(localCacheProvider)
        .put(
          _cacheKey,
          jsonEncode(next.map((VisitorCatalog c) => c.toJson()).toList()),
        );
  }

  Future<void> add(VisitorCatalog c) => _save(<VisitorCatalog>[
    c,
    ...state.where((VisitorCatalog x) => x.shortUuid != c.shortUuid),
  ]);

  Future<void> remove(String shortUuid) => _save(
    state.where((VisitorCatalog x) => x.shortUuid != shortUuid).toList(),
  );
}

final NotifierProvider<VisitorCatalogsController, List<VisitorCatalog>>
visitorCatalogsProvider =
    NotifierProvider<VisitorCatalogsController, List<VisitorCatalog>>(
      VisitorCatalogsController.new,
    );

/// Productos de un catálogo (nuevos primero, hasta 60).
/// shortcut: sin paginación; paginar cuando haya catálogos de cientos de productos.
final visitorCatalogProductsProvider = FutureProvider.autoDispose
    .family<(VisitorCatalog, List<VisitorProduct>), String>((
      Ref ref,
      String code,
    ) async {
      final VisitorCatalogApi api = ref.watch(visitorCatalogApiProvider);
      final CatalogPage p = await api.fetchPage(code);
      final List<String> ids = <String>{
        ...p.newIds,
        ...p.ids,
      }.take(60).toList();
      return (p.catalog, await api.previews(ids, p.catalog.catalogId));
    });

/// Novedades: los 6 productos nuevos más recientes de cada catálogo guardado.
final FutureProvider<List<(VisitorCatalog, VisitorProduct)>>
visitorFeedProvider =
    FutureProvider.autoDispose<List<(VisitorCatalog, VisitorProduct)>>((
      Ref ref,
    ) async {
      final VisitorCatalogApi api = ref.watch(visitorCatalogApiProvider);
      final List<VisitorCatalog> saved = ref.watch(buyCatalogsProvider);
      final List<List<(VisitorCatalog, VisitorProduct)>> per =
          await Future.wait(
            saved.map((VisitorCatalog c) async {
              try {
                final CatalogPage p = await api.fetchPage(c.shortUuid);
                final List<VisitorProduct> prods = await api.previews(
                  p.newIds.take(6).toList(),
                  p.catalog.catalogId,
                );
                return <(VisitorCatalog, VisitorProduct)>[
                  for (final VisitorProduct x in prods) (p.catalog, x),
                ];
              } catch (_) {
                return <
                  (VisitorCatalog, VisitorProduct)
                >[]; // un catálogo caído no tumba el feed
              }
            }),
          );
      return per
          .expand((List<(VisitorCatalog, VisitorProduct)> l) => l)
          .toList();
    });

const String _seenKey = 'visitor_seen';

/// Ids de productos nuevos ya vistos en las "historias" (en el celular).
/// shortcut: guarda los últimos 500; suficiente mientras el feed trae 6 por catálogo.
class VisitorSeenController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final String? raw = ref.read(localCacheProvider).get(_seenKey);
    if (raw == null) return <String>{};
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<String>().toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> mark(String id) async {
    if (state.contains(id)) return;
    final Set<String> next = <String>{...state, id};
    state = next;
    final List<String> l = next.toList();
    await ref
        .read(localCacheProvider)
        .put(_seenKey, jsonEncode(l.sublist(max(0, l.length - 500))));
  }
}

final NotifierProvider<VisitorSeenController, Set<String>> visitorSeenProvider =
    NotifierProvider<VisitorSeenController, Set<String>>(
      VisitorSeenController.new,
    );
