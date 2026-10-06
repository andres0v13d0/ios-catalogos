import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../auth/presentation/auth_vector_icons.dart';
import '../domain/reseller_banner.dart';
import 'catalog_design_tokens.dart';
import 'catalog_products_icons.dart';

/// Lanzador de URLs inyectable (para tests y para abrir WhatsApp/compartir).
typedef UrlLauncher = Future<bool> Function(Uri uri);

/// Compartidor nativo inyectable (hoja del sistema).
typedef NativeSharer = Future<void> Function(String text);

Future<bool> _defaultLaunch(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Future<void> _defaultShare(String text) => SharePlus.instance.share(ShareParams(text: text));

/// Abre la hoja inferior "Compartir catálogo" (diseños Compartir-1/Compartir-2).
///
/// Fondo blanco radio 36 con asa, overlay rgba(0,22,52,0.62). [onChangeBanner]
/// se invoca al tocar "Cambiar banner" (abre la pantalla de banner). Los
/// lanzadores son inyectables para pruebas.
Future<void> showResellerShareSheet(
  BuildContext context, {
  required ResellerBannerState banner,
  required VoidCallback onChangeBanner,
  UrlLauncher launcher = _defaultLaunch,
  NativeSharer sharer = _defaultShare,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x9E001634), // rgba(0,22,52,0.62)
    builder: (BuildContext sheetContext) => _ResellerShareSheet(
      banner: banner,
      onChangeBanner: onChangeBanner,
      launcher: launcher,
      sharer: sharer,
    ),
  );
}

class _ResellerShareSheet extends StatefulWidget {
  const _ResellerShareSheet({
    required this.banner,
    required this.onChangeBanner,
    required this.launcher,
    required this.sharer,
  });

  final ResellerBannerState banner;
  final VoidCallback onChangeBanner;
  final UrlLauncher launcher;
  final NativeSharer sharer;

  @override
  State<_ResellerShareSheet> createState() => _ResellerShareSheetState();
}

class _ResellerShareSheetState extends State<_ResellerShareSheet> {
  bool _copied = false;
  bool _showToast = false;

  /// Enlace COMPLETO que se comparte/copia: incluye `?v=<hash>` si hay banner
  /// propio (rompe la caché de WhatsApp). El redirect del backend lo ignora.
  String get _fullLink => widget.banner.shareLinkWithCacheBust;

  /// Texto de la vista previa del enlace (lo que se muestra en la fila, sin el
  /// `?v=` para no ensuciar la UI).
  String get _displayLink {
    final link = widget.banner.shareLink;
    return link.isEmpty ? 'share.minymol.com' : link;
  }

  String get _shareMessage {
    final name = widget.banner.publicName.trim();
    final titled = name.isEmpty ? 'Mira mi catálogo' : 'Mira mi catálogo: $name';
    return '$titled\n$_fullLink';
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _fullLink));
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _copied = true;
      _showToast = true;
    });
    // El aviso flotante dura ~2s; el botón "Copiado" vuelve a "Copiar" después.
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _copied = false;
        _showToast = false;
      });
    });
  }

  Future<void> _sendWhatsApp() async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(_shareMessage)}');
    bool ok = false;
    try {
      ok = await widget.launcher(uri);
    } catch (_) {
      ok = false;
    }
    if (ok) return;
    // Fallback a la hoja nativa de compartir.
    try {
      await widget.sharer(_shareMessage);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp. Intenta con "Más opciones".')),
      );
    }
  }

  Future<void> _moreOptions() async {
    try {
      await widget.sharer(_shareMessage);
    } catch (_) {
      // Mejor esfuerzo.
    }
  }

  @override
  Widget build(BuildContext context) {
    final double s = catalogScale(context);
    final ResellerBannerState banner = widget.banner;
    final String subtitle = banner.hasPriceRules
        ? 'Tus clientes verán tus precios ajustados.'
        : 'Tus clientes verán el catálogo del proveedor.';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(36 * s)),
        ),
        child: SafeArea(
          top: false,
          child: Stack(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.fromLTRB(20 * s, 10 * s, 20 * s, 20 * s),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Asa
                    Center(
                      child: Container(
                        width: 44 * s,
                        height: 5 * s,
                        margin: EdgeInsets.only(bottom: 16 * s),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD7E2F0),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Text(
                      'Compartir catálogo',
                      style: TextStyle(fontSize: 18 * s, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                    SizedBox(height: 4 * s),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13 * s, color: CatalogTokens.textMuted, height: 1.4),
                    ),
                    SizedBox(height: 18 * s),

                    // Fila del enlace + Copiar
                    _LinkRow(scale: s, displayLink: _displayLink, copied: _copied, onCopy: _copyLink),
                    SizedBox(height: 18 * s),

                    // Vista previa de WhatsApp
                    _SharePreviewCard(scale: s, banner: banner),
                    SizedBox(height: 10 * s),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onChangeBanner();
                        },
                        child: Text(
                          'Cambiar banner',
                          style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.w600, color: AppColors.secondary),
                        ),
                      ),
                    ),
                    SizedBox(height: 10 * s),

                    // Enviar por WhatsApp (principal, degradado)
                    _WhatsAppButton(scale: s, onTap: _sendWhatsApp),
                    SizedBox(height: 10 * s),

                    // Más opciones (secundario)
                    _MoreOptionsButton(scale: s, onTap: _moreOptions),
                  ],
                ),
              ),

              // Aviso flotante "¡Enlace copiado!"
              if (_showToast)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 10 * s,
                  child: Center(child: _CopiedToast(scale: s)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.scale, required this.displayLink, required this.copied, required this.onCopy});

  final double scale;
  final String displayLink;
  final bool copied;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Container(
      padding: EdgeInsets.fromLTRB(14 * s, 6 * s, 6 * s, 6 * s),
      decoration: BoxDecoration(
        color: CatalogTokens.searchBackground,
        borderRadius: BorderRadius.circular(14 * s),
        border: Border.all(color: CatalogTokens.cardBorder),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              displayLink,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13 * s, color: AppColors.primary),
            ),
          ),
          SizedBox(width: 8 * s),
          Semantics(
            button: true,
            label: copied ? 'Copiado' : 'Copiar enlace',
            child: Material(
              color: copied ? AppColors.brand : AppColors.primary,
              borderRadius: BorderRadius.circular(10 * s),
              child: InkWell(
                borderRadius: BorderRadius.circular(10 * s),
                onTap: copied ? null : onCopy,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 9 * s),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (copied) ...<Widget>[
                        SizedBox(
                          width: 15 * s,
                          height: 15 * s,
                          child: CustomPaint(painter: CheckPainter(color: AppColors.primary)),
                        ),
                        SizedBox(width: 6 * s),
                      ],
                      Text(
                        copied ? 'Copiado' : 'Copiar',
                        style: TextStyle(
                          fontSize: 13 * s,
                          fontWeight: FontWeight.w600,
                          color: copied ? AppColors.primary : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SharePreviewCard extends StatelessWidget {
  const _SharePreviewCard({required this.scale, required this.banner});

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
        borderRadius: BorderRadius.circular(16 * s),
        border: Border.all(color: CatalogTokens.cardBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(color: CatalogTokens.quickActionShadow, offset: Offset(0, 10 * s), blurRadius: 24 * s),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1.91,
            child: Container(
              color: const Color(0xFFEAF0FF),
              child: imageUrl == null
                  ? Center(
                      child: SizedBox(
                        width: 38 * s,
                        height: 38 * s,
                        child: CustomPaint(painter: ImageIconPainter(color: CatalogTokens.textMuted)),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      key: const Key('share_preview_image'),
                      placeholder: (c, _) => const ColoredBox(color: Color(0xFFEAF0FF)),
                      errorWidget: (c, _, _) => Center(
                        child: SizedBox(
                          width: 38 * s,
                          height: 38 * s,
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

class _WhatsAppButton extends StatelessWidget {
  const _WhatsAppButton({required this.scale, required this.onTap});

  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Semantics(
      button: true,
      label: 'Enviar por WhatsApp',
      child: Container(
        height: 54 * s,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16 * s),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[AppColors.accent, AppColors.brand],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(color: const Color.fromRGBO(0, 255, 148, 0.3), offset: Offset(0, 10 * s), blurRadius: 24 * s),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(16 * s),
            onTap: onTap,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Enviar por WhatsApp',
                    style: TextStyle(fontSize: 16 * s, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                  SizedBox(width: 10 * s),
                  SizedBox(
                    width: 20 * s,
                    height: 20 * s,
                    child: CustomPaint(painter: WhatsAppPainter(color: AppColors.primary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreOptionsButton extends StatelessWidget {
  const _MoreOptionsButton({required this.scale, required this.onTap});

  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Semantics(
      button: true,
      label: 'Más opciones',
      child: Material(
        color: CatalogTokens.searchBackground,
        borderRadius: BorderRadius.circular(16 * s),
        child: InkWell(
          borderRadius: BorderRadius.circular(16 * s),
          onTap: onTap,
          child: Container(
            height: 50 * s,
            alignment: Alignment.center,
            child: Text(
              'Más opciones',
              style: TextStyle(fontSize: 15 * s, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

class _CopiedToast extends StatelessWidget {
  const _CopiedToast({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 10 * s),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(color: CatalogTokens.greenGlowShadow, offset: Offset(0, 6 * s), blurRadius: 16 * s),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 16 * s,
            height: 16 * s,
            child: CustomPaint(painter: CheckPainter(color: AppColors.brand)),
          ),
          SizedBox(width: 8 * s),
          Text(
            '¡Enlace copiado!',
            style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.w600, color: Colors.white),
          ),
        ],
      ),
    );
  }
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
