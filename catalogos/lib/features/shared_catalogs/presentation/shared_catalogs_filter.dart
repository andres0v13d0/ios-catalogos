import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado del filtro de la lista de catálogos compartidos (tarea 1.15):
/// un proveedor opcional seleccionado y un texto de búsqueda por nombre.
class SharedCatalogsFilter {
  const SharedCatalogsFilter({this.providerId, this.search = ''});

  /// Proveedor seleccionado (chip/dropdown); `null` = todos.
  final int? providerId;

  /// Texto de búsqueda (filtra por nombre de catálogo).
  final String search;

  bool get isEmpty => providerId == null && search.trim().isEmpty;

  SharedCatalogsFilter copyWith({
    int? providerId,
    bool clearProvider = false,
    String? search,
  }) {
    return SharedCatalogsFilter(
      providerId: clearProvider ? null : (providerId ?? this.providerId),
      search: search ?? this.search,
    );
  }
}

/// Notifier del filtro (selección de proveedor + búsqueda).
class SharedCatalogsFilterController extends Notifier<SharedCatalogsFilter> {
  @override
  SharedCatalogsFilter build() => const SharedCatalogsFilter();

  /// Selecciona un proveedor (o `null` para "todos").
  void selectProvider(int? providerId) {
    state = providerId == null
        ? state.copyWith(clearProvider: true)
        : state.copyWith(providerId: providerId);
  }

  /// Actualiza el texto de búsqueda.
  void setSearch(String value) => state = state.copyWith(search: value);

  /// Limpia el filtro por completo.
  void clear() => state = const SharedCatalogsFilter();
}

/// Provider del filtro de catálogos compartidos.
final NotifierProvider<SharedCatalogsFilterController, SharedCatalogsFilter>
    sharedCatalogsFilterProvider =
    NotifierProvider<SharedCatalogsFilterController, SharedCatalogsFilter>(
  SharedCatalogsFilterController.new,
);
