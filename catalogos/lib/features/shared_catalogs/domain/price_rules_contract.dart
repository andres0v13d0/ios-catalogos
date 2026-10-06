/// Modelos del contrato REAL de `/reseller/app/catalogs/:catalogId/...`
/// (`reseller-price-rules.controller.ts`/`.service.ts`, backend) — backend de
/// "Ajustar precios" del revendedor. Ver PASO 0 de la tarea: contrato
/// verificado contra el código fuente real, no un resumen.
library;

import 'price_rule_calculator.dart';

/// Quién origina la regla EFECTIVA de un producto en el listado paginado:
/// su propia regla, o la del catálogo (fallback). `null` = sin regla.
enum RuleOrigin {
  product,
  catalog;

  static RuleOrigin? fromApi(String? raw) {
    switch (raw) {
      case 'product':
        return RuleOrigin.product;
      case 'catalog':
        return RuleOrigin.catalog;
      default:
        return null;
    }
  }
}

/// Un producto tal como lo entrega
/// `GET /reseller/app/catalogs/:catalogId/products` (paginado): precio del
/// proveedor Y ajustado por separado, más el origen de la regla efectiva.
/// NUNCA se usa este contrato para la vista pública (esa sigue sin exponer el
/// precio del proveedor).
class CatalogPriceRuleProduct {
  const CatalogPriceRuleProduct({
    required this.id,
    required this.nombre,
    required this.imagen,
    required this.precioProveedor,
    required this.precioAjustado,
    required this.reglaOrigen,
  });

  final String id;
  final String nombre;

  /// Imagen principal (única URL), o `null` si el producto no tiene.
  final String? imagen;

  /// Mapa `cantidad → precio` SIN ajustar (tal como lo cobra el proveedor).
  final Map<String, num> precioProveedor;

  /// Mapa `cantidad → precio` YA ajustado por la regla efectiva (si hay).
  final Map<String, num> precioAjustado;

  final RuleOrigin? reglaOrigen;

  /// Menor precio ajustado (para "Desde $X" / vista previa).
  num? get lowestAdjustedPrice =>
      precioAjustado.isEmpty ? null : precioAjustado.values.reduce((a, b) => a < b ? a : b);

  /// Menor precio del proveedor (para la línea "Proveedor $X" de la vista previa).
  num? get lowestProviderPrice =>
      precioProveedor.isEmpty ? null : precioProveedor.values.reduce((a, b) => a < b ? a : b);

  factory CatalogPriceRuleProduct.fromJson(Map<String, dynamic> json) {
    return CatalogPriceRuleProduct(
      id: '${json['id'] ?? ''}',
      nombre: '${json['nombre'] ?? ''}',
      imagen: json['imagen'] as String?,
      precioProveedor: _parsePrecios(json['precioProveedor']),
      precioAjustado: _parsePrecios(json['precioAjustado']),
      reglaOrigen: RuleOrigin.fromApi(json['reglaOrigen'] as String?),
    );
  }

  static Map<String, num> _parsePrecios(dynamic raw) {
    if (raw is! Map) return const <String, num>{};
    final result = <String, num>{};
    raw.forEach((key, value) {
      final n = value is num ? value : num.tryParse('${value ?? ''}');
      if (n != null) result['$key'] = n;
    });
    return result;
  }
}

/// Página de `GET /reseller/app/catalogs/:catalogId/products?page=&pageSize=`.
class PriceRulesProductsPage {
  const PriceRulesProductsPage({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.products,
  });

  final int total;
  final int page;
  final int pageSize;
  final List<CatalogPriceRuleProduct> products;

  factory PriceRulesProductsPage.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'];
    return PriceRulesProductsPage(
      total: _asInt(json['total']) ?? 0,
      page: _asInt(json['page']) ?? 1,
      pageSize: _asInt(json['pageSize']) ?? 20,
      products: rawProducts is List
          ? rawProducts
                .whereType<Map>()
                .map((e) => CatalogPriceRuleProduct.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const <CatalogPriceRuleProduct>[],
    );
  }
}

/// Respuesta de `GET /reseller/app/catalogs/:catalogId/price-rules`: la regla
/// de catálogo (si existe) y el mapa de reglas propias por producto.
class PriceRulesSummary {
  const PriceRulesSummary({required this.catalogRule, required this.productRules});

  final PriceRule? catalogRule;

  /// `productId → regla propia` (solo productos con regla propia).
  final Map<String, PriceRule> productRules;

  factory PriceRulesSummary.fromJson(Map<String, dynamic> json) {
    final rawCatalogRule = json['catalogRule'];
    final rawProductRules = json['productRules'];
    final productRules = <String, PriceRule>{};
    if (rawProductRules is List) {
      for (final item in rawProductRules) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final productId = '${map['productId'] ?? ''}';
          final ruleRaw = map['rule'];
          if (productId.isNotEmpty && ruleRaw is Map) {
            productRules[productId] = PriceRule.fromJson(Map<String, dynamic>.from(ruleRaw));
          }
        }
      }
    }
    return PriceRulesSummary(
      catalogRule: rawCatalogRule is Map
          ? PriceRule.fromJson(Map<String, dynamic>.from(rawCatalogRule))
          : null,
      productRules: productRules,
    );
  }
}

/// Respuesta de `PUT /reseller/app/catalogs/:catalogId/price-rules`.
class SavedCatalogRuleResult {
  const SavedCatalogRuleResult({
    required this.rule,
    required this.affectedProductIds,
    required this.productsWithOwnRule,
  });

  final PriceRule rule;
  final List<String> affectedProductIds;
  final List<String> productsWithOwnRule;

  factory SavedCatalogRuleResult.fromJson(Map<String, dynamic> json) {
    return SavedCatalogRuleResult(
      rule: PriceRule.fromJson(Map<String, dynamic>.from(json['rule'] as Map)),
      affectedProductIds: _stringList(json['affectedProductIds']),
      productsWithOwnRule: _stringList(json['productsWithOwnRule']),
    );
  }
}

/// Respuesta de `PUT /reseller/app/catalogs/:catalogId/products/:productId/price-rule`.
class SavedProductRuleResult {
  const SavedProductRuleResult({required this.rule, required this.productId});

  final PriceRule rule;
  final String productId;

  factory SavedProductRuleResult.fromJson(Map<String, dynamic> json) {
    return SavedProductRuleResult(
      rule: PriceRule.fromJson(Map<String, dynamic>.from(json['rule'] as Map)),
      productId: '${json['productId'] ?? ''}',
    );
  }
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const <String>[];
  return raw.map((e) => '$e').toList();
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
