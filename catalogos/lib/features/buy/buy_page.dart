import 'package:flutter/material.dart';

import '../visitor/visitor_buy_page.dart';

/// Pestaña "Comprar": los catálogos que guardó por enlace y, si es revendedor
/// con sesión, también los que le compartieron sus proveedores (con
/// "Personalizar"), con sus productos nuevos.
class BuyPage extends StatelessWidget {
  const BuyPage({super.key});

  @override
  Widget build(BuildContext context) => const VisitorBuyPage();
}
