import 'catalog.dart';

/// Un grupo de catálogos de un mismo proveedor (encabezado de sección en la UI,
/// tarea 1.15).
class CatalogGroup {
  const CatalogGroup({
    required this.providerId,
    required this.providerLabel,
    required this.catalogs,
  });

  /// Id del proveedor del grupo.
  final int providerId;

  /// Etiqueta a mostrar como encabezado de sección.
  final String providerLabel;

  /// Catálogos del proveedor (orden estable por nombre a mostrar).
  final List<Catalog> catalogs;
}

/// Una opción de proveedor para el filtro (chip/dropdown), tarea 1.15.
class ProviderOption {
  const ProviderOption({required this.id, required this.label});

  final int id;
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProviderOption && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// Agrupa [catalogs] por proveedor y los ordena de forma estable:
/// grupos por etiqueta de proveedor (A→Z) y catálogos por nombre (A→Z).
List<CatalogGroup> groupByProvider(List<Catalog> catalogs) {
  final byProvider = <int, List<Catalog>>{};
  final labels = <int, String>{};
  for (final c in catalogs) {
    byProvider.putIfAbsent(c.providerId, () => <Catalog>[]).add(c);
    labels[c.providerId] = c.providerLabel;
  }

  final groups = byProvider.entries.map((entry) {
    final list = List<Catalog>.from(entry.value)
      ..sort((a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return CatalogGroup(
      providerId: entry.key,
      // La etiqueta usa el NOMBRE del proveedor (providerLabel). Nunca
      // "Proveedor <id>": cuando falta el nombre cae a 'Proveedor' sin id.
      providerLabel: labels[entry.key] ?? 'Proveedor',
      catalogs: list,
    );
  }).toList()
    ..sort((a, b) =>
        a.providerLabel.toLowerCase().compareTo(b.providerLabel.toLowerCase()));

  return groups;
}

/// Lista de proveedores distintos presentes en [catalogs], ordenada por
/// etiqueta (para poblar el filtro de proveedor).
List<ProviderOption> distinctProviders(List<Catalog> catalogs) {
  final labels = <int, String>{};
  for (final c in catalogs) {
    labels[c.providerId] = c.providerLabel;
  }
  final options = labels.entries
      .map((e) => ProviderOption(id: e.key, label: e.value))
      .toList()
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return options;
}

/// Aplica filtro cliente por [providerId] (si no es nulo) y por [search]
/// (subcadena case-insensitive sobre el nombre a mostrar). Fallback de cliente
/// cuando el backend no filtró (tarea 1.15 prefiere pasar providerId/search a
/// la API, con este filtrado como respaldo).
List<Catalog> filterCatalogs(
  List<Catalog> catalogs, {
  int? providerId,
  String? search,
}) {
  final query = (search ?? '').trim().toLowerCase();
  return catalogs.where((c) {
    if (providerId != null && c.providerId != providerId) return false;
    if (query.isNotEmpty && !c.displayName.toLowerCase().contains(query)) {
      return false;
    }
    return true;
  }).toList();
}
