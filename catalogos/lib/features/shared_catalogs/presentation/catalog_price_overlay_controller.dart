import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../data/reseller_price_rules_repository.dart';
import '../domain/price_rule_calculator.dart';
import '../domain/price_rules_contract.dart';

/// Overlay de "Ajustar precios" para la cuadrícula de "Productos del
/// catálogo": precio del proveedor + origen de la regla por producto, y la
/// regla de catálogo (para la insignia del acceso rápido). Se obtiene de los
/// endpoints NUEVOS del revendedor (`/reseller/app/catalogs/...`), NUNCA de
/// la vista pública (que nunca expone el precio del proveedor).
///
/// Es puramente una mejora de presentación: cualquier error (red, 403, el
/// catálogo no es un canal, etc.) deja el overlay vacío en vez de romper la
/// pantalla — la cuadrícula ya funciona sin él (etapa 1).
class CatalogPriceOverlayState {
  const CatalogPriceOverlayState({this.catalogRule, this.byProductId = const {}});

  final PriceRule? catalogRule;
  final Map<String, CatalogPriceRuleProduct> byProductId;

  static const CatalogPriceOverlayState empty = CatalogPriceOverlayState();
}

class CatalogPriceOverlayController extends AsyncNotifier<CatalogPriceOverlayState> {
  CatalogPriceOverlayController(this._catalogId);

  final String _catalogId;

  ResellerPriceRulesRepository get _repo => ref.read(resellerPriceRulesRepositoryProvider);

  @override
  Future<CatalogPriceOverlayState> build() async {
    final summaryResult = await _repo.getRulesSummary(_catalogId);
    if (summaryResult is Err<PriceRulesSummary>) {
      return CatalogPriceOverlayState.empty;
    }
    final summary = (summaryResult as Ok<PriceRulesSummary>).value;

    final byProductId = <String, CatalogPriceRuleProduct>{};
    int page = 1;
    int? total;
    // Acotado a 10 páginas (≤1000 productos): protección razonable contra un
    // bucle largo si `total` llegara a ser enorme; en la práctica un catálogo
    // de canal cabe en 1-2 páginas.
    while (total == null || (byProductId.length < total && page <= 10)) {
      final pageResult = await _repo.getCatalogProducts(
        _catalogId,
        page: page,
        pageSize: ResellerPriceRulesRepository.maxPageSize,
      );
      if (pageResult is Err<PriceRulesProductsPage>) break;
      final value = (pageResult as Ok<PriceRulesProductsPage>).value;
      for (final product in value.products) {
        byProductId[product.id] = product;
      }
      total = value.total;
      if (value.products.isEmpty) break;
      page++;
    }

    return CatalogPriceOverlayState(catalogRule: summary.catalogRule, byProductId: byProductId);
  }

  /// Fuerza una recarga (tras guardar/quitar una regla desde el editor).
  Future<void> reload() async {
    state = const AsyncLoading<CatalogPriceOverlayState>();
    state = await AsyncValue.guard(build);
  }
}

final catalogPriceOverlayControllerProvider = AsyncNotifierProvider.family<
  CatalogPriceOverlayController,
  CatalogPriceOverlayState,
  String
>(CatalogPriceOverlayController.new);
