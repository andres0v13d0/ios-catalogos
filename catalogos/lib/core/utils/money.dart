/// Utilidades de formateo monetario en pesos colombianos (COP).
///
/// Ver diseño §5 "Redondeo: COP sin decimales (UX-2), usando `NumberFormat`
/// es-CO en Flutter". Convención colombiana:
/// - separador de miles: `.`
/// - símbolo: `$`
/// - sin decimales en el flujo normal de precios.
///
/// Formato de salida de [formatCop]: `"$ 1.500.000"` (símbolo, espacio y el
/// entero con separadores de miles). Se incluye un espacio tras el `$` por
/// legibilidad.
library;

import 'package:intl/intl.dart';

/// Símbolo de moneda mostrado antes del importe.
const String _copSymbol = r'$';

/// Formateador de enteros con separador de miles al estilo es-CO (usa `.`).
///
/// Fijamos el patrón y los símbolos de forma explícita para no depender de que
/// los datos del locale es-CO estén inicializados en tiempo de ejecución; así
/// el resultado es determinista y testeable.
final NumberFormat _copInteger = NumberFormat('#,##0', 'en')
  ..maximumFractionDigits = 0;

/// Formatea un importe entero (en pesos) como COP: `"$ 1.500.000"`.
///
/// - Redondea a entero (sin decimales), acorde a UX-2.
/// - Usa `.` como separador de miles.
/// - Los valores negativos conservan el signo antes del símbolo: `"-$ 1.000"`.
///
/// Ejemplos:
/// ```dart
/// formatCop(0);        // "$ 0"
/// formatCop(1500000);  // "$ 1.500.000"
/// formatCop(-2500);    // "-$ 2.500"
/// ```
String formatCop(num amount) {
  final rounded = amount.round();
  final sign = rounded < 0 ? '-' : '';
  return '$sign$_copSymbol ${formatCopPlain(rounded)}';
}

/// Formatea sin el símbolo de moneda: `"1.500.000"`.
///
/// Útil cuando el símbolo se muestra por separado en la UI. Siempre devuelve el
/// valor absoluto agrupado en miles (el signo lo gestiona [formatCop]).
String formatCopPlain(num amount) {
  final formatted = _copInteger.format(amount.round().abs());
  // `NumberFormat('#,##0','en')` agrupa con `,`; lo convertimos a `.` (es-CO).
  return formatted.replaceAll(',', '.');
}
