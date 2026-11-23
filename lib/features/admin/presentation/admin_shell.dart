import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_scope.dart';
import '../data/admin_repository.dart';
import '../../../core/format.dart';
import '../../../core/network/api_config.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../auth/domain/user.dart';
import '../../catalog/domain/store.dart';
import '../../orders/domain/order.dart';
import '../../orders/presentation/order_tracking_page.dart';
import '../../profile/presentation/profile_page.dart';

/// Panel del administrador: resumen, cuentas, tiendas por verificar,
/// pedidos, sugerencias, reclamos, movimientos, registros y chat directo.
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
    'Movimientos',
    'Registros',
    'Chat',
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
          _MovementsTab(),
          _RegistrationsTab(),
          _DirectChatTab(),
          _FeedbackTab(),
          _ReclamacionesTab(),
        ],
      ),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Resumen'),
        NavigationDestination(icon: Icon(Icons.people_outline), label: 'Usuarios'),
        NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Tiendas'),
        NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Pedidos'),
        NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'Movimientos'),
        NavigationDestination(icon: Icon(Icons.person_add_outlined), label: 'Registros'),
        NavigationDestination(icon: Icon(Icons.chat_outlined), label: 'Chat'),
        NavigationDestination(icon: Icon(Icons.feedback_outlined), label: 'Ideas'),
        NavigationDestination(icon: Icon(Icons.report_problem_outlined), label: 'Reclamos'),
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
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
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
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
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
// Usuarios
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
                leading: Icon(user.isActive ? Icons.block : Icons.check_circle_outline),
                title: Text(user.isActive ? 'Bloquear cuenta' : 'Reactivar cuenta'),
                onTap: () => Navigator.pop(sheet, 'toggle'),
              ),
            if (user.isSupplier && user.storeId != null)
              ListTile(
                leading: Icon(user.storeVerified ? Icons.remove_moderator : Icons.verified_user,
                    color: user.storeVerified ? Colors.orange : Colors.blue),
                title: Text(user.storeVerified ? 'Quitar verificación de tienda' : 'Verificar tienda'),
                onTap: () => Navigator.pop(sheet, 'verify:${!user.storeVerified}'),
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
      } else if (action.startsWith('verify:')) {
        await admin.verifyStore(user.storeId!, action == 'verify:true');
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
                    backgroundColor: u.isActive ? null : Colors.red.withValues(alpha: 0.2),
                    child: Icon(switch (u.role) {
                      UserRole.admin => Icons.admin_panel_settings,
                      UserRole.supplier => Icons.storefront,
                      UserRole.buyer => Icons.person,
                    }),
                  ),
                  title: Text(u.name),
                  subtitle: Text(
                    '${u.email}  ·  ${u.role.label}'
                    '${u.isActive ? '' : '  ·  BLOQUEADO'}'
                    '${u.isSupplier && u.storeId != null ? (u.storeVerified ? '  ·  VERIFICADO' : '  ·  NO VERIFICADO') : ''}',
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
// Tiendas
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
// Pedidos
// ---------------------------------------------------------------------------
class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  Future<void> _exportOrdersPdf(BuildContext context) async {
    final base = ApiConfig.baseUrl;
    final token = AppScope.of(context).api.token;
    final params = <String, String>{};
    if (token != null) params['token'] = token;
    final uri = Uri.parse('$base/admin/orders.pdf').replace(queryParameters: params);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final admin = AppScope.adminOf(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Expanded(child: Text('Todos los pedidos', style: TextStyle(fontWeight: FontWeight.bold))),
              OutlinedButton.icon(
                onPressed: () => _exportOrdersPdf(context),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('PDF'),
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<List<Order>>(
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
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Movimientos de pago
// ---------------------------------------------------------------------------
class _MovementsTab extends StatefulWidget {
  const _MovementsTab();

  @override
  State<_MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<_MovementsTab> {
  String? _dateFrom;
  String? _dateTo;
  final _emailCtrl = TextEditingController();
  String _preset = 'month';
  int _reload = 0;

  @override
  void initState() {
    super.initState();
    _applyPreset('month');
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    _preset = preset;
    switch (preset) {
      case 'day':
        _dateFrom = DateTime(now.year, now.month, now.day).toIso8601String();
        _dateTo = null;
      case 'week':
        _dateFrom = now.subtract(const Duration(days: 7)).toIso8601String();
        _dateTo = null;
      case 'month':
        _dateFrom = DateTime(now.year, now.month, 1).toIso8601String();
        _dateTo = null;
      case 'year':
        _dateFrom = DateTime(now.year, 1, 1).toIso8601String();
        _dateTo = null;
      default:
        _dateFrom = null;
        _dateTo = null;
    }
    setState(() => _reload++);
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (range == null) return;
    setState(() {
      _preset = 'custom';
      _dateFrom = range.start.toIso8601String();
      _dateTo = range.end.add(const Duration(days: 1)).toIso8601String();
      _reload++;
    });
  }

  Future<void> _exportMovementsPdf(BuildContext context) async {
    final base = ApiConfig.baseUrl;
    final token = AppScope.of(context).api.token;
    final params = <String, String>{};
    if (_dateFrom != null) params['date_from'] = _dateFrom!;
    if (_dateTo != null) params['date_to'] = _dateTo!;
    final email = _emailCtrl.text.trim();
    if (email.isNotEmpty) params['buyer_email'] = email;
    if (token != null) params['token'] = token;
    final uri = Uri.parse('$base/admin/movements.pdf').replace(queryParameters: params);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final admin = AppScope.adminOf(context);
    return Column(
      children: [
        // Filtros
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              hintText: 'Buscar por correo del comprador',
              prefixIcon: Icon(Icons.email_outlined),
              isDense: true,
            ),
            onSubmitted: (_) => setState(() => _reload++),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              for (final (key, label) in [
                ('day', 'Hoy'),
                ('week', 'Semana'),
                ('month', 'Mes'),
                ('year', 'Año'),
              ]) ...[
                FilterChip(
                  label: Text(label),
                  selected: _preset == key,
                  onSelected: (_) => _applyPreset(key),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],
              ActionChip(
                label: const Text('Rango...'),
                onPressed: _pickRange,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
        Expanded(
          child: AsyncView<Map<String, dynamic>>(
            refreshKey: '$_dateFrom|$_dateTo|${_emailCtrl.text}|$_reload',
            load: () => admin.movements(
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              buyerEmail: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
            ),
            builder: (context, data) {
              final items = (data['items'] as List?) ?? [];
              final daily = (data['daily'] as List?) ?? [];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatGrid(items: [
                          ('Pagos', '${data['total']}', Icons.receipt_long),
                          ('Total', soles(data['total_amount'] ?? 0), Icons.payments),
                          ('Comisión', soles(data['total_fee'] ?? 0), Icons.percent),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => _exportMovementsPdf(context),
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                          label: const Text('PDF'),
                        ),
                      ),
                    ],
                  ),
                  if (daily.isNotEmpty) ...[
                    const SectionTitle('Ventas por día'),
                    SizedBox(
                      height: 120,
                      child: _BarChart(
                        values: daily
                            .map((d) => (
                              (d['day'] as String).substring(5),
                              (d['amount'] as num).toDouble(),
                            ))
                            .toList(),
                      ),
                    ),
                  ],
                  const SectionTitle('Detalle'),
                  for (final raw in items)
                    if (raw is Map)
                      Builder(builder: (context) {
                        final images = (raw['payment_images'] as List?)
                            ?.cast<String>()
                            .map((p) => ApiConfig.imageUrl(p))
                            .whereType<String>()
                            .toList() ?? [];
                        return ListTile(
                          dense: true,
                          leading: images.isNotEmpty
                              ? GestureDetector(
                                  onTap: () => _showPaymentImages(context, images),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      images.first,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Icon(
                                        Icons.receipt_long,
                                        size: 20,
                                        color: orderStatusColor(raw['status'] as String? ?? ''),
                                      ),
                                    ),
                                  ),
                                )
                              : Icon(
                                  orderStatusIcon(raw['status'] as String? ?? ''),
                                  color: orderStatusColor(raw['status'] as String? ?? ''),
                                  size: 20,
                                ),
                          title: Text('${raw['code']}  ·  ${soles((raw['total'] as num?) ?? 0)}'),
                          subtitle: Text(
                            '${(raw['buyer'] as Map?)?['name'] ?? ''} → '
                            '${(raw['store'] as Map?)?['business_name'] ?? ''}\n'
                            '${raw['status_label'] ?? ''}  ·  comisión ${soles((raw['platform_fee'] as num?) ?? 0)}'
                            '${images.isNotEmpty ? '  ·  ${images.length} captura(s)' : ''}',
                          ),
                          isThreeLine: true,
                          onTap: () {
                            final id = raw['id'] as int?;
                            if (id != null) {
                              Navigator.pushNamed(context, OrderTrackingPage.route, arguments: id);
                            }
                          },
                        );
                      }),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

void _showPaymentImages(BuildContext context, List<String> urls) {
  showDialog(
    context: context,
    builder: (_) => Dialog(
      child: SizedBox(
        width: 400,
        height: 400,
        child: PageView.builder(
          itemCount: urls.length,
          itemBuilder: (_, i) => InteractiveViewer(
            child: Image.network(urls[i], fit: BoxFit.contain),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Registros de usuarios
// ---------------------------------------------------------------------------
class _RegistrationsTab extends StatefulWidget {
  const _RegistrationsTab();

  @override
  State<_RegistrationsTab> createState() => _RegistrationsTabState();
}

class _RegistrationsTabState extends State<_RegistrationsTab> {
  String? _dateFrom;
  String? _dateTo;
  String? _role;
  String _preset = 'month';
  int _reload = 0;

  @override
  void initState() {
    super.initState();
    _applyPreset('month');
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    _preset = preset;
    switch (preset) {
      case 'day':
        _dateFrom = DateTime(now.year, now.month, now.day).toIso8601String();
        _dateTo = null;
      case 'week':
        _dateFrom = now.subtract(const Duration(days: 7)).toIso8601String();
        _dateTo = null;
      case 'month':
        _dateFrom = DateTime(now.year, now.month, 1).toIso8601String();
        _dateTo = null;
      case 'year':
        _dateFrom = DateTime(now.year, 1, 1).toIso8601String();
        _dateTo = null;
      default:
        _dateFrom = null;
        _dateTo = null;
    }
    setState(() => _reload++);
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (range == null) return;
    setState(() {
      _preset = 'custom';
      _dateFrom = range.start.toIso8601String();
      _dateTo = range.end.add(const Duration(days: 1)).toIso8601String();
      _reload++;
    });
  }

  Future<void> _exportPdf(BuildContext context) async {
    final base = ApiConfig.baseUrl;
    final token = AppScope.of(context).api.token;
    final params = <String, String>{};
    if (_dateFrom != null) params['date_from'] = _dateFrom!;
    if (_dateTo != null) params['date_to'] = _dateTo!;
    if (_role != null) params['role'] = _role!;
    if (token != null) params['token'] = token;
    final uri = Uri.parse('$base/admin/registrations.pdf').replace(queryParameters: params);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final admin = AppScope.adminOf(context);
    return Column(
      children: [
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              for (final (key, label) in [
                ('day', 'Hoy'),
                ('week', 'Semana'),
                ('month', 'Mes'),
                ('year', 'Año'),
              ]) ...[
                FilterChip(
                  label: Text(label),
                  selected: _preset == key,
                  onSelected: (_) => _applyPreset(key),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],
              ActionChip(
                label: const Text('Rango...'),
                onPressed: _pickRange,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              for (final (key, label) in [
                (null, 'Todos'),
                ('buyer', 'Compradores'),
                ('supplier', 'Proveedores'),
              ]) ...[
                FilterChip(
                  label: Text(label),
                  selected: _role == key,
                  onSelected: (_) => setState(() {
                    _role = key;
                    _reload++;
                  }),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Expanded(
          child: AsyncView<Map<String, dynamic>>(
            refreshKey: '$_dateFrom|$_dateTo|$_role|$_reload',
            load: () => admin.registrations(
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              role: _role,
            ),
            builder: (context, data) {
              final items = (data['items'] as List?) ?? [];
              final daily = (data['daily'] as List?) ?? [];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatGrid(items: [
                          ('Total registros', '${data['total']}', Icons.people),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => _exportPdf(context),
                          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                          label: const Text('PDF'),
                        ),
                      ),
                    ],
                  ),
                  if (daily.isNotEmpty) ...[
                    const SectionTitle('Registros por día'),
                    SizedBox(
                      height: 120,
                      child: _BarChart(
                        values: daily
                            .map((d) => (
                              (d['day'] as String).substring(5),
                              (d['count'] as num).toDouble(),
                            ))
                            .toList(),
                      ),
                    ),
                  ],
                  const SectionTitle('Detalle'),
                  for (final raw in items)
                    if (raw is Map)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          raw['role'] == 'supplier' ? Icons.storefront : Icons.person,
                          size: 20,
                        ),
                        title: Text('${raw['name']}'),
                        subtitle: Builder(builder: (_) {
                          final pc = raw['product_count'];
                          final prodTxt = pc != null && pc > 0 ? '  ·  $pc prods' : '';
                          final loginTxt = raw['last_login_at'] != null
                              ? '  ·  Login: ${shortDate(parseServerDate(raw['last_login_at'] as String))}'
                              : '';
                          return Text(
                            '${raw['email']}  ·  ${raw['role']}$prodTxt\n'
                            'Pedidos: ${raw['order_count']}  ·  Registro: ${shortDate(parseServerDate(raw['created_at'] as String))}'
                            '$loginTxt',
                          );
                        }),
                        isThreeLine: true,
                      ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chat directo admin <-> proveedores
// ---------------------------------------------------------------------------
class _DirectChatTab extends StatefulWidget {
  const _DirectChatTab();

  @override
  State<_DirectChatTab> createState() => _DirectChatTabState();
}

class _DirectChatTabState extends State<_DirectChatTab> {
  int? _selectedUserId;
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    if (_selectedUserId != null) {
      return _DirectChatView(
        userId: _selectedUserId!,
        onBack: () => setState(() {
          _selectedUserId = null;
          _reload++;
        }),
      );
    }

    final admin = AppScope.adminOf(context);
    return AsyncView<List<Map<String, dynamic>>>(
      refreshKey: _reload,
      load: admin.directConversations,
      isEmpty: (c) => c.isEmpty,
      emptyIcon: Icons.chat_outlined,
      emptyMessage: 'No hay proveedores registrados.',
      builder: (context, convos) => ListView.separated(
        itemCount: convos.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = convos[i];
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.storefront)),
            title: Text('${c['name']}'),
            subtitle: Text(
              '${c['store_name']}  ·  ${c['email']}\n'
              '${c['last_message'] ?? 'Sin mensajes'}',
            ),
            isThreeLine: true,
            onTap: () => setState(() => _selectedUserId = c['user_id'] as int),
          );
        },
      ),
    );
  }
}

class _DirectChatView extends StatefulWidget {
  const _DirectChatView({required this.userId, required this.onBack});

  final int userId;
  final VoidCallback onBack;

  @override
  State<_DirectChatView> createState() => _DirectChatViewState();
}

class _DirectChatViewState extends State<_DirectChatView> {
  final _messages = <DirectChatMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
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

  void _merge(Iterable<DirectChatMessage> news) {
    final ids = {for (final m in _messages) m.id};
    final nuevos = news.where((m) => ids.add(m.id)).toList();
    if (nuevos.isEmpty) return;
    setState(() => _messages.addAll(nuevos));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _refresh() async {
    try {
      final news = await AppScope.adminOf(context).directMessages(
        widget.userId,
        afterId: _messages.isEmpty ? 0 : _messages.last.id,
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

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _sending = true);
    try {
      final sent = await AppScope.adminOf(context).sendDirectMessage(
        widget.userId,
        text,
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
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final imageUrl = await AppScope.of(context).api.uploadImage(file, folder: 'chat');
      if (!mounted) return;
      final sent = await AppScope.adminOf(context).sendDirectMessage(
        widget.userId,
        'Imagen adjunta',
        imageUrl: imageUrl,
      );
      if (!mounted) return;
      _merge([sent]);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = AppScope.sessionOf(context).user?.id;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Back button bar
        Material(
          elevation: 1,
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
              const Expanded(child: Text('Chat con proveedor', style: TextStyle(fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
              ? const EmptyState(
                  message: 'Escribe al proveedor.\nPuedes enviar capturas de pagos, avisos, etc.',
                  icon: Icons.chat_bubble_outline,
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final m = _messages[i];
                    final mine = m.senderId == me;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!mine)
                              Text(m.senderName, style: TextStyle(fontSize: 11, color: scheme.outline, fontWeight: FontWeight.bold)),
                            if (m.imageUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    ApiConfig.imageUrl(m.imageUrl!) ?? m.imageUrl!,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
                                  ),
                                ),
                              ),
                            Text(m.body),
                            Text(timeLabel(m.at), style: TextStyle(fontSize: 10, color: scheme.outline)),
                          ],
                        ),
                      ),
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
                ),
                Expanded(
                  child: TextField(
                    controller: _input,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(hintText: 'Escribe un mensaje'),
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
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await admin.responderReclamacion(rec['id'] as int, respuesta: ctrl.text.trim(), resuelto: resuelto);
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
            load: () => admin.reclamaciones(resuelto: _soloPendientes ? false : null),
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
                    resuelto ? Icons.check_circle_outline : Icons.report_problem_outlined,
                    color: resuelto ? Colors.green : Colors.orange,
                  ),
                  title: Text('${r['correlativo']}  ·  ${r['tipo']?.toString().toUpperCase() ?? ''}'),
                  subtitle: Text('${r['nombre']}  ·  ${r['correo']}\n${r['bien_contratado']}'),
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

// ---------------------------------------------------------------------------
// Grafico de barras minimo (sin dependencias)
// ---------------------------------------------------------------------------
class _BarChart extends StatelessWidget {
  const _BarChart({required this.values});

  final List<(String label, double value)> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final maxVal = values.map((v) => v.$2).reduce((a, b) => a > b ? a : b);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      values[i].$2.toInt().toString(),
                      style: const TextStyle(fontSize: 8),
                      maxLines: 1,
                    ),
                    Container(
                      height: maxVal > 0 ? (values[i].$2 / maxVal) * 80 : 2,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      values[i].$1,
                      style: TextStyle(fontSize: 7, color: scheme.outline),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
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
