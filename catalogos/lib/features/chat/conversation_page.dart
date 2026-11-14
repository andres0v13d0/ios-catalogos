import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/push_service.dart';
import 'chat_api.dart';

/// Conversación con un proveedor. Se actualiza cada 8 s mientras está abierta
/// (shortcut: sin socket ni push; ver Fase 5 pendiente de notificaciones).
class ConversationPage extends ConsumerStatefulWidget {
  const ConversationPage({super.key, required this.conversationId, this.title});

  final String conversationId;
  final String? title;

  @override
  ConsumerState<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends ConsumerState<ConversationPage> {
  final TextEditingController _input = TextEditingController();
  List<ChatMessage> _messages = const <ChatMessage>[];
  bool _loading = true;
  bool _failed = false;
  Timer? _timer;

  ChatApi get _api => ref.read(chatApiProvider);

  @override
  void initState() {
    super.initState();
    activeChatId = widget.conversationId;
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
    if (text.isEmpty) return;
    _input.clear();
    try {
      await _api.send(widget.conversationId, text);
      await _load();
    } catch (_) {
      if (!mounted) return;
      _input.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos enviar el mensaje. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title ?? 'Chat')),
    body: Column(
      children: <Widget>[
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _failed
              ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: const Text('Reintentar'),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (_, int i) {
                    final ChatMessage m = _messages[_messages.length - 1 - i];
                    return Align(
                      alignment: m.mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: m.mine
                              ? const Color(0xFFD9F4FF)
                              : Colors.black12,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(m.text),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(LucideIcons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
