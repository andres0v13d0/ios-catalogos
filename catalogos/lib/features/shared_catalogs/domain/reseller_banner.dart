/// Modelos de "Banner del catálogo" y "Compartir enlace" del revendedor.
///
/// El banner del revendedor es, en el backend, el `ogImageUrl` de SU fila hija
/// (canal). Se usa EXCLUSIVAMENTE como vista previa Open Graph (og:image) del
/// enlace compartible; no aparece dentro de la página del catálogo. La fila
/// hija nace con `ogImageUrl = null` (ver backend `createResellerChannel`), por
/// lo que "tiene banner propio" equivale a `ownBannerUrl != null`.
library;

/// Estado del banner/compartir de un catálogo del revendedor, tal como lo
/// necesitan las pantallas. Se arma desde el detalle del catálogo compartido
/// (`GET /reseller/me/shared-catalogs`) y se actualiza con la respuesta de
/// `PUT`/`DELETE .../banner`.
class ResellerBannerState {
  const ResellerBannerState({
    required this.catalogId,
    required this.shareLink,
    required this.publicName,
    required this.hasPriceRules,
    this.ownBannerUrl,
    this.providerImageUrl,
    this.ownBannerWidth,
    this.ownBannerHeight,
    this.ownBannerBytes,
  });

  /// Id (uuid) de la fila hija del revendedor.
  final String catalogId;

  /// Enlace compartible completo (`https://share.minymol.com/<id>`). Puede ser
  /// cadena vacía si el canal aún no tiene enlace generado.
  final String shareLink;

  /// Nombre público del catálogo (para el texto real de la vista previa).
  final String publicName;

  /// `true` si el revendedor tiene reglas de precio en este catálogo (decide el
  /// subtítulo de la hoja de compartir).
  final bool hasPriceRules;

  /// Banner PROPIO del revendedor (su `ogImageUrl`), o `null` si no subió nada.
  final String? ownBannerUrl;

  /// Imagen del PROVEEDOR a mostrar como vista previa cuando no hay banner
  /// propio (banner del catálogo / del proveedor). Puede ser `null`.
  final String? providerImageUrl;

  /// Medidas reales del banner propio ya procesado (solo informativas en la UI;
  /// pueden venir `null` si el backend no las expone).
  final int? ownBannerWidth;
  final int? ownBannerHeight;

  /// Peso real del archivo del banner propio en bytes (informativo), si se
  /// conoce.
  final int? ownBannerBytes;

  bool get hasOwnBanner => (ownBannerUrl ?? '').trim().isNotEmpty;

  /// Imagen a usar en la vista previa de WhatsApp: el banner propio si existe,
  /// si no la del proveedor.
  String? get previewImageUrl => hasOwnBanner ? ownBannerUrl : providerImageUrl;

  /// Enlace a compartir con rompe-caché: si hay banner propio, añade
  /// `?v=<hash corto de la URL del banner>` para que WhatsApp vuelva a pedir la
  /// vista previa cuando el revendedor cambia la imagen. El redirect del
  /// backend ignora este parámetro (lookup por id del path).
  String get shareLinkWithCacheBust {
    if (shareLink.isEmpty || !hasOwnBanner) return shareLink;
    final v = _shortHash(ownBannerUrl!);
    final sep = shareLink.contains('?') ? '&' : '?';
    return '$shareLink${sep}v=$v';
  }

  ResellerBannerState copyWith({
    String? ownBannerUrl,
    bool clearOwnBanner = false,
    int? ownBannerWidth,
    int? ownBannerHeight,
    int? ownBannerBytes,
    String? shareLink,
  }) {
    return ResellerBannerState(
      catalogId: catalogId,
      shareLink: shareLink ?? this.shareLink,
      publicName: publicName,
      hasPriceRules: hasPriceRules,
      providerImageUrl: providerImageUrl,
      ownBannerUrl: clearOwnBanner ? null : (ownBannerUrl ?? this.ownBannerUrl),
      ownBannerWidth: clearOwnBanner ? null : (ownBannerWidth ?? this.ownBannerWidth),
      ownBannerHeight: clearOwnBanner ? null : (ownBannerHeight ?? this.ownBannerHeight),
      ownBannerBytes: clearOwnBanner ? null : (ownBannerBytes ?? this.ownBannerBytes),
    );
  }
}

/// Hash corto y estable (base36, 8 chars) de una cadena, sin dependencias.
/// Determinista para una misma URL (misma versión → mismo `?v=`), cambia al
/// cambiar la imagen (URL nueva con uuid distinto). FNV-1a de 32 bits.
String _shortHash(String input) {
  int hash = 0x811c9dc5;
  for (final codeUnit in input.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(36);
}
