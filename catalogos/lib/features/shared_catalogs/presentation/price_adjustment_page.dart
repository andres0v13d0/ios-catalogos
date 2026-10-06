import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../auth/presentation/auth_gradient_button.dart';
import '../../auth/presentation/auth_vector_icons.dart';
import '../domain/price_rule_calculator.dart';
import '../domain/price_rules_contract.dart';
import 'catalog_design_tokens.dart';
import 'catalog_products_icons.dart';
import 'price_adjustment_controller.dart';
import 'price_keypad.dart';
import 'product_thumbnail.dart';

/// Pantalla "Ajustar precios" (ver `docs/design/ajustar-precios.html`, 4
/// estados): catálogo completo o un solo producto (mismo widget, ver
/// [PriceAdjustmentArgs.isSingleProduct]). El backend es la fuente de verdad;
/// este widget solo orquesta [PriceAdjustmentController].
///
/// Devuelve `true` al hacer pop si se guardó o se quitó una regla (para que
/// quien empujó esta ruta refresque la lista e invalide su caché), o `false`
/// si se volvió sin cambios.
class PriceAdjustmentPage extends ConsumerWidget {
  const PriceAdjustmentPage({super.key, required this.args});

  final PriceAdjustmentArgs args;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => _RemoveConfirmationDialog(
        isSingleProduct: args.isSingleProduct,
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed ?? false) {
      await ref.read(priceAdjustmentControllerProvider(args).notifier).onRemove();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PriceAdjustmentState state = ref.watch(priceAdjustmentControllerProvider(args));
    final PriceAdjustmentController controller = ref.read(
      priceAdjustmentControllerProvider(args).notifier,
    );

    // El estado "Removido" no tiene pantalla propia en el diseño: se cierra
    // solo, devolviendo `true` para que la lista de productos se refresque.
    ref.listen<PriceAdjustmentState>(priceAdjustmentControllerProvider(args), (previous, next) {
      if (next is PriceAdjustmentRemoved && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(true);
      }
    });

    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, bool? result) {
        if (didPop) return;
        Navigator.of(context).pop(false);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.primary,
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints outerConstraints) {
              final double s = catalogScale(context);
              return Stack(
            children: <Widget>[
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
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
                child: switch (state) {
                  PriceAdjustmentLoading() => const _CenteredSpinner(),
                  PriceAdjustmentLoadError(:final failure) => _LoadErrorBody(
                    message: failure.message,
                    onBack: () => Navigator.of(context).pop(false),
                  ),
                  PriceAdjustmentReady() => _EditorBody(
                    args: args,
                    state: state,
                    controller: controller,
                    onRemove: () => _confirmRemove(context, ref),
                  ),
                  PriceAdjustmentSavedCatalog(:final result) => _DoneBody(
                    title: 'Precios actualizados',
                    subtitleRule: result.rule,
                    rows: <(String, String)>[
                      ('Productos con el ajuste del catálogo', '${result.affectedProductIds.length}'),
                      ('Con ajuste propio (no cambian)', '${result.productsWithOwnRule.length}'),
                      ('Ajuste del catálogo', _ruleLabel(result.rule)),
                    ],
                    onBack: () => Navigator.of(context).pop(true),
                  ),
                  PriceAdjustmentSavedProduct(:final result) => _DoneBody(
                    title: 'Precio actualizado',
                    subtitleRule: result.rule,
                    rows: <(String, String)>[
                      ('Ajuste de este producto', _ruleLabel(result.rule)),
                    ],
                    onBack: () => Navigator.of(context).pop(true),
                  ),
                  PriceAdjustmentRemoved() => const _CenteredSpinner(),
                },
              ),
            ],
              );
            },
          ),
        ),
      ),
    );
  }
}

String _ruleLabel(PriceRule rule) =>
    rule.mode == PriceRuleMode.percent ? '+${rule.value}%' : '+\$${formatCopPlain(rule.value)}';

class _CenteredSpinner extends StatelessWidget {
  const _CenteredSpinner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
    );
  }
}

class _LoadErrorBody extends StatelessWidget {
  const _LoadErrorBody({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _BackButton(onTap: onBack),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.error_outline, size: 40, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap, this.scale = 1});

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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x24FFFFFF), // rgba(255,255,255,0.14)
                ),
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

/// Cuerpo del editor (estados 1/2/3): cabecera, pestañas, número grande,
/// chips, vista previa en vivo y botón de aplicar/guardar, con el teclado
/// propio anclado abajo. Adaptable: sin alturas fijas, sin scroll de página.
class _EditorBody extends StatelessWidget {
  const _EditorBody({
    required this.args,
    required this.state,
    required this.controller,
    required this.onRemove,
  });

  final PriceAdjustmentArgs args;
  final PriceAdjustmentReady state;
  final PriceAdjustmentController controller;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double s = catalogScale(context);
        // Las teclas escalan con `s` pero nunca bajan de 44dp (mínimo táctil
        // pedido explícitamente), aunque `s` sí pueda llegar a 0.82.
        final double keyHeight = (52 * s).clamp(44.0, double.infinity);

        // El teclado SIEMPRE se dibuja a su tamaño pleno (teclas ≥44dp, ver
        // PriceKeypad): nunca se encoge más allá de ese piso. Todo lo de
        // ARRIBA del teclado (pestañas, número, chips, vista previa, botón)
        // vive dentro de un `Expanded` + `FittedBox(scaleDown)`: si el
        // contenido ya escalado por `s` no entra en el espacio disponible
        // (viewports extremos), se reduce aún más COMO BLOQUE — nunca se
        // recorta ni desborda, y nunca hace falta scroll de página.
        return Column(
          children: <Widget>[
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.fromLTRB(16 * s, 8 * s, 16 * s, 0),
                        child: args.isSingleProduct
                            ? _SingleProductTopBar(
                                scale: s,
                                productName: state.currentPreview.nombre,
                                imageUrl: state.currentPreview.imagen,
                                hasOwnRule: state.hasOwnRule,
                                removing: state.removing,
                                onBack: () => Navigator.of(context).pop(false),
                                onRemove: onRemove,
                              )
                            : _CatalogWideTopBar(
                                scale: s,
                                totalProducts: state.totalProducts,
                                hasOwnRule: state.hasOwnRule,
                                removing: state.removing,
                                onBack: () => Navigator.of(context).pop(false),
                                onRemove: onRemove,
                              ),
                      ),
                      SizedBox(height: 16 * s),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20 * s),
                        child: _ModeTabs(scale: s, mode: state.mode, onChanged: controller.onModeChanged),
                      ),
                      SizedBox(height: 14 * s),
                      _BigNumberArea(scale: s, mode: state.mode, rawDigits: state.rawDigits),
                      SizedBox(height: 12 * s),
                      _ChipsRow(scale: s, mode: state.mode, value: state.value, onTap: controller.onChipTap),
                      if (args.isSingleProduct && state.catalogRule != null) ...<Widget>[
                        SizedBox(height: 14 * s),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20 * s),
                          child: _UseCatalogRuleRow(
                            scale: s,
                            rule: state.catalogRule!,
                            onUse: () => controller.onUseCatalogRule(),
                          ),
                        ),
                      ],
                      SizedBox(height: 14 * s),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20 * s),
                        child: _PreviewCard(
                          scale: s,
                          product: state.currentPreview,
                          adjustedPrice: state.previewAdjustedPrice,
                          showChangeButton: !args.isSingleProduct && state.previewProducts.length > 1,
                          onChange: controller.onChangePreview,
                        ),
                      ),
                      if (state.actionError != null) ...<Widget>[
                        Padding(
                          padding: EdgeInsets.fromLTRB(20 * s, 10 * s, 20 * s, 0),
                          child: Text(
                            state.actionError!.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12.5 * s, color: CatalogTokens.errorOnDark),
                          ),
                        ),
                      ],
                      SizedBox(height: 24 * s),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20 * s),
                        child: AuthGradientButton(
                          label: args.isSingleProduct
                              ? 'Guardar para este producto'
                              : 'Aplicar a ${state.totalProducts} producto${state.totalProducts == 1 ? '' : 's'}',
                          iconPainter: const CheckPainter(color: AppColors.primary),
                          enabled: state.canSubmit,
                          loading: state.saving,
                          onPressed: () => controller.onSubmit(),
                          height: 52 * s,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 12 * s),
            PriceKeypad(
              showZerosKey: state.mode == PriceRuleMode.fixed,
              onDigit: controller.onDigit,
              onAppendZeros: controller.onAppendZeros,
              onBackspace: controller.onBackspace,
              onClear: controller.onClear,
              locked: state.isBusy,
              keyHeight: keyHeight,
              padding: EdgeInsets.fromLTRB(20 * s, 12 * s, 20 * s, 20 * s),
              gap: 8 * s,
            ),
          ],
        );
      },
    );
  }
}

class _CatalogWideTopBar extends StatelessWidget {
  const _CatalogWideTopBar({
    required this.scale,
    required this.totalProducts,
    required this.hasOwnRule,
    required this.removing,
    required this.onBack,
    required this.onRemove,
  });

  final double scale;
  final int totalProducts;
  final bool hasOwnRule;
  final bool removing;
  final VoidCallback onBack;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _BackButton(onTap: onBack, scale: s),
        SizedBox(width: 8 * s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Ajustar precios',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18 * s, height: 1.3, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              Text(
                'Catálogo completo · $totalProducts producto${totalProducts == 1 ? '' : 's'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12 * s, height: 1.4, color: CatalogTokens.subtitleOnDark),
              ),
            ],
          ),
        ),
        if (hasOwnRule) _RemoveButton(scale: s, loading: removing, onTap: onRemove),
      ],
    );
  }
}

class _SingleProductTopBar extends StatelessWidget {
  const _SingleProductTopBar({
    required this.scale,
    required this.productName,
    required this.imageUrl,
    required this.hasOwnRule,
    required this.removing,
    required this.onBack,
    required this.onRemove,
  });

  final double scale;
  final String productName;
  final String? imageUrl;
  final bool hasOwnRule;
  final bool removing;
  final VoidCallback onBack;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _BackButton(onTap: onBack, scale: s),
        SizedBox(width: 10 * s),
        Builder(
          builder: (BuildContext context) {
            final double size = 36 * s;
            final double dpr = MediaQuery.devicePixelRatioOf(context);
            return SizedBox(
              width: size,
              height: size,
              child: ProductThumbnail(
                url: imageUrl,
                memCachePixels: (size * dpr).round(),
                borderRadius: 10 * s,
                fallbackIconSize: 18 * s,
              ),
            );
          },
        ),
        SizedBox(width: 10 * s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Solo este producto',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12 * s, height: 1.3, color: CatalogTokens.subtitleOnDark),
              ),
              Text(
                productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15 * s, height: 1.3, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ),
        if (hasOwnRule) _RemoveButton(scale: s, loading: removing, onTap: onRemove),
      ],
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.scale, required this.loading, required this.onTap});

  final double scale;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Semantics(
      button: true,
      enabled: !loading,
      label: 'Quitar ajuste',
      child: Material(
        color: CatalogTokens.whiteOverlay10,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: loading ? null : onTap,
          child: Container(
            height: 44 * s,
            padding: EdgeInsets.symmetric(horizontal: 16 * s),
            decoration: BoxDecoration(
              border: Border.all(color: CatalogTokens.whiteOverlay28),
              borderRadius: BorderRadius.circular(999),
            ),
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
                    width: 16 * s,
                    height: 16 * s,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Quitar',
                    style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.scale, required this.mode, required this.onChanged});

  final double scale;
  final PriceRuleMode mode;
  final ValueChanged<PriceRuleMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Container(
      height: 48 * s,
      padding: EdgeInsets.all(4 * s),
      decoration: BoxDecoration(
        color: CatalogTokens.whiteOverlay12,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _ModeTab(
              scale: s,
              label: 'Porcentaje',
              selected: mode == PriceRuleMode.percent,
              onTap: () => onChanged(PriceRuleMode.percent),
            ),
          ),
          SizedBox(width: 4 * s),
          Expanded(
            child: _ModeTab(
              scale: s,
              label: 'Valor fijo',
              selected: mode == PriceRuleMode.fixed,
              onTap: () => onChanged(PriceRuleMode.fixed),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.scale, required this.label, required this.selected, required this.onTap});

  final double scale;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            height: double.infinity,
            alignment: Alignment.center,
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: CatalogTokens.tabActiveShadow, offset: Offset(0, 6 * s), blurRadius: 16 * s),
                    ],
                  )
                : null,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14 * s,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : CatalogTokens.subtitleOnDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BigNumberArea extends StatelessWidget {
  const _BigNumberArea({required this.scale, required this.mode, required this.rawDigits});

  final double scale;
  final PriceRuleMode mode;
  final String rawDigits;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final String display = rawDigits.isEmpty ? '0' : rawDigits;
    final String label = mode == PriceRuleMode.percent ? 'Subir el precio en' : 'Sumar al precio de cada producto';
    final double numberSize = (mode == PriceRuleMode.percent ? 60 : 56) * s;
    final double affixSize = (mode == PriceRuleMode.percent ? 32 : 30) * s;

    return Semantics(
      liveRegion: true,
      label: mode == PriceRuleMode.percent ? '$display por ciento' : 'Más \$$display pesos',
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24 * s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13 * s, height: 1.4, color: CatalogTokens.subtitleOnDark),
            ),
            SizedBox(height: 4 * s),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    mode == PriceRuleMode.percent ? '+' : '+\$',
                    style: TextStyle(fontSize: affixSize, fontWeight: FontWeight.w700, color: AppColors.accent),
                  ),
                  Text(
                    display,
                    style: TextStyle(fontSize: numberSize, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  if (mode == PriceRuleMode.percent)
                    Text(
                      '%',
                      style: TextStyle(fontSize: 34 * s, fontWeight: FontWeight.w700, color: AppColors.accent),
                    ),
                  SizedBox(width: 4 * s),
                  Container(width: 3 * s, height: 44 * s, color: AppColors.accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  const _ChipsRow({required this.scale, required this.mode, required this.value, required this.onTap});

  final double scale;
  final PriceRuleMode mode;
  final int value;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final List<int> presets = mode == PriceRuleMode.percent
        ? const <int>[10, 15, 20, 30]
        : const <int>[5000, 10000, 20000];

    // UNA sola fila horizontal centrada de píldoras COMPACTAS (cada una se
    // ciñe a su texto, `flex:none` del HTML), separadas 8dp. Nunca `Expanded`
    // (no se reparten el ancho) ni `Wrap` con hijos que se estiren a toda la
    // fila. El eje principal usa `min` para que el bloque se centre como un
    // todo (ver docs/design/ajustar-precios.html).
    final List<Widget> chips = <Widget>[];
    for (int i = 0; i < presets.length; i++) {
      if (i > 0) chips.add(SizedBox(width: 8 * s));
      final int preset = presets[i];
      final bool active = preset == value;
      final String label = mode == PriceRuleMode.percent ? '$preset%' : '+\$${formatCopPlain(preset)}';
      chips.add(
        _PresetChip(scale: s, label: label, active: active, onTap: () => onTap(preset)),
      );
    }

    // `FittedBox(scaleDown)` + `Row(min)` centrado: las píldoras SIEMPRE van
    // en una sola fila; si en conjunto no cupieran (etiquetas anchas de Valor
    // fijo en pantallas angostas / textScaler grande) se reducen como bloque,
    // nunca se apilan ni desbordan.
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: chips,
        ),
      ),
    );
  }
}

/// Píldora de atajo compacta (10%/15%/… o +$5.000/…): se ciñe a su texto
/// (nunca ocupa toda la fila). Activa = fondo cian #5de0e6 + texto navy w700;
/// inactiva = borde blanco 30% + fondo blanco 8% + texto blanco w600.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.scale,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final double scale;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Material(
        color: active ? AppColors.accent : CatalogTokens.whiteOverlay08,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            height: 40 * s,
            padding: EdgeInsets.symmetric(horizontal: 16 * s),
            decoration: BoxDecoration(
              border: active ? null : Border.all(color: CatalogTokens.whiteOverlay30, width: 1.5),
              borderRadius: BorderRadius.circular(999),
            ),
            // Sin `alignment` (que haría crecer el Container a todo el ancho
            // disponible): un `Row` con `mainAxisSize.min` ciñe el ancho al
            // texto y lo centra verticalmente dentro de la altura fija.
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14 * s,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    color: active ? AppColors.primary : Colors.white,
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

class _UseCatalogRuleRow extends StatelessWidget {
  const _UseCatalogRuleRow({required this.scale, required this.rule, required this.onUse});

  final double scale;
  final PriceRule rule;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Container(
      height: 52 * s,
      padding: EdgeInsets.fromLTRB(16 * s, 0, 8 * s, 0),
      decoration: BoxDecoration(
        color: CatalogTokens.whiteOverlay12,
        border: Border.all(color: CatalogTokens.whiteOverlay20),
        borderRadius: BorderRadius.circular(16 * s),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 13 * s, color: Colors.white),
                children: <InlineSpan>[
                  const TextSpan(text: 'Usar el ajuste del catálogo '),
                  TextSpan(
                    text: '(${_ruleLabel(rule)})',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent),
                  ),
                ],
              ),
              maxLines: 2,
            ),
          ),
          Semantics(
            button: true,
            label: 'Usar el ajuste del catálogo',
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onUse,
                child: Container(
                  height: 40 * s,
                  padding: EdgeInsets.symmetric(horizontal: 16 * s),
                  alignment: Alignment.center,
                  child: Text(
                    'Usar',
                    style: TextStyle(fontSize: 13 * s, fontWeight: FontWeight.w700, color: AppColors.primary),
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

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.scale,
    required this.product,
    required this.adjustedPrice,
    required this.showChangeButton,
    required this.onChange,
  });

  final double scale;
  final CatalogPriceRuleProduct product;
  final num? adjustedPrice;
  final bool showChangeButton;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final num? providerPrice = product.lowestProviderPrice;
    final num? perUnit = (adjustedPrice != null && providerPrice != null)
        ? adjustedPrice! - providerPrice
        : null;

    return Container(
      padding: EdgeInsets.all(12 * s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22 * s),
        boxShadow: <BoxShadow>[
          BoxShadow(color: CatalogTokens.darkCardShadow, offset: Offset(0, 18 * s), blurRadius: 40 * s),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showChangeButton) ...<Widget>[
            Row(
              children: <Widget>[
                _PreviewThumbnail(scale: s, url: product.imagen),
                SizedBox(width: 12 * s),
                Expanded(
                  child: Text(
                    product.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14 * s, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Cambiar producto de vista previa',
                  child: InkWell(
                    onTap: onChange,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4 * s, vertical: 10 * s),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(
                            width: 16 * s,
                            height: 16 * s,
                            child: CustomPaint(painter: SwapPainter(color: AppColors.secondary)),
                          ),
                          SizedBox(width: 6 * s),
                          Text(
                            'Cambiar',
                            style: TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w600, color: AppColors.secondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10 * s),
          ],
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _PriceColumn(scale: s, label: 'Proveedor', value: providerPrice, big: false),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12 * s),
                  child: SizedBox(
                    width: 18 * s,
                    height: 18 * s,
                    child: CustomPaint(painter: ArrowForwardPainter(color: CatalogTokens.textMuted)),
                  ),
                ),
                _PriceColumn(scale: s, label: 'Tu precio', value: adjustedPrice, big: true),
              ],
            ),
          ),
          if (perUnit != null) ...<Widget>[
            SizedBox(height: 8 * s),
            // `Wrap` en vez de `Row`: a textScaler grande en pantallas angostas,
            // "Redondeado a la centena" pasa a una segunda línea en vez de
            // desbordar horizontalmente (nunca overflow, nunca scroll).
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8 * s,
              runSpacing: 2 * s,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8 * s, vertical: 2 * s),
                  decoration: BoxDecoration(
                    color: CatalogTokens.perUnitBadgeBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '+\$${formatCopPlain(perUnit)} por unidad',
                    style: TextStyle(fontSize: 11 * s, fontWeight: FontWeight.w700, color: CatalogTokens.perUnitBadgeText),
                  ),
                ),
                Text(
                  'Redondeado a la centena',
                  style: TextStyle(fontSize: 11 * s, color: CatalogTokens.textMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Miniatura del producto en la tarjeta de vista previa: EXACTAMENTE la misma
/// imagen que las tarjetas de la cuadrícula ([ProductThumbnail]) — contenedor
/// cuadrado 1:1, `BoxFit.cover`, esquinas redondeadas (radio 12), mismo
/// marcador/respaldo. Sin degradado de banner ni `memCacheHeight`.
class _PreviewThumbnail extends StatelessWidget {
  const _PreviewThumbnail({required this.scale, required this.url});

  final double scale;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final double size = 48 * scale;
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: size,
      height: size,
      child: ProductThumbnail(
        url: url,
        memCachePixels: (size * dpr).round(),
        borderRadius: 12 * scale,
        fallbackIconSize: 22 * scale,
      ),
    );
  }
}

class _PriceColumn extends StatelessWidget {
  const _PriceColumn({required this.scale, required this.label, required this.value, required this.big});

  final double scale;
  final String label;
  final num? value;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: TextStyle(fontSize: 11 * s, color: CatalogTokens.textMuted)),
        Text(
          value == null ? '—' : '\$${formatCopPlain(value!)}',
          style: TextStyle(
            fontSize: (big ? 24 : 16) * s,
            fontWeight: big ? FontWeight.w700 : FontWeight.w600,
            color: big ? AppColors.primary : CatalogTokens.textMuted,
          ),
        ),
      ],
    );
  }
}

/// Estado 4 "Listo": resumen con los datos que devolvió el backend al
/// guardar. "Compartir ahora" queda detrás de un flag (etapa posterior, ver
/// `catalog_products_flags.dart`): mientras tanto NO se dibuja.
class _DoneBody extends StatelessWidget {
  const _DoneBody({
    required this.title,
    required this.subtitleRule,
    required this.rows,
    required this.onBack,
  });

  final String title;
  final PriceRule subtitleRule;
  final List<(String, String)> rows;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final double s = catalogScale(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          children: <Widget>[
            Positioned(left: 16 * s, top: 0, child: _BackButton(onTap: onBack, scale: s)),
            // Los anillos "sonar" los dibuja ahora `_SuccessBurst` alrededor
            // del círculo verde (ver más abajo), animados en bucle.
            Positioned.fill(
              top: 56 * s,
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox(height: 120 * s),
                        _SuccessBurst(scale: s),
                        SizedBox(height: 28 * s),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24 * s),
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 26 * s, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                        SizedBox(height: 12 * s),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32 * s),
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(fontSize: 14 * s, color: CatalogTokens.subtitleOnDark),
                              children: <InlineSpan>[
                                const TextSpan(text: 'Tu enlace ya muestra los precios con '),
                                TextSpan(
                                  text: _ruleLabel(subtitleRule),
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 36 * s),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20 * s),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 18 * s),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22 * s),
                              boxShadow: <BoxShadow>[
                                BoxShadow(color: CatalogTokens.darkCardShadow, offset: Offset(0, 18 * s), blurRadius: 40 * s),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                for (int i = 0; i < rows.length; i++)
                                  Container(
                                    padding: EdgeInsets.symmetric(vertical: 12 * s),
                                    decoration: BoxDecoration(
                                      border: i == rows.length - 1
                                          ? null
                                          : Border(bottom: BorderSide(color: CatalogTokens.summaryDivider)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        Flexible(
                                          child: Text(
                                            rows[i].$1,
                                            style: TextStyle(fontSize: 13 * s, color: CatalogTokens.textMuted),
                                          ),
                                        ),
                                        SizedBox(width: 8 * s),
                                        Text(
                                          rows[i].$2,
                                          style: TextStyle(fontSize: 15 * s, fontWeight: FontWeight.w700, color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20 * s),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20 * s),
                          child: _SecondaryDarkButton(scale: s, label: 'Volver al catálogo', onTap: onBack),
                        ),
                        SizedBox(height: 20 * s),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
          ],
        );
      },
    );
  }
}

/// Círculo de éxito del estado "Listo" con sus ONDAS "sonar" animadas (ver
/// `docs/design/ajustar-precios.html`, donde el lienzo estático solo muestra
/// posiciones intermedias de la onda).
///
/// - Entrada (una vez, ~450 ms): el círculo verde escala 0.6 → 1.0 con rebote
///   (easeOutBack) y el check se dibuja con trazo progresivo (~350 ms,
///   empezando un poco después). Vibración leve (`HapticFeedback.lightImpact`).
/// - Ondas (bucle): dos anillos de borde cian 2dp que nacen del borde del
///   círculo (escala 1.0 ≈ 120dp) y se expanden a ≈2.1 (≈250dp) mientras su
///   opacidad baja de ≈0.45 a 0; periodo 2.4s, la 2ª desfasada 1.2s, easeOut.
/// - Respiración muy sutil del brillo verde (1.0 → 1.05) con el mismo periodo.
///
/// UN solo [AnimationController] en `repeat()` mueve las dos ondas (con
/// desfase) y la respiración; un segundo controlador one-shot anima la
/// entrada. Todo dentro de un [RepaintBoundary]; sin trabajo cuando la
/// pantalla no está visible ([TickerMode], que pausa los controllers).
///
/// Accesibilidad: si `MediaQuery.disableAnimations` está activo NO anima —
/// muestra los anillos estáticos del diseño y el check ya dibujado. Las ondas
/// son decorativas ([ExcludeSemantics]); el título lo anuncia el lector.
class _SuccessBurst extends StatefulWidget {
  const _SuccessBurst({required this.scale});

  final double scale;

  @override
  State<_SuccessBurst> createState() => _SuccessBurstState();
}

class _SuccessBurstState extends State<_SuccessBurst> with TickerProviderStateMixin {
  late final AnimationController _waves; // bucle: ondas + respiración
  late final AnimationController _entry; // one-shot: círculo + check

  /// Diámetro base del círculo (marco de referencia) y escala máxima de la onda.
  static const double _circleRef = 120;
  static const double _maxWaveScale = 2.1; // ≈250dp sobre 120dp

  bool _reduceMotion = false;
  bool _didInit = false;

  @override
  void initState() {
    super.initState();
    _waves = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _entry = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!_didInit || reduce != _reduceMotion) {
      _reduceMotion = reduce;
      _didInit = true;
      if (_reduceMotion) {
        // Sin animación: anillos estáticos y check ya dibujado.
        _waves.stop();
        _entry.value = 1.0;
      } else {
        _waves.repeat();
        _entry.forward(from: 0);
        // Vibración leve de confirmación (no bloquea ni afecta layout).
        HapticFeedback.lightImpact();
      }
    }
  }

  @override
  void dispose() {
    _waves.dispose();
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.scale;
    final double circle = _circleRef * s;
    // Lado del lienzo del burst = diámetro máximo de la onda (≈250dp·s),
    // acotado para no exceder el ancho disponible (nunca overflow en 320dp).
    final double available = MediaQuery.sizeOf(context).width;
    final double maxBox = (_circleRef * _maxWaveScale * s).clamp(circle, available);

    return ExcludeSemantics(
      child: RepaintBoundary(
        // El lienzo ocupa `circle` en el layout (como antes) pero permite que
        // las ondas pinten MÁS AFUERA sin empujar el layout ni recortarse,
        // acotadas a `maxBox` (≤ ancho de pantalla → sin overflow).
        child: SizedBox(
          width: circle,
          height: circle,
          child: OverflowBox(
            maxWidth: maxBox,
            maxHeight: maxBox,
            child: SizedBox(
              width: maxBox,
              height: maxBox,
              child: AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[_waves, _entry]),
                builder: (BuildContext context, Widget? child) {
                  final double wave = _reduceMotion ? 0.35 : _waves.value;
                  // easeOutBack para la entrada del círculo.
                  final double entry = _reduceMotion
                      ? 1.0
                      : Curves.easeOutBack.transform(_entry.value.clamp(0.0, 1.0));
                  // El check empieza un poco después y dura ~350ms (de 450ms).
                  final double checkT = _reduceMotion
                      ? 1.0
                      : (((_entry.value - 0.22) / 0.78).clamp(0.0, 1.0));
                  // Respiración del brillo: 1.0 → 1.05 con el periodo de onda.
                  final double glow = _reduceMotion
                      ? 1.0
                      : 1.0 + 0.05 * (0.5 - 0.5 * math.cos(2 * math.pi * _waves.value));

                  return CustomPaint(
                    painter: _SuccessBurstPainter(
                      scale: s,
                      circleDiameter: circle,
                      waveT: wave,
                      maxWaveScale: _maxWaveScale,
                      entryScale: _reduceMotion ? 1.0 : (0.6 + 0.4 * entry).clamp(0.0, 1.2),
                      checkProgress: checkT,
                      glowScale: glow,
                      reduceMotion: _reduceMotion,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

}

/// Dibuja el círculo verde (con su brillo), el check progresivo y las dos
/// ondas "sonar". Todo en coordenadas centradas en el lienzo del burst.
class _SuccessBurstPainter extends CustomPainter {
  const _SuccessBurstPainter({
    required this.scale,
    required this.circleDiameter,
    required this.waveT,
    required this.maxWaveScale,
    required this.entryScale,
    required this.checkProgress,
    required this.glowScale,
    required this.reduceMotion,
  });

  final double scale;
  final double circleDiameter;
  final double waveT; // 0..1 posición en el ciclo de onda
  final double maxWaveScale;
  final double entryScale; // escala del círculo (entrada)
  final double checkProgress; // 0..1 trazo del check
  final double glowScale; // respiración del brillo
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double baseRadius = circleDiameter / 2;

    // ---- Ondas "sonar" (detrás del círculo) ----
    // Dos fases desfasadas 0.5 (1.2s de 2.4s). easeOut en el radio.
    for (final double phase in <double>[0.0, 0.5]) {
      final double t = reduceMotion
          ? (phase == 0.0 ? 0.35 : 0.7) // posiciones intermedias estáticas (≈180 y ≈250)
          : (waveT + phase) % 1.0;
      final double eased = Curves.easeOut.transform(t);
      final double ringScale = 1.0 + (maxWaveScale - 1.0) * eased;
      final double opacity = (0.45 * (1.0 - t)).clamp(0.0, 0.45);
      if (opacity <= 0.001) continue;
      final Paint ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * scale
        ..color = const Color(0xFF5DE0E6).withValues(alpha: opacity);
      canvas.drawCircle(center, baseRadius * ringScale, ringPaint);
    }

    // ---- Brillo verde (sombra) con respiración ----
    final double glowRadius = baseRadius * glowScale;
    final Paint glowPaint = Paint()
      ..color = const Color(0x6600FF94)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * scale);
    canvas.drawCircle(center.translate(0, 10 * scale), glowRadius, glowPaint);

    // ---- Círculo verde (entrada con rebote) ----
    final double r = baseRadius * entryScale;
    final Rect circleRect = Rect.fromCircle(center: center, radius: r);
    final Paint fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[AppColors.accent, AppColors.brand],
      ).createShader(circleRect);
    canvas.drawCircle(center, r, fill);

    // ---- Check progresivo (trazo) ----
    if (checkProgress > 0) {
      final double cs = circleDiameter / 24; // el check base ocupa ~58dp dentro de 120dp
      // Escalamos el path del check (viewBox 24) a ~58dp centrado.
      final double checkSize = 58 * scale;
      final double k = checkSize / 24;
      final Offset topLeft = center - Offset(checkSize / 2, checkSize / 2);
      Offset p(double x, double y) => topLeft + Offset(x * k, y * k);
      final Path check = Path()
        ..moveTo(p(5, 12.5).dx, p(5, 12.5).dy)
        ..lineTo(p(9.5, 17).dx, p(9.5, 17).dy)
        ..lineTo(p(19, 7.5).dx, p(19, 7.5).dy);

      final Path drawn = _fractionOfPath(check, checkProgress * entryScale.clamp(0.0, 1.0));
      final Paint checkPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4 * cs
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.primary;
      canvas.drawPath(drawn, checkPaint);
    }
  }

  /// Devuelve el sub-path correspondiente a [fraction] (0..1) de la longitud
  /// total de [path] — para "dibujar" el check con un trazo progresivo.
  Path _fractionOfPath(Path path, double fraction) {
    if (fraction >= 1.0) return path;
    final Path result = Path();
    for (final PathMetric metric in path.computeMetrics()) {
      result.addPath(metric.extractPath(0, metric.length * fraction.clamp(0.0, 1.0)), Offset.zero);
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _SuccessBurstPainter old) =>
      old.waveT != waveT ||
      old.entryScale != entryScale ||
      old.checkProgress != checkProgress ||
      old.glowScale != glowScale ||
      old.reduceMotion != reduceMotion;
}

class _SecondaryDarkButton extends StatelessWidget {
  const _SecondaryDarkButton({required this.scale, required this.label, required this.onTap});

  final double scale;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: CatalogTokens.whiteOverlay08,
        borderRadius: BorderRadius.circular(18 * s),
        child: InkWell(
          borderRadius: BorderRadius.circular(18 * s),
          onTap: onTap,
          child: Container(
            height: 52 * s,
            decoration: BoxDecoration(
              border: Border.all(color: CatalogTokens.whiteOverlay30, width: 1.5),
              borderRadius: BorderRadius.circular(18 * s),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(fontSize: 15 * s, fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _RemoveConfirmationDialog extends StatelessWidget {
  const _RemoveConfirmationDialog({
    required this.isSingleProduct,
    required this.onCancel,
    required this.onConfirm,
  });

  final bool isSingleProduct;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    // Diálogo propio (nunca `AlertDialog` por defecto): tarjeta blanca con
    // las mismas decoraciones (radio, sombra, Poppins, colores de marca) que
    // el resto de la app — ver `docs/design/ajustar-precios.html`.
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x59000A1E), offset: Offset(0, 18), blurRadius: 40),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '¿Quitar el ajuste de precio?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            Text(
              isSingleProduct
                  ? 'Este producto dejará de tener un ajuste propio. Si el catálogo tiene un ajuste general, ese seguirá aplicando.'
                  : 'Se eliminará el ajuste de todo el catálogo. Los productos con un ajuste propio no se ven afectados.',
              style: const TextStyle(fontSize: 14, height: 1.4, color: CatalogTokens.textMuted),
            ),
            const SizedBox(height: 22),
            Row(
              children: <Widget>[
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Cancelar',
                    child: Material(
                      color: const Color(0xFFF4F8FC),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: onCancel,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          child: Center(
                            child: Text(
                              'Cancelar',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Quitar',
                    child: Material(
                      color: const Color(0xFFFFE9E9),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: onConfirm,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          child: Center(
                            child: Text(
                              'Quitar',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFB3261E)),
                            ),
                          ),
                        ),
                      ),
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
