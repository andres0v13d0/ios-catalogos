import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import 'visitor_catalogs.dart';

/// Destino de un enlace `share.minymol.com/<id>` abierto desde fuera de la app:
/// lo resuelve al catálogo y reemplaza esta pantalla por él.
class ShareLinkPage extends ConsumerStatefulWidget {
  const ShareLinkPage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ShareLinkPage> createState() => _ShareLinkPageState();
}

class _ShareLinkPageState extends ConsumerState<ShareLinkPage> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() => _failed = false);
    try {
      final CatalogPage? page = await ref
          .read(visitorCatalogApiProvider)
          .lookupPage('https://share.minymol.com/${widget.id}');
      if (!mounted) return;
      if (page == null) return setState(() => _failed = true);
      context.go(AppRoutes.visitorCatalogPath(page.catalog.shortUuid));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: _failed
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('No pudimos abrir este catálogo.'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _resolve,
                  child: const Text('Reintentar'),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.buy),
                  child: const Text('Ir al inicio'),
                ),
              ],
            )
          : const CircularProgressIndicator(),
    ),
  );
}
