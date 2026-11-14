import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/money.dart';
import '../buy/cart_controller.dart';

/// Número en el formato que pide WhatsApp (solo dígitos, con indicativo de país).
/// Igual que la web: "+57…" o "57…" quedan tal cual; un celular colombiano que
/// empieza por 3 recibe el 57.
String formatWhatsAppNumber(String raw) {
  final String clean = raw.replaceAll(RegExp(r'[^\d+]'), '');
  if (clean.startsWith('+')) return clean.substring(1);
  if (clean.startsWith('57')) return clean;
  if (clean.startsWith('3')) return '57$clean';
  return clean;
}

/// Enlace que abre el chat con [phone] y el [message] ya escrito.
Uri whatsappUri(String phone, String message, {required bool android}) {
  final String p = formatWhatsAppNumber(phone);
  final String text = Uri.encodeComponent(message);
  return Uri.parse(
    android
        ? 'https://api.whatsapp.com/send?phone=$p&text=$text'
        : 'https://wa.me/$p?text=$text',
  );
}

/// Mensaje del pedido para WhatsApp: productos, total y el enlace con el detalle.
/// [total] es el que calculó el servidor; con [hidePrices] no se muestra ningún monto.
String buildOrderMessage(
  List<CartLine> lines,
  String link, {
  required num total,
  bool hidePrices = false,
}) {
  final String products = lines
      .map((CartLine l) {
        final List<String> specs = <String>[
          if (l.color != null && l.color!.isNotEmpty) 'Color: ${l.color}',
          if (l.size != null && l.size!.isNotEmpty) 'Talla: ${l.size}',
          'Cantidad: ${l.quantity}',
        ];
        final StringBuffer b = StringBuffer(l.name)
          ..write('\n  • ${specs.join(', ')}');
        if (!hidePrices && (l.unitPrice ?? 0) > 0) {
          b.write('\n${formatCop(l.unitPrice!)} c/u');
        }
        return b.toString();
      })
      .join('\n\n');
  final String word = lines.length == 1 ? 'producto' : 'productos';
  final String totalLine = !hidePrices && total > 0
      ? 'Total estimado: ${formatCop(total)}'
      : 'Precios por confirmar con el proveedor';
  return '¡Hola!\n\nEste es mi pedido de ${lines.length} $word:\n\n$products'
      '\n\n$totalLine\n\nPuedes ver todos los detalles aquí: $link\n\n¡Gracias!';
}

/// Resumen corto para la vista previa del enlace ("6 Tenis, 12 Sandalia y 2 más").
String buildOrderSummary(List<CartLine> lines, {int max = 3}) {
  final List<String> parts = lines
      .map((CartLine l) => '${l.quantity} ${l.name}')
      .toList();
  final String shown = parts.take(max).join(', ');
  final int rest = parts.length - max;
  final String text = rest > 0 ? '$shown y $rest más' : shown;
  return text.length > 300 ? '${text.substring(0, 297)}...' : text;
}

/// Abre un enlace fuera de la app (WhatsApp). Se puede sustituir en pruebas.
final Provider<Future<bool> Function(Uri)> whatsappLauncherProvider =
    Provider<Future<bool> Function(Uri)>(
      (Ref ref) =>
          (Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
    );
