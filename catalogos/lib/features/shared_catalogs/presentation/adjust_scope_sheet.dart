import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../domain/price_rule_calculator.dart';
import '../domain/price_rules_contract.dart';

/// Resultado de [showAdjustScopeSheet]: lista vacía = todo el catálogo.
typedef AdjustScope = ({List<CatalogSubcategory> subcategories});

/// "¿Qué quieres ajustar?" en dos pasos: todo el catálogo (sigue de una) o
/// "Por subcategoría", que abre una segunda pantalla con botones para elegir
/// una o varias.
Future<AdjustScope?> showAdjustScopeSheet(
  BuildContext context, {
  required List<CatalogSubcategory> subcategories,
  required PriceRule? catalogRule,
}) => showModalBottomSheet<AdjustScope>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (BuildContext c) =>
      _Sheet(subcategories: subcategories, catalogRule: catalogRule),
);

String _ruleText(PriceRule r) => r.mode == PriceRuleMode.percent
    ? '+${r.value}%'
    : '+\$${formatCopPlain(r.value)}';

class _Sheet extends StatefulWidget {
  const _Sheet({required this.subcategories, required this.catalogRule});

  final List<CatalogSubcategory> subcategories;
  final PriceRule? catalogRule;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  bool _picking = false;
  final Set<String> _selected = <String>{};

  void _finish(List<CatalogSubcategory> subs) =>
      Navigator.pop<AdjustScope>(context, (subcategories: subs));

  @override
  Widget build(BuildContext context) {
    final double maxH = MediaQuery.sizeOf(context).height * 0.75;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            // El segundo paso entra deslizando desde la izquierda.
            transitionBuilder: (Widget child, Animation<double> a) =>
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(-1, 0),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
                  child: child,
                ),
            child: _picking
                ? _PickStep(
                    key: const ValueKey<String>('pick'),
                    subcategories: widget.subcategories,
                    selected: _selected,
                    onToggle: (String id) => setState(() {
                      _selected.contains(id)
                          ? _selected.remove(id)
                          : _selected.add(id);
                    }),
                    onBack: () => setState(() => _picking = false),
                    onContinue: () => _finish(<CatalogSubcategory>[
                      for (final CatalogSubcategory s in widget.subcategories)
                        if (_selected.contains(s.id)) s,
                    ]),
                  )
                : _ScopeStep(
                    key: const ValueKey<String>('scope'),
                    catalogRule: widget.catalogRule,
                    onAll: () => _finish(const <CatalogSubcategory>[]),
                    onSubcategories: () => setState(() => _picking = true),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.only(top: 12, bottom: 16),
      width: 44,
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0xFFD5DCE8),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

class _ScopeStep extends StatelessWidget {
  const _ScopeStep({
    super.key,
    required this.catalogRule,
    required this.onAll,
    required this.onSubcategories,
  });

  final PriceRule? catalogRule;
  final VoidCallback onAll;
  final VoidCallback onSubcategories;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _Handle(),
        const Text(
          '¿Qué quieres ajustar?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 14),
        _OptionCard(
          icon: LucideIcons.layers,
          title: 'Todo el catálogo',
          subtitle: 'Un mismo ajuste para todos los productos',
          badge: catalogRule == null ? null : _ruleText(catalogRule!),
          onTap: onAll,
        ),
        const SizedBox(height: 10),
        _OptionCard(
          icon: LucideIcons.tag,
          title: 'Por subcategoría',
          subtitle: 'Elige una o varias subcategorías',
          chevron: true,
          onTap: onSubcategories,
        ),
      ],
    ),
  );
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.chevron = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final bool chevron;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFEEF3FB),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Icon(icon, size: 22, color: AppColors.secondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5B6B84),
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Text(
                badge!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
            if (chevron)
              const Icon(
                LucideIcons.chevronRight,
                color: Color(0xFF5B6B84),
                size: 20,
              ),
          ],
        ),
      ),
    ),
  );
}

class _PickStep extends StatelessWidget {
  const _PickStep({
    super.key,
    required this.subcategories,
    required this.selected,
    required this.onToggle,
    required this.onBack,
    required this.onContinue,
  });

  final List<CatalogSubcategory> subcategories;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _Handle(),
        Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Volver',
              onPressed: onBack,
              icon: const Icon(
                LucideIcons.chevronLeft,
                color: AppColors.primary,
              ),
            ),
            const Expanded(
              child: Text(
                'Elige las subcategorías',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 0, 10),
          child: Text(
            'Puedes tocar varias. El ajuste se aplicará a todas.',
            style: TextStyle(fontSize: 12, color: Color(0xFF5B6B84)),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final CatalogSubcategory s in subcategories)
                  _SubChip(
                    sub: s,
                    on: selected.contains(s.id),
                    onTap: () => onToggle(s.id),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: selected.isEmpty ? null : onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: Text(
              selected.isEmpty
                  ? 'Elige al menos una'
                  : 'Continuar (${selected.length})',
            ),
          ),
        ),
      ],
    ),
  );
}

class _SubChip extends StatelessWidget {
  const _SubChip({required this.sub, required this.on, required this.onTap});

  final CatalogSubcategory sub;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: on ? AppColors.secondary : Colors.white,
    shape: StadiumBorder(
      side: BorderSide(
        color: on ? AppColors.secondary : const Color(0xFFCFE0F7),
        width: 1.5,
      ),
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (on) ...<Widget>[
              const Icon(LucideIcons.check, size: 15, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              sub.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: on ? Colors.white : AppColors.secondary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              sub.rule == null
                  ? '${sub.productCount}'
                  : '${sub.productCount} · ${_ruleText(sub.rule!)}',
              style: TextStyle(
                fontSize: 11,
                color: on ? const Color(0xCCFFFFFF) : const Color(0xFF5B6B84),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
