/// Modelo de un catálogo compartido vinculado al revendedor (tareas 1.14/1.15).
///
/// === FORMA REAL DEL BACKEND (anidada) ===
/// `GET /reseller/me/shared-catalogs` y `POST /reseller/sync-shared-catalogs`
/// devuelven elementos con esta forma (ver `serializeSharedCatalog` en
/// `backend/src/modules/reseller/reseller.controller.ts`):
///
/// ```json
/// {
///   "id": 3,                 // reseller_shared_catalogs.id (INT serial) — el id del VÍNCULO
///   "catalogId": "<uuid>",   // private_catalogs.id (UUID) — el que necesita el detalle
///   "providerId": 5,
///   "linkedAt": "...",
///   "catalog":  { "id": "<uuid>", "publicName", "description", "bannerUrl", "enlace", "priceField" },
///   "provider": { "id", "nombreEmpresa", "logoUrl", "logoOptimizedUrl", "bannerUrl", "bannerDesktopUrl", "bannerMobileUrl" }
/// }
/// ```
///
/// === RELACIÓN DE ENTIDADES (backend) ===
/// - `reseller_shared_catalogs.id` = INT serial (el "3"). Entidad:
///   `backend/src/modules/reseller/entities/reseller-shared-catalog.entity.ts`.
///   NUNCA usar este id como id de catálogo.
/// - `reseller_shared_catalogs.catalog_id` = UUID → FK a `private_catalogs.id`.
///   El detalle `GET /catalog/by-catalog/:catalogId/products`
///   (`backend/src/modules/private-catalogs/private-catalogs.controller.ts`,
///   `@Param ParseUUIDPipe`) EXIGE este UUID. Por eso [id] debe ser el UUID.
/// - Datos públicos del proveedor en `proveedores`
///   (`backend/src/modules/providers/entity/provider.entity.ts`): `nombre_empresa`,
///   `logo_url`, `logo_optimized_url`, `banner_url`, `banner_desktop_url`,
///   `banner_mobile_url`.
///
/// [Catalog.fromJson] prioriza la forma anidada real, pero sigue siendo
/// **tolerante** (acepta claves anidadas o planas, snake o camelCase) para la
/// caché local y para payloads legados.
class Catalog {
  const Catalog({
    required this.id,
    required this.displayName,
    required this.providerId,
    this.linkId,
    this.providerName,
    this.providerLogoUrl,
    this.providerBannerUrl,
    this.bannerUrl,
    this.ogImageUrl,
    this.priceField,
    this.isReseller,
  });

  /// Id del catálogo (**UUID** de `private_catalogs`). Es el que se pasa al
  /// detalle (`/catalog/by-catalog/<uuid>/products`). NUNCA el id del vínculo.
  final String id;

  /// Id serial del vínculo `reseller_shared_catalogs` (top-level `id`). Es
  /// opcional e informativo; no debe usarse para abrir el detalle.
  final int? linkId;

  /// Nombre a mostrar del catálogo (preferimos `catalog.publicName`).
  final String displayName;

  /// Id del proveedor (denormalizado en `reseller_shared_catalogs`).
  final int providerId;

  /// Nombre del proveedor (de `provider.nombreEmpresa`); puede ser `null`.
  final String? providerName;

  /// Logo del proveedor (preferimos el optimizado); puede ser `null`.
  final String? providerLogoUrl;

  /// Banner del proveedor para encabezados; puede ser `null`.
  final String? providerBannerUrl;

  /// URL del banner del catálogo; puede ser `null`.
  final String? bannerUrl;

  /// Portada de respaldo del catálogo (`catalog.ogImageUrl`); puede ser `null`.
  /// Se usa como segundo candidato de imagen de la tarjeta cuando no hay
  /// [bannerUrl] propio del catálogo.
  final String? ogImageUrl;

  /// Campo de precio del catálogo. `'none'` ⇒ modo "sin precios".
  final String? priceField;

  /// Marca opcional de catálogo de revendedor; puede ser `null`.
  final bool? isReseller;

  /// Etiqueta de proveedor usada para agrupar/encabezados en la UI. Si hay
  /// [providerName] lo usa; si no, cae a un genérico `'Proveedor'` SIN el id
  /// (nunca `Proveedor <id>`).
  String get providerLabel {
    final name = (providerName ?? '').trim();
    return name.isNotEmpty ? name : 'Proveedor';
  }

  /// Iniciales (hasta 2, mayúsculas) del nombre del proveedor para el avatar.
  /// Devuelve un marcador neutro `'PR'` cuando no hay nombre.
  String get providerInitials {
    final name = (providerName ?? '').trim();
    if (name.isEmpty) return 'PR';
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'PR';
    if (words.length == 1) {
      final w = words.first;
      final take = w.length >= 2 ? w.substring(0, 2) : w;
      return take.toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  /// Imagen principal de la tarjeta (el CATÁLOGO es el protagonista). Orden de
  /// resolución: banner del catálogo → portada (ogImage) del catálogo → banner
  /// del proveedor → `null` (la UI muestra un gradiente de marca). Las cadenas
  /// vacías se tratan como ausentes.
  String? get coverImageUrl {
    final candidates = <String?>[bannerUrl, ogImageUrl, providerBannerUrl];
    for (final c in candidates) {
      if (c != null && c.trim().isNotEmpty) return c;
    }
    return null;
  }

  /// `true` si el catálogo oculta precios (`priceField == 'none'`). La UI
  /// muestra una insignia discreta "Sin precios".
  bool get isPriceHidden => (priceField ?? '').toLowerCase() == 'none';

  /// Construye un [Catalog] desde el JSON del backend. Prioriza la forma
  /// anidada real (`catalog`/`provider`) y acepta también claves planas
  /// (snake/camelCase) por tolerancia (caché local / payloads legados).
  factory Catalog.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> catalog = _asMap(json['catalog']);
    final Map<String, dynamic> provider = _asMap(json['provider']);

    // --- id del catálogo (UUID). Prioriza catalogId / catalog.id; el top-level
    // `id` solo se acepta si parece un UUID (nunca el id numérico del vínculo).
    final String? catalogIdField =
        _asString(_pick(json, const <String>['catalogId', 'catalog_id']));
    final String? nestedCatalogId = _asString(catalog['id']);
    final dynamic topLevelId = json['id'];
    final String? legacyUuid =
        _looksLikeUuid(topLevelId) ? _asString(topLevelId) : null;
    final String id = catalogIdField ?? nestedCatalogId ?? legacyUuid ?? '';

    // --- linkId: clave explícita `linkId` (round-trip de la caché) o el
    // top-level `id` cuando es numérico (forma real del backend).
    final int? linkId = _asInt(json['linkId']) ??
        (legacyUuid == null ? _asInt(topLevelId) : null);

    // --- displayName: catalog.publicName | ... | top-level publicName | ''.
    // PRIVACIDAD: NUNCA se usa internalName/internal_name como fallback; el
    // nombre interno del catálogo jamás debe mostrarse al revendedor.
    final String displayName = _asString(
          _pick(catalog, const <String>['publicName', 'public_name']) ??
              _pick(json, const <String>[
                'publicName',
                'public_name',
                'nombre',
              ]),
        ) ??
        '';

    // --- providerId: top-level providerId | provider.id | provider_id.
    final int providerId = _asInt(
          _pick(json, const <String>['providerId', 'provider_id']) ??
              provider['id'],
        ) ??
        0;

    // --- providerName: provider.nombreEmpresa | ... | top-level providerName.
    final String? providerName = _asString(
      _pick(provider, const <String>['nombreEmpresa', 'nombre_empresa']) ??
          _pick(json, const <String>[
            'providerName',
            'provider_name',
            'providerNombreEmpresa',
          ]),
    );

    // --- providerLogoUrl: optimizado primero, luego logo_url.
    final String? providerLogoUrl = _asString(
      _pick(provider, const <String>[
            'logoOptimizedUrl',
            'logo_optimized_url',
            'logoUrl',
            'logo_url',
          ]) ??
          _pick(json, const <String>[
            'providerLogoUrl',
            'provider_logo_url',
          ]),
    );

    // --- providerBannerUrl: provider.bannerUrl | banner_url.
    final String? providerBannerUrl = _asString(
      _pick(provider, const <String>['bannerUrl', 'banner_url']) ??
          _pick(json, const <String>[
            'providerBannerUrl',
            'provider_banner_url',
          ]),
    );

    // --- bannerUrl (del catálogo): catalog.bannerUrl | ... | top-level.
    final String? bannerUrl = _asString(
      _pick(catalog, const <String>['bannerUrl', 'banner_url']) ??
          _pick(json, const <String>['bannerUrl', 'banner_url']),
    );

    // --- ogImageUrl (portada del catálogo): catalog.ogImageUrl | ... | top-level.
    final String? ogImageUrl = _asString(
      _pick(catalog, const <String>['ogImageUrl', 'og_image_url']) ??
          _pick(json, const <String>['ogImageUrl', 'og_image_url']),
    );

    // --- priceField: catalog.priceField | ... | top-level.
    final String? priceField = _asString(
      _pick(catalog, const <String>['priceField', 'price_field']) ??
          _pick(json, const <String>['priceField', 'price_field']),
    );

    // --- isReseller: catalog.isReseller | ... | top-level.
    final bool? isReseller = _asBool(
      _pick(catalog, const <String>['isReseller', 'is_reseller']) ??
          _pick(json, const <String>['isReseller', 'is_reseller']),
    );

    return Catalog(
      id: id,
      linkId: linkId,
      displayName: displayName,
      providerId: providerId,
      providerName: providerName,
      providerLogoUrl: providerLogoUrl,
      providerBannerUrl: providerBannerUrl,
      bannerUrl: bannerUrl,
      ogImageUrl: ogImageUrl,
      priceField: priceField,
      isReseller: isReseller,
    );
  }

  /// Serializa a JSON plano con claves estables (usado para la caché local
  /// Hive). Diseñado para que `fromJson(toJson(x)) == x` (round-trip).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'catalogId': id,
        'linkId': linkId,
        'publicName': displayName,
        'providerId': providerId,
        'providerName': providerName,
        'providerLogoUrl': providerLogoUrl,
        'providerBannerUrl': providerBannerUrl,
        'bannerUrl': bannerUrl,
        'ogImageUrl': ogImageUrl,
        'priceField': priceField,
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

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  /// Heurística para distinguir un UUID de un id numérico del vínculo.
  static bool _looksLikeUuid(dynamic value) {
    if (value is! String) return false;
    final re = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return re.hasMatch(value);
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
          other.linkId == linkId &&
          other.displayName == displayName &&
          other.providerId == providerId &&
          other.providerName == providerName &&
          other.providerLogoUrl == providerLogoUrl &&
          other.providerBannerUrl == providerBannerUrl &&
          other.bannerUrl == bannerUrl &&
          other.ogImageUrl == ogImageUrl &&
          other.priceField == priceField &&
          other.isReseller == isReseller;

  @override
  int get hashCode => Object.hash(
        id,
        linkId,
        displayName,
        providerId,
        providerName,
        providerLogoUrl,
        providerBannerUrl,
        bannerUrl,
        ogImageUrl,
        priceField,
        isReseller,
      );

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
