import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../domain/catalog.dart';
import 'catalog_card.dart';
import 'home_palette.dart';

/// Carrusel horizontal de catálogos (ver
/// `docs/design/inicio-a-carrusel.html`): la tarjeta activa a tamaño
/// completo y la siguiente asoma por la derecha a escala ≈0.94, con puntos
/// debajo. Con 1 solo catálogo, es una tarjeta única sin puntos (estado "un
/// solo catálogo" del mockup).
class CatalogCarousel extends StatefulWidget {
  const CatalogCarousel({
    super.key,
    required this.catalogs,
    required this.onOpenCatalog,
    required this.dotsHeight,
    this.compact = false,
  });

  final List<Catalog> catalogs;
  final ValueChanged<Catalog> onOpenCatalog;

  /// Alto reservado para los puntos (0 si hay 1 solo catálogo).
  final double dotsHeight;

  /// Pantallas cortas (≤640dp de alto): tarjeta más compacta (ver
  /// [CatalogCard.compact]).
  final bool compact;

  @override
  State<CatalogCarousel> createState() => _CatalogCarouselState();
}

class _CatalogCarouselState extends State<CatalogCarousel> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _announcePage(int index) {
    final FlutterView? view = View.maybeOf(context);
    if (view == null) return;
    SemanticsService.sendAnnouncement(
      view,
      'Catálogo ${index + 1} de ${widget.catalogs.length}',
      TextDirection.ltr,
    );
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.catalogs.length;
    if (total <= 1) {
      // Estado "un solo catálogo": tarjeta única, sin asomo ni puntos. El
      // relleno horizontal es proporcional al ancho (≈7.5% por lado, lo
      // mismo que deja la tarjeta del carrusel con viewportFraction 0.85)
      // en vez de los 30dp fijos del mockup (pensado solo para 390 de
      // ancho).
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double hPad = (constraints.maxWidth * 0.075).clamp(16.0, 40.0);
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            // `Center` afloja la restricción de alto (de tight a loose) que
            // llega desde el `Expanded` del `_Scaffold`: así la tarjeta usa
            // su alto natural (banner con tope + texto/botón pegados) en
            // vez de estirarse a rellenar toda la pantalla, y el sobrante
            // queda como aire arriba/abajo de la tarjeta, no dentro de ella.
            child: total == 1
                ? Center(
                    child: CatalogCard(
                      key: Key('catalog_${widget.catalogs.first.id}'),
                      catalog: widget.catalogs.first,
                      variantIndex: 0,
                      compact: widget.compact,
                      onTap: () => widget.onOpenCatalog(widget.catalogs.first),
                    ),
                  )
                : const SizedBox.shrink(),
          );
        },
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: PageView.builder(
            // `PageView` recorta (`Clip.hardEdge`, el valor por defecto) su
            // contenido exactamente en el borde de su propio alto, lo que
            // cortaba en seco la sombra de [CatalogCard] justo en el borde
            // de la tarjeta cuando esta llena todo el alto disponible (sin
            // margen propio debajo, en pantallas cortas). `Clip.none` deja
            // que la sombra pinte más allá de ese borde; el colchón fijo de
            // debajo (antes de los puntos) le da margen para terminar de
            // desaparecer sobre el mismo blanco antes de llegar a ellos.
            clipBehavior: Clip.none,
            controller: _controller,
            itemCount: total,
            onPageChanged: (int index) {
              setState(() => _page = index);
              _announcePage(index);
            },
            itemBuilder: (BuildContext context, int index) {
              return AnimatedBuilder(
                animation: _controller,
                builder: (BuildContext context, Widget? child) {
                  double scale = 1;
                  if (_controller.position.haveDimensions) {
                    final double distance =
                        (index - (_controller.page ?? _page.toDouble())).abs();
                    scale = (1 - (distance.clamp(0.0, 1.0) * 0.06));
                  } else if (index != _page) {
                    scale = 0.94;
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Transform.scale(scale: scale, child: child),
                  );
                },
                // `Center` afloja la restricción de alto que da el
                // `PageView` (tight, igual al alto del visor) para que la
                // tarjeta use su alto natural y el sobrante quede fuera de
                // ella (ver comentario equivalente en el estado de un solo
                // catálogo, arriba).
                child: Center(
                  child: CatalogCard(
                    key: Key('catalog_${widget.catalogs[index].id}'),
                    catalog: widget.catalogs[index],
                    variantIndex: index,
                    compact: widget.compact,
                    onTap: () => widget.onOpenCatalog(widget.catalogs[index]),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.dotsHeight > 0) ...<Widget>[
          // Colchón fijo entre la tarjeta y los puntos: en pantallas cortas
          // la tarjeta llena TODO el alto del `PageView` (sin aire propio
          // debajo), y la sombra de [CatalogCard] (`BoxShadow` offset 20)
          // se corta en seco contra el blanco liso de los puntos si no se
          // le reserva este margen — se nota como una franja distinta justo
          // encima de ellos. Restarlo aquí (en vez de a [widget.dotsHeight])
          // encoge la tarjeta (su banner es `Flexible`) en vez de los
          // puntos, que conservan su alto.
          const SizedBox(height: 24),
          SizedBox(
            height: widget.dotsHeight,
            child: Center(
              child: ExcludeSemantics(
                child: _CarouselDots(total: total, index: _page),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Puntos del carrusel: con 2-3 catálogos, un punto por catálogo; con más de
/// 3, siempre 3 puntos como máximo (activo = píldora, vecino = círculo 8,
/// borde = círculo 5 que avisa que hay más en esa dirección).
class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.total, required this.index});

  final int total;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (total <= 3) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < total; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            _Dot(role: i == index ? _DotRole.active : _DotRole.neighbor),
          ],
        ],
      );
    }

    // Ventana de 3 índices alrededor del activo, pegada a los bordes.
    late final List<int> window;
    if (index == 0) {
      window = <int>[0, 1, 2];
    } else if (index == total - 1) {
      window = <int>[total - 3, total - 2, total - 1];
    } else {
      window = <int>[index - 1, index, index + 1];
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < window.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _Dot(
              key: ValueKey<int>(window[i]),
              role: window[i] == index
                  ? _DotRole.active
                  : ((window[i] - index).abs() == 1
                        ? _DotRole.neighbor
                        : _DotRole.edge),
            ),
          ),
        ],
      ],
    );
  }
}

enum _DotRole { active, neighbor, edge }

class _Dot extends StatelessWidget {
  const _Dot({super.key, required this.role});

  final _DotRole role;

  @override
  Widget build(BuildContext context) {
    final Duration duration = const Duration(milliseconds: 250);
    switch (role) {
      case _DotRole.active:
        return AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          width: 26,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF001634),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      case _DotRole.neighbor:
        return AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: HomePalette.dotInactive,
            shape: BoxShape.circle,
          ),
        );
      case _DotRole.edge:
        return AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: HomePalette.dotInactive,
            shape: BoxShape.circle,
          ),
        );
    }
  }
}
