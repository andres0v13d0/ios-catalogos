import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/auth_gradient_button.dart';
import '../../auth/presentation/auth_vector_icons.dart';
import '../domain/reseller_banner.dart';
import 'catalog_design_tokens.dart';
import 'catalog_products_icons.dart';
import 'reseller_banner_controller.dart';

/// Pantalla "Banner del catálogo" (diseños Banner-1 sin banner / Banner-2 con
/// banner). Misma línea visual de "Ajustar precios": fondo degradado
/// #001634→#003A85→#004AAD, botón principal degradado #5DE0E6→#00FF94, tarjeta
/// blanca de vista previa de WhatsApp y botón volver translúcido 44×44.
///
/// El banner del revendedor se usa SOLO como vista previa Open Graph del
/// enlace; no aparece dentro del catálogo. La imagen se muestra SIEMPRE con su
/// proporción original; en la burbuja usa BoxFit.cover solo para llenar la
/// tarjeta (como WhatsApp), sin alterar el archivo subido.
class ResellerBannerPage extends ConsumerWidget {
  const ResellerBannerPage({super.key, required this.args});

  final ResellerBannerState args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ResellerBannerUiState state = ref.watch(resellerBannerControllerProvider(args));
    final ResellerBannerController controller =
        ref.read(resellerBannerControllerProvider(args).notifier);
    final double s = catalogScale(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: <double>[0.0, 0.55, 1.0],
                    colors: <Color>[AppColors.primary, CatalogTokens.adjustGradientMid, AppColors.secondary],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -60 * s,
              top: -40 * s,
              width: 380 * s,
              height: 380 * s,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[const Color(0x665DE0E6), const Color(0x665DE0E6).withAlpha(0)],
                    stops: const <double>[0.0, 0.68],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -70 * s,
              top: 430 * s,
              width: 200 * s,
              height: 200 * s,
              child: const DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0x1F00FF94)),
              ),
            ),
            SafeArea(
              child: _Body(args: args, state: state, controller: controller, scale: s),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.args, required this.state, required this.controller, required this.scale});

  final ResellerBannerState args;
  final ResellerBannerUiState state;
  final ResellerBannerController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final ResellerBannerState banner = state.banner;
    final bool hasOwn = banner.hasOwnBanner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // --- Cabecera: volver + título + (Quitar si hay banner propio) ---
        Padding(
          padding: EdgeInsets.fromLTRB(16 * s, 12 * s, 16 * s, 0),
          child: Row(
            children: <Widget>[
              _BackButton(scale: s, onTap: () => Navigator.of(context).maybePop()),
              SizedBox(width: 12 * s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Banner del catálogo',
                      style: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2),
                    ),
                    SizedBox(height: 2 * s),
                    Text(
                      'Vista previa del enlace',
                      style: TextStyle(fontSize: 12 * s, color: CatalogTokens.subtitleOnDark, height: 1.3),
                    ),
                  ],
                ),
              ),
              if (hasOwn)
                _RemoveButton(
                  scale: s,
                  onTap: state.isUploading ? null : () => _confirmRemove(context),
                ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16 * s, 18 * s, 16 * s, 24 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // --- Vista previa de WhatsApp (tarjeta blanca) ---
                _WhatsAppPreviewCard(scale: s, banner: banner),
                SizedBox(height: 18 * s),

                if (!hasOwn) ..._idleNoBanner(context, s) else ..._withBanner(context, s, banner),

                if (state.phase == ResellerBannerPhase.error && state.errorMessage != null) ...<Widget>[
                  SizedBox(height: 14 * s),
                  _ErrorNotice(
                    scale: s,
                    message: state.errorMessage!,
                    showSettings: state.permissionDenied,
                    onRetry: state.isUploading ? null : () => controller.retry(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _idleNoBanner(BuildContext context, double s) {
    return <Widget>[
      // Zona punteada "Sube tu banner"
      _DashedDropZone(scale: s, onTap: state.isUploading ? null : () => controller.pickAndUpload()),
      SizedBox(height: 12 * s),
      Text(
        'Solo se usa como vista previa al compartir el enlace por WhatsApp. '
        'No aparece dentro de tu catálogo.',
        style: TextStyle(fontSize: 12.5 * s, color: CatalogTokens.subtitleOnDark, height: 1.45),
      ),
      SizedBox(height: 18 * s),
      AuthGradientButton(
        label: 'Elegir imagen',
        iconPainter: ImageIconPainter(color: AppColors.primary),
        enabled: !state.isUploading,
        loading: state.isUploading,
        onPressed: () => controller.pickAndUpload(),
      ),
    ];
  }

  List<Widget> _withBanner(BuildContext context, double s, ResellerBannerState banner) {
    return <Widget>[
      _SavedBannerCard(scale: s, banner: banner),
      SizedBox(height: 12 * s),
      _CacheNotice(scale: s),
      SizedBox(height: 18 * s),
      AuthGradientButton(
        label: 'Cambiar banner',
        iconPainter: SwapPainter(color: AppColors.primary),
        enabled: !state.isUploading,
        loading: state.isUploading,
        onPressed: () => controller.pickAndUpload(),
      ),
      SizedBox(height: 12 * s),
      _DoneButton(scale: s, onTap: state.isUploading ? null : () => Navigator.of(context).maybePop()),
    ];
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => _RemoveConfirmDialog(),
    );
    if (ok ?? false) {
      await controller.removeBanner();
    }
  }
}

/// Botón volver translúcido 44×44 (idéntico al de "Ajustar precios").
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap, required this.scale});

  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Semantics(
      button: true,
      label: 'Volver',
      child: SizedBox(
        width: 44 * s,
        height: 44 * s,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(
              child: Container(
                width: 44 * s,
                height: 44 * s,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x24FFFFFF)),
                child: Center(
                  child: SizedBox(
                    width: 22 * s,
                    height: 22 * s,
                    child: CustomPaint(painter: ChevronLeftPainter(color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Quitar" arriba a la derecha (solo con banner propio).
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.scale, required this.onTap});

  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Semantics(
      button: true,
      label: 'Quitar banner',
      child: Material(
        color: const Color(0x24FFFFFF),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 8 * s),
            child: Text(
              'Quitar',
              style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta blanca con la vista previa de WhatsApp real (burbuja con imagen y
/// textos derivados del catálogo).
class _WhatsAppPreviewCard extends StatelessWidget {
  const _WhatsAppPreviewCard({required this.scale, required this.banner});

  final double scale;
  final ResellerBannerState banner;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final String? imageUrl = banner.previewImageUrl;
    final String title = banner.publicName.trim().isNotEmpty ? banner.publicName.trim() : 'Mi catálogo';
    final String domain = _domainOf(banner.shareLink);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18 * s),
        boxShadow: <BoxShadow>[
          BoxShadow(color: CatalogTokens.darkCardShadow, offset: Offset(0, 12 * s), blurRadius: 28 * s),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Imagen de la vista previa (BoxFit.cover solo para llenar la tarjeta).
          AspectRatio(
            aspectRatio: 1.91,
            child: Container(
              color: const Color(0xFFEAF0FF),
              child: imageUrl == null
                  ? Center(
                      child: SizedBox(
                        width: 40 * s,
                        height: 40 * s,
                        child: CustomPaint(painter: ImageIconPainter(color: CatalogTokens.textMuted)),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      key: const Key('wa_preview_image'),
                      placeholder: (c, _) => const ColoredBox(color: Color(0xFFEAF0FF)),
                      errorWidget: (c, _, _) => Center(
                        child: SizedBox(
                          width: 40 * s,
                          height: 40 * s,
                          child: CustomPaint(painter: ImageIconPainter(color: CatalogTokens.textMuted)),
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(12 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14 * s, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
                SizedBox(height: 3 * s),
                Text(
                  'Mira mi catálogo',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12 * s, color: CatalogTokens.textMuted, height: 1.35),
                ),
                SizedBox(height: 6 * s),
                Text(
                  domain,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11 * s, color: CatalogTokens.searchHint, letterSpacing: 0.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Zona punteada "Sube tu banner".
class _DashedDropZone extends StatelessWidget {
  const _DashedDropZone({required this.scale, required this.onTap});

  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Semantics(
      button: true,
      label: 'Sube tu banner',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18 * s),
        child: CustomPaint(
          painter: _DashedBorderPainter(radius: 18 * s, color: CatalogTokens.whiteOverlay30),
          child: Container(
            height: 120 * s,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: 34 * s,
                  height: 34 * s,
                  child: CustomPaint(painter: ImageIconPainter(color: Colors.white)),
                ),
                SizedBox(height: 10 * s),
                Text(
                  'Sube tu banner',
                  style: TextStyle(fontSize: 14 * s, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta "Banner guardado" con medidas y peso reales.
class _SavedBannerCard extends StatelessWidget {
  const _SavedBannerCard({required this.scale, required this.banner});

  final double scale;
  final ResellerBannerState banner;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final String measures = (banner.ownBannerWidth != null && banner.ownBannerHeight != null)
        ? '${banner.ownBannerWidth} × ${banner.ownBannerHeight} px'
        : 'Imagen guardada';
    final String? weight = banner.ownBannerBytes != null ? _formatBytes(banner.ownBannerBytes!) : null;

    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: CatalogTokens.whiteOverlay10,
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: CatalogTokens.whiteOverlay20),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38 * s,
            height: 38 * s,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0x3800FF94), shape: BoxShape.circle),
            child: SizedBox(
              width: 20 * s,
              height: 20 * s,
              child: CustomPaint(painter: CheckPainter(color: AppColors.brand)),
            ),
          ),
          SizedBox(width: 12 * s),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Banner guardado',
                  style: TextStyle(fontSize: 14 * s, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                SizedBox(height: 2 * s),
                Text(
                  weight == null ? measures : '$measures · $weight',
                  style: TextStyle(fontSize: 12 * s, color: CatalogTokens.subtitleOnDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de caché de WhatsApp (con banner propio).
class _CacheNotice extends StatelessWidget {
  const _CacheNotice({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Text(
      'Si ya compartiste el enlace antes, WhatsApp puede seguir mostrando la imagen anterior '
      'durante un rato. Al reenviarlo verá la nueva.',
      style: TextStyle(fontSize: 12 * s, color: CatalogTokens.subtitleOnDark, height: 1.45),
    );
  }
}

/// Botón "Listo" (secundario, translúcido).
class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.scale, required this.onTap});

  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Semantics(
      button: true,
      label: 'Listo',
      child: Material(
        color: CatalogTokens.whiteOverlay12,
        borderRadius: BorderRadius.circular(16 * s),
        child: InkWell(
          borderRadius: BorderRadius.circular(16 * s),
          onTap: onTap,
          child: Container(
            height: 52 * s,
            alignment: Alignment.center,
            child: Text(
              'Listo',
              style: TextStyle(fontSize: 15 * s, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Aviso de error en español con "Reintentar" y opcional "Abrir ajustes".
class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({
    required this.scale,
    required this.message,
    required this.showSettings,
    required this.onRetry,
  });

  final double scale;
  final String message;
  final bool showSettings;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Container(
      padding: EdgeInsets.all(14 * s),
      decoration: BoxDecoration(
        color: const Color(0x1AFF4D4D),
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: const Color(0x33FF4D4D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: TextStyle(fontSize: 13 * s, color: CatalogTokens.errorOnDark, height: 1.4),
          ),
          SizedBox(height: 10 * s),
          Row(
            children: <Widget>[
              _SmallAction(scale: s, label: 'Reintentar', onTap: onRetry),
              if (showSettings) ...<Widget>[
                SizedBox(width: 10 * s),
                _SmallAction(scale: s, label: 'Abrir ajustes', onTap: () => _openSettings()),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    // image_picker no expone openAppSettings; sin permission_handler (por
    // decisión de producto) solo se muestra el mensaje. Si en el futuro se
    // agrega el paquete, aquí iría AppSettings.openAppSettings().
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.scale, required this.label, required this.onTap});

  final double scale;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Material(
      color: CatalogTokens.whiteOverlay14,
      borderRadius: BorderRadius.circular(10 * s),
      child: InkWell(
        borderRadius: BorderRadius.circular(10 * s),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 7 * s),
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5 * s, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _RemoveConfirmDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x33001634), offset: Offset(0, 18), blurRadius: 40)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              '¿Quitar el banner?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Volverá a verse la imagen del proveedor en la vista previa del enlace.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: CatalogTokens.textMuted, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF4F8FC),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0x1AFF4D4D),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Quitar',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFD12E2E)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Borde punteado redondeado (CustomPainter, sin dependencias extra).
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final Path path = Path()..addRRect(rrect);
    const double dash = 7;
    const double gap = 5;
    for (final ui in _dashedMetrics(path, dash, gap)) {
      canvas.drawPath(ui, paint);
    }
  }

  Iterable<Path> _dashedMetrics(Path source, double dash, double gap) sync* {
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = distance + dash;
        yield metric.extractPath(distance, next.clamp(0, metric.length));
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}

String _domainOf(String link) {
  if (link.isEmpty) return 'share.minymol.com';
  try {
    final uri = Uri.parse(link);
    final host = uri.host.isNotEmpty ? uri.host : 'share.minymol.com';
    final path = uri.path.isNotEmpty && uri.path != '/' ? uri.path : '';
    return '$host$path';
  } catch (_) {
    return 'share.minymol.com';
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}
