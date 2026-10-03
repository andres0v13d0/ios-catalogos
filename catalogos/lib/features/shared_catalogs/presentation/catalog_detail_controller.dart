import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../core/storage/local_cache.dart';
import '../data/catalog_detail_repository.dart';
import '../domain/catalog_detail.dart';

/// Prefijo de la clave de caché del detalle de catálogo (tarea 1.18).
///
/// A diferencia de la caché de la **lista** (`shared_catalogs`), aquí cada
/// catálogo consultado se persiste bajo su propia clave `catalog_detail:<id>`,
/// JSON-encoded, para la lectura offline *stale-while-revalidate*.
const String kCatalogDetailCachePrefix = 'catalog_detail:';

/// Construye la clave de caché del detalle para un [catalogId].
String catalogDetailCacheKey(String catalogId) =>
    '$kCatalogDetailCachePrefix$catalogId';

/// Estado del detalle de catálogo (tareas 1.16/1.18).
///
/// Envuelve el [detail] cargado y la bandera [fromCache] (procedencia): si la
/// vista proviene de la caché local (aún no revalidada o la red falló), la UI
/// muestra un indicador sutil de "sin conexión / desactualizado".
class CatalogDetailState {
  const CatalogDetailState({required this.detail, this.fromCache = false});

  final CatalogDetail detail;
  final bool fromCache;

  CatalogDetailState copyWith({CatalogDetail? detail, bool? fromCache}) {
    return CatalogDetailState(
      detail: detail ?? this.detail,
      fromCache: fromCache ?? this.fromCache,
    );
  }
}

/// Controlador del detalle de catálogo (tareas 1.16 y 1.18).
///
/// Familia parametrizada por `catalogId`. Flujo *stale-while-revalidate*
/// (diseño §2.5/§8), espejo del `SharedCatalogsController`:
/// 1. En [build], si hay una vista cacheada para este id, se emite de inmediato
///    (`fromCache: true`) y se revalida en segundo plano.
/// 2. Si no hay caché, carga directa desde red (puede propagar error).
/// 3. Al éxito de red, persiste la vista por id y la emite fresca
///    (`fromCache: false`).
/// 4. Si la red falla pero hay caché, conserva la caché con `fromCache: true`
///    (ruta offline, CA de 1.18). Si no hay caché, propaga el error.
class CatalogDetailController extends AsyncNotifier<CatalogDetailState> {
  /// La familia inyecta el `catalogId` por constructor (ver provider abajo).
  CatalogDetailController(this._catalogId);

  final String _catalogId;

  CatalogDetailRepository get _repo =>
      ref.read(catalogDetailRepositoryProvider);
  LocalCache get _cache => ref.read(localCacheProvider);

  @override
  Future<CatalogDetailState> build() async {
    final cached = _readCache();
    if (cached != null) {
      Future<void>.microtask(_revalidate);
      return CatalogDetailState(detail: cached, fromCache: true);
    }
    return _fetch();
  }

  /// Reintento manual (botón "reintentar" o pull-to-refresh del detalle).
  Future<void> refresh() => _revalidate();

  Future<void> _revalidate() async {
    try {
      final fresh = await _fetch();
      if (!ref.mounted) return;
      state = AsyncData<CatalogDetailState>(fresh);
    } catch (error, stack) {
      if (!ref.mounted) return;
      final cached = _readCache();
      if (cached != null) {
        state = AsyncData<CatalogDetailState>(
          CatalogDetailState(detail: cached, fromCache: true),
        );
      } else {
        state = AsyncError<CatalogDetailState>(error, stack);
      }
    }
  }

  /// Pide el detalle a la red y lo persiste en caché por id. Lanza si falla
  /// (lo captura [_revalidate] para aplicar la política offline).
  Future<CatalogDetailState> _fetch() async {
    final result = await _repo.getCatalogProducts(_catalogId);
    switch (result) {
      case Ok<CatalogDetail>(:final value):
        await _writeCache(value);
        return CatalogDetailState(detail: value, fromCache: false);
      case Err<CatalogDetail>(:final failure):
        throw failure;
    }
  }

  CatalogDetail? _readCache() {
    try {
      final raw = _cache.get(catalogDetailCacheKey(_catalogId));
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CatalogDetail.fromJson(decoded, fallbackId: _catalogId);
      }
      if (decoded is Map) {
        return CatalogDetail.fromJson(
          Map<String, dynamic>.from(decoded),
          fallbackId: _catalogId,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(CatalogDetail detail) async {
    final encoded = jsonEncode(detail.toJson());
    await _cache.put(catalogDetailCacheKey(_catalogId), encoded);
  }
}

/// Provider (familia por `catalogId`) del controlador del detalle de catálogo.
///
/// La función de creación recibe el `catalogId` (argumento de la familia) y lo
/// inyecta en el constructor del controlador.
final catalogDetailControllerProvider =
    AsyncNotifierProvider.family<CatalogDetailController, CatalogDetailState,
        String>(
  CatalogDetailController.new,
  // Desactiva el reintento automático de Riverpod: la política de reintento la
  // gobierna la UI (botón "Reintentar"/pull-to-refresh → `refresh`) y la caché
  // offline. Sin esto, un fallo de red sin caché reintentaría en bucle.
  retry: (int retryCount, Object error) => null,
);
