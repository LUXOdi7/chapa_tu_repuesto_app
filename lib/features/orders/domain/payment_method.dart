import 'package:flutter/material.dart';

/// Metodos que acepta `/orders/checkout` y `/orders/{id}/payment`.
/// El `key` es el valor exacto que espera el backend.
enum PaymentMethod {
  card('card', 'Tarjeta de crédito / débito', Icons.credit_card,
      'Visa, Mastercard, Amex.'),
  yape('yape', 'Yape', Icons.qr_code_2,
      'Escanea el QR de la tienda desde tu app.'),
  transfer('transfer', 'Transferencia bancaria', Icons.account_balance,
      'Ingresa el número de operación después de transferir.');

  const PaymentMethod(this.key, this.label, this.icon, this.hint);

  final String key;
  final String label;
  final IconData icon;
  final String hint;

  static PaymentMethod parse(String? value) => PaymentMethod.values.firstWhere(
        (m) => m.key == value,
        orElse: () => PaymentMethod.card,
      );
}
