// Tests del filtro del detalle de catálogo (tarea 1.17).
//
// Verifica el filtrado del lado del cliente:
// - búsqueda por nombre (subcadena case-insensitive),
// - faceta por variante (color/talla) con la aproximación documentada
//   (el payload no trae categoría por producto; se usan las variantes).

import 'package:catalogos/features/shared_catalogs/domain/catalog_detail.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_detail_filter.dart';
import 'package:flutter_test/flutter_test.dart';

const List<Product> _products = <Product>[
  Product(
    id: 'p1',
    nombre: 'Camiseta Roja',
    colores: <Variant>[Variant(id: 'r', name: 'Rojo')],
    tallas: <Variant>[Variant(id: 'm', name: 'M')],
  ),
  Product(
    id: 'p2',
    nombre: 'Gorra Azul',
    colores: <Variant>[Variant(id: 'a', name: 'Azul')],
    tallas: <Variant>[Variant(id: 'u', name: 'Única')],
  ),
  Product(
    id: 'p3',
    nombre: 'Camisa Formal',
    colores: <Variant>[
      Variant(id: 'b', name: 'Blanco'),
      Variant(id: 'a', name: 'Azul'),
    ],
    tallas: <Variant>[Variant(id: 'l', name: 'L')],
  ),
];

void main() {
  group('filterProducts por nombre', () {
    test('subcadena case-insensitive estrecha la lista', () {
      final result = filterProducts(_products, search: 'cami');
      expect(result.map((p) => p.id), <String>['p1', 'p3']);
    });

    test('búsqueda sin coincidencias → lista vacía', () {
      expect(filterProducts(_products, search: 'zzz'), isEmpty);
    });

    test('búsqueda vacía → todos', () {
      expect(filterProducts(_products, search: '   '), hasLength(3));
    });
  });

  group('filterProducts por faceta de variante', () {
    test('color estrecha a los productos que lo ofrecen', () {
      final result = filterProducts(_products, color: 'Azul');
      expect(result.map((p) => p.id), <String>['p2', 'p3']);
    });

    test('talla estrecha correctamente', () {
      final result = filterProducts(_products, size: 'M');
      expect(result.map((p) => p.id), <String>['p1']);
    });

    test('nombre + color se combinan (AND)', () {
      final result =
          filterProducts(_products, search: 'cami', color: 'Azul');
      // "cami" → p1, p3; color Azul → p2, p3 ⇒ intersección p3.
      expect(result.map((p) => p.id), <String>['p3']);
    });
  });

  group('facetas disponibles', () {
    test('distinctColors ordenados y únicos', () {
      expect(distinctColors(_products), <String>['Azul', 'Blanco', 'Rojo']);
    });

    test('distinctSizes ordenados y únicos', () {
      expect(distinctSizes(_products), <String>['L', 'M', 'Única']);
    });
  });
}
