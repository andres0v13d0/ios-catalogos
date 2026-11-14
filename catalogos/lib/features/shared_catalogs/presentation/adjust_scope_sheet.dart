import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../domain/price_rule_calculator.dart';
import '../domain/price_rules_contract.dart';

/// Resultado de [showAdjustScopeSheet]: `null` en `subcategory` = todo el catálogo.
typedef AdjustScope = ({CatalogSubcategory? subcategory});

/// "¿Qué quieres ajustar?": todo el catálogo o una de sus subcategorías.
Future<AdjustScope?> showAdjustScopeSheet(
  BuildContext context, {
  required List<CatalogSubcategory> subcategories,
  required PriceRule? catalogRule,
}) => showModalBottomSheet<AdjustScope>(
  context: context,
  isScrollControlled: true,
  builder: (BuildContext c) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
      child: ListView(
        shrinkWrap: true,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              '¿Qué quieres ajustar?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          ListTile(
            title: const Text('Todo el catálogo'),
            trailing: _Badge(catalogRule),
            onTap: () => Navigator.pop(c, (subcategory: null)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Por subcategoría',
              style: TextStyle(fontSize: 12, color: Color(0xFF5B6B84)),
            ),
          ),
          for (final CatalogSubcategory s in subcategories)
            ListTile(
              title: Text(s.name),
              subtitle: Text(
                '${s.productCount} producto${s.productCount == 1 ? '' : 's'}',
              ),
              trailing: _Badge(s.rule),
              onTap: () => Navigator.pop(c, (subcategory: s)),
            ),
        ],
      ),
    ),
  ),
);

class _Badge extends StatelessWidget {
  const _Badge(this.rule);

  final PriceRule? rule;

  @override
  Widget build(BuildContext context) {
    if (rule == null) return const SizedBox.shrink();
    return Text(
      rule!.mode == PriceRuleMode.percent
          ? '+${rule!.value}%'
          : '+\$${formatCopPlain(rule!.value)}',
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.secondary,
      ),
    );
  }
}
