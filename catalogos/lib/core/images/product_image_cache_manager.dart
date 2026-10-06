import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Caché en disco de las imágenes de producto (tarea de rendimiento de la
/// cuadrícula "Productos del catálogo").
///
/// `Image.network` (lo que se usaba antes) solo cachea en memoria mientras la
/// app sigue viva: cerrar y reabrir un catálogo vuelve a descargar TODAS las
/// imágenes. Este `CacheManager` (vía `cached_network_image`) persiste los
/// bytes ya decodificados en disco entre sesiones.
///
/// - [stalePeriod] 30 días: las imágenes de producto se suben con key S3/
///   CloudFront **inmutable** por subida (UUID nuevo cada vez — ver
///   `ProductImagesService.uploadAndProcess` en el backend, `imageId =
///   uuidv4()`), así que una URL nunca cambia de contenido: no hay riesgo de
///   servir una imagen "vieja" por quedarse en caché más tiempo del debido.
///   30 días es solo un límite de espacio/higiene, no de frescura.
/// - [maxNrOfCacheObjects] 300: suficiente para varios catálogos completos
///   (típicamente 20-100 productos) sin dejar crecer el disco sin límite en
///   celulares con poco almacenamiento.
///
/// Instancia propia (no [DefaultCacheManager]) para no compartir el límite ni
/// el TTL con otras imágenes de la app (banners, logos de proveedor) que
/// tienen su propio ciclo de vida.
class ProductImageCacheManager {
  const ProductImageCacheManager._();

  static const String key = 'productImageCache';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 300,
    ),
  );
}
