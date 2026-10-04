/// Modelos del detalle de catálogo (productos) — tareas 1.16/1.17/1.18.
///
/// === RECONCILIACIÓN DE NOMBRES DE CAMPO (TODO cuando el backend esté vivo) ===
/// El backend real (`GET /catalog/by-catalog/:id/products` y
/// `POST /catalog/products/previews`) devuelve una estructura **mixta**:
/// `snake_case` en el nivel raíz (`banner_url`, `provider_id`, `logo_url`...) y
/// `camelCase` dentro de `catalog` (`publicName`, `priceField`...). Igual que el
/// modelo `Catalog` compartido, aquí [CatalogDetail.fromJson] y
/// [Product.fromJson] son **tolerantes**: aceptan ambas convenciones para las
/// claves ambiguas y toleran que `colores`/`tallas` lleguen como lista de
/// objetos `{ id, name }` o como lista de strings.
///
/// Cuando el backend esté en vivo, revisar la respuesta real y, si procede,
/// endurecer estos parsers a los nombres definitivos (centralizado aquí para
/// que el cambio sea de un solo punto). Ver `tasks.md` 1.16.
library;

/// Una variante de producto (color o talla). El backend puede enviar cada
/// variante como objeto `{ id, name }` o como string suelto; [Variant.parse]
/// tolera ambas formas.
class Variant {
  const Variant({required this.id, required this.name});

  /// Id de la variante (puede coincidir con el nombre cuando llegó como string).
  final String id;

  /// Nombre a mostrar de la variante.
  final String name;

  /// Parsea una variante desde objeto `{ id, name }` o string.
  static Variant? parse(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      return Variant(id: trimmed, name: trimmed);
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final name = _asString(map['name'] ?? map['nombre']) ?? '';
      final id = _asString(map['id']) ?? name;
      if (name.isEmpty && id.isEmpty) return null;
      return Variant(id: id.isEmpty ? name : id, name: name.isEmpty ? id : name);
    }
    return null;
  }

  /// Parsea una lista de variantes tolerando objetos y strings mezclados.
  static List<Variant> parseList(dynamic raw) {
    if (raw is! List) return const <Variant>[];
    final result = <Variant>[];
    for (final item in raw) {
      final v = parse(item);
      if (v != null) result.add(v);
    }
    return result;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{'id': id, 'name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Variant && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'Variant($id, $name)';
}

/// Un producto del catálogo (tarea 1.16).
///
/// [precios] es un mapa `cantidad → precio por esa cantidad` (claves = las
/// cantidades disponibles). En el modo "sin precios" (ver [CatalogDetail]) las
/// claves se conservan pero todos los valores llegan en 0; [hasRealPrices]
/// permite a la UI decidir si mostrar importes o un marcador de "a convenir".
class Product {
  const Product({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.imagenes = const <String>[],
    this.colores = const <Variant>[],
    this.tallas = const <Variant>[],
    this.precios = const <String, num>{},
    this.unidadMedida,
    this.moneda = 'COP',
  });

  final String id;
  final String nombre;
  final String? descripcion;

  /// URLs de imágenes del producto (puede estar vacía).
  final List<String> imagenes;

  /// Colores disponibles (tolerante a objetos o strings).
  final List<Variant> colores;

  /// Tallas disponibles (tolerante a objetos o strings).
  final List<Variant> tallas;

  /// Mapa `cantidad(string) → precio(num)`. Claves = cantidades disponibles.
  final Map<String, num> precios;

  final String? unidadMedida;

  /// Moneda del producto; por defecto `COP`.
  final String moneda;

  /// Primera imagen disponible, o `null` si no hay ninguna.
  String? get primaryImage => imagenes.isNotEmpty ? imagenes.first : null;

  /// Cantidades disponibles ordenadas numéricamente (claves de [precios]).
  List<String> get cantidades {
    final keys = precios.keys.toList()
      ..sort((a, b) {
        final na = num.tryParse(a);
        final nb = num.tryParse(b);
        if (na != null && nb != null) return na.compareTo(nb);
        return a.compareTo(b);
      });
    return keys;
  }

  /// `true` si al menos un precio es mayor que 0. En el modo "sin precios" del
  /// backend (todos los valores en 0) esto es `false`, de modo que la UI puede
  /// mostrar las cantidades sin importes reales.
  bool get hasRealPrices => precios.values.any((p) => p > 0);

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: _asString(_pick(json, const <String>['id'])) ?? '',
      nombre: _asString(_pick(json, const <String>['nombre', 'name'])) ?? '',
      descripcion: _asString(
        _pick(json, const <String>['descripcion', 'description']),
      ),
      imagenes: _asStringList(
        _pick(json, const <String>['imagenes', 'images', 'imagenes_url']),
      ),
      colores: Variant.parseList(
        _pick(json, const <String>['colores', 'colors']),
      ),
      tallas: Variant.parseList(
        _pick(json, const <String>['tallas', 'sizes']),
      ),
      precios: _parsePrecios(_pick(json, const <String>['precios', 'prices'])),
      unidadMedida: _asString(
        _pick(json, const <String>['unidadMedida', 'unidad_medida']),
      ),
      moneda: _asString(_pick(json, const <String>['moneda', 'currency'])) ??
          'COP',
    );
  }

  /// Serializa a JSON tolerante (usado para la caché local Hive).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'imagenes': imagenes,
        'colores': colores.map((v) => v.toJson()).toList(),
        'tallas': tallas.map((v) => v.toJson()).toList(),
        // Los mapas de precios se serializan con claves string (ya lo son).
        'precios': precios.map((k, v) => MapEntry(k, v)),
        'unidadMedida': unidadMedida,
        'moneda': moneda,
      };

  static Map<String, num> _parsePrecios(dynamic raw) {
    if (raw is! Map) return const <String, num>{};
    final result = <String, num>{};
    raw.forEach((key, value) {
      final k = key.toString();
      final n = value is num ? value : num.tryParse('${value ?? ''}');
      if (n != null) result[k] = n;
    });
    return result;
  }
}

/// Detalle completo de un catálogo con sus productos (tarea 1.16).
///
/// Modela la respuesta de `GET /catalog/by-catalog/:id/products`. Expone el
/// banner, metadatos del catálogo y la lista de [products]. La bandera
/// [priceHidden] ("sin precios") se deriva de dos señales, acorde al contrato:
/// - `catalog.priceField == 'none'`, o
/// - todos los productos tienen precios en 0 (cantidades preservadas, importes
///   ocultos). Ver [CatalogDetail.fromJson].
class CatalogDetail {
  const CatalogDetail({
    required this.id,
    required this.products,
    this.bannerUrl,
    this.nombreEmpresa,
    this.providerId,
    this.logoUrl,
    this.publicName,
    this.description,
    this.telefono,
    this.priceField,
    this.categoryId,
    this.subcategoryId,
    this.priceHiddenOverride,
  });

  /// Id del catálogo (uuid). Puede venir de `catalog.id` o del id solicitado.
  final String id;

  /// Productos del catálogo.
  final List<Product> products;

  /// URL del banner (preferimos `banner_url` del nivel raíz).
  final String? bannerUrl;

  /// Nombre de la empresa/proveedor (nivel raíz `nombre_empresa`).
  final String? nombreEmpresa;

  /// Id del proveedor (nivel raíz `provider_id`).
  final int? providerId;

  /// URL del logo del proveedor.
  final String? logoUrl;

  /// Nombre público del catálogo (`catalog.publicName`).
  final String? publicName;

  /// Descripción del catálogo (`catalog.description`).
  final String? description;

  /// Teléfono del catálogo (`catalog.telefono`).
  final String? telefono;

  /// Campo de precio elegido por el proveedor (`catalog.priceField`). Cuando es
  /// `'none'`, el catálogo está en modo "sin precios".
  final String? priceField;

  /// Id de categoría del catálogo (`catalog.categoryId`), usado como faceta de
  /// filtro en el detalle (tarea 1.17).
  final String? categoryId;

  /// Id de subcategoría del catálogo (`catalog.subcategoryId`).
  final String? subcategoryId;

  /// Override explícito de "sin precios" (para la caché; evita recomputar). Si
  /// es `null`, [priceHidden] lo deriva de [priceField]/precios.
  final bool? priceHiddenOverride;

  /// Nombre a mostrar en el encabezado del detalle.
  String get displayName =>
      (publicName ?? '').trim().isNotEmpty
          ? publicName!.trim()
          : (nombreEmpresa ?? 'Catálogo').trim();

  /// `true` si el catálogo está en modo "sin precios" (CA de 1.16):
  /// - `priceField == 'none'`, o
  /// - hay productos pero ninguno tiene precios reales (todos en 0).
  bool get priceHidden {
    if (priceHiddenOverride != null) return priceHiddenOverride!;
    if ((priceField ?? '').toLowerCase() == 'none') return true;
    if (products.isEmpty) return false;
    return products.every((p) => !p.hasRealPrices);
  }

  factory CatalogDetail.fromJson(
    Map<String, dynamic> json, {
    String? fallbackId,
  }) {
    final catalogRaw = json['catalog'];
    final Map<String, dynamic> catalog = catalogRaw is Map
        ? Map<String, dynamic>.from(catalogRaw)
        : const <String, dynamic>{};

    return CatalogDetail(
      id: _asString(_pick(catalog, const <String>['id'])) ??
          _asString(_pick(json, const <String>['id'])) ??
          fallbackId ??
          '',
      products: _parseProducts(json['products']),
      bannerUrl: _asString(
        _pick(json, const <String>['banner_url', 'bannerUrl']) ??
            _pick(json, const <String>[
              'banner_desktop_url',
              'banner_mobile_url',
            ]) ??
            _pick(catalog, const <String>['banner_url', 'bannerUrl']),
      ),
      nombreEmpresa: _asString(
        _pick(json, const <String>['nombre_empresa', 'nombreEmpresa']),
      ),
      providerId: _asInt(
        _pick(json, const <String>['provider_id', 'providerId']),
      ),
      logoUrl: _asString(
        _pick(json, const <String>[
          'logo_optimized_url',
          'logo_url',
          'logoUrl',
        ]),
      ),
      // PRIVACIDAD: NUNCA se usa 'internalName' como fallback. El endpoint
      // legado puede incluir internalName, pero el nombre interno del catálogo
      // jamás debe renderizarse. ('name' en ese endpoint = publicName, por eso
      // es un fallback aceptable.) Ver displayName: si publicName queda vacío,
      // cae al nombre del proveedor o a 'Catálogo', nunca al interno.
      publicName: _asString(
        _pick(catalog, const <String>[
          'publicName',
          'public_name',
          'name',
        ]),
      ),
      description: _asString(
        _pick(catalog, const <String>['description', 'descripcion']),
      ),
      telefono: _asString(
        _pick(catalog, const <String>['telefono', 'phone']),
      ),
      priceField: _asString(
        _pick(catalog, const <String>['priceField', 'price_field']),
      ),
      categoryId: _asString(
        _pick(catalog, const <String>['categoryId', 'category_id']),
      ),
      subcategoryId: _asString(
        _pick(catalog, const <String>['subcategoryId', 'subcategory_id']),
      ),
      priceHiddenOverride: _asBool(
        _pick(json, const <String>['priceHiddenOverride']),
      ),
    );
  }

  /// Serializa a JSON para la caché local Hive. Persiste [priceHidden] como
  /// override para no depender de recomputarlo tras deserializar.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'catalog': <String, dynamic>{
          'id': id,
          'publicName': publicName,
          'description': description,
          'telefono': telefono,
          'priceField': priceField,
          'categoryId': categoryId,
          'subcategoryId': subcategoryId,
        },
        'banner_url': bannerUrl,
        'nombre_empresa': nombreEmpresa,
        'provider_id': providerId,
        'logo_url': logoUrl,
        'products': products.map((p) => p.toJson()).toList(),
        'priceHiddenOverride': priceHidden,
      };

  static List<Product> _parseProducts(dynamic raw) {
    if (raw is! List) return const <Product>[];
    final result = <Product>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        result.add(Product.fromJson(item));
      } else if (item is Map) {
        result.add(Product.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Helpers de parseo tolerante (compartidos por los modelos de este archivo).
// ---------------------------------------------------------------------------

dynamic _pick(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value;
  }
  return null;
}

String? _asString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool? _asBool(dynamic value) {
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

List<String> _asStringList(dynamic value) {
  if (value is! List) return const <String>[];
  final result = <String>[];
  for (final item in value) {
    final s = _asString(item);
    if (s != null && s.trim().isNotEmpty) result.add(s);
  }
  return result;
}
