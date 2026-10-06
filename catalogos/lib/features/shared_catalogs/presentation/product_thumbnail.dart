import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../auth/presentation/auth_palette.dart';
import '../../../core/images/product_image_cache_manager.dart';

/// Imagen de producto compartida por la cuadrícula de "Productos del catálogo"
/// y la vista previa / cabecera de "Ajustar precios" (fuente ÚNICA, para que
/// no diverjan): contenedor CUADRADO 1:1 con esquinas redondeadas
/// ([borderRadius]), imagen `BoxFit.cover` + `Alignment.center` (recorta lo
/// que sobra sin deformar — nunca `contain`, que deja franjas, ni `fill`, que
/// estira).
///
/// Mientras carga muestra un marcador neutro; si la URL es nula/vacía o la
/// carga falla, un cuadro de color de marca con un ícono (nunca el degradado
/// de banners). Decodifica pasando SOLO el ancho ([memCacheWidth]); dar
/// también el alto obliga a `ResizeImage` a la política "exact" (ancho×alto
/// fijos) que cambia la proporción.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    required this.url,
    required this.memCachePixels,
    this.borderRadius = 14,
    this.fallbackIconSize = 36,
  });

  /// URL de la imagen (variante de cuadrícula), o `null`/vacía si no hay.
  final String? url;

  /// Ancho (px físicos) al que decodificar la imagen; `null` = tamaño
  /// original. Nunca se pasa el alto (ver nota de clase).
  final int? memCachePixels;

  /// Radio de las esquinas redondeadas (14 en la cuadrícula, 12 en la vista
  /// previa de "Ajustar precios").
  final double borderRadius;

  /// Tamaño del ícono del respaldo cuando no hay imagen.
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: AspectRatio(
        aspectRatio: 1,
        child: _image(),
      ),
    );
  }

  Widget _image() {
    if (url == null || url!.trim().isEmpty) {
      return _ProductImageFallback(iconSize: fallbackIconSize);
    }
    return CachedNetworkImage(
      imageUrl: url!,
      cacheManager: ProductImageCacheManager.instance,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      width: double.infinity,
      height: double.infinity,
      // SOLO el ancho: dar ancho+alto obliga a la política "exact" de
      // ResizeImage y deforma las fotos no cuadradas. Con solo el ancho, el
      // alto se deriva manteniendo la proporción; `BoxFit.cover` recorta.
      memCacheWidth: memCachePixels,
      fadeInDuration: const Duration(milliseconds: 150),
      useOldImageOnUrlChange: true,
      placeholder: (BuildContext context, String url) => const _ProductImagePlaceholder(),
      errorWidget: (BuildContext context, String url, Object error) =>
          _ProductImageFallback(iconSize: fallbackIconSize),
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Color(0xFFF4F8FC)),
    );
  }
}

class _ProductImageFallback extends StatelessWidget {
  const _ProductImageFallback({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFF4F8FC)),
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: AuthPalette.textMuted,
          size: iconSize,
        ),
      ),
    );
  }
}
