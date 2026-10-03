/// Modelo de un catálogo compartido vinculado al revendedor (tareas 1.14/1.15).
///
/// === RECONCILIACIÓN DE NOMBRES DE CAMPO (TODO cuando el backend esté vivo) ===
/// Los contratos reales del backend (`POST /reseller/sync-shared-catalogs`,
/// `GET /reseller/me/shared-catalogs`) devuelven una lista `catalogs: [...]`,
/// pero los **nombres exactos** de los campos de cada catálogo NO están
/// totalmente fijados en el diseño (§3 denormaliza `provider_id` en
/// `reseller_shared_catalogs`, y la entidad origen es `private_catalogs`).
///
/// Para no bloquearnos, [Catalog.fromJson] es **tolerante**: acepta tanto
/// `snake_case` como `camelCase` para las claves ambiguas:
///   - id            ← id
///   - nombre a mostrar ← publicName | public_name | nombre | internalName | internal_name
///   - providerId    ← providerId | provider_id
///   - providerName  ← providerName | provider_name | null
///   - bannerUrl     ← bannerUrl | banner_url | null
///   - isReseller    ← isReseller | is_reseller | null
///
/// Cuando el backend esté en vivo, revisar la respuesta real y, si procede,
/// endurecer este parser a los nombres definitivos (centralizado aquí para que
/// el cambio sea de un solo punto). Ver también `tasks.md` 1.14/1.15.
class Catalog {
  const Catalog({
    required this.id,
    required this.displayName,
    required this.providerId,
    this.providerName,
    this.bannerUrl,
    this.isReseller,
  });

  /// Id del catálogo (uuid del `private_catalogs`).
  final String id;

  /// Nombre a mostrar del catálogo (preferimos `publicName`).
  final String displayName;

  /// Id del proveedor (denormalizado en `reseller_shared_catalogs`).
  final int providerId;

  /// Nombre del proveedor para agrupar/encabezados; puede ser `null`.
  final String? providerName;

  /// URL del banner del catálogo; puede ser `null`.
  final String? bannerUrl;

  /// Marca opcional de catálogo de revendedor; puede ser `null`.
  final bool? isReseller;

  /// Etiqueta de proveedor usada para agrupar en la UI. Si no hay
  /// `providerName`, cae a `Proveedor <providerId>`.
  String get providerLabel =>
      (providerName ?? '').trim().isNotEmpty
          ? providerName!.trim()
          : 'Proveedor $providerId';

  /// Construye un [Catalog] desde el JSON del backend de forma **tolerante**
  /// (acepta snake_case y camelCase). Ver nota de reconciliación arriba.
  factory Catalog.fromJson(Map<String, dynamic> json) {
    return Catalog(
      id: _asString(_pick(json, const <String>['id']))!,
      displayName: _asString(
            _pick(json, const <String>[
              'publicName',
              'public_name',
              'nombre',
              'internalName',
              'internal_name',
            ]),
          ) ??
          '',
      providerId: _asInt(
            _pick(json, const <String>['providerId', 'provider_id']),
          ) ??
          0,
      providerName: _asString(
        _pick(json, const <String>['providerName', 'provider_name']),
      ),
      bannerUrl: _asString(
        _pick(json, const <String>['bannerUrl', 'banner_url']),
      ),
      isReseller: _asBool(
        _pick(json, const <String>['isReseller', 'is_reseller']),
      ),
    );
  }

  /// Serializa a JSON en camelCase (usado para la caché local Hive).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'publicName': displayName,
        'providerId': providerId,
        'providerName': providerName,
        'bannerUrl': bannerUrl,
        'isReseller': isReseller,
      };

  /// Devuelve el primer valor no nulo entre las [keys] candidatas.
  static dynamic _pick(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) return value;
    }
    return null;
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    if (value is num) return value != 0;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Catalog &&
          other.id == id &&
          other.displayName == displayName &&
          other.providerId == providerId &&
          other.providerName == providerName &&
          other.bannerUrl == bannerUrl &&
          other.isReseller == isReseller;

  @override
  int get hashCode =>
      Object.hash(id, displayName, providerId, providerName, bannerUrl, isReseller);

  @override
  String toString() =>
      'Catalog(id: $id, displayName: $displayName, providerId: $providerId, '
      'providerName: $providerName)';
}

/// Resultado de `POST /reseller/sync-shared-catalogs`: `{ linked, catalogs }`.
///
/// [linked] es la cantidad de catálogos recién vinculados (0 en llamadas
/// idempotentes posteriores). [catalogs] es la lista completa de catálogos
/// vinculados al revendedor tras el sync.
class SyncResult {
  const SyncResult({required this.linked, required this.catalogs});

  /// Número de catálogos recién vinculados por esta llamada.
  final int linked;

  /// Lista de catálogos compartidos del revendedor tras el sync.
  final List<Catalog> catalogs;

  /// Parse tolerante de la respuesta del backend.
  factory SyncResult.fromJson(Map<String, dynamic> json) {
    final rawLinked = json['linked'];
    final linked = rawLinked is num
        ? rawLinked.toInt()
        : int.tryParse('${rawLinked ?? ''}') ?? 0;
    return SyncResult(
      linked: linked,
      catalogs: parseCatalogList(json['catalogs']),
    );
  }
}

/// Parse tolerante de una lista `catalogs` (acepta `null`, lista de mapas).
List<Catalog> parseCatalogList(dynamic raw) {
  if (raw is! List) return const <Catalog>[];
  final result = <Catalog>[];
  for (final item in raw) {
    if (item is Map<String, dynamic>) {
      result.add(Catalog.fromJson(item));
    } else if (item is Map) {
      result.add(Catalog.fromJson(Map<String, dynamic>.from(item)));
    }
  }
  return result;
}
