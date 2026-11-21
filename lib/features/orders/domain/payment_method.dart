import 'package:flutter/material.dart';

/// Metodos que acepta `/orders/checkout` y `/orders/{id}/payment`.
/// El `key` es el valor exacto que espera el backend.
///
/// `card` se mantiene como valor legacy (ordenes antiguas); no se ofrece
/// en el checkout nuevo. Todo pago pasa por Yape QR al admin.
enum PaymentMethod {
  card(
    'card',
    'Tarjeta (legacy)',
    Icons.credit_card,
    'Ya no disponible.',
  ),
  yape(
    'yape',
    'Yape',
    Icons.qr_code_2,
    'Paga escaneando el QR o por numero de celular.',
  ),
  transfer(
    'transfer',
    'Transferencia bancaria',
    Icons.account_balance,
    'Ingresa el numero de operacion despues de transferir.',
  );

  const PaymentMethod(this.key, this.label, this.icon, this.hint);

  final String key;
  final String label;
  final IconData icon;
  final String hint;

  /// Metodos que se ofrecen al comprador en el checkout.
  static List<PaymentMethod> get available => [yape];

  static PaymentMethod parse(String? value) => PaymentMethod.values.firstWhere(
    (m) => m.key == value,
    orElse: () => PaymentMethod.yape,
  );
}
