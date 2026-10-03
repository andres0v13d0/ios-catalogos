import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../core/storage/local_cache.dart';
import '../data/shared_catalogs_repository.dart';
import '../domain/catalog.dart';

/// Clave de la caché Hive para la lista de catálogos compartidos (tarea 1.15).
///
/// Esta es la caché de la **lista** de catálogos compartidos (Fase 1). NO es la
/// caché del detalle de catálogo (tarea 1.18), que usará su propia clave.
const String kSharedCatalogsCacheKey = 'shared_catalogs';

/// Estado de los catálogos compartidos (tarea 1.14/1.15).
///
/// Envuelve la lista completa de [catalogs] (sin filtrar, para poder derivar
/// grupos y proveedores en la UI) junto con dos banderas de procedencia:
/// - [fromCache]: la lista proviene de la caché local (aún no revalidada o la
///   red falló). La UI muestra un indicador sutil de "offline/desactualizado".
/// - [linked]: catálogos recién vinculados por el último sync (0 en llamadas
///   idempotentes posteriores).
class SharedCatalogsState {
  const SharedCatalogsState({
    this.catalogs = const <Catalog>[],
    this.fromCache = false,
    this.linked = 0,
  });

  final List<Catalog> catalogs;
  final bool fromCache;
  final int linked;

  SharedCatalogsState copyWith({
    List<Catalog>? catalogs,
    bool? fromCache,
    int? linked,
  }) {
    return SharedCatalogsState(
      catalogs: catalogs ?? this.catalogs,
      fromCache: fromCache ?? this.fromCache,
      linked: linked ?? this.linked,
    );
  }
}

/// Controlador de catálogos compartidos (tareas 1.14/1.15).
///
/// Flujo (stale-while-revalidate, diseño §2.5/§8):
/// 1. En [build], si hay una lista cacheada en Hive, se emite de inmediato
///    (marcada `fromCache: true`) para que la UI no muestre un spinner vacío.
/// 2. Luego revalida contra el backend: hace `syncSharedCatalogs()` (idempotente)
///    y luego `getSharedCatalogs()`; al éxito persiste la lista y la emite
///    como fresca (`fromCache: false`).
/// 3. Si la red falla pero hay caché, se conserva la caché con `fromCache: true`
///    (ruta offline). Si no hay caché, se propaga el error (AsyncError).
///
/// [refresh] re-ejecuta sync+GET (pull-to-refresh) sin vaciar la UI.
class SharedCatalogsController extends AsyncNotifier<SharedCatalogsState> {
  SharedCatalogsRepository get _repo =>
      ref.read(sharedCatalogsRepositoryProvider);
  LocalCache get _cache => ref.read(localCacheProvider);

  @override
  Future<SharedCatalogsState> build() async {
    final cached = _readCache();
    if (cached != null && cached.isNotEmpty) {
      // Emite la caché de inmediato y revalida en segundo plano.
      Future<void>.microtask(_revalidate);
      return SharedCatalogsState(catalogs: cached, fromCache: true);
    }
    // Sin caché utilizable: carga directa (puede propagar error si falla).
    return _syncAndFetch();
  }

  /// Pull-to-refresh (tarea 1.15): re-ejecuta sync+GET conservando la lista
  /// actual visible mientras se revalida.
  Future<void> refresh() async {
    await _revalidate();
  }

  /// Revalida desde la red; si falla y hay caché, conserva la caché marcada
  /// como `fromCache`. Nunca deja la UI en error si existe algo cacheado.
  Future<void> _revalidate() async {
    try {
      final fresh = await _syncAndFetch();
      // El controlador pudo desecharse mientras revalidábamos en segundo plano
      // (p. ej. logout o navegación); no toques el estado si ya no está montado.
      if (!ref.mounted) return;
      state = AsyncData<SharedCatalogsState>(fresh);
    } catch (error, stack) {
      if (!ref.mounted) return;
      final cached = _readCache();
      if (cached != null && cached.isNotEmpty) {
        state = AsyncData<SharedCatalogsState>(
          SharedCatalogsState(catalogs: cached, fromCache: true),
        );
      } else {
        state = AsyncError<SharedCatalogsState>(error, stack);
      }
    }
  }

  /// Ejecuta `sync` (idempotente) y luego `GET` de la lista; persiste en caché.
  /// Lanza si cualquiera de los dos pasos devuelve un fallo (lo captura
  /// [_revalidate] para aplicar la política offline).
  Future<SharedCatalogsState> _syncAndFetch() async {
    int linked = 0;
    final syncResult = await _repo.syncSharedCatalogs();
    switch (syncResult) {
      case Ok<SyncResult>(:final value):
        linked = value.linked;
      case Err<SyncResult>(:final failure):
        throw failure;
    }

    final listResult = await _repo.getSharedCatalogs();
    switch (listResult) {
      case Ok<List<Catalog>>(:final value):
        await _writeCache(value);
        return SharedCatalogsState(
          catalogs: value,
          fromCache: false,
          linked: linked,
        );
      case Err<List<Catalog>>(:final failure):
        throw failure;
    }
  }

  List<Catalog>? _readCache() {
    try {
      final raw = _cache.get(kSharedCatalogsCacheKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      return parseCatalogList(decoded);
    } catch (_) {
      // Caché corrupta: ignórala (se sobreescribirá al revalidar).
      return null;
    }
  }

  Future<void> _writeCache(List<Catalog> catalogs) async {
    final encoded = jsonEncode(catalogs.map((c) => c.toJson()).toList());
    await _cache.put(kSharedCatalogsCacheKey, encoded);
  }
}

/// Provider del controlador de catálogos compartidos.
final AsyncNotifierProvider<SharedCatalogsController, SharedCatalogsState>
    sharedCatalogsControllerProvider =
    AsyncNotifierProvider<SharedCatalogsController, SharedCatalogsState>(
  SharedCatalogsController.new,
);
