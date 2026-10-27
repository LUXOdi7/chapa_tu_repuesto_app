import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../data/admin_repository.dart';
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

  static const _titles = [
    'Resumen',
    'Usuarios',
    'Tiendas',
    'Pedidos',
    'Sugerencias',
    'Reclamos',
  ];

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      selectedIndex: _tab,
      onSelected: (i) => setState(() => _tab = i),
      appBar: AppBar(
        title: BrandTitle('Admin · ${_titles[_tab]}'),
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
        children: const [
          _StatsTab(),
          _UsersTab(),
          _StoresTab(),
          _OrdersTab(),
          _FeedbackTab(),
          _ReclamacionesTab(),
        ],
      ),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Resumen',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          label: 'Usuarios',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          label: 'Tiendas',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Pedidos',
        ),
        NavigationDestination(
          icon: Icon(Icons.feedback_outlined),
          label: 'Ideas',
        ),
        NavigationDestination(
          icon: Icon(Icons.report_problem_outlined),
          label: 'Reclamos',
        ),
      ],
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
              _StatGrid(
                items: [
                  ('Compradores', '${users['buyer']}', Icons.person_outline),
                  ('Proveedores', '${users['supplier']}', Icons.store_outlined),
                  ('Tiendas', '${s['stores']}', Icons.storefront),
                  (
                    'Por verificar',
                    '${s['stores_pending_verification']}',
                    Icons.pending_actions,
                  ),
                  ('Repuestos', '${s['products']}', Icons.inventory_2_outlined),
                  (
                    'Ventas pagadas',
                    soles((s['gmv'] as num?) ?? 0),
                    Icons.payments_outlined,
                  ),
                  (
                    'Sugerencias',
                    '${s['feedback_open']}',
                    Icons.feedback_outlined,
                  ),
                ],
              ),
              const SectionTitle('Pedidos por estado'),
              for (final e in orders.entries)
                ListTile(
                  dense: true,
                  leading: Icon(
                    orderStatusIcon(e.key),
                    color: orderStatusColor(e.key),
                  ),
                  title: Text(orderStatusLabel(e.key)),
                  trailing: Text(
                    '${e.value}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              SectionTitle(
                'Categorías de repuesto',
                trailing: TextButton.icon(
                  onPressed: () async {
                    await _newCategory(context);
                    if (mounted) setState(() => _reload++);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final key in knownCategories)
                      Chip(
                        label: Text(categoryLabel(key)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

/// Alta de categoria desde el panel (tambien pueden las tiendas).
Future<void> _newCategory(BuildContext context) async {
  final catalog = AppScope.catalogOf(context);
  final ctrl = TextEditingController();
  final label = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Nueva categoría'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nombre'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, ctrl.text.trim()),
          child: const Text('Crear'),
        ),
      ],
    ),
  );
  if (label == null || label.length < 2 || !context.mounted) return;
  try {
    await catalog.createCategory(label);
    if (context.mounted) showInfo(context, 'Categoría "$label" creada');
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});

  final List<(String, String, IconData)> items;

  @override
  // Tarjetas compactas de alto fijo: en web/tablet entran 4-6 por fila en
  // vez de estirarse a media pantalla.
  Widget build(BuildContext context) => GridView(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 200,
      mainAxisExtent: 76,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    ),
    children: [
      for (final (label, value, icon) in items)
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        value,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
            ListTile(
              title: Text(user.name),
              subtitle: Text('${user.email}  ·  ${user.role.label}'),
            ),
            const Divider(height: 1),
            if (user.id != me?.id)
              ListTile(
                leading: Icon(
                  user.isActive ? Icons.block : Icons.check_circle_outline,
                ),
                title: Text(
                  user.isActive ? 'Bloquear cuenta' : 'Reactivar cuenta',
                ),
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
        await admin.updateUser(
          user.id,
          role: UserRole.parse(action.substring(5)),
        );
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
            decoration: const InputDecoration(
              hintText: 'Nombre o correo',
              prefixIcon: Icon(Icons.search),
            ),
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
                  onSelected: (v) => setState(() => _role = v ? r : null),
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
                    backgroundColor: u.isActive
                        ? null
                        : Colors.red.withValues(alpha: 0.2),
                    child: Icon(switch (u.role) {
                      UserRole.admin => Icons.admin_panel_settings,
                      UserRole.supplier => Icons.storefront,
                      UserRole.buyer => Icons.person,
                    }),
                  ),
                  title: Text(u.name),
                  subtitle: Text(
                    '${u.email}  ·  ${u.role.label}${u.isActive ? '' : '  ·  BLOQUEADO'}',
                  ),
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
                final subLabel = s.subscriptionActive
                    ? 'Suscripción: ${s.subscriptionDaysLeft}d restantes'
                    : s.subscriptionDaysLeft > -900
                        ? 'Suscripción vencida'
                        : 'Sin suscripción';
                return ListTile(
                  leading: Icon(
                    s.verified ? Icons.verified_user : Icons.pending,
                    color: s.verified ? Colors.blue : Colors.orange,
                  ),
                  title: Text(s.businessName),
                  subtitle: Text(
                    '${s.ownerEmail != null ? '${s.ownerEmail}  ·  ' : ''}'
                    'RUC ${s.ruc}  ·  ${s.district}\n'
                    '${s.address}\n$subLabel',
                  ),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                        ),
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
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                        ),
                        onPressed: () async {
                          try {
                            await admin.extendSubscription(s.id);
                            if (context.mounted) {
                              showInfo(context, 'Suscripción extendida 30 días');
                              setState(() => _reload++);
                            }
                          } catch (e) {
                            if (context.mounted) showError(context, e);
                          }
                        },
                        child: const Text('+30 días'),
                      ),
                    ],
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
            leading: Icon(
              orderStatusIcon(o.status),
              color: orderStatusColor(o.status),
            ),
            title: Text('${o.code}  ·  ${soles(o.total)}'),
            subtitle: Text(
              '${o.buyerName ?? ''} → ${o.store.businessName}\n${o.statusLabel}  ·  ${shortDate(o.createdAt)}',
            ),
            isThreeLine: true,
            onTap: () => Navigator.pushNamed(
              context,
              OrderTrackingPage.route,
              arguments: o.id,
            ),
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
              subtitle: Text(
                '${f['message']}\n— ${user['name']} (${user['email']})',
              ),
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

// ---------------------------------------------------------------------------
// Reclamaciones INDECOPI
// ---------------------------------------------------------------------------
class _ReclamacionesTab extends StatefulWidget {
  const _ReclamacionesTab();

  @override
  State<_ReclamacionesTab> createState() => _ReclamacionesTabState();
}

class _ReclamacionesTabState extends State<_ReclamacionesTab> {
  bool _soloPendientes = true;
  int _reload = 0;

  Future<void> _responder(
    Map<String, dynamic> rec,
    AdminRepository admin,
  ) async {
    final ctrl = TextEditingController(text: rec['respuesta'] as String? ?? '');
    var resuelto = rec['resuelto'] as bool? ?? false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text('Reclamo ${rec['correlativo']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Respuesta al consumidor'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Marcar como resuelto'),
                value: resuelto,
                onChanged: (v) => set(() => resuelto = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await admin.responderReclamacion(
        rec['id'] as int,
        respuesta: ctrl.text.trim(),
        resuelto: resuelto,
      );
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
        SwitchListTile(
          title: const Text('Solo pendientes'),
          value: _soloPendientes,
          onChanged: (v) => setState(() {
            _soloPendientes = v;
            _reload++;
          }),
        ),
        Expanded(
          child: AsyncView<List<Map<String, dynamic>>>(
            refreshKey: '$_soloPendientes|$_reload',
            load: () => admin.reclamaciones(
              resuelto: _soloPendientes ? false : null,
            ),
            isEmpty: (r) => r.isEmpty,
            emptyIcon: Icons.check_circle_outline,
            emptyMessage: 'No hay reclamaciones pendientes.',
            builder: (context, items) => ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = items[i];
                final resuelto = r['resuelto'] as bool? ?? false;
                return ListTile(
                  leading: Icon(
                    resuelto
                        ? Icons.check_circle_outline
                        : Icons.report_problem_outlined,
                    color: resuelto ? Colors.green : Colors.orange,
                  ),
                  title: Text(
                    '${r['correlativo']}  ·  ${r['tipo']?.toString().toUpperCase() ?? ''}',
                  ),
                  subtitle: Text(
                    '${r['nombre']}  ·  ${r['correo']}\n${r['bien_contratado']}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.more_vert),
                  onTap: () => _responder(r, admin),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
