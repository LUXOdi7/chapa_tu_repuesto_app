import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../orders/presentation/order_tracking_page.dart';

/// Campana de la barra: badge con no leídas (se refresca cada 30 s y al volver
/// de la bandeja) y acceso a [NotificationsPage].
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final n = await AppScope.of(context).auth.unreadNotifications();
      if (mounted) setState(() => _unread = n);
    } catch (_) {
      /* sin red: se queda el ultimo valor */
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Notificaciones',
    icon: Badge.count(
      count: _unread,
      isLabelVisible: _unread > 0,
      child: const Icon(Icons.notifications_outlined),
    ),
    onPressed: () async {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
      );
      if (mounted) _load();
    },
  );
}

/// Bandeja: estados de pedido, mensajes del chat, alertas, cambios de
/// producto y calificaciones. Botón de recargar como el chat.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  int _reload = 0;

  static IconData _icon(String kind) => switch (kind) {
    'order' => Icons.local_shipping_outlined,
    'message' => Icons.chat_bubble_outline,
    'alert' => Icons.notifications_active_outlined,
    'product' => Icons.edit_note,
    'review' => Icons.star_outline,
    _ => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final auth = AppScope.of(context).auth;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          IconButton(
            tooltip: 'Marcar todas como leídas',
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              try {
                await auth.markAllNotificationsRead();
                if (mounted) setState(() => _reload++);
              } catch (e) {
                if (mounted) showError(this.context, e);
              }
            },
          ),
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => _reload++),
          ),
        ],
      ),
      body: AsyncView<List<Map<String, dynamic>>>(
        refreshKey: _reload,
        load: auth.notifications,
        isEmpty: (n) => n.isEmpty,
        emptyIcon: Icons.notifications_none,
        emptyMessage: 'Sin notificaciones por ahora.',
        builder: (context, items) => RefreshIndicator(
          onRefresh: () async => setState(() => _reload++),
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              final unread = n['read_at'] == null;
              final orderId = n['order_id'] as int?;
              return ListTile(
                tileColor: unread
                    ? Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.06)
                    : null,
                leading: Icon(
                  _icon(n['kind'] as String? ?? ''),
                  color: unread ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(
                  n['title'] as String? ?? '',
                  style: TextStyle(
                    fontWeight: unread ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  '${n['body']}\n${dateTimeLabel(parseServerDate(n['created_at'] as String))}',
                ),
                isThreeLine: true,
                trailing: orderId != null
                    ? const Icon(Icons.chevron_right)
                    : null,
                onTap: () async {
                  try {
                    if (unread) await auth.markNotificationRead(n['id'] as int);
                  } catch (_) {
                    /* se reintenta al recargar */
                  }
                  if (!context.mounted) return;
                  if (orderId != null) {
                    await Navigator.pushNamed(
                      context,
                      OrderTrackingPage.route,
                      arguments: orderId,
                    );
                  }
                  if (context.mounted) setState(() => _reload++);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
