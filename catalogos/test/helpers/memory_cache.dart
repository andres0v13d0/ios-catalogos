import 'package:catalogos/core/storage/storage.dart';

/// LocalCache en memoria para tests de widgets (sin Hive ni disco).
class MemoryCache implements LocalCache {
  final Map<String, String> _m = <String, String>{};

  @override
  Future<void> put(String key, String value) async => _m[key] = value;

  @override
  String? get(String key) => _m[key];

  @override
  DateTime? savedAt(String key) => null;

  @override
  bool contains(String key) => _m.containsKey(key);

  @override
  Future<void> delete(String key) async => _m.remove(key);

  @override
  Future<void> clear() async => _m.clear();

  @override
  Future<void> close() async {}
}
