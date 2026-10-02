/// Caché local clave/valor sobre Hive (diseño §2.5 y §8).
///
/// En la Fase 0 solo **inicializamos** la capa de almacenamiento y exponemos
/// una abstracción mínima ([LocalCache]) lista para usarse en features
/// posteriores. La caché completa de catálogos con estrategia
/// *stale-while-revalidate* se construye en la tarea 1.18; aquí no se
/// implementa el cacheo de catálogos.
///
/// Se eligió **Hive** sobre drift porque:
/// - no requiere generación de código (sin `build_runner` para arrancar),
/// - inicializa en una sola llamada (`Hive.initFlutter()`),
/// - permite tests sin dispositivo real usando un directorio temporal.
library;

import 'package:hive_flutter/hive_flutter.dart';

/// Nombre de la caja (box) por defecto para datos cacheados de la app.
const String kDefaultCacheBox = 'app_cache';

/// Inicializa la capa de caché local.
///
/// Debe llamarse una vez durante el bootstrap (ver `main.dart`), después de
/// `WidgetsFlutterBinding.ensureInitialized()`. Abre y devuelve una
/// [LocalCache] respaldada por la caja [boxName].
///
/// En tests se puede inicializar Hive con un directorio temporal
/// (`Hive.init(path)`) y pasar `initHive: false` para no volver a inicializarlo.
Future<LocalCache> initLocalCache({
  String boxName = kDefaultCacheBox,
  bool initHive = true,
}) async {
  if (initHive) {
    await Hive.initFlutter();
  }
  final box = await Hive.openBox<String>(boxName);
  return LocalCache(box);
}

/// Abstracción mínima de caché clave/valor con marca de tiempo opcional.
///
/// Guarda cadenas (p. ej. JSON serializado) junto a un `savedAt` para permitir
/// más adelante políticas de frescura (*stale-while-revalidate*). La lógica de
/// expiración/refresco en background se define en la tarea 1.18.
class LocalCache {
  LocalCache(this._box);

  final Box<String> _box;

  /// Sufijo de la clave donde se guarda la marca de tiempo (epoch ms) del
  /// último `put` de cada entrada.
  static const String _tsSuffix = '::savedAt';

  /// Guarda [value] bajo [key] y registra el instante de guardado.
  Future<void> put(String key, String value) async {
    await _box.put(key, value);
    await _box.put(
      '$key$_tsSuffix',
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Devuelve el valor cacheado para [key], o `null` si no existe.
  String? get(String key) => _box.get(key);

  /// Instante en que se guardó [key], o `null` si no hay registro.
  DateTime? savedAt(String key) {
    final raw = _box.get('$key$_tsSuffix');
    if (raw == null) return null;
    final ms = int.tryParse(raw);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Indica si existe un valor para [key].
  bool contains(String key) => _box.containsKey(key);

  /// Elimina [key] y su marca de tiempo asociada.
  Future<void> delete(String key) async {
    await _box.delete(key);
    await _box.delete('$key$_tsSuffix');
  }

  /// Vacía por completo la caja de caché.
  Future<void> clear() => _box.clear();

  /// Cierra la caja subyacente (liberar en logout o al terminar tests).
  Future<void> close() => _box.close();
}
