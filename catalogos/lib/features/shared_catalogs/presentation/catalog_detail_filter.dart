import '../domain/catalog_detail.dart';

/// Búsqueda por nombre sobre los productos del catálogo (tarea 2.1).
///
/// === DECISIÓN / SUPUESTO DOCUMENTADO ===
/// El contrato de `GET /catalog/by-catalog/:id/products` NO entrega categoría
/// ni subcategoría **por producto** (solo a nivel de `catalog`, un único valor
/// para todo el catálogo), así que no sirven para particionar la lista de
/// productos cargada. La pantalla "Productos del catálogo" (diseño A) por eso
/// solo ofrece búsqueda por nombre; el filtrado es del lado del cliente sobre
/// la lista ya cargada, con subcadena case-insensitive.
///
/// Si en el futuro el backend añade categoría por producto, o se agregan
/// facetas de color/talla a la UI, este es el punto único donde extender el
/// filtro.
List<Product> filterProducts(List<Product> products, {String search = ''}) {
  final String query = search.trim().toLowerCase();
  if (query.isEmpty) return products;
  return products
      .where((Product p) => p.nombre.toLowerCase().contains(query))
      .toList();
}
