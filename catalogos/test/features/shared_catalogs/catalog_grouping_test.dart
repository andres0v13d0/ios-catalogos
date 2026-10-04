// Tests de agrupación y filtrado de catálogos compartidos (tarea 1.15).

import 'package:catalogos/features/shared_catalogs/domain/catalog.dart';
import 'package:catalogos/features/shared_catalogs/domain/catalog_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

Catalog _c({
  required String id,
  required String name,
  required int providerId,
  String? providerName,
}) {
  return Catalog(
    id: id,
    displayName: name,
    providerId: providerId,
    providerName: providerName,
  );
}

void main() {
  final catalogs = <Catalog>[
    _c(id: '1', name: 'Zapatos', providerId: 10, providerName: 'Proveedor A'),
    _c(id: '2', name: 'Bolsos', providerId: 10, providerName: 'Proveedor A'),
    _c(id: '3', name: 'Camisas', providerId: 20, providerName: 'Proveedor B'),
    _c(id: '4', name: 'Pantalones', providerId: 20, providerName: 'Proveedor B'),
  ];

  group('groupByProvider', () {
    test('agrupa catálogos de 2+ proveedores correctamente', () {
      final groups = groupByProvider(catalogs);

      expect(groups, hasLength(2));
      // Orden de grupos por etiqueta de proveedor (A antes que B).
      expect(groups[0].providerLabel, 'Proveedor A');
      expect(groups[1].providerLabel, 'Proveedor B');
      expect(groups[0].catalogs.map((c) => c.id), <String>['2', '1']);
      expect(groups[1].catalogs.map((c) => c.id), <String>['3', '4']);
    });

    test('ordena catálogos por nombre dentro del grupo', () {
      final groups = groupByProvider(catalogs);
      // Proveedor A: "Bolsos" antes que "Zapatos".
      expect(groups[0].catalogs.first.displayName, 'Bolsos');
    });

    test('usa providerLabel de fallback (sin id) cuando no hay providerName',
        () {
      final groups = groupByProvider(<Catalog>[
        _c(id: 'x', name: 'Sin nombre', providerId: 77),
      ]);
      // Nunca "Proveedor 77": sin nombre cae a 'Proveedor' sin el id.
      expect(groups.single.providerLabel, 'Proveedor');
    });
  });

  group('distinctProviders', () {
    test('devuelve proveedores distintos ordenados', () {
      final providers = distinctProviders(catalogs);
      expect(providers.map((p) => p.id), <int>[10, 20]);
      expect(providers.map((p) => p.label),
          <String>['Proveedor A', 'Proveedor B']);
    });
  });

  group('filterCatalogs', () {
    test('el filtro por proveedor estrecha los resultados', () {
      final filtered = filterCatalogs(catalogs, providerId: 20);
      expect(filtered, hasLength(2));
      expect(filtered.every((c) => c.providerId == 20), isTrue);
    });

    test('la búsqueda filtra por nombre (case-insensitive)', () {
      final filtered = filterCatalogs(catalogs, search: 'cami');
      expect(filtered, hasLength(1));
      expect(filtered.single.displayName, 'Camisas');
    });

    test('proveedor + búsqueda combinados', () {
      final filtered =
          filterCatalogs(catalogs, providerId: 10, search: 'zap');
      expect(filtered, hasLength(1));
      expect(filtered.single.displayName, 'Zapatos');
    });

    test('sin filtros devuelve todo', () {
      expect(filterCatalogs(catalogs), hasLength(4));
    });
  });
}
