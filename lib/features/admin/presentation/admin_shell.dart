import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../auth/domain/user.dart';
import '../../catalog/domain/store.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_tracking_page.dart';
import '../../profile/presentation/profile_page.dart';

/// Panel del administrador: resumen, cuentas, tiendas por verificar,
/// pedidos y sugerencias de los usuarios.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;

  static const _titles = ['Resumen', 'Usuarios', 'Tiendas', 'Pedidos', 'Sugerencias'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin · ${_titles[_tab]}'),
        actions: [
          IconButton(
            tooltip: 'Mi cuenta',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => Navigator.pushNamed(context, ProfilePage.route),
          ),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [_StatsTab(), _UsersTab(), _StoresTab(), _OrdersTab(), _FeedbackTab()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Resumen'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Usuarios'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Tiendas'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Pedidos'),
          NavigationDestination(icon: Icon(Icons.feedback_outlined), label: 'Ideas'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resumen
// ---------------------------------------------------------------------------
class _StatsTab extends StatefulWidget {
  const _StatsTab();

  @override
  State<_StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<_StatsTab> {
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    final admin = AppScope.adminOf(context);
    return AsyncView<Map<String, dynamic>>(
      refreshKey: _reload,
      load: admin.stats,
      builder: (context, s) {
        final users = (s['users'] as Map).cast<String, dynamic>();
        final orders = (s['orders'] as Map).cast<String, dynamic>();
        return RefreshIndicator(
          onRefresh: () async => setState(() => _reload++),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatGrid(items: [
                ('Compradores', '${users['buyer']}', Icons.person_outline),
                ('Proveedores', '${users['supplier']}', Icons.store_outlined),
                ('Tiendas', '${s['stores']}', Icons.storefront),
                ('Por verificar', '${s['stores_pending_verification']}', Icons.pending_actions),
                ('Repuestos', '${s['products']}', Icons.inventory_2_outlined),
                ('Ventas pagadas', soles((s['gmv'] as num?) ?? 0), Icons.payments_outlined),
                ('Sugerencias', '${s['feedback_open']}', Icons.feedback_outlined),
              ]),
              const SectionTitle('Pedidos por estado'),
              for (final e in orders.entries)
                ListTile(
                  dense: true,
                  leading: Icon(orderStatusIcon(e.key), color: orderStatusColor(e.key)),
                  title: Text(orderStatusLabel(e.key)),
                  trailing: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});

  final List<(String, String, IconData)> items;

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (final (label, value, icon) in items)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(icon, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(value,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          Text(label, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
}

// ---------------------------------------------------------------------------
// Usuarios: buscar, bloquear/activar, cambiar perfil
// ---------------------------------------------------------------------------
class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _q = '';
  UserRole? _role;
  int _reload = 0;

  Future<void> _edit(User user) async {
    final admin = AppScope.adminOf(context);
    final me = AppScope.sessionOf(context).user;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(user.name), subtitle: Text('${user.email}  ·  ${user.role.label}')),
            const Divider(height: 1),
            if (user.id != me?.id)
              ListTile(
                leading: Icon(user.isActive ? Icons.block : Icons.check_circle_outline),
                title: Text(user.isActive ? 'Bloquear cuenta' : 'Reactivar cuenta'),
                onTap: () => Navigator.pop(sheet, 'toggle'),
              ),
            for (final role in UserRole.values)
              if (role != user.role && (user.id != me?.id))
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: Text('Cambiar a ${role.label}'),
                  onTap: () => Navigator.pop(sheet, 'role:${role.key}'),
                ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      if (action == 'toggle') {
        await admin.updateUser(user.id, isActive: !user.isActive);
      } else {
        await admin.updateUser(user.id, role: UserRole.parse(action.substring(5)));
      }
      if (mounted) setState(() => _reload++);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = AppScope.adminOf(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Nombre o correo', prefixIcon: Icon(Icons.search)),
            onSubmitted: (v) => setState(() => _q = v.trim()),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              FilterChip(
                label: const Text('Todos'),
                selected: _role == null,
                onSelected: (_) => setState(() => _role = null),
                visualDensity: VisualDensity.compact,
              ),
              for (final r in UserRole.values) ...[
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(r.label),
                  selected: _role == r,
                  onSelected: (_) => setState(() => _role = r),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: AsyncView<List<User>>(
            refreshKey: '$_q|$_role|$_reload',
            load: () => admin.users(q: _q.isEmpty ? null : _q, role: _role),
            isEmpty: (u) => u.isEmpty,
            emptyMessage: 'No hay usuarios con ese filtro.',
            builder: (context, users) => ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final u = users[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: u.isActive ? null : Colors.red.withValues(alpha: 0.2),
                    child: Icon(switch (u.role) {
                      UserRole.admin => Icons.admin_panel_settings,
                      UserRole.supplier => Icons.storefront,
                      UserRole.buyer => Icons.person,
                    }),
                  ),
                  title: Text(u.name),
                  subtitle: Text('${u.email}  ·  ${u.role.label}${u.isActive ? '' : '  ·  BLOQUEADO'}'),
                  trailing: const Icon(Icons.more_vert),
                  onTap: () => _edit(u),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tiendas: verificar RUC
// ---------------------------------------------------------------------------
class _StoresTab extends StatefulWidget {
  const _StoresTab();

  @override
  State<_StoresTab> createState() => _StoresTabState();
}

class _StoresTabState extends State<_StoresTab> {
  bool _onlyPending = true;
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    final admin = AppScope.adminOf(context);
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Solo pendientes de verificar'),
          value: _onlyPending,
          onChanged: (v) => setState(() => _onlyPending = v),
        ),
        Expanded(
          child: AsyncView<List<Store>>(
            refreshKey: '$_onlyPending|$_reload',
            load: () => admin.stores(onlyPending: _onlyPending),
            isEmpty: (s) => s.isEmpty,
            emptyIcon: Icons.verified_outlined,
            emptyMessage: 'No hay tiendas pendientes.',
            builder: (context, stores) => ListView.separated(
              itemCount: stores.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = stores[i];
                return ListTile(
                  leading: Icon(s.verified ? Icons.verified_user : Icons.pending,
                      color: s.verified ? Colors.blue : Colors.orange),
                  title: Text(s.businessName),
                  subtitle: Text('RUC ${s.ruc}  ·  ${s.district}\n${s.address}'),
                  isThreeLine: true,
                  // TextButton, no FilledButton: el tema le da a FilledButton ancho
                  // infinito (CTA a pantalla completa) y como `trailing` revienta el layout.
                  trailing: TextButton(
                    onPressed: () async {
                      try {
                        await admin.verifyStore(s.id, !s.verified);
                        if (context.mounted) setState(() => _reload++);
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    },
                    child: Text(s.verified ? 'Quitar' : 'Verificar'),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pedidos de toda la plataforma
// ---------------------------------------------------------------------------
class _OrdersTab extends StatelessWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context) {
    final admin = AppScope.adminOf(context);
    return AsyncView<List<Order>>(
      load: admin.orders,
      isEmpty: (o) => o.isEmpty,
      emptyMessage: 'Todavía no hay pedidos.',
      builder: (context, orders) => ListView.separated(
        itemCount: orders.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final o = orders[i];
          return ListTile(
            leading: Icon(orderStatusIcon(o.status), color: orderStatusColor(o.status)),
            title: Text('${o.code}  ·  ${soles(o.total)}'),
            subtitle: Text('${o.buyerName ?? ''} → ${o.store.businessName}\n${o.statusLabel}  ·  ${shortDate(o.createdAt)}'),
            isThreeLine: true,
            onTap: () => Navigator.pushNamed(context, OrderTrackingPage.route, arguments: o.id),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sugerencias
// ---------------------------------------------------------------------------
class _FeedbackTab extends StatefulWidget {
  const _FeedbackTab();

  @override
  State<_FeedbackTab> createState() => _FeedbackTabState();
}

class _FeedbackTabState extends State<_FeedbackTab> {
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    final admin = AppScope.adminOf(context);
    return AsyncView<List<Map<String, dynamic>>>(
      refreshKey: _reload,
      load: admin.feedback,
      isEmpty: (f) => f.isEmpty,
      emptyIcon: Icons.lightbulb_outline,
      emptyMessage: 'Sin sugerencias pendientes.',
      builder: (context, items) => ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final f = items[i];
          final user = (f['user'] as Map).cast<String, dynamic>();
          return Card(
            child: ListTile(
              title: Text(f['subject'] as String? ?? ''),
              subtitle: Text('${f['message']}\n— ${user['name']} (${user['email']})'),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: 'Marcar resuelta',
                icon: const Icon(Icons.task_alt),
                onPressed: () async {
                  try {
                    await admin.resolveFeedback(f['id'] as int);
                    if (context.mounted) setState(() => _reload++);
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
