import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'whatsapp_order_models.dart';
import 'whatsapp_orders_api.dart';

class SocialOrderDetailScreen extends StatefulWidget {
  const SocialOrderDetailScreen({required this.orderId, super.key});
  final String orderId;

  @override
  State<SocialOrderDetailScreen> createState() =>
      _SocialOrderDetailScreenState();
}

class _SocialOrderDetailScreenState extends State<SocialOrderDetailScreen> {
  SocialOrder? _order;
  bool _isLoading = true;
  bool _isWorking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final order = await whatsappOrdersApi.getOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _action(String action) async {
    final order = _order;
    if (order == null) return;
    if (action == 'confirm_manually') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm customer approval?'),
          content: const Text(
            'Only continue if you have verified with the customer that they agree to place this validated order. This will create an order in OrdiFy.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Customer agreed'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isWorking = true);
    try {
      await whatsappOrdersApi.actOnOrder(
        order.id,
        action: action,
        customerConfirmed: action == 'confirm_manually',
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (action) {
            'confirm_manually' => 'WhatsApp order confirmed',
            'reject' => 'Order rejected',
            _ => 'Customer asked to edit the order',
          }),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      await _load();
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _openChat() async {
    final phone = _order?.customerPhone.replaceAll(RegExp(r'\D'), '');
    if (phone == null || phone.isEmpty) return;
    final opened = await launchUrl(
      Uri.parse('https://wa.me/$phone'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      appBar: AppBar(
        title: const Text('WhatsApp Order'),
        backgroundColor: const Color(0xFF07120C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : order == null
          ? _DetailError(message: _error ?? 'Order not found', onRetry: _load)
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _DetailPanel(
                  title: 'Order status',
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _statusLabel(order.status),
                          style: TextStyle(
                            color: _statusColor(order.status),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _openChat,
                        tooltip: 'Open chat in WhatsApp',
                        icon: const Icon(
                          Icons.chat_rounded,
                          color: Color(0xFF34F087),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DetailPanel(
                  title: 'Customer and parsed order',
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Customer',
                        value: order.customerName.isEmpty
                            ? '—'
                            : order.customerName,
                      ),
                      _DetailRow(label: 'WhatsApp', value: order.customerPhone),
                      _DetailRow(
                        label: 'Product code',
                        value: order.productCode,
                      ),
                      _DetailRow(label: 'Quantity', value: '${order.quantity}'),
                      _DetailRow(label: 'PIN', value: order.pincode ?? '—'),
                      _DetailRow(
                        label: 'Address',
                        value: order.address ?? '—',
                        multiline: true,
                      ),
                      _DetailRow(
                        label: 'Payment',
                        value: order.paymentMethod ?? '—',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DetailPanel(
                  title: 'Backend validation',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            order.validation.isValid
                                ? Icons.verified_rounded
                                : Icons.error_rounded,
                            color: order.validation.isValid
                                ? const Color(0xFF34F087)
                                : const Color(0xFFFF687A),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            order.validation.isValid
                                ? 'Product, price, stock and delivery validated'
                                : 'Validation failed',
                            style: TextStyle(
                              color: order.validation.isValid
                                  ? const Color(0xFF34F087)
                                  : const Color(0xFFFF9AA6),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      if (order.validation.productName != null)
                        _DetailRow(
                          label: 'Product',
                          value: order.validation.productName!,
                        ),
                      if (order.validation.availableStock != null)
                        _DetailRow(
                          label: 'Available stock',
                          value: '${order.validation.availableStock}',
                        ),
                      if (order.validation.deliveryDays != null)
                        _DetailRow(
                          label: 'Est. delivery',
                          value: '${order.validation.deliveryDays} days',
                        ),
                      for (final error in order.validation.errors)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            error,
                            style: const TextStyle(
                              color: Color(0xFFFF9AA6),
                              height: 1.35,
                            ),
                          ),
                        ),
                      if (order.validation.messageError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            order.validation.messageError!,
                            style: const TextStyle(color: Color(0xFFFF9AA6)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DetailPanel(
                  title: 'Saved price breakdown',
                  child: Column(
                    children: [
                      _MoneyRow(label: 'Subtotal', amount: order.subtotal),
                      _MoneyRow(
                        label: 'Delivery fee',
                        amount: order.deliveryFee,
                      ),
                      _MoneyRow(label: 'Tax', amount: order.tax),
                      _MoneyRow(label: 'Discount', amount: -order.discount),
                      const Divider(color: Colors.white24),
                      _MoneyRow(
                        label: 'Total',
                        amount: order.total,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DetailPanel(
                  title: 'Message timeline',
                  child: order.messages.isEmpty
                      ? const Text(
                          'No messages recorded.',
                          style: TextStyle(color: Colors.white60),
                        )
                      : Column(
                          children: order.messages.map((message) {
                            final isInbound = message['direction'] == 'inbound';
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isInbound
                                    ? Colors.white.withOpacity(0.06)
                                    : const Color(0xFF12321F),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isInbound ? 'CUSTOMER' : 'ORDIFY',
                                    style: TextStyle(
                                      color: isInbound
                                          ? Colors.white60
                                          : const Color(0xFF34F087),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    message['text']?.toString() ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _formatDate(message['at']?.toString()),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                if (_canManage(order)) ...[
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed:
                        _isWorking ||
                            !order.validation.isValid ||
                            order.status == 'confirmation_processing'
                        ? null
                        : () => _action('confirm_manually'),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Confirm manually'),
                  ),
                  const SizedBox(height: 9),
                  OutlinedButton.icon(
                    onPressed: _isWorking ? null : () => _action('ask_edit'),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Ask customer to edit'),
                  ),
                  const SizedBox(height: 9),
                  TextButton.icon(
                    onPressed: _isWorking ? null : () => _action('reject'),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject order'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFF8290),
                    ),
                  ),
                ],
                if (_isWorking) ...[
                  const SizedBox(height: 10),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
    );
  }
}

bool _canManage(SocialOrder order) =>
    order.status == 'awaiting_customer_confirmation' ||
    order.status == 'confirmation_failed' ||
    order.status == 'edit_requested' ||
    order.status == 'failed_validation' ||
    order.status == 'out_of_stock';

String _formatDate(String? value) {
  if (value == null) return '';
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  final local = date.toLocal();
  return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _statusLabel(String status) {
  switch (status) {
    case 'awaiting_customer_confirmation':
      return 'Awaiting customer confirmation';
    case 'confirmation_processing':
      return 'Processing customer confirmation';
    case 'confirmation_failed':
      return 'Confirmation message failed';
    case 'failed_validation':
      return 'Failed validation';
    case 'out_of_stock':
      return 'Out of stock';
    case 'confirmed':
      return 'Confirmed';
    case 'edit_requested':
      return 'Customer asked to edit';
    case 'rejected':
      return 'Rejected';
    default:
      return status.replaceAll('_', ' ');
  }
}

Color _statusColor(String status) {
  if (status == 'confirmed') return const Color(0xFF34F087);
  if (status == 'awaiting_customer_confirmation' ||
      status == 'confirmation_processing') {
    return const Color(0xFFFFC857);
  }
  if (status == 'out_of_stock' ||
      status == 'failed_validation' ||
      status == 'confirmation_failed') {
    return const Color(0xFFFF687A);
  }
  return const Color(0xFF9DF6FF);
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF101A14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.10)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.multiline = false,
  });
  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: multiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.amount,
    this.isTotal = false,
  });
  final String label;
  final double amount;
  final bool isTotal;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: isTotal ? Colors.white : Colors.white60,
              fontWeight: isTotal ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          '₹${amount.abs().toStringAsFixed(2)}${amount < 0 ? ' -' : ''}',
          style: TextStyle(
            color: isTotal ? const Color(0xFF34F087) : Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: isTotal ? 16 : 13,
          ),
        ),
      ],
    ),
  );
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
