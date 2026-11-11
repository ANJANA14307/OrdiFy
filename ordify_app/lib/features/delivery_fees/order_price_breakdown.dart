import 'package:flutter/material.dart';

class OrderPriceBreakdown extends StatelessWidget {
  final double subtotal;
  final double deliveryFee;
  final double tax;
  final double discount;
  final double total;

  const OrderPriceBreakdown({
    super.key,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.discount,
    required this.total,
  });

  factory OrderPriceBreakdown.fromOrder(Map<String, dynamic> order) {
    double amount(String key) {
      final value = order[key];
      return value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    }

    return OrderPriceBreakdown(
      subtotal: amount('subtotal'),
      deliveryFee: amount('delivery_fee'),
      tax: amount('tax_amount'),
      discount: amount('discount_amount'),
      total: amount('total_amount'),
    );
  }

  String _currency(double value) => '₹${value.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101A16).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          _PriceRow(label: 'Subtotal', value: _currency(subtotal)),
          const SizedBox(height: 10),
          _PriceRow(
            label: 'Delivery Fee',
            value: deliveryFee == 0 ? 'FREE' : _currency(deliveryFee),
            valueColor: const Color(0xFF34F087),
          ),
          const SizedBox(height: 10),
          _PriceRow(label: 'Tax', value: _currency(tax)),
          const SizedBox(height: 10),
          _PriceRow(
            label: 'Discount',
            value: '-${_currency(discount)}',
            valueColor: const Color(0xFF34F087),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(color: Colors.white24, height: 1),
          ),
          _PriceRow(
            label: 'Total',
            value: _currency(total),
            isEmphasized: true,
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isEmphasized;

  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isEmphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: isEmphasized ? Colors.white : Colors.white70,
      fontSize: isEmphasized ? 16 : 13,
      fontWeight: isEmphasized ? FontWeight.w900 : FontWeight.w600,
    );
    return Row(
      children: [
        Text(label, style: style),
        const Spacer(),
        Text(
          value,
          style: style.copyWith(
            color: valueColor ?? style.color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
