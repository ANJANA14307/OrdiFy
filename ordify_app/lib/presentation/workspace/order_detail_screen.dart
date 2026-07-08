import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ordify_app/core/network/api_client.dart';

import 'ordify_workspace_widgets.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    this.orderId,
    this.order,
  });

  final String? orderId;
  final dynamic order;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic>? order;
  Map<String, dynamic>? customer;
  List<dynamic> items = [];
  List<dynamic> payments = [];
  List<dynamic> invoices = [];

  String? get resolvedOrderId {
    if (widget.orderId != null && widget.orderId!.isNotEmpty) {
      return widget.orderId;
    }

    if (widget.order is Map) {
      final oldOrder = Map<String, dynamic>.from(widget.order as Map);
      return oldOrder['id']?.toString();
    }

    return null;
  }

  @override
  void initState() {
    super.initState();

    if (widget.order is Map) {
      order = Map<String, dynamic>.from(widget.order as Map);
    }

    fetchOrderDetail();
  }

  Future<void> fetchOrderDetail() async {
    final id = resolvedOrderId;

    if (id == null || id.isEmpty) {
      setState(() {
        errorMessage = 'Order ID not found';
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await apiClient.get('/orders/$id');
      final data = Map<String, dynamic>.from(response.data as Map);

      setState(() {
        order = data['order'] == null
            ? order
            : Map<String, dynamic>.from(data['order'] as Map);

        customer = data['customer'] == null
            ? null
            : Map<String, dynamic>.from(data['customer'] as Map);

        items = data['items'] ?? [];
        payments = data['payments'] ?? [];
        invoices = data['invoices'] ?? [];
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  Future<void> updateOrderStatus(String status) async {
    final id = resolvedOrderId;

    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order ID not found')),
      );
      return;
    }

    try {
      await apiClient.patch(
        '/orders/$id/status',
        data: {'status': status},
      );

      await fetchOrderDetail();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order moved to $status')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  String paymentStatus() {
    if (payments.isEmpty) return 'unpaid';

    final hasPaid = payments.any((payment) {
      if (payment is! Map) return false;
      return payment['status'] == 'paid';
    });

    return hasPaid ? 'paid' : 'pending';
  }

  Color statusColor(String status) {
    if (status == 'new') return const Color(0xFF47A7FF);
    if (status == 'confirmed') return const Color(0xFFFFC857);
    if (status == 'packed') return const Color(0xFFB788FF);
    if (status == 'shipped') return const Color(0xFF50E3C2);
    if (status == 'delivered') return const Color(0xFF34F087);
    if (status == 'cancelled') return const Color(0xFFFF5E73);
    return const Color(0xFF9CA3AF);
  }

  Color paymentColor(String status) {
    if (status == 'paid') return const Color(0xFF34F087);
    if (status == 'pending') return const Color(0xFFFFC857);
    return const Color(0xFFFF5E73);
  }

  Future<void> openStatusSheet() async {
    final statuses = [
      'new',
      'confirmed',
      'packed',
      'shipped',
      'delivered',
      'cancelled',
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1510),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Move Order Stage',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              ...statuses.map((status) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor(status).withOpacity(0.18),
                    child: Icon(
                      Icons.circle,
                      color: statusColor(status),
                      size: 14,
                    ),
                  ),
                  title: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await updateOrderStatus(status);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentOrder = order;
    final currentCustomer = customer;
    final id = resolvedOrderId;
    final payStatus = paymentStatus();

    final orderNumber = currentOrder?['order_number']?.toString() ??
        currentOrder?['id']?.toString() ??
        'Order';

    final status = currentOrder?['status']?.toString() ?? 'new';
    final amount = currentOrder?['total_amount']?.toString() ?? '0';
    final source = currentOrder?['source']?.toString() ?? 'manual';

    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.25,
            colors: [
              Color(0xFF16C76A),
              Color(0xFF0A2418),
              Color(0xFF050807),
            ],
            stops: [0.0, 0.36, 1.0],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : currentOrder == null
                      ? const Center(
                          child: Text(
                            'Order not found',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: fetchOrderDetail,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () => context.pop(),
                                    icon: const Icon(
                                      Icons.arrow_back_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Order Detail',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 25,
                                        fontWeight: FontWeight.w900,
                                        shadows: [
                                          Shadow(
                                            color: Color(0xFFFFC8C8),
                                            blurRadius: 9,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: fetchOrderDetail,
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              OrdifyGlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      orderNumber,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        shadows: [
                                          Shadow(
                                            color: Color(0xFFFFC8C8),
                                            blurRadius: 9,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '₹$amount • $source',
                                      style: const TextStyle(
                                        color: Color(0xFFE8FFF2),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Row(
                                      children: [
                                        _Pill(
                                          text: status.toUpperCase(),
                                          color: statusColor(status),
                                        ),
                                        const SizedBox(width: 10),
                                        _Pill(
                                          text: payStatus.toUpperCase(),
                                          color: paymentColor(payStatus),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              OrdifyGlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Quick Actions',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _ActionButton(
                                            icon: Icons.payments_rounded,
                                            label: 'Payments',
                                            onTap: id == null
                                                ? null
                                                : () async {
                                                    await context.push(
                                                      '/orders/$id/payments',
                                                    );
                                                    await fetchOrderDetail();
                                                  },
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _ActionButton(
                                            icon: Icons.picture_as_pdf_rounded,
                                            label: 'Invoice',
                                            onTap: id == null
                                                ? null
                                                : () async {
                                                    await context.push(
                                                      '/orders/$id/invoice-share',
                                                    );
                                                    await fetchOrderDetail();
                                                  },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF34F087),
                                          side: BorderSide(
                                            color:
                                                Colors.white.withOpacity(0.22),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                        onPressed: openStatusSheet,
                                        icon: const Icon(
                                          Icons.swap_horiz_rounded,
                                        ),
                                        label: const Text(
                                          'Change Stage',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              OrdifyGlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Customer',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (currentCustomer == null)
                                      const Text(
                                        'No customer details',
                                        style: TextStyle(
                                          color: Color(0xFFE8FFF2),
                                        ),
                                      )
                                    else ...[
                                      Text(
                                        '${currentCustomer['display_name'] ?? currentCustomer['instagram_username'] ?? 'Customer'}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (currentCustomer['instagram_username'] !=
                                          null)
                                        Text(
                                          '@${currentCustomer['instagram_username']}',
                                          style: const TextStyle(
                                            color: Color(0xFFE8FFF2),
                                          ),
                                        ),
                                      if (currentCustomer['phone'] != null)
                                        Text(
                                          'Phone: ${currentCustomer['phone']}',
                                          style: const TextStyle(
                                            color: Color(0xFFE8FFF2),
                                          ),
                                        ),
                                      if (currentCustomer['email'] != null)
                                        Text(
                                          'Email: ${currentCustomer['email']}',
                                          style: const TextStyle(
                                            color: Color(0xFFE8FFF2),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              OrdifyGlassCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Items',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (items.isEmpty)
                                      const Text(
                                        'No items found',
                                        style: TextStyle(
                                          color: Color(0xFFE8FFF2),
                                        ),
                                      )
                                    else
                                      ...items.map((item) {
                                        final itemMap =
                                            Map<String, dynamic>.from(
                                          item as Map,
                                        );

                                        return Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.06),
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            border: Border.all(
                                              color:
                                                  Colors.white.withOpacity(0.15),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.inventory_2_rounded,
                                                color: Color(0xFF34F087),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  'Product: ${itemMap['product_id']}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                'x${itemMap['quantity']}',
                                                style: const TextStyle(
                                                  color: Color(0xFFE8FFF2),
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF34F087),
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      onPressed: onTap,
      child: Column(
        children: [
          Icon(icon),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.42)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}