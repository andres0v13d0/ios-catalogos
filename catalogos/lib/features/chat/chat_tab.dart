import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/router/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/widgets/brand_header.dart';
import 'chat_api.dart';
import 'conversation_page.dart';

/// Pestaña "Chat" (pública): conversaciones de este dispositivo con los proveedores.
class ChatTab extends ConsumerStatefulWidget {
  const ChatTab({super.key});

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> {
  bool _onlyUnread = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ChatConversation>> async = ref.watch(
      conversationsProvider,
    );
    return Scaffold(
      backgroundColor: kSheetTint,
      body: Column(
        children: <Widget>[
          BrandHeader(
            title: 'Chat',
            sheetColor: kSheetTint,
            child: Row(
              children: <Widget>[
                BrandChip(
                  label: 'Todos',
                  on: !_onlyUnread,
                  onTap: () => setState(() => _onlyUnread = false),
                ),
                const SizedBox(width: 8),
                BrandChip(
                  label: 'No leídos',
                  on: _onlyUnread,
                  onTap: () => setState(() => _onlyUnread = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(conversationsProvider),
                  child: const Text('No pudimos cargar tus chats. Reintentar'),
                ),
              ),
              data: (List<ChatConversation> all) {
                final List<ChatConversation> list = _onlyUnread
                    ? all.where((ChatConversation c) => c.unread > 0).toList()
                    : all;
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(conversationsProvider),
                  child: list.isEmpty
                      ? ListView(
                          children: <Widget>[
                            const SizedBox(height: 80),
                            const Icon(
                              LucideIcons.messageCircle,
                              size: 40,
                              color: Color(0xFF5B6B84),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _onlyUnread ? 'No tienes mensajes sin leer.' : 'Aún no tienes conversaciones. Abre un catálogo y toca el ícono de chat para preguntar por un producto.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: list.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, int i) => _ConversationCard(
                            c: list[i],
                            onTap: () async {
                              await context.push(
                                AppRoutes.conversationPath(list[i].id),
                                extra: ConversationInfo(
                                  title: list[i].title,
                                  subtitle: list[i].subtitle,
                                  logoUrl: list[i].logoUrl,
                                  isSupport: list[i].isSupport,
                                  catalogId: list[i].catalogId,
                                ),
                              );
                              ref.invalidate(conversationsProvider);
                            },
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _when(DateTime? t) {
  if (t == null) return '';
  final DateTime n = DateTime.now();
  final DateTime l = t.toLocal();
  if (l.year == n.year && l.month == n.month && l.day == n.day) {
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
  return '${l.day}/${l.month}';
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.c, required this.onTap});

  final ChatConversation c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 1.5,
    shadowColor: const Color(0x14001634),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 48,
                height: 48,
                child: c.logoUrl == null
                    ? const ColoredBox(
                        color: Color(0xFFE3ECFB),
                        child: Icon(
                          LucideIcons.store,
                          color: AppColors.secondary,
                        ),
                      )
                    : Image.network(c.logoUrl!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.lastMessage ?? c.subtitle ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF5B6B84),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  _when(c.lastMessageAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5B6B84),
                  ),
                ),
                if (c.unread > 0)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${c.unread}',
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
