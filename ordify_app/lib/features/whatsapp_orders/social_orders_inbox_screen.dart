import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'whatsapp_order_models.dart';
import 'whatsapp_orders_api.dart';

class SocialOrdersInboxScreen extends StatefulWidget {
  const SocialOrdersInboxScreen({super.key});

  @override
  State<SocialOrdersInboxScreen> createState() =>
      _SocialOrdersInboxScreenState();
}

class _SocialOrdersInboxScreenState extends State<SocialOrdersInboxScreen> {
  List<SocialOrder> _orders = [];
  WhatsAppConfig? _config;
  bool _isLoading = true;
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
      final config = await whatsappOrdersApi.getConfig();
      final orders = await whatsappOrdersApi.getOrders();
      if (!mounted) return;
      setState(() {
        _config = config;
        _orders = orders;
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF050807),
    appBar: AppBar(
      title: const Text('WhatsApp Orders'),
      backgroundColor: const Color(0xFF07120C),
      foregroundColor: Colors.white,
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ],
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? _InboxMessage(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load inbox',
            message: _error!,
            actionLabel: 'Retry',
            onAction: _load,
          )
        : _orders.isEmpty && _config?.status != 'connected'
        ? _InboxMessage(
            icon: Icons.link_off_rounded,
            title: 'WhatsApp is not connected',
            message:
                'Set up your business number and Cloud API phone number ID to start receiving orders.',
            actionLabel: 'Set up WhatsApp',
            onAction: () => context.push('/whatsapp-ordering'),
          )
        : _orders.isEmpty
        ? const _InboxMessage(
            icon: Icons.inbox_rounded,
            title: 'No WhatsApp orders yet',
            message:
                'Customer orders will appear here after the backend validates their product code and delivery details.',
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _orders.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final order = _orders[index];
                return _SocialOrderCard(
                  order: order,
                  onTap: () => context.push('/whatsapp-orders/${order.id}'),
                );
              },
            ),
          ),
  );
}

class _SocialOrderCard extends StatelessWidget {
  const _SocialOrderCard({required this.order, required this.onTap});
  final SocialOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF101A14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.customerName.isEmpty
                        ? order.customerPhone
                        : order.customerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _StatusPill(label: _statusLabel(order.status), color: color),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              order.customerPhone,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                _OrderTag(label: order.productCode),
                const SizedBox(width: 8),
                _OrderTag(label: 'Qty ${order.quantity}'),
                const Spacer(),
                Text(
                  '₹${order.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF34F087),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (!order.validation.isValid &&
                order.validation.errors.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                order.validation.errors.first,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFFF9AA6), fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderTag extends StatelessWidget {
  const _OrderTag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
    ),
  );
}

class _InboxMessage extends StatelessWidget {
  const _InboxMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 50, color: const Color(0xFF34F087)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, height: 1.45),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.settings_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

Color _statusColor(String status) {
  switch (status) {
    case 'confirmed':
      return const Color(0xFF34F087);
    case 'awaiting_customer_confirmation':
    case 'confirmation_processing':
      return const Color(0xFFFFC857);
    case 'out_of_stock':
    case 'failed_validation':
    case 'confirmation_failed':
      return const Color(0xFFFF687A);
    case 'rejected':
      return const Color(0xFFB788FF);
    default:
      return const Color(0xFF9DF6FF);
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'awaiting_customer_confirmation':
      return 'Awaiting customer confirmation';
    case 'confirmation_processing':
      return 'Processing confirmation';
    case 'confirmation_failed':
      return 'Confirmation message failed';
    case 'failed_validation':
      return 'Failed validation';
    case 'out_of_stock':
      return 'Out of stock';
    case 'confirmed':
      return 'Confirmed';
    case 'edit_requested':
      return 'Edit requested';
    case 'rejected':
      return 'Rejected';
    default:
      return status.replaceAll('_', ' ');
  }
}
