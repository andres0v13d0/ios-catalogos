// Test de filterProducts (búsqueda por nombre, tarea 2.1).
//
// El contrato de productos no trae categoría/subcategoría por producto (solo
// a nivel de catálogo), así que la pantalla "Productos del catálogo" (diseño
// A) solo filtra por nombre, del lado del cliente. Ver el comentario de
// catalog_detail_filter.dart para el razonamiento completo.

import 'package:catalogos/features/shared_catalogs/domain/catalog_detail.dart';
import 'package:catalogos/features/shared_catalogs/presentation/catalog_detail_filter.dart';
import 'package:flutter_test/flutter_test.dart';

const List<Product> _products = <Product>[
  Product(id: 'p1', nombre: 'Camiseta Básica Algodón'),
  Product(id: 'p2', nombre: 'Chaqueta Deportiva'),
  Product(id: 'p3', nombre: 'Gorra Clásica'),
];

void main() {
  group('filterProducts por nombre', () {
    test('subcadena case-insensitive estrecha la lista', () {
      final result = filterProducts(_products, search: 'chaq');
      expect(result.map((p) => p.id), <String>['p2']);
    });

    test('búsqueda sin coincidencias → lista vacía', () {
      final result = filterProducts(_products, search: 'zapatos');
      expect(result, isEmpty);
    });

    test('búsqueda vacía → todos', () {
      final result = filterProducts(_products, search: '   ');
      expect(result, _products);
    });
  });
}
