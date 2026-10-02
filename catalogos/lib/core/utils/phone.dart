/// Utilidades de normalización de números telefónicos a formato E.164.
///
/// Ver diseño §Fase 1 (login OTP con selector de país, **default +57**) y
/// requisitos de autenticación. El backend persiste `telefono_e164` único, por
/// lo que el cliente debe enviar siempre un número en E.164 canónico.
///
/// E.164: `+` seguido del código de país y el número nacional, sin espacios ni
/// separadores, máximo 15 dígitos en total. Para Colombia el código es `57` y
/// los números móviles son de 10 dígitos (empiezan por `3`), p. ej.
/// `3001234567` → `+573001234567`.
library;

/// Código de país por defecto (Colombia) sin el prefijo `+`.
const String defaultCountryCode = '57';

/// Normaliza un número telefónico a E.164 usando [countryCode] como país por
/// defecto (Colombia `57`).
///
/// Reglas:
/// - Elimina espacios, guiones, paréntesis y puntos.
/// - Si el número viene con prefijo internacional (`+` o `00`), respeta ese
///   código de país.
/// - Si viene como número nacional, antepone `+<countryCode>`.
/// - Tolera un `0` troncal nacional inicial (lo descarta).
///
/// Devuelve el número en E.164 (`+57XXXXXXXXXX`) o `null` si la entrada no
/// produce un número válido (vacía, con letras, o fuera de rango de longitud).
///
/// Ejemplos:
/// ```dart
/// normalizeToE164('3001234567');        // "+573001234567"
/// normalizeToE164('300 123 4567');      // "+573001234567"
/// normalizeToE164('(300) 123-4567');    // "+573001234567"
/// normalizeToE164('+573001234567');     // "+573001234567"
/// normalizeToE164('abc');               // null
/// ```
String? normalizeToE164(String? input, {String countryCode = defaultCountryCode}) {
  if (input == null) return null;

  final trimmed = input.trim();
  if (trimmed.isEmpty) return null;

  // ¿La entrada declara explícitamente un prefijo internacional?
  final hasPlus = trimmed.startsWith('+');
  final hasZeroZero = trimmed.startsWith('00');

  // Nos quedamos solo con los dígitos.
  var digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;

  // `00` como prefijo internacional equivale a `+`.
  if (hasZeroZero) {
    digits = digits.substring(2);
    if (digits.isEmpty) return null;
    return _validate(digits);
  }

  // `+` ya trae el código de país incluido en los dígitos.
  if (hasPlus) {
    return _validate(digits);
  }

  // Si ya empieza con el código de país y la longitud es la esperada
  // (código + 10 dígitos nacionales), lo tratamos como internacional sin `+`.
  if (digits.startsWith(countryCode) &&
      digits.length == countryCode.length + 10) {
    return _validate(digits);
  }

  // Número nacional: descartamos un `0` troncal inicial si existe.
  if (digits.startsWith('0')) {
    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    if (digits.isEmpty) return null;
  }

  return _validate('$countryCode$digits');
}

/// Valida la longitud total E.164 (entre 8 y 15 dígitos, estándar permisivo)
/// y devuelve el número con el prefijo `+`, o `null` si está fuera de rango.
String? _validate(String digits) {
  if (digits.length < 8 || digits.length > 15) return null;
  return '+$digits';
}

/// Indica si [value] es un E.164 válido (`+` seguido de 8 a 15 dígitos).
bool isValidE164(String? value) {
  if (value == null) return false;
  return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(value);
}
