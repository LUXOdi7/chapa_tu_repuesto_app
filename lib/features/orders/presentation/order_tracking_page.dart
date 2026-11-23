import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../catalog/presentation/store_page.dart';
import '../data/order_repository.dart';
import '../domain/order.dart';
import 'chat_page.dart';
import 'receipt_page.dart';

/// Seguimiento del pedido.
///
/// Los botones de accion se construyen con `next_status`, que el backend
/// calcula segun el estado y el perfil de quien pregunta: la app no repite la
/// maquina de estados ni decide quien puede hacer que.
class OrderTrackingPage extends StatefulWidget {
  const OrderTrackingPage({super.key, required this.orderId});

  static const route = '/tracking';

  final int orderId;

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  int _reload = 0;
  bool _busy = false;

  void _refresh() => setState(() => _reload++);

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Muestra el QR de Yape del admin + codigo de pedido + telefono.
  /// El comprador paga en Yape y luego sube la captura al chat.
  Future<void> _pay(Order order) async {
    final repo = AppScope.ordersOf(context);

    // Cargar datos de Yape (QR + telefono)
    YapeInfo? yape;
    try {
      yape = await repo.yapeInfo();
    } catch (_) {}

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Pagar ${soles(order.total)}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // QR image
              if (yape?.qrImage != null && yape!.qrImage!.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Image.network(
                    yape.qrImage!,
                    height: 220,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.qr_code_2,
                      size: 120,
                      color: Colors.grey,
                    ),
                  ),
                )
              else
                const Icon(Icons.qr_code_2, size: 120, color: Colors.grey),
              const SizedBox(height: 12),
              // Phone number
              if (yape != null && yape.phone.isNotEmpty) ...[
                const Text(
                  'O paga al numero:',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: yape!.phone));
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Numero copiado')),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        yape.phone,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.copy, size: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Order code for reference
              Builder(builder: (ctx) {
                final scheme = Theme.of(ctx).colorScheme;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.outline.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Pon este codigo como referencia en Yape:',
                        style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: order.code));
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(content: Text('Codigo copiado')),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              order.code,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.copy, size: 18, color: scheme.onSecondaryContainer),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 14),
              Text(
                'Monto: ${soles(order.total)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Despues de pagar, envia la captura de pantalla '
                'en el chat con el administrador para que verifique tu pago.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Abrir el chat con el admin para enviar la captura
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ChatPage(
                    order: order,
                    initialChannel: 'admin',
                  ),
                ),
              ).then((_) {
                if (mounted) _refresh();
              });
            },
            icon: const Icon(Icons.chat),
            label: const Text('Ir al chat'),
          ),
        ],
      ),
    );
  }

  Future<void> _review(Order order) async {
    final repo = AppScope.ordersOf(context);
    final comment = TextEditingController();
    var rating = 5;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Text('Califica a ${order.store.businessName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setLocal(() => rating = i),
                      icon: Icon(
                        i <= rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                    ),
                ],
              ),
              TextField(
                controller: comment,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Comentario (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    await _run(
      () => repo.review(
        order.id,
        rating: rating,
        comment: comment.text.trim().isEmpty ? null : comment.text.trim(),
      ),
    );
  }

  /// Abre el PDF en el navegador/visor (Android y web) con un enlace firmado.
  Future<void> _downloadPdf(Order order) async {
    final repo = AppScope.ordersOf(context);
    await _run(() async {
      final url = await repo.receiptPdfUrl(order.id);
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        throw Exception('No se pudo abrir el PDF.');
      }
    });
  }

  /// La tienda califica al comprador (puntualidad de pago / recepcion).
  Future<void> _reviewBuyer(Order order) async {
    final repo = AppScope.ordersOf(context);
    final comment = TextEditingController();
    var rating = 5;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Text('Califica a ${order.buyerName ?? 'el comprador'}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¿Pagó puntual y recibió sin problemas?'),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      onPressed: () => setLocal(() => rating = i),
                      icon: Icon(
                        i <= rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                    ),
                ],
              ),
              TextField(
                controller: comment,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Comentario (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => repo.reviewBuyer(
        order.id,
        rating: rating,
        comment: comment.text.trim().isEmpty ? null : comment.text.trim(),
      ),
    );
  }

  Future<void> _changeStatus(Order order, String status) async {
    final repo = AppScope.ordersOf(context);
    if (status == 'cancelled') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Cancelar el pedido?'),
          content: const Text(
            'Se devuelve el stock a la tienda. Esta acción no se deshace.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sí, cancelar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _run(() => repo.setStatus(order.id, status));
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: AsyncView<Order>(
        refreshKey: _reload,
        load: () => scope.orders.byId(widget.orderId),
        builder: (context, order) => Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _OrderHeader(order: order),
                  _Timeline(order: order),
                  if (order.status == 'payment_rejected')
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.red),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tu pago fue rechazado. Revisa el chat con el admin para ver el motivo y sube una nueva captura.',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (order.items.isNotEmpty) ...[
                    const SectionTitle('Productos'),
                    for (final item in order.items)
                      ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        title: Text(
                          item.productName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(item.brandAndCode),
                        trailing: Text(soles(item.subtotal)),
                      ),
                  ],
                  const SectionTitle('Detalle'),
                  _Fact(label: 'Subtotal', value: soles(order.subtotal)),
                  _Fact(label: 'Envío', value: soles(order.shippingCost)),
                  _Fact(label: 'Total', value: soles(order.total), bold: true),
                  _Fact(label: 'Pago', value: order.paymentMethod.label),
                  if (order.paymentOpNumber != null)
                    _Fact(label: 'N° operación', value: order.paymentOpNumber!),
                  if (order.paidAt != null)
                    _Fact(label: 'Pagado', value: dateTimeLabel(order.paidAt!)),
                  if (order.platformFee > 0)
                    _Fact(
                      label: 'Comisión (${(order.platformFeeRate * 100).toStringAsFixed(0)}%)',
                      value: soles(order.platformFee),
                    ),
                  if (order.deliveryAddress != null)
                    _Fact(
                      label: 'Entrega',
                      value:
                          order.deliveryAddress! +
                          (order.hasDeliveryPoint ? '  ·  📍 en el mapa' : ''),
                    ),
                  if (order.notes != null && order.notes!.isNotEmpty)
                    _Fact(label: 'Nota', value: order.notes!),
                  _Fact(label: 'Tienda', value: order.store.businessName),
                  if (order.store.phone != null)
                    _Fact(label: 'Teléfono', value: order.store.phone!),
                  if (order.buyerName != null)
                    _Fact(
                      label: 'Comprador',
                      value:
                          '${order.buyerName!}  ·  ${order.buyerRatingLabel}',
                    ),
                  if (order.buyerPhone != null)
                    _Fact(label: 'Tel. comprador', value: order.buyerPhone!),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        // OutlinedButton: el tema da ancho infinito a FilledButton y
                        // dentro de un Wrap eso revienta el layout.
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => ChatPage(order: order),
                              ),
                            );
                            if (mounted) _refresh();
                          },
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: Text(
                            order.messageCount == 0
                                ? 'Consultar'
                                : 'Mensajes (${order.messageCount})',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(
                            context,
                            StorePage.route,
                            arguments: order.store.id,
                          ),
                          icon: const Icon(Icons.storefront_outlined),
                          label: const Text('Ver tienda'),
                        ),
                        if (order.canReviewBuyer)
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _reviewBuyer(order),
                            icon: const Icon(Icons.star_outline),
                            label: const Text('Calificar comprador'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => openDirections(context, order.store),
                          icon: const Icon(Icons.directions),
                          label: const Text('Cómo llegar'),
                        ),
                        if (order.isPaid) ...[
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              ReceiptPage.route,
                              arguments: order.id,
                            ),
                            icon: const Icon(Icons.description_outlined),
                            label: const Text('Ver constancia'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _downloadPdf(order),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Descargar PDF'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            _Actions(
              order: order,
              busy: _busy,
              onPay: () => _pay(order),
              onReview: () => _review(order),
              onStatus: (s) => _changeStatus(order, s),
            ),
          ],
        ),
      ),
    );
  }
}

/// Botonera construida a partir de `next_status`: si viene vacio, no hay nada
/// que hacer y no se muestra nada.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.order,
    required this.busy,
    required this.onPay,
    required this.onReview,
    required this.onStatus,
  });

  final Order order;
  final bool busy;
  final VoidCallback onPay;
  final VoidCallback onReview;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    if (order.nextStatus.isEmpty) return const SizedBox.shrink();

    final isAdmin = AppScope.sessionOf(context).user?.isAdmin ?? false;

    final buttons = <Widget>[];
    for (final status in order.nextStatus) {
      if (status == 'payment_verified' && !isAdmin) {
        // Comprador/proveedor: mostrar QR de Yape para pagar.
        buttons.add(
          FilledButton.icon(
            onPressed: busy ? null : onPay,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.payments_outlined),
            label: Text('Pagar ${soles(order.total)}'),
          ),
        );
      } else if (status == 'payment_verified' && isAdmin) {
        // Admin: verificar/aprobar el pago (no paga, solo confirma).
        buttons.add(
          FilledButton.icon(
            onPressed: busy ? null : () => onStatus(status),
            icon: const Icon(Icons.verified_outlined),
            label: const Text('Verificar pago'),
          ),
        );
      } else if (status == 'payment_rejected') {
        buttons.add(
          FilledButton.icon(
            onPressed: busy ? null : () => onStatus(status),
            icon: const Icon(Icons.block),
            label: const Text('Rechazar pago'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        );
      } else if (status == 'closed') {
        buttons.add(
          FilledButton.icon(
            onPressed: busy ? null : onReview,
            icon: const Icon(Icons.star_outline),
            label: const Text('Calificar y cerrar'),
          ),
        );
      } else if (status == 'cancelled') {
        buttons.add(
          TextButton.icon(
            onPressed: busy ? null : () => onStatus(status),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancelar pedido'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        );
      } else {
        buttons.add(
          FilledButton.icon(
            onPressed: busy ? null : () => onStatus(status),
            icon: Icon(orderStatusIcon(status)),
            label: Text(orderActionLabel(status)),
          ),
        );
      }
    }

    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              for (final button in buttons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SizedBox(width: double.infinity, child: button),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    if (order.isCancelled) {
      return ListTile(
        leading: const Icon(Icons.cancel, color: Colors.red, size: 32),
        title: const Text('Pedido cancelado'),
        subtitle: const Text('El stock volvió a la tienda.'),
      );
    }

    final current = orderTimeline.indexOf(order.status);
    DateTime? when(String status) {
      for (final e in order.events) {
        if (e.status == status) return e.at;
      }
      return null;
    }

    return Stepper(
      currentStep: current < 0 ? 0 : current,
      physics: const NeverScrollableScrollPhysics(),
      controlsBuilder: (_, _) => const SizedBox.shrink(),
      steps: [
        for (var i = 0; i < orderTimeline.length; i++)
          Step(
            title: Text(
              i == current
                  ? order.statusLabel
                  : orderStatusLabel(orderTimeline[i]),
            ),
            subtitle: when(orderTimeline[i]) != null
                ? Text(dateTimeLabel(when(orderTimeline[i])!))
                : (i == current ? const Text('Estado actual') : null),
            content: const SizedBox.shrink(),
            isActive: i <= current,
            state: switch (i - current) {
              < 0 => StepState.complete,
              0 => StepState.editing,
              _ => StepState.indexed,
            },
          ),
      ],
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // `primaryContainer`/`onPrimaryContainer` en vez de blanco fijo sobre
    // `primary`: en tema oscuro el primary es azul claro y el texto blanco
    // desaparece.
    final onHeader = scheme.onPrimaryContainer;

    return Container(
      width: double.infinity,
      color: scheme.primaryContainer,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(orderStatusIcon(order.status), color: onHeader),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.statusLabel,
                  style: TextStyle(
                    color: onHeader,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Text(
                order.code,
                style: TextStyle(
                  color: onHeader.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            order.store.businessName,
            style: TextStyle(
              color: onHeader.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateTimeLabel(order.createdAt),
                style: TextStyle(
                  color: onHeader.withValues(alpha: 0.75),
                  fontSize: 13,
                ),
              ),
              Text(
                soles(order.total),
                style: TextStyle(
                  color: onHeader,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
