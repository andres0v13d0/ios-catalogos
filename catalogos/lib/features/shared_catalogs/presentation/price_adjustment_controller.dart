import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../data/reseller_price_rules_repository.dart';
import '../domain/price_rule_calculator.dart';
import '../domain/price_rules_contract.dart';

/// Argumentos de navegación de [PriceAdjustmentController]/`PriceAdjustmentPage`.
///
/// `singleProduct == null` → modo "catálogo completo" (estados 1/2 del
/// diseño). `singleProduct != null` → modo "un solo producto" (estado 3,
/// abierto desde el lápiz): se reutiliza el producto YA cargado por la
/// cuadrícula (con su `precioProveedor`), sin pedirlo de nuevo a la red.
class PriceAdjustmentArgs {
  const PriceAdjustmentArgs({
    required this.catalogId,
    required this.totalProductsHint,
    this.singleProduct,
  });

  final String catalogId;

  /// Total de productos del catálogo conocido de antemano (de
  /// `CatalogDetail.products.length`), usado como respaldo antes de que
  /// resuelva la carga; en modo catálogo completo se reemplaza por el
  /// `total` real que devuelve el backend.
  final int totalProductsHint;

  final CatalogPriceRuleProduct? singleProduct;

  bool get isSingleProduct => singleProduct != null;
}

sealed class PriceAdjustmentState {
  const PriceAdjustmentState();
}

class PriceAdjustmentLoading extends PriceAdjustmentState {
  const PriceAdjustmentLoading();
}

class PriceAdjustmentLoadError extends PriceAdjustmentState {
  const PriceAdjustmentLoadError(this.failure);
  final Failure failure;
}

/// Editor interactivo (estados 1/2/3 del diseño).
class PriceAdjustmentReady extends PriceAdjustmentState {
  const PriceAdjustmentReady({
    required this.previewProducts,
    required this.previewIndex,
    required this.mode,
    required this.rawDigits,
    required this.catalogRule,
    required this.hasOwnRule,
    required this.totalProducts,
    required this.saving,
    required this.removing,
    required this.actionError,
  });

  /// Productos para la vista previa ("Cambiar" rota entre ellos). En modo "un
  /// solo producto" tiene exactamente 1 elemento (fijo).
  final List<CatalogPriceRuleProduct> previewProducts;
  final int previewIndex;
  final PriceRuleMode mode;

  /// Dígitos escritos con el teclado propio ('' = vacío). El valor numérico
  /// es [value].
  final String rawDigits;

  /// Regla de catálogo vigente — solo se usa en modo "un solo producto", para
  /// el renglón "Usar el ajuste del catálogo (+30%)". `null` si el catálogo no
  /// tiene regla propia (no debería mostrarse ese renglón).
  final PriceRule? catalogRule;

  /// `true` si YA existe una regla guardada en este alcance (de catálogo, o
  /// propia del producto) — controla si se muestra "Quitar".
  final bool hasOwnRule;

  final int totalProducts;
  final bool saving;
  final bool removing;

  /// Error transitorio de la última acción de guardar/quitar (se limpia en la
  /// siguiente interacción).
  final Failure? actionError;

  CatalogPriceRuleProduct get currentPreview =>
      previewProducts[previewIndex % previewProducts.length];

  int get value => int.tryParse(rawDigits) ?? 0;

  bool get isBusy => saving || removing;

  bool get canSubmit => !isBusy && _isValueValid;

  bool get _isValueValid {
    if (value <= 0) return false;
    return mode == PriceRuleMode.percent
        ? value >= kPercentValueMin && value <= kPercentValueMax
        : value >= kFixedValueMin && value <= kFixedValueMax;
  }

  /// Precio ajustado en vivo del producto de vista previa con el borrador
  /// actual (null si el valor todavía no es válido: no hay nada que mostrar).
  num? get previewAdjustedPrice {
    final num? base = currentPreview.lowestProviderPrice;
    if (base == null || !_isValueValid) return null;
    return applyPriceRule(base, PriceRule(mode: mode, value: value));
  }

  PriceAdjustmentReady copyWith({
    int? previewIndex,
    PriceRuleMode? mode,
    String? rawDigits,
    bool? saving,
    bool? removing,
    required Failure? actionError,
  }) {
    return PriceAdjustmentReady(
      previewProducts: previewProducts,
      previewIndex: previewIndex ?? this.previewIndex,
      mode: mode ?? this.mode,
      rawDigits: rawDigits ?? this.rawDigits,
      catalogRule: catalogRule,
      hasOwnRule: hasOwnRule,
      totalProducts: totalProducts,
      saving: saving ?? this.saving,
      removing: removing ?? this.removing,
      actionError: actionError,
    );
  }
}

class PriceAdjustmentSavedCatalog extends PriceAdjustmentState {
  const PriceAdjustmentSavedCatalog(this.result);
  final SavedCatalogRuleResult result;
}

class PriceAdjustmentSavedProduct extends PriceAdjustmentState {
  const PriceAdjustmentSavedProduct(this.result);
  final SavedProductRuleResult result;
}

class PriceAdjustmentRemoved extends PriceAdjustmentState {
  const PriceAdjustmentRemoved();
}

/// Controlador del editor "Ajustar precios" (catálogo completo o un solo
/// producto, ver [PriceAdjustmentArgs]). El backend es la fuente de verdad:
/// este controlador solo calcula la vista previa en vivo (vía
/// `applyPriceRule`, puerto Dart) y orquesta las llamadas de guardar/quitar.
///
/// `Notifier` (no `StateNotifier`, removido en Riverpod 3.x): [_args] llega
/// por constructor (igual que `CatalogDetailController` con `catalogId`); el
/// repositorio se resuelve vía `ref` dentro de [build], nunca en el
/// constructor, siguiendo la misma convención que el resto de controladores
/// de la app (ver `profile_controller.dart`).
class PriceAdjustmentController extends Notifier<PriceAdjustmentState> {
  PriceAdjustmentController(this._args);

  final PriceAdjustmentArgs _args;

  ResellerPriceRulesRepository get _repo => ref.read(resellerPriceRulesRepositoryProvider);

  @override
  PriceAdjustmentState build() {
    Future<void>.microtask(_load);
    return const PriceAdjustmentLoading();
  }

  Future<void> _load() async {
    final summaryResult = await _repo.getRulesSummary(_args.catalogId);
    if (summaryResult is Err<PriceRulesSummary>) {
      state = PriceAdjustmentLoadError(summaryResult.failure);
      return;
    }
    final summary = (summaryResult as Ok<PriceRulesSummary>).value;

    List<CatalogPriceRuleProduct> previewProducts;
    PriceRule? existingRule;
    int totalProducts;
    PriceRule? catalogRuleForProductMode;

    if (_args.isSingleProduct) {
      previewProducts = <CatalogPriceRuleProduct>[_args.singleProduct!];
      existingRule = summary.productRules[_args.singleProduct!.id];
      totalProducts = _args.totalProductsHint;
      catalogRuleForProductMode = summary.catalogRule;
    } else {
      final pageResult = await _repo.getCatalogProducts(
        _args.catalogId,
        page: 1,
        pageSize: ResellerPriceRulesRepository.maxPageSize,
      );
      if (pageResult is Err<PriceRulesProductsPage>) {
        state = PriceAdjustmentLoadError(pageResult.failure);
        return;
      }
      final page = (pageResult as Ok<PriceRulesProductsPage>).value;
      if (page.products.isEmpty) {
        state = const PriceAdjustmentLoadError(
          ServerFailure(message: 'Este catálogo aún no tiene productos para ajustar.'),
        );
        return;
      }
      previewProducts = page.products;
      existingRule = summary.catalogRule;
      totalProducts = page.total;
      catalogRuleForProductMode = null;
    }

    if (!ref.mounted) return;
    state = PriceAdjustmentReady(
      previewProducts: previewProducts,
      previewIndex: 0,
      mode: existingRule?.mode ?? PriceRuleMode.percent,
      rawDigits: existingRule != null ? existingRule.value.toString() : '',
      catalogRule: catalogRuleForProductMode,
      hasOwnRule: existingRule != null,
      totalProducts: totalProducts,
      saving: false,
      removing: false,
      actionError: null,
    );
  }

  void onModeChanged(PriceRuleMode mode) {
    final s = state;
    if (s is! PriceAdjustmentReady || s.mode == mode || s.isBusy) return;
    // Cambiar de pestaña limpia el número: un valor del otro modo (p. ej.
    // 80% → fijo) no tiene sentido arrastrado al nuevo modo.
    state = s.copyWith(mode: mode, rawDigits: '', actionError: null);
  }

  void onDigit(String digit) {
    final s = state;
    if (s is! PriceAdjustmentReady || s.isBusy) return;
    final String base = s.rawDigits == '0' ? '' : s.rawDigits;
    final String candidate = base + digit;
    if (!_withinMax(candidate, s.mode)) return;
    state = s.copyWith(rawDigits: candidate, actionError: null);
  }

  /// Tecla "000" (solo Valor fijo).
  void onAppendZeros() {
    final s = state;
    if (s is! PriceAdjustmentReady || s.isBusy) return;
    if (s.mode != PriceRuleMode.fixed || s.rawDigits.isEmpty) return;
    final String candidate = '${s.rawDigits}000';
    if (!_withinMax(candidate, s.mode)) return;
    state = s.copyWith(rawDigits: candidate, actionError: null);
  }

  void onBackspace() {
    final s = state;
    if (s is! PriceAdjustmentReady || s.isBusy || s.rawDigits.isEmpty) return;
    state = s.copyWith(
      rawDigits: s.rawDigits.substring(0, s.rawDigits.length - 1),
      actionError: null,
    );
  }

  void onClear() {
    final s = state;
    if (s is! PriceAdjustmentReady || s.isBusy) return;
    state = s.copyWith(rawDigits: '', actionError: null);
  }

  void onChipTap(int presetValue) {
    final s = state;
    if (s is! PriceAdjustmentReady || s.isBusy) return;
    if (!_withinMax('$presetValue', s.mode)) return;
    state = s.copyWith(rawDigits: '$presetValue', actionError: null);
  }

  void onChangePreview() {
    final s = state;
    if (s is! PriceAdjustmentReady || s.previewProducts.length <= 1) return;
    state = s.copyWith(
      previewIndex: (s.previewIndex + 1) % s.previewProducts.length,
      actionError: s.actionError,
    );
  }

  Future<bool> onSubmit() async {
    final s = state;
    if (s is! PriceAdjustmentReady || !s.canSubmit) return false;
    state = s.copyWith(saving: true, actionError: null);
    final rule = PriceRule(mode: s.mode, value: s.value);

    if (_args.isSingleProduct) {
      final result = await _repo.upsertProductRule(_args.catalogId, _args.singleProduct!.id, rule);
      if (!ref.mounted) return false;
      switch (result) {
        case Ok<SavedProductRuleResult>(:final value):
          state = PriceAdjustmentSavedProduct(value);
          return true;
        case Err<SavedProductRuleResult>(:final failure):
          state = s.copyWith(saving: false, actionError: failure);
          return false;
      }
    }

    final result = await _repo.upsertCatalogRule(_args.catalogId, rule);
    if (!ref.mounted) return false;
    switch (result) {
      case Ok<SavedCatalogRuleResult>(:final value):
        state = PriceAdjustmentSavedCatalog(value);
        return true;
      case Err<SavedCatalogRuleResult>(:final failure):
        state = s.copyWith(saving: false, actionError: failure);
        return false;
    }
  }

  /// "Quitar" (con confirmación en la UI): borra la regla de este alcance.
  Future<bool> onRemove() async {
    final s = state;
    if (s is! PriceAdjustmentReady || s.isBusy) return false;
    state = s.copyWith(removing: true, actionError: null);

    final result = _args.isSingleProduct
        ? await _repo.deleteProductRule(_args.catalogId, _args.singleProduct!.id)
        : await _repo.deleteCatalogRule(_args.catalogId);

    if (!ref.mounted) return false;
    switch (result) {
      case Ok<void>():
        state = const PriceAdjustmentRemoved();
        return true;
      case Err<void>(:final failure):
        state = s.copyWith(removing: false, actionError: failure);
        return false;
    }
  }

  /// "Usar el ajuste del catálogo" (estado 3, sin confirmación): misma
  /// operación que quitar, borra la regla propia del producto para que vuelva
  /// a heredar la del catálogo.
  Future<bool> onUseCatalogRule() => onRemove();

  bool _withinMax(String digits, PriceRuleMode mode) {
    if (digits.isEmpty) return true;
    final int? n = int.tryParse(digits);
    if (n == null) return false;
    final int max = mode == PriceRuleMode.percent ? kPercentValueMax : kFixedValueMax;
    return n <= max;
  }
}

final priceAdjustmentControllerProvider =
    NotifierProvider.family<PriceAdjustmentController, PriceAdjustmentState, PriceAdjustmentArgs>(
      PriceAdjustmentController.new,
    );
