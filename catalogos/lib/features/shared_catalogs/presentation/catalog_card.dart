import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/auth_gradient_button.dart';
import '../../auth/presentation/auth_palette.dart';
import '../../auth/presentation/auth_vector_icons.dart';
import '../domain/catalog.dart';
import 'home_palette.dart';

/// Tarjeta de un catálogo del carrusel "Tus catálogos" (ver
/// `docs/design/inicio-a-carrusel.html`).
///
/// El banner y el logo del proveedor son marcadores de posición en el mockup
/// (degradado + iniciales); aquí usan la imagen real del catálogo/proveedor
/// (mismo patrón `Image.network` + `errorBuilder` que ya usa el detalle de
/// catálogo) y solo caen al degradado/iniciales si no hay imagen o falla la
/// carga. Los círculos decorativos del banner SOLO se dibujan en el
/// fallback — nunca sobre una imagen real.
class CatalogCard extends StatelessWidget {
  const CatalogCard({
    super.key,
    required this.catalog,
    required this.onTap,
    required this.variantIndex,
    this.compact = false,
  });

  final Catalog catalog;
  final VoidCallback onTap;

  /// Alterna el esquema de color del degradado/logo de respaldo (0 o 1) para
  /// que varias tarjetas sin imagen real no se vean idénticas.
  final int variantIndex;

  /// Pantallas cortas (≤640dp de alto): menos relleno, tipografías algo
  /// menores y botón de 48dp (mínimo táctil) en vez de 54dp.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final String priceLabel = catalog.isPriceHidden
        ? 'Sin precios'
        : 'Con precios';
    final double namePad = compact ? 12 : 16;
    final double nameFontSize = compact ? 17 : 19;
    final double providerFontSize = compact ? 12 : 13;
    final double buttonBlockTopPad = compact ? 12 : 16;
    final double buttonBlockBottomPad = compact ? 14 : 20;
    final double badgeButtonGap = compact ? 12 : 16;
    final double buttonHeight = compact ? 48 : 54;

    return Semantics(
      button: true,
      label:
          'Catálogo ${catalog.displayName}, de ${catalog.providerLabel}, $priceLabel',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: HomePalette.cardBorder),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color.fromRGBO(0, 22, 52, 0.2),
              offset: Offset(0, 20),
              blurRadius: 50,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // El banner nunca pasa de ~1.1x el ancho de la tarjeta (el
                // mockup usa un banner cuadrado, 330x330 para una tarjeta de
                // 330 de ancho). `Flexible(loose)` (en vez de `Expanded`)
                // hace que el banner solo consuma el alto que de verdad
                // necesita (hasta el tope, o todo el disponible en
                // pantallas cortas): el bloque de texto/botón queda
                // SIEMPRE pegado justo debajo, sin huecos. Si la tarjeta
                // completa (banner+texto+botón) termina siendo más baja que
                // el espacio que le da el carrusel, el `Center` que envuelve
                // cada tarjeta en `CatalogCarousel` reparte ese sobrante
                // como aire FUERA de la tarjeta.
                Flexible(
                  fit: FlexFit.loose,
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          return ConstrainedBox(
                            key: ValueKey<String>(
                              'catalog_card_banner_${catalog.id}',
                            ),
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth,
                              maxHeight: constraints.maxWidth * 1.1,
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: <Widget>[
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(27),
                                    ),
                                    child: _Banner(
                                      imageUrl: catalog.coverImageUrl,
                                      variantIndex: variantIndex,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 20,
                                  bottom: -34,
                                  child: _ProviderLogo(
                                    logoUrl: catalog.providerLogoUrl,
                                    initials: catalog.providerInitials,
                                    variantIndex: variantIndex,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                  ),
                ),
                Padding(
                  // Sin `ConstrainedBox(minHeight:...)`: el bloque de texto
                  // usa su alto natural (nombre 1-2 líneas + proveedor), que
                  // ya es mayor que el solape del logo (34dp) con cualquier
                  // nombre no vacío — forzar un mínimo solo dejaba hueco en
                  // blanco antes de la etiqueta cuando el nombre era corto.
                  padding: EdgeInsets.fromLTRB(100, namePad, 16, 0),
                  // El nombre/proveedor topan su crecimiento en 1.05x: con
                  // `textScaler` del sistema más grande (hasta 1.3x), sin
                  // este tope el bloque nombre+proveedor+etiqueta ya no cabe
                  // en los ~16dp de separación del diseño sin ensanchar los
                  // huecos de la tarjeta. Sigue siendo más grande que el
                  // texto base (1.0x) y el nombre/proveedor conservan su
                  // ellipsis, así que el contenido real nunca se pierde.
                  child: _DenseTextScale(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          catalog.displayName,
                          style: TextStyle(
                            fontSize: nameFontSize,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          catalog.providerLabel,
                          style: TextStyle(
                            fontSize: providerFontSize,
                            height: 1.4,
                            color: AuthPalette.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    buttonBlockTopPad,
                    16,
                    buttonBlockBottomPad,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _DenseTextScale(
                        child: _PriceBadge(
                          hidden: catalog.isPriceHidden,
                          compact: compact,
                        ),
                      ),
                      SizedBox(height: badgeButtonGap),
                      AuthGradientButton(
                        label: 'Ver catálogo',
                        height: buttonHeight,
                        iconPainter: const ArrowForwardPainter(
                          color: AppColors.primary,
                          strokeWidth: 2.4,
                        ),
                        enabled: true,
                        loading: false,
                        onPressed: onTap,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.imageUrl, required this.variantIndex});

  final String? imageUrl;
  final int variantIndex;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return _GradientBannerFallback(variantIndex: variantIndex);
    }
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          _GradientBannerFallback(variantIndex: variantIndex),
    );
  }
}

/// Degradado de marca + círculos decorativos: SOLO se dibuja cuando no hay
/// imagen real de banner (marcador de posición, ver cabecera del archivo).
class _GradientBannerFallback extends StatelessWidget {
  const _GradientBannerFallback({required this.variantIndex});

  final int variantIndex;

  @override
  Widget build(BuildContext context) {
    final bool altA = variantIndex.isEven;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: altA
              ? const <Color>[AppColors.accent, AppColors.secondary]
              : const <Color>[AppColors.brand, AppColors.accent],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            right: altA ? -50 : null,
            left: altA ? null : -50,
            top: -60,
            width: 240,
            height: 240,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: altA ? 0.22 : 0.3),
              ),
            ),
          ),
          Positioned(
            left: altA ? 90 : null,
            right: altA ? null : 20,
            bottom: -90,
            width: 200,
            height: 200,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: altA
                    ? const Color(0x5900FF94) // rgba(0,255,148,0.35)
                    : const Color(0x40004AAD), // rgba(0,74,173,0.25)
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderLogo extends StatelessWidget {
  const _ProviderLogo({
    required this.logoUrl,
    required this.initials,
    required this.variantIndex,
  });

  final String? logoUrl;
  final String initials;
  final int variantIndex;

  @override
  Widget build(BuildContext context) {
    final bool altA = variantIndex.isEven;
    final Widget fallback = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: altA
              ? const <Color>[AppColors.primary, AppColors.secondary]
              : const <Color>[AppColors.accent, AppColors.brand],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: altA ? AppColors.accent : AppColors.primary,
          ),
        ),
      ),
    );

    final Widget inner = (logoUrl == null || logoUrl!.trim().isEmpty)
        ? fallback
        : ClipOval(
            child: Image.network(
              logoUrl!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stack,
              ) => fallback,
            ),
          );

    return Container(
      width: 68,
      height: 68,
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(0, 22, 52, 0.28),
            offset: Offset(0, 10),
            blurRadius: 22,
          ),
        ],
      ),
      child: ClipOval(child: inner),
    );
  }
}

class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.hidden, this.compact = false});

  final bool hidden;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: hidden
            ? HomePalette.priceOffBackground
            : HomePalette.priceOnBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        hidden ? 'Sin precios' : 'Con precios',
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: hidden ? HomePalette.priceOffText : HomePalette.priceOnText,
        ),
      ),
    );
  }
}

/// Topa el `textScaler` heredado a 1.05x para el nombre/proveedor/etiqueta
/// de la tarjeta: ese bloque ya va apretado contra el banner y el botón
/// (ver comentario en su punto de uso), y un `textScaler` de sistema más
/// grande (hasta 1.3x) lo desbordaría. El resto de la pantalla (título,
/// botón "Ver catálogo", etc.) sigue escalando hasta el tope general de
/// 1.3x de `HomePage`.
class _DenseTextScale extends StatelessWidget {
  const _DenseTextScale({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 1.05),
      ),
      child: child,
    );
  }
}
