import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../catalog/presentation/store_page.dart';
import '../domain/order.dart';
import '../domain/payment_method.dart';
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

  /// Tarjeta en tienda con pasarela: `/payments/{id}/start` devuelve la URL
  /// del checkout (Mercado Pago o Niubiz); se abre en el navegador y el
  /// backend aprueba el pedido cuando la pasarela confirma. Sin pasarela o con
  /// Yape/transferencia: pago manual con numero de operacion.
  Future<void> _pay(Order order) async {
    // El repositorio se toma ANTES del dialogo: despues del await el context
    // ya no es de fiar.
    final repo = AppScope.ordersOf(context);
    final controller = TextEditingController();
    var method = order.paymentMethod;

    if (order.storeHasGateway && method == PaymentMethod.card) {
      await _run(() async {
        final start = await repo.startPayment(order.id);
        final url = start.checkoutUrl;
        if (url == null) return; // ya quedo aprobado (simulado)
        if (!await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        )) {
          throw Exception('No se pudo abrir el checkout de ${start.provider}.');
        }
        if (mounted) {
          showInfo(
            context,
            'Cuando termines de pagar, vuelve y toca actualizar.',
          );
        }
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setLocal) => AlertDialog(
          title: Text('Pagar ${soles(order.total)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<PaymentMethod>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Método'),
                items: [
                  for (final m in PaymentMethod.values)
                    // Con pasarela real, "tarjeta" pasa por el checkout externo
                    if (m != PaymentMethod.card || !order.storeHasGateway)
                      DropdownMenuItem(value: m, child: Text(m.label)),
                ],
                onChanged: (m) => setLocal(() => method = m ?? method),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'N° de operación (opcional)',
                  helperText: 'Si lo dejas vacío se genera uno simulado',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar pago'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final number = controller.text.trim();
    await _run(
      () => repo.pay(
        order.id,
        method: method,
        operationNumber: number.isEmpty ? null : number,
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

    final buttons = <Widget>[];
    for (final status in order.nextStatus) {
      // El paso a payment_verified no es un cambio de estado suelto: pasa por
      // /orders/{id}/payment, que registra el numero de operacion.
      if (status == 'payment_verified') {
        buttons.add(
          FilledButton.icon(
            onPressed: busy ? null : onPay,
            icon: const Icon(Icons.payments_outlined),
            label: Text('Pagar ${soles(order.total)}'),
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
