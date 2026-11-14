import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/storage/storage.dart';
import '../buy/cart_controller.dart';
import '../shared_catalogs/domain/catalog.dart';

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
  });

  final String shortUuid;
  final String catalogId;
  final String name;
  final String? logoUrl;
  final String? providerName;
  final String? bannerUrl;
  final String? priceField;

  /// Forma que entiende la tarjeta del carrusel (la misma de Vender).
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
  };

  factory VisitorCatalog.fromJson(Map<String, dynamic> j) => VisitorCatalog(
    shortUuid: j['shortUuid'] as String,
    catalogId: j['catalogId'] as String,
    name: j['name'] as String,
    logoUrl: j['logoUrl'] as String?,
    providerName: j['providerName'] as String?,
    bannerUrl: j['bannerUrl'] as String?,
    priceField: j['priceField'] as String?,
  );
}

/// Producto de `POST /catalog/products/previews`. `prices` es cantidad→precio.
class VisitorProduct {
  const VisitorProduct({
    required this.id,
    required this.name,
    required this.prices,
    this.image,
    this.minTotal = 1,
    this.colors = const <String>[],
    this.sizes = const <String>[],
  });

  final String id;
  final String name;
  final String? image;
  final Map<int, int> prices;
  final int minTotal;
  final List<String> colors;
  final List<String> sizes;

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
    for (final Object? i in (j['imagenes'] as List<dynamic>?) ?? const []) {
      final Map<String, dynamic>? m = (i as Map?)?.cast<String, dynamic>();
      final String? u = (m?['mediumUrl'] ?? m?['imageUrl']) as String?;
      if (u != null && u.isNotEmpty) {
        image = u;
        break;
      }
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
  VisitorCatalogApi(this._dio);

  final Dio _dio;

  /// Resuelve lo que pegó el usuario a un [VisitorCatalog]; `null` si no existe.
  Future<VisitorCatalog?> lookup(String raw) async {
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
      final CatalogPage page = await fetchPage(code);
      return page.catalog;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<CatalogPage> fetchPage(String shortUuid) async {
    final Response<Map<String, dynamic>> r = await _dio
        .get<Map<String, dynamic>>('/catalog/short/$shortUuid');
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
              'nombre': buyer.nombre.trim(),
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
      number: (d['providerOrderNumber'] as num?)?.toInt() ?? 0,
      total: (d['total'] as num?) ?? 0,
    );
  }

  Future<List<VisitorProduct>> previews(
    List<String> ids,
    String catalogId,
  ) async {
    if (ids.isEmpty) return const <VisitorProduct>[];
    final Response<List<dynamic>> r = await _dio.post<List<dynamic>>(
      '/catalog/products/previews',
      data: <String, dynamic>{'ids': ids, 'catalogId': catalogId},
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
  const BuyerInfo({
    required this.nombre,
    this.celular,
    this.ciudad,
    this.direccion,
  });

  final String nombre;
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
  const SubmittedOrder({required this.number, required this.total});

  final int number;
  final num total;
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
      (Ref ref) => VisitorCatalogApi(ref.watch(dioProvider)),
    );

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
      if (c.bannerUrl != null || c.providerName != null) continue;
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
      final List<VisitorCatalog> saved = ref.watch(visitorCatalogsProvider);
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
