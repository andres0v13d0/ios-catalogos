/// Cálculo del precio ajustado por una regla de revendedor (markup, nunca
/// descuento) — puerto exacto de `price-rule-calculator.ts` del backend
/// (`surtte/main/backend/src/modules/reseller/pricing/price-rule-calculator.ts`).
///
/// Usado SOLO para la vista previa en vivo del editor "Ajustar precios": el
/// backend es la fuente de verdad al guardar (recalcula y persiste la regla,
/// no el precio final).
///
/// Aritmética entera en centavos, NUNCA floats: `int` de Dart es de 64 bits en
/// el runtime nativo (Android/iOS), de sobra para precios en pesos colombianos
/// sin riesgo de desbordamiento ni de error de redondeo binario.
library;

enum PriceRuleMode {
  percent,
  fixed;

  /// Valor tal como lo espera/devuelve el backend (`'percent'`/`'fixed'`).
  String get api => this == PriceRuleMode.percent ? 'percent' : 'fixed';

  static PriceRuleMode? fromApi(String? raw) {
    switch (raw) {
      case 'percent':
        return PriceRuleMode.percent;
      case 'fixed':
        return PriceRuleMode.fixed;
      default:
        return null;
    }
  }
}

/// Una regla de ajuste: modo + valor entero (porcentaje 1..300 o pesos
/// enteros 1..10.000.000).
class PriceRule {
  const PriceRule({required this.mode, required this.value});

  final PriceRuleMode mode;
  final int value;

  factory PriceRule.fromJson(Map<String, dynamic> json) {
    final mode = PriceRuleMode.fromApi(json['mode'] as String?);
    final rawValue = json['value'];
    final value = rawValue is num
        ? rawValue.toInt()
        : int.tryParse('${rawValue ?? ''}') ?? 0;
    if (mode == null) {
      throw const FormatException('Regla de precio con modo desconocido');
    }
    return PriceRule(mode: mode, value: value);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'mode': mode.api,
    'value': value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceRule && other.mode == mode && other.value == value;

  @override
  int get hashCode => Object.hash(mode, value);

  @override
  String toString() => 'PriceRule(${mode.api}, $value)';
}

const int kPercentValueMin = 1;
const int kPercentValueMax = 300;
const int kFixedValueMin = 1;
const int kFixedValueMax = 10000000;

const int _hundredPesosInCents = 10000;

/// Error controlado de una regla/precio inválidos (modo, rango, o un precio
/// de proveedor que no parsea como número).
class InvalidPriceRuleException implements Exception {
  const InvalidPriceRuleException(this.message);

  final String message;

  @override
  String toString() => 'InvalidPriceRuleException: $message';
}

/// Valida rango/entero de una regla. Lanza [InvalidPriceRuleException] si no
/// cumple — misma validación que el backend (`validatePriceRule`).
void validatePriceRule(PriceRuleMode mode, int value) {
  if (mode == PriceRuleMode.percent &&
      (value < kPercentValueMin || value > kPercentValueMax)) {
    throw InvalidPriceRuleException(
      'El porcentaje debe estar entre $kPercentValueMin y $kPercentValueMax',
    );
  }
  if (mode == PriceRuleMode.fixed &&
      (value < kFixedValueMin || value > kFixedValueMax)) {
    throw InvalidPriceRuleException(
      'El valor fijo debe estar entre $kFixedValueMin y $kFixedValueMax',
    );
  }
}

/// Convierte un precio (`num`, puede traer centavos) a centavos enteros
/// exactos, vía su representación decimal con 2 decimales (igual que el
/// backend parsea `decimal(10,2)`) — nunca multiplicación en punto flotante.
int _priceToCents(num price) {
  if (price < 0 || !price.isFinite) {
    throw InvalidPriceRuleException('Precio de proveedor inválido: $price');
  }
  final String fixed = price.toStringAsFixed(2);
  final int dot = fixed.indexOf('.');
  final String intPart = fixed.substring(0, dot);
  final String decPart = fixed.substring(dot + 1);
  return int.parse(intPart) * 100 + int.parse(decPart);
}

/// Redondea centavos a la centena de PESOS más cercana (10000 centavos),
/// mitad hacia arriba.
int _roundToHundredPesos(int cents) {
  final int quotient = cents ~/ _hundredPesosInCents;
  final int remainder = cents % _hundredPesosInCents;
  final bool roundUp = remainder * 2 >= _hundredPesosInCents;
  return (roundUp ? quotient + 1 : quotient) * _hundredPesosInCents;
}

/// Aplica una regla (o ninguna) al precio del proveedor. Sin regla, retorna
/// el precio del proveedor tal cual (en pesos). Lanza
/// [InvalidPriceRuleException] si la regla no es válida.
num applyPriceRule(num providerPrice, PriceRule? rule) {
  final int baseCents = _priceToCents(providerPrice);
  if (rule == null) {
    return baseCents / 100;
  }
  validatePriceRule(rule.mode, rule.value);

  final int adjustedCents = rule.mode == PriceRuleMode.percent
      ? (baseCents * (100 + rule.value)) ~/ 100
      : baseCents + rule.value * 100;

  int roundedCents = _roundToHundredPesos(adjustedCents);
  if (roundedCents < baseCents) {
    roundedCents += _hundredPesosInCents; // protección de piso
  }
  return roundedCents / 100;
}
