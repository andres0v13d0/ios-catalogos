import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Abre todas las fotos ampliadas: se desliza a izquierda/derecha y se hace
/// zoom con los dedos. Devuelve la posición en la que quedó el usuario.
Future<int?> showImageGallery(
  BuildContext context,
  List<String> images, {
  int initial = 0,
}) => Navigator.of(context, rootNavigator: true).push<int>(
  PageRouteBuilder<int>(
    opaque: false,
    barrierColor: Colors.black,
    pageBuilder: (_, _, _) => _Gallery(images: images, initial: initial),
    transitionsBuilder: (_, Animation<double> a, _, Widget child) =>
        FadeTransition(opacity: a, child: child),
  ),
);

class _Gallery extends StatefulWidget {
  const _Gallery({required this.images, required this.initial});

  final List<String> images;
  final int initial;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  late final PageController _pages = PageController(
    initialPage: widget.initial,
  );
  late int _page = widget.initial;
  final TransformationController _zoom = TransformationController();

  /// Con zoom, un dedo mueve la foto; sin zoom, un dedo cambia de foto.
  bool _zoomed = false;

  @override
  void dispose() {
    _pages.dispose();
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<int>(
    canPop: false,
    onPopInvokedWithResult: (bool didPop, int? _) {
      if (!didPop) Navigator.of(context).pop(_page);
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          PageView.builder(
            controller: _pages,
            physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
            itemCount: widget.images.length,
            onPageChanged: (int i) {
              _zoom.value = Matrix4.identity();
              setState(() {
                _page = i;
                _zoomed = false;
              });
            },
            itemBuilder: (_, int i) => InteractiveViewer(
              transformationController: i == _page ? _zoom : null,
              panEnabled: _zoomed,
              minScale: 1,
              maxScale: 4,
              onInteractionEnd: (_) {
                final bool z = _zoom.value.getMaxScaleOnAxis() > 1.01;
                if (z != _zoomed) setState(() => _zoomed = z);
              },
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.images[i],
                  fit: BoxFit.contain,
                  placeholder: (_, _) =>
                      const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (_, _, _) => const Icon(
                    LucideIcons.imageOff,
                    color: Colors.white54,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(_page),
                    icon: const Icon(LucideIcons.x, color: Colors.white),
                  ),
                  const Spacer(),
                  if (widget.images.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x66FFFFFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_page + 1} / ${widget.images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
