/// Flags de activación por etapas de "Productos del catálogo" (diseño A,
/// `docs/design/productos-a.html`).
///
/// El HTML de referencia es el diseño COMPLETO (con todas las funciones);
/// estas banderas controlan qué partes ya están construidas y deben
/// dibujarse. Cuando una función se implemente, cambia su flag a `true` en
/// este único archivo — no hace falta tocar la pantalla.
abstract final class CatalogProductsFlags {
  const CatalogProductsFlags._();

  /// Fila de 3 accesos bajo la cabecera: "Ajustar precios", "Imagen del
  /// enlace", "Compartir enlace".
  static const bool showQuickActions = false;

  /// Botón verde "Compartir enlace" de la cabecera (arriba a la derecha).
  static const bool showShareHeaderButton = false;

  /// Botón lápiz ("Ajustar el precio de este producto") sobre cada tarjeta.
  static const bool showPerProductEdit = false;

  /// Etiqueta verde de ajuste (p. ej. "+30%") sobre la imagen del producto.
  static const bool showMarkupBadge = false;

  /// Línea "Proveedor $X" bajo el precio ajustado de cada producto.
  static const bool showProviderPrice = false;
}
