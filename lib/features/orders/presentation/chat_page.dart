import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../domain/order.dart';

/// Consultas comprador <-> tienda dentro de un pedido.
///
/// ponytail: refresco cada 4 s con `after_id` (solo lo nuevo) en vez de
/// WebSocket/FCM; cambiar a push cuando exista el proyecto Firebase.
class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.order});

  final Order order;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messages = <ChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // AppScope (InheritedWidget) no se puede leer dentro de initState:
    // la primera carga va al siguiente microtask.
    Future.microtask(_refresh);
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final news = await AppScope.ordersOf(context).messages(
        widget.order.id,
        afterId: _messages.isEmpty ? 0 : _messages.last.id,
      );
      if (!mounted) return;
      setState(() {
        _messages.addAll(news);
        _loading = false;
      });
      if (news.isNotEmpty) _scrollToEnd();
    } catch (e) {
      if (mounted && _loading) {
        setState(() => _loading = false);
        showError(context, e);
      }
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      final sent = await AppScope.ordersOf(context)
          .sendMessage(widget.order.id, text);
      if (!mounted) return;
      _input.clear();
      setState(() => _messages.add(sent));
      _scrollToEnd();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  });

  @override
  Widget build(BuildContext context) {
    final me = AppScope.sessionOf(context).user?.id;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido ${widget.order.code}'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? const EmptyState(
                    message: 'Escribe tu consulta sobre este pedido.\nLa otra parte recibe un aviso por correo.',
                    icon: Icons.chat_bubble_outline,
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final mine = m.senderId == me;
                      // Chip de fecha centrado una sola vez por dia (como WhatsApp).
                      final newDay =
                          i == 0 || !sameDay(_messages[i - 1].at, m.at);
                      return Column(
                        children: [
                          if (newDay)
                            Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  dayLabel(m.at),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.outline,
                                  ),
                                ),
                              ),
                            ),
                          Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.sizeOf(context).width * 0.75,
                              ),
                              decoration: BoxDecoration(
                                color: mine
                                    ? scheme.primaryContainer
                                    : scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!mine)
                                    Text(
                                      m.senderName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.outline,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  Text(m.body),
                                  Text(
                                    timeLabel(m.at),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: scheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje',
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
