import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/router/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/notifications/push_service.dart';
import '../../core/utils/money.dart';
import '../auth/presentation/auth_state_provider.dart';
import '../shared_catalogs/presentation/reseller_banner_controller.dart'
    show imagePickerProvider;
import '../visitor/visitor_catalogs.dart';
import '../../shared/widgets/brand_header.dart';
import 'chat_api.dart';
import 'support_faq.dart';

/// Datos de la cabecera de una conversación (los pasa quien la abre).
class ConversationInfo {
  const ConversationInfo({
    required this.title,
    this.subtitle,
    this.logoUrl,
    this.isSupport = false,
    this.catalogId,
    this.draftProduct,
  });

  /// Producto por el que se pregunta: queda adjunto sobre el cuadro de texto
  /// y se envía junto con el mensaje (como una foto en WhatsApp).
  final Map<String, dynamic>? draftProduct;

  /// Catálogo de la conversación: de ahí salen los productos que se adjuntan.
  final String? catalogId;

  /// Chat de soporte de FLY+: trae preguntas rápidas que se responden solas.
  final bool isSupport;

  final String title;
  final String? subtitle;
  final String? logoUrl;
}

/// Conversación con un proveedor. Se actualiza cada 8 s mientras está abierta
/// (shortcut: sin socket; el aviso push cubre cuando la app está en segundo plano).
class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key, required this.conversationId, this.info});

  final String conversationId;
  final ConversationInfo? info;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

const List<String> _quickReplies = <String>[
  '¿Está disponible?',
  'Precio por mayor',
  '¿Hacen envíos?',
];

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final TextEditingController _input = TextEditingController();
  List<ChatMessage> _messages = const <ChatMessage>[];
  bool _loading = true;
  bool _failed = false;
  bool _sending = false;
  Timer? _timer;
  // Preguntas y respuestas rápidas del soporte: solo viven en esta pantalla.
  final List<ChatMessage> _local = <ChatMessage>[];
  bool _askFeedback = false;
  bool _faqOpen = false; // lista de preguntas desplegada con el botón
  Map<String, dynamic>? _draft; // producto adjunto sin enviar

  ChatApi get _api => ref.read(chatApiProvider);

  @override
  void initState() {
    super.initState();
    activeChatId = widget.conversationId;
    _draft = widget.info?.draftProduct;
    _input.addListener(() => setState(() {}));
    _load();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _load());
  }

  @override
  void dispose() {
    if (activeChatId == widget.conversationId) activeChatId = null;
    _timer?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<ChatMessage> m = await _api.messages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages = m;
        _loading = false;
        _failed = false;
      });
      await _api.markRead(widget.conversationId);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = _messages.isEmpty;
        });
      }
    }
  }

  Future<void> _send() async {
    final String text = _input.text.trim();
    final Map<String, dynamic>? draft = _draft;
    if ((text.isEmpty && draft == null) || _sending) return;
    setState(() {
      _sending = true;
      _draft = null;
    });
    _input.clear();
    try {
      if (draft != null) await _api.sendProduct(widget.conversationId, draft);
      if (text.isNotEmpty) await _api.send(widget.conversationId, text);
      await _load();
    } catch (_) {
      if (!mounted) return;
      _input.text = text;
      _draft = draft;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos enviar el mensaje. Intenta de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.chat);
    }
  }

  ConversationInfo _info() {
    if (widget.info != null) return widget.info!;
    // Abierta desde un aviso: la cabecera sale de la lista de conversaciones.
    final ChatConversation? c = ref
        .watch(conversationsProvider)
        .value
        ?.where((ChatConversation x) => x.id == widget.conversationId)
        .firstOrNull;
    return ConversationInfo(
      title: c?.title ?? 'Chat',
      subtitle: c?.subtitle,
      logoUrl: c?.logoUrl,
      isSupport: c?.isSupport ?? false,
      catalogId: c?.catalogId,
    );
  }

  Future<void> _attach(ConversationInfo info) async {
    final VisitorCatalog? cat = ref
        .read(visitorCatalogsProvider)
        .where((VisitorCatalog c) => c.catalogId == info.catalogId)
        .firstOrNull;
    // Las fotos solo con cuenta: subir al almacenamiento exige sesión.
    final bool canPhoto = ref.read(isSignedInProvider);
    final String? pick = await showModalBottomSheet<String>(
      context: context,
      builder: (BuildContext c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (cat != null)
              ListTile(
                leading: const Icon(LucideIcons.shoppingBag),
                title: const Text('Producto'),
                subtitle: const Text('Pregunta por un producto del catálogo'),
                onTap: () => Navigator.pop(c, 'product'),
              ),
            if (canPhoto)
              ListTile(
                leading: const Icon(LucideIcons.image),
                title: const Text('Foto'),
                onTap: () => Navigator.pop(c, 'photo'),
              ),
          ],
        ),
      ),
    );
    if (pick == 'product' && cat != null) await _pickProduct(cat);
    if (pick == 'photo') await _sendPhoto();
  }

  Future<void> _pickProduct(VisitorCatalog cat) async {
    final VisitorProduct? p = await showModalBottomSheet<VisitorProduct>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext c) => _ProductPicker(shortUuid: cat.shortUuid),
    );
    if (p == null) return;
    setState(() => _draft = productChatPayload(cat, p));
  }

  Future<void> _sendPhoto() async {
    final XFile? f = await ref
        .read(imagePickerProvider)
        .pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 85,
        );
    if (f == null) return;
    await _guarded(
      () async =>
          _api.sendImage(widget.conversationId, f.name, await f.readAsBytes()),
      'No pudimos enviar la foto. Intenta de nuevo.',
    );
  }

  Future<void> _guarded(Future<void> Function() send, String error) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await send();
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _say(String text, {required bool mine}) => _local.add(
    ChatMessage(
      id: 'local-${_local.length}',
      text: text,
      mine: mine,
      createdAt: DateTime.now(),
    ),
  );

  void _faq(SupportFaq f) => setState(() {
    _faqOpen = false;
    _say(f.question, mine: true);
    _say('${f.answer}\n\n$kSupportAsk', mine: false);
    _askFeedback = true;
  });

  void _thanks() => setState(() {
    _say(kSupportYes, mine: true);
    _say(kSupportThanks, mine: false);
    _askFeedback = false;
    _faqOpen = false;
  });

  /// Manda un mensaje real al equipo (le llega la notificación) y responde según el horario.
  Future<void> _talkToSupport() async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _askFeedback = false;
      _faqOpen = false;
    });
    try {
      await _api.send(widget.conversationId, kSupportRequestMessage);
      _say(supportIsOpen() ? kSupportOpen : kSupportClosed, mine: false);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos avisar a soporte. Intenta de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ConversationInfo info = _info();
    final bool canSend =
        (_input.text.trim().isNotEmpty || _draft != null) && !_sending;
    final bool support = info.isSupport;
    final bool showQuick =
        !support &&
        !_loading &&
        !_failed &&
        !_messages.any((ChatMessage m) => m.mine) &&
        _input.text.isEmpty;
    return Scaffold(
      backgroundColor: kSheetTint,
      body: Column(
        children: <Widget>[
          BrandHeader(
            title: info.title,
            subtitle: info.subtitle,
            titleSize: 17,
            sheetColor: kSheetTint,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                BrandHeaderButton(
                  icon: LucideIcons.chevronLeft,
                  label: 'Volver',
                  onTap: _back,
                ),
                const SizedBox(width: 10),
                _Avatar(url: info.logoUrl),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _failed
                ? Center(
                    child: TextButton(
                      onPressed: _load,
                      child: const Text('No pudimos cargar. Reintentar'),
                    ),
                  )
                : _MessageList(
                    messages: support
                        ? <ChatMessage>[..._messages, ..._local]
                        : _messages,
                  ),
          ),
          if (support && !_loading && !_failed && _input.text.isEmpty)
            if (!_askFeedback && !_faqOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _quickChip(
                    'Preguntas frecuentes',
                    () => setState(() => _faqOpen = true),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (_askFeedback) ...<Widget>[
                          _quickChip(kSupportYes, _thanks),
                          _quickChip('No, hablar con soporte', _talkToSupport),
                        ] else ...<Widget>[
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Preguntas frecuentes: selecciona una',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                          for (final SupportFaq f in kSupportFaqs)
                            _quickChip(f.question, () => _faq(f)),
                          _quickChip(
                            kTalkToSupport,
                            _talkToSupport,
                            strong: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          if (showQuick)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickReplies.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, int i) => ActionChip(
                  label: Text(_quickReplies[i]),
                  onPressed: () {
                    _input.text = _quickReplies[i];
                    _input.selection = TextSelection.collapsed(
                      offset: _input.text.length,
                    );
                  },
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFCFE0F7), width: 1.5),
                  shape: const StadiumBorder(),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ),
          if (_draft != null)
            _DraftProduct(
              product: _draft!,
              onRemove: () => setState(() => _draft = null),
            ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Color(0x14001634),
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (!support)
                      IconButton(
                        tooltip: 'Adjuntar',
                        onPressed: _sending ? null : () => _attach(info),
                        icon: const Icon(
                          LucideIcons.paperclip,
                          color: AppColors.secondary,
                        ),
                      ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: kSheetTint,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(fontSize: 14),
                          decoration: const InputDecoration(
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: 'Escribe un mensaje',
                            hintStyle: TextStyle(color: Color(0xFF8A97AB)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      button: true,
                      label: 'Enviar',
                      child: Material(
                        color: canSend
                            ? AppColors.secondary
                            : AppColors.secondary.withValues(alpha: 0.35),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: canSend ? _send : null,
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: _sending
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    LucideIcons.send,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _quickChip(String label, VoidCallback onTap, {bool strong = false}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ActionChip(
        label: Text(label),
        onPressed: onTap,
        backgroundColor: strong ? AppColors.secondary : Colors.white,
        side: const BorderSide(color: Color(0xFFCFE0F7), width: 1.5),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: strong ? Colors.white : AppColors.secondary,
        ),
      ),
    );

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: const Color(0xFFCFE0F7),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.accent, width: 2),
    ),
    clipBehavior: Clip.antiAlias,
    child: url == null || url!.isEmpty
        ? const Icon(LucideIcons.store, color: AppColors.secondary, size: 20)
        : Image.network(url!, fit: BoxFit.cover),
  );
}

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _dayLabel(DateTime t) {
  final DateTime n = DateTime.now();
  final DateTime today = DateTime(n.year, n.month, n.day);
  final int diff = today.difference(DateTime(t.year, t.month, t.day)).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  return '${t.day}/${t.month}/${t.year}';
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Escribe tu primera pregunta. El proveedor te responde por aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF5B6B84)),
          ),
        ),
      );
    }
    // Cronológico con separadores de día; la lista va invertida (abajo = reciente).
    final List<Object> items = <Object>[];
    String? lastDay;
    for (final ChatMessage m in messages) {
      final String d = _dayLabel(m.createdAt);
      final String key =
          '${m.createdAt.year}-${m.createdAt.month}-${m.createdAt.day}';
      if (key != lastDay) {
        items.add(d);
        lastDay = key;
      }
      items.add(m);
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: items.length,
      itemBuilder: (_, int i) {
        final Object it = items[items.length - 1 - i];
        if (it is String) return _DayChip(label: it);
        return _Bubble(m: it as ChatMessage);
      },
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFDFE8F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF5B6B84),
        ),
      ),
    ),
  );
}

/// Producto adjunto, listo para enviar, sobre el cuadro de texto.
class _DraftProduct extends StatelessWidget {
  const _DraftProduct({required this.product, required this.onRemove});

  final Map<String, dynamic> product;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final String? img = product['imageUrl'] as String?;
    final num? price = product['price'] as num?;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 0),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kSheetTint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            if (img != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  img,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                ),
              ),
            if (img != null) const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${product['name']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  if (price != null)
                    Text(
                      formatCop(price),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondary,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Quitar',
              onPressed: onRemove,
              icon: const Icon(LucideIcons.x, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m});

  final ChatMessage m;

  Widget _text() => Text(
    m.text,
    style: TextStyle(
      fontSize: 14,
      height: 1.4,
      color: m.mine ? Colors.white : AppColors.primary,
    ),
  );

  Widget _content() {
    if (m.type == 'IMAGE') {
      if (m.fileExpired || m.fileUrl == null) {
        return Text(
          'Foto no disponible',
          style: TextStyle(color: m.mine ? Colors.white : AppColors.primary),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(m.fileUrl!, width: 220, fit: BoxFit.cover),
      );
    }
    final Map<String, dynamic>? p = m.type == 'PRODUCT' ? m.metadata : null;
    if (p == null) return _text();
    final String? img = p['imageUrl'] as String?;
    final num? price = p['price'] as num?;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (img != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(img, width: 56, height: 56, fit: BoxFit.cover),
          ),
        if (img != null) const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${p['name']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: m.mine ? Colors.white : AppColors.primary,
                ),
              ),
              if (price != null)
                Text(
                  formatCop(price),
                  style: TextStyle(
                    fontSize: 12,
                    color: m.mine ? Colors.white : AppColors.secondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool mine = m.mine;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.74,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: mine ? AppColors.secondary : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 6),
                bottomRight: Radius.circular(mine ? 6 : 18),
              ),
              boxShadow: mine
                  ? null
                  : const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x12001634),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: _content(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _hhmm(m.createdAt),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B7A93),
                  ),
                ),
                if (mine) ...<Widget>[
                  const SizedBox(width: 3),
                  const Icon(
                    LucideIcons.check,
                    size: 13,
                    color: AppColors.secondary,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista de productos del catálogo para adjuntar a un mensaje.
class _ProductPicker extends ConsumerWidget {
  const _ProductPicker({required this.shortUuid});

  final String shortUuid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(visitorCatalogProductsProvider(shortUuid));
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('No pudimos cargar los productos.')),
        data: ((VisitorCatalog, List<VisitorProduct>) d) => ListView(
          children: <Widget>[
            for (final VisitorProduct p in d.$2)
              ListTile(
                leading: p.image == null
                    ? const Icon(LucideIcons.package)
                    : Image.network(
                        p.image!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                      ),
                title: Text(
                  p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: p.priceFrom > 0 ? Text(formatCop(p.priceFrom)) : null,
                onTap: () => Navigator.pop(context, p),
              ),
          ],
        ),
      ),
    );
  }
}
