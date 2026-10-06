/// Flags de activación por etapas de "Productos del catálogo" (diseño A,
/// `docs/design/productos-a.html`) y "Ajustar precios"
/// (`docs/design/ajustar-precios.html`).
///
/// Los HTML son el diseño COMPLETO (con todas las funciones). La cabecera y
/// sus 3 accesos, el lápiz por producto, la insignia y "Proveedor $X" se
/// dibujan SIEMPRE (fieles al diseño); "Imagen del enlace" y "Compartir
/// enlace" todavía no tienen backend, así que al tocarlos se muestra un
/// aviso "Próximamente" en vez de abrir una pantalla rota.
abstract final class CatalogProductsFlags {
  const CatalogProductsFlags._();

  /// Botón "Compartir ahora" del estado "Listo" de "Ajustar precios". Etapa
  /// posterior (el enlace del canal se gestiona en otra pantalla todavía).
  static const bool showShareNowButton = false;
}
