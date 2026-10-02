// Tests de la caché local Hive (tarea 0.6, diseño §2.5/§8).
//
// Se usa un directorio temporal con `Hive.init(path)` para no depender de un
// dispositivo real; por eso `initLocalCache(initHive: false)` evita volver a
// inicializar Hive dentro del helper.

import 'dart:io';

import 'package:catalogos/core/storage/local_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_cache_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('initLocalCache abre una caja y devuelve una LocalCache usable',
      () async {
    final cache = await initLocalCache(
      boxName: 'test_box',
      initHive: false,
    );
    expect(cache, isA<LocalCache>());
    await cache.close();
  });

  test('put/get almacena y recupera valores', () async {
    final cache = await initLocalCache(boxName: 'test_box', initHive: false);

    expect(cache.get('k'), isNull);
    expect(cache.contains('k'), isFalse);

    await cache.put('k', 'v');

    expect(cache.get('k'), 'v');
    expect(cache.contains('k'), isTrue);
    expect(cache.savedAt('k'), isNotNull);

    await cache.close();
  });

  test('delete elimina valor y marca de tiempo', () async {
    final cache = await initLocalCache(boxName: 'test_box', initHive: false);
    await cache.put('k', 'v');

    await cache.delete('k');

    expect(cache.get('k'), isNull);
    expect(cache.savedAt('k'), isNull);
    expect(cache.contains('k'), isFalse);

    await cache.close();
  });

  test('clear vacía la caja', () async {
    final cache = await initLocalCache(boxName: 'test_box', initHive: false);
    await cache.put('a', '1');
    await cache.put('b', '2');

    await cache.clear();

    expect(cache.get('a'), isNull);
    expect(cache.get('b'), isNull);

    await cache.close();
  });

  test('la persistencia sobrevive a reabrir la caja', () async {
    final cache = await initLocalCache(boxName: 'persist_box', initHive: false);
    await cache.put('token', 'abc');
    await cache.close();

    final reopened =
        await initLocalCache(boxName: 'persist_box', initHive: false);
    expect(reopened.get('token'), 'abc');
    await reopened.close();
  });
}
