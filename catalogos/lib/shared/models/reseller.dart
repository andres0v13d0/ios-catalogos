/// Modelo del revendedor (reseller), compartido entre features (tarea 1.13).
///
/// Mapea el contrato REAL del backend (camelCase):
///   { id:int, firebaseUid:string, telefonoE164:string,
///     nombre:string|null, countryCode:string }
///
/// `GET /reseller/me` y `PATCH /reseller/me` devuelven este objeto SIN `tipo`.
/// `POST /auth/login` devuelve el mismo objeto CON un campo extra
/// `tipo: 'REVENDEDOR'`. [fromJson] tolera ese campo extra (lo ignora) para
/// poder parsear ambas respuestas con el mismo modelo.
class Reseller {
  const Reseller({
    required this.id,
    required this.telefonoE164,
    required this.countryCode,
    this.firebaseUid,
    this.nombre,
  });

  /// Id del reseller en el backend.
  final int id;

  /// UID de Firebase asociado.
  ///
  /// Puede ser `null`: la respuesta de `POST /auth/reseller/verify-code`
  /// devuelve el reseller SIN `firebaseUid` (`{ id, telefonoE164, nombre,
  /// countryCode }`), mientras que `GET/PATCH /reseller/me` y `POST /auth/login`
  /// sí lo incluyen. [fromJson] tolera su ausencia.
  final String? firebaseUid;

  /// Teléfono en formato E.164.
  final String telefonoE164;

  /// Nombre del reseller; `null`/vacío significa perfil incompleto (tarea 1.13).
  final String? nombre;

  /// Código de país ISO (p. ej. `CO`).
  final String countryCode;

  /// `true` si el perfil tiene un nombre no vacío.
  bool get isProfileComplete => (nombre ?? '').trim().isNotEmpty;

  /// Construye un [Reseller] desde el JSON del backend (camelCase).
  ///
  /// Tolera el campo extra `tipo` (presente solo en `/auth/login`) y la
  /// ausencia de `firebaseUid` (ausente en la respuesta de `verify-code`).
  factory Reseller.fromJson(Map<String, dynamic> json) {
    return Reseller(
      id: (json['id'] as num).toInt(),
      firebaseUid: json['firebaseUid'] as String?,
      telefonoE164: json['telefonoE164'] as String,
      nombre: json['nombre'] as String?,
      countryCode: json['countryCode'] as String,
      // `tipo` se ignora deliberadamente.
    );
  }

  /// Serializa a JSON (camelCase). No incluye `tipo`.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'firebaseUid': firebaseUid,
        'telefonoE164': telefonoE164,
        'nombre': nombre,
        'countryCode': countryCode,
      };

  Reseller copyWith({
    int? id,
    String? firebaseUid,
    String? telefonoE164,
    String? nombre,
    String? countryCode,
  }) {
    return Reseller(
      id: id ?? this.id,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      telefonoE164: telefonoE164 ?? this.telefonoE164,
      nombre: nombre ?? this.nombre,
      countryCode: countryCode ?? this.countryCode,
    );
  }

  @override
  String toString() =>
      'Reseller(id: $id, telefonoE164: $telefonoE164, nombre: $nombre, '
      'countryCode: $countryCode)';
}
