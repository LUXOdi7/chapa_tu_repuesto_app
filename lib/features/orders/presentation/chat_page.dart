import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../core/network/api_config.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../domain/order.dart';

/// Chat del pedido con soporte de canales (supplier / admin) e imagenes.
///
/// ponytail: refresco cada 4 s con `after_id` (solo lo nuevo) en vez de
/// WebSocket/FCM; cambiar a push cuando exista el proyecto Firebase.
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.order,
    this.initialChannel = 'supplier',
  });

  final Order order;
  final String initialChannel;

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
  late String _channel;

  @override
  void initState() {
    super.initState();
    _channel = widget.initialChannel;
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

  void _merge(Iterable<ChatMessage> news) {
    final ids = {for (final m in _messages) m.id};
    final nuevos = news.where((m) => ids.add(m.id)).toList();
    if (nuevos.isEmpty) return;
    setState(() => _messages.addAll(nuevos));
    _scrollToEnd();
  }

  Future<void> _refresh() async {
    try {
      final news = await AppScope.ordersOf(context).messages(
        widget.order.id,
        afterId: _messages.isEmpty ? 0 : _messages.last.id,
        channel: _channel,
      );
      if (!mounted) return;
      if (_loading) setState(() => _loading = false);
      _merge(news);
    } catch (e) {
      if (mounted && _loading) {
        setState(() => _loading = false);
        showError(context, e);
      }
    }
  }

  void _switchChannel(String channel) {
    if (channel == _channel) return;
    setState(() {
      _channel = channel;
      _messages.clear();
      _loading = true;
    });
    _refresh();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _sending = true);
    try {
      final sent = await AppScope.ordersOf(context).sendMessage(
        widget.order.id,
        text,
        channel: _channel,
      );
      if (!mounted) return;
      _merge([sent]);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;

    setState(() => _sending = true);
    try {
      final imageUrl = await AppScope.of(context).api.uploadImage(
        file,
        folder: 'chat',
      );
      if (!mounted) return;
      final sent = await AppScope.ordersOf(context).sendMessage(
        widget.order.id,
        'Captura de pago',
        imageUrl: imageUrl,
        channel: _channel,
      );
      if (!mounted) return;
      _merge([sent]);
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
          // Channel switcher
          Material(
            elevation: 1,
            child: Row(
              children: [
                Expanded(
                  child: _ChannelTab(
                    label: 'Admin',
                    icon: Icons.admin_panel_settings,
                    selected: _channel == 'admin',
                    onTap: () => _switchChannel('admin'),
                  ),
                ),
                Expanded(
                  child: _ChannelTab(
                    label: 'Proveedor',
                    icon: Icons.storefront,
                    selected: _channel == 'supplier',
                    onTap: () => _switchChannel('supplier'),
                  ),
                ),
              ],
            ),
          ),
          if (_channel == 'admin')
            Container(
              width: double.infinity,
              color: Colors.amber.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const Text(
                'Envia aqui tu captura de pago de Yape. El administrador verificara y confirmara tu pago.',
                style: TextStyle(fontSize: 11, color: Colors.brown),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? EmptyState(
                    message: _channel == 'admin'
                        ? 'Envia tu captura de pago aqui.\nEl administrador la revisara.'
                        : 'Escribe tu consulta sobre este pedido.\nLa otra parte recibe un aviso por correo.',
                    icon: Icons.chat_bubble_outline,
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      final mine = m.senderId == me;
                      final newDay =
                          i == 0 || !sameDay(_messages[i - 1].at, m.at);
                      return Column(
                        children: [
                          if (newDay)
                            Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 10),
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
                                  if (m.imageUrl != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          ApiConfig.imageUrl(m.imageUrl!) ??
                                              m.imageUrl!,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.broken_image,
                                                size: 48,
                                              ),
                                        ),
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
                  IconButton(
                    onPressed: _sending ? null : _sendImage,
                    icon: const Icon(Icons.image_outlined),
                    tooltip: 'Enviar imagen',
                  ),
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

class _ChannelTab extends StatelessWidget {
  const _ChannelTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? scheme.primary : scheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
