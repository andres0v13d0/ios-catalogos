import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/theme/app_colors.dart';
import 'scan_qr_page.dart';
import 'visitor_catalogs.dart';

/// Hoja "Agregar catálogo": pega el enlace, se consulta el catálogo y se
/// muestra una vista previa antes de guardarlo. Devuelve `true` si se guardó.
Future<bool?> showAddCatalogSheet(BuildContext context) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x8015171C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const AddCatalogSheet(),
    );

enum _Status { idle, loading, found, error }

class AddCatalogSheet extends ConsumerStatefulWidget {
  const AddCatalogSheet({super.key});

  @override
  ConsumerState<AddCatalogSheet> createState() => _AddCatalogSheetState();
}

class _AddCatalogSheetState extends ConsumerState<AddCatalogSheet> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  int _seq = 0; // descarta respuestas de consultas viejas
  _Status _status = _Status.idle;
  CatalogPage? _page;
  String? _error;
  bool _retriable = false;
  bool _saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      _seq++;
      setState(() {
        _status = _Status.idle;
        _page = null;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), _lookup);
  }

  Future<void> _paste() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    _ctrl.text = text;
    _ctrl.selection = TextSelection.collapsed(offset: text.length);
    _debounce?.cancel();
    await _lookup();
  }

  Future<void> _scan() async {
    final String? raw = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const ScanQrPage()),
    );
    if (raw == null || !mounted) return;
    _ctrl.text = raw;
    _debounce?.cancel();
    await _lookup();
  }

  Future<void> _lookup() async {
    final String raw = _ctrl.text.trim();
    if (raw.isEmpty) return;
    final int mine = ++_seq;
    setState(() {
      _status = _Status.loading;
      _page = null;
      _error = null;
    });
    try {
      final CatalogPage? page = await ref
          .read(visitorCatalogApiProvider)
          .lookupPage(raw);
      if (!mounted || mine != _seq) return;
      setState(() {
        _page = page;
        _status = page == null ? _Status.error : _Status.found;
        _error = page == null
            ? 'No encontramos ese catálogo. Revisa que el enlace esté completo.'
            : null;
        _retriable = false;
      });
    } on DioException {
      if (!mounted || mine != _seq) return;
      setState(() {
        _status = _Status.error;
        _error = 'No pudimos conectar. Revisa tu internet e intenta de nuevo.';
        _retriable = true;
      });
    }
  }

  bool get _alreadySaved =>
      _page != null &&
      ref
          .read(visitorCatalogsProvider)
          .any((VisitorCatalog c) => c.shortUuid == _page!.catalog.shortUuid);

  Future<void> _save() async {
    if (_page == null || _saving) return;
    setState(() => _saving = true);
    await ref.read(visitorCatalogsProvider.notifier).add(_page!.catalog);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final double inset = MediaQuery.viewInsetsOf(context).bottom;
    final bool canSave = _status == _Status.found && !_alreadySaved && !_saving;
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5DCE8),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Agregar catálogo',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pega el enlace público del catálogo o escanea su código QR.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF5B6B84),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Enlace del catálogo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 54,
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.secondary, width: 1.5),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        onChanged: _onChanged,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                        ),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          hintText: 'https://share.minymol.com/…',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8A97AB),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 38,
                      child: TextButton.icon(
                        onPressed: _paste,
                        icon: const Icon(LucideIcons.clipboardPaste, size: 16),
                        label: const Text('Pegar'),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFE3ECFB),
                          foregroundColor: AppColors.secondary,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _scan,
                icon: const Icon(LucideIcons.scanQrCode, size: 18),
                label: const Text('Escanear código QR'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  side: const BorderSide(color: AppColors.secondary),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (_status == _Status.error && _error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Color(0xFFD12B2B),
                          ),
                        ),
                      ),
                      if (_retriable)
                        TextButton(
                          onPressed: _lookup,
                          child: const Text('Reintentar'),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: switch (_status) {
                  _Status.loading => const _Skeleton(),
                  _Status.found => _Preview(
                    page: _page!,
                    alreadySaved: _alreadySaved,
                  ),
                  _ => const SizedBox(width: double.infinity),
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    disabledBackgroundColor: AppColors.secondary.withValues(
                      alpha: 0.35,
                    ),
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _saving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('Agregando…'),
                          ],
                        )
                      : const Text('Agregar a mis catálogos'),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.page, required this.alreadySaved});

  final CatalogPage page;
  final bool alreadySaved;

  @override
  Widget build(BuildContext context) {
    final VisitorCatalog c = page.catalog;
    final int n = page.ids.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 52,
              height: 52,
              child: c.logoUrl == null || c.logoUrl!.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFE3ECFB),
                      child: Icon(
                        LucideIcons.store,
                        color: AppColors.secondary,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: c.logoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const ColoredBox(
                        color: Color(0xFFE3ECFB),
                        child: Icon(
                          LucideIcons.store,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                if (c.providerName != null && c.providerName != c.name)
                  Text(
                    c.providerName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5B6B84),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  alreadySaved
                      ? 'Ya tienes este catálogo'
                      : 'Catálogo encontrado · $n ${n == 1 ? 'producto' : 'productos'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: alreadySaved
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: alreadySaved
                        ? AppColors.secondary
                        : const Color(0xFF5B6B84),
                  ),
                ),
              ],
            ),
          ),
          if (!alreadySaved)
            const Icon(
              LucideIcons.circleCheck,
              color: Color(0xFF0F9D6B),
              size: 22,
            ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  Widget _bar(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: const Color(0xFFE3E9F3),
      borderRadius: BorderRadius.circular(h / 2),
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7FC),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFE3E9F3),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _bar(160, 12),
              const SizedBox(height: 8),
              _bar(110, 10),
            ],
          ),
        ),
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.secondary,
          ),
        ),
      ],
    ),
  );
}
