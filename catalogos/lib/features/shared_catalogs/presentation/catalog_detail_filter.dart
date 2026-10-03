import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/catalog_detail.dart';

/// Filtro del detalle de catálogo (tarea 1.17).
///
/// === DECISIÓN DE FACETAS / SUPUESTO DOCUMENTADO ===
/// El contrato de `GET /catalog/by-catalog/:id/products` NO entrega categoría ni
/// subcategoría **por producto**: `categoryId`/`subcategoryId` existen solo a
/// nivel de `catalog` (un único valor para todo el catálogo), por lo que no
/// sirven para particionar la lista de productos cargada.
///
/// Por tanto, siguiendo la guía de la tarea (priorizar la búsqueda por nombre,
/// que es la señal fiable, e implementar el filtro con las facetas realmente
/// disponibles en el payload), el filtro combina:
///   1. **Búsqueda por nombre** (subcadena case-insensitive sobre `nombre`) —
///      la vía principal y siempre soportada.
///   2. **Faceta por variante disponible** (color y/o talla), derivada de los
///      propios productos (`colores`/`tallas`). Es la aproximación más cercana a
///      "categoría/subcategoría" que el payload permite sin inventar datos.
/// Todo el filtrado es **del lado del cliente** sobre la lista ya cargada.
///
/// Si en el futuro el backend añade categoría por producto, basta con extender
/// [DetailFilter]/[filterProducts] aquí (punto único de cambio).
class DetailFilter {
  const DetailFilter({this.search = '', this.color, this.size});

  /// Texto de búsqueda por nombre de producto.
  final String search;

  /// Nombre de color seleccionado como faceta (o `null` = todos).
  final String? color;

  /// Nombre de talla seleccionada como faceta (o `null` = todas).
  final String? size;

  bool get isEmpty => search.trim().isEmpty && color == null && size == null;

  DetailFilter copyWith({
    String? search,
    String? color,
    bool clearColor = false,
    String? size,
    bool clearSize = false,
  }) {
    return DetailFilter(
      search: search ?? this.search,
      color: clearColor ? null : (color ?? this.color),
      size: clearSize ? null : (size ?? this.size),
    );
  }
}

/// Notifier del filtro del detalle (búsqueda + facetas de variante).
class DetailFilterController extends Notifier<DetailFilter> {
  @override
  DetailFilter build() => const DetailFilter();

  void setSearch(String value) => state = state.copyWith(search: value);

  void selectColor(String? color) {
    state = color == null
        ? state.copyWith(clearColor: true)
        : state.copyWith(color: color);
  }

  void selectSize(String? size) {
    state = size == null
        ? state.copyWith(clearSize: true)
        : state.copyWith(size: size);
  }

  void clear() => state = const DetailFilter();
}

/// Provider del filtro del detalle de catálogo.
final NotifierProvider<DetailFilterController, DetailFilter>
    detailFilterProvider =
    NotifierProvider<DetailFilterController, DetailFilter>(
  DetailFilterController.new,
);

/// Aplica el filtro del cliente sobre [products]:
/// - por nombre (subcadena case-insensitive) si [search] no está vacío;
/// - por color si [color] no es nulo (el producto debe ofrecer ese color);
/// - por talla si [size] no es nula (el producto debe ofrecer esa talla).
List<Product> filterProducts(
  List<Product> products, {
  String search = '',
  String? color,
  String? size,
}) {
  final query = search.trim().toLowerCase();
  return products.where((p) {
    if (query.isNotEmpty && !p.nombre.toLowerCase().contains(query)) {
      return false;
    }
    if (color != null &&
        !p.colores.any((v) => v.name.toLowerCase() == color.toLowerCase())) {
      return false;
    }
    if (size != null &&
        !p.tallas.any((v) => v.name.toLowerCase() == size.toLowerCase())) {
      return false;
    }
    return true;
  }).toList();
}

/// Colores distintos presentes en [products] (facetas de color), ordenados.
List<String> distinctColors(List<Product> products) {
  final set = <String>{};
  for (final p in products) {
    for (final v in p.colores) {
      if (v.name.trim().isNotEmpty) set.add(v.name.trim());
    }
  }
  final list = set.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}

/// Tallas distintas presentes en [products] (facetas de talla), ordenadas.
List<String> distinctSizes(List<Product> products) {
  final set = <String>{};
  for (final p in products) {
    for (final v in p.tallas) {
      if (v.name.trim().isNotEmpty) set.add(v.name.trim());
    }
  }
  final list = set.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}
