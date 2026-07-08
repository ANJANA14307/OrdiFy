import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ordify_app/core/network/api_client.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<dynamic> orders = [];
  List<dynamic> customers = [];
  List<dynamic> products = [];

  String selectedStatus = 'all';
  String? updatingOrderId;

  final List<String> statuses = const [
    'all',
    'new',
    'confirmed',
    'packed',
    'shipped',
    'delivered',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await apiClient.get('/orders');

      setState(() {
        orders = response.data['orders'] ?? [];
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  List<dynamic> get filteredOrders {
    if (selectedStatus == 'all') return orders;

    return orders.where((order) {
      final orderMap = Map<String, dynamic>.from(order as Map);
      return orderMap['status']?.toString() == selectedStatus;
    }).toList();
  }

  int countForStatus(String status) {
    if (status == 'all') return orders.length;

    return orders.where((order) {
      final orderMap = Map<String, dynamic>.from(order as Map);
      return orderMap['status']?.toString() == status;
    }).length;
  }

  int get activeCount {
    return countForStatus('new') +
        countForStatus('confirmed') +
        countForStatus('packed') +
        countForStatus('shipped');
  }

  Future<void> fetchCreateOrderData() async {
    final customersResponse = await apiClient.get('/customers');
    final productsResponse = await apiClient.get('/products');

    customers = customersResponse.data['customers'] ?? [];
    products = productsResponse.data['products'] ?? [];
  }

  Future<void> openCreateOrderSheet() async {
    try {
      await fetchCreateOrderData();

      if (!mounted) return;

      final created = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF0B1510),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        builder: (_) {
          return CreateOrderSheet(
            customers: customers,
            products: products,
          );
        },
      );

      if (created == true) {
        await fetchOrders();
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  void openOrderDetail(dynamic order) {
    final orderMap = Map<String, dynamic>.from(order as Map);
    final orderId = orderMap['id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order ID not found')),
      );
      return;
    }

    context.push('/orders/$orderId');
  }

  String? nextStatus(String status) {
    switch (status) {
      case 'new':
        return 'confirmed';
      case 'confirmed':
        return 'packed';
      case 'packed':
        return 'shipped';
      case 'shipped':
        return 'delivered';
      default:
        return null;
    }
  }

  String nextActionLabel(String status) {
    switch (status) {
      case 'new':
        return 'Confirm';
      case 'confirmed':
        return 'Pack';
      case 'packed':
        return 'Ship';
      case 'shipped':
        return 'Deliver';
      default:
        return '';
    }
  }

  Future<void> moveOrderToNextStatus(Map<String, dynamic> order) async {
    final orderId = order['id']?.toString();
    final currentStatus = order['status']?.toString() ?? 'new';
    final next = nextStatus(currentStatus);

    if (orderId == null || orderId.isEmpty || next == null) return;

    setState(() {
      updatingOrderId = orderId;
    });

    try {
      await apiClient.patch(
        '/orders/$orderId/status',
        data: {'status': next},
      );

      await fetchOrders();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order moved to $next')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          updatingOrderId = null;
        });
      }
    }
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

  String formatStatus(String status) {
    if (status == 'all') return 'All';
    return status[0].toUpperCase() + status.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final visibleOrders = filteredOrders;

    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF34F087),
        foregroundColor: Colors.black,
        elevation: 14,
        onPressed: openCreateOrderSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Order',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.2,
            colors: [
              Color(0xFF0FCB63),
              Color(0xFF0B2418),
              Color(0xFF050807),
            ],
            stops: [0.0, 0.38, 1.0],
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
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchOrders,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                        children: [
                          _Header(
                            onRefresh: fetchOrders,
                            onNotifications: () =>
                                context.push('/notifications'),
                            onActivity: () => context.push('/activity'),
                          ),
                          const SizedBox(height: 22),
                          _CommandCard(
                            total: orders.length,
                            active: activeCount,
                            delivered: countForStatus('delivered'),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Order Pipeline',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFFFD6D6),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 46,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: statuses.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final status = statuses[index];
                                final isSelected = selectedStatus == status;

                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedStatus = status;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF34F087)
                                          : Colors.white.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF34F087)
                                            : Colors.white.withOpacity(0.22),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${formatStatus(status)} ${countForStatus(status)}',
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.black
                                              : Colors.white,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (visibleOrders.isEmpty)
                            const _EmptyOrders()
                          else
                            ...visibleOrders.map((order) {
                              final orderMap =
                                  Map<String, dynamic>.from(order as Map);

                              final status =
                                  orderMap['status']?.toString() ?? 'new';

                              return _OrderCard(
                                order: orderMap,
                                statusColor: statusColor(status),
                                nextActionLabel: nextActionLabel(status),
                                hasNextAction: nextStatus(status) != null,
                                isUpdating: updatingOrderId ==
                                    orderMap['id']?.toString(),
                                onTap: () => openOrderDetail(orderMap),
                                onNextAction: () =>
                                    moveOrderToNextStatus(orderMap),
                              );
                            }),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onRefresh,
    required this.onNotifications,
    required this.onActivity,
  });

  final VoidCallback onRefresh;
  final VoidCallback onNotifications;
  final VoidCallback onActivity;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            color: const Color(0xFF34F087),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF34F087).withOpacity(0.45),
                blurRadius: 24,
              ),
            ],
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: Colors.black,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage flow',
                style: TextStyle(
                  color: Color(0xFFE8FFF2),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Orders Hub',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(
                      color: Color(0xFFFFC8C8),
                      blurRadius: 9,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onNotifications,
          icon: const Icon(Icons.notifications_rounded),
          color: Colors.white,
        ),
        IconButton(
          onPressed: onActivity,
          icon: const Icon(Icons.history_rounded),
          color: Colors.white,
        ),
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          color: Colors.white,
        ),
      ],
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({
    required this.total,
    required this.active,
    required this.delivered,
  });

  final int total;
  final int active;
  final int delivered;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Command Center',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Color(0xFFFFD6D6),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track customer orders, payments, packing, delivery and invoices.',
            style: TextStyle(
              color: Color(0xFFE8FFF2),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.receipt_long_rounded,
                  value: total.toString(),
                  label: 'Orders',
                  iconColor: Color(0xFF34F087),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.bolt_rounded,
                  value: active.toString(),
                  label: 'Active',
                  iconColor: Color(0xFFFFC857),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  icon: Icons.check_circle_rounded,
                  value: delivered.toString(),
                  label: 'Done',
                  iconColor: Color(0xFF9DF6FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 25),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(color: Color(0xFFFFD6D6), blurRadius: 8),
              ],
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.statusColor,
    required this.nextActionLabel,
    required this.hasNextAction,
    required this.isUpdating,
    required this.onTap,
    required this.onNextAction,
  });

  final Map<String, dynamic> order;
  final Color statusColor;
  final String nextActionLabel;
  final bool hasNextAction;
  final bool isUpdating;
  final VoidCallback onTap;
  final VoidCallback onNextAction;

  @override
  Widget build(BuildContext context) {
    final orderNumber =
        order['order_number']?.toString() ?? order['id']?.toString() ?? 'Order';

    final amount = order['total_amount']?.toString() ?? '0';
    final source = order['source']?.toString() ?? 'manual';
    final status = order['status']?.toString() ?? 'new';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: _GlassCard(
        padding: const EdgeInsets.all(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    height: 54,
                    width: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34F087).withOpacity(0.22),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: statusColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          orderNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            shadows: [
                              Shadow(
                                color: Color(0xFFFFC8C8),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹$amount • $source',
                          style: const TextStyle(
                            color: Color(0xFFE8FFF2),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusColor.withOpacity(0.35)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasNextAction) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF34F087),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: isUpdating ? null : onNextAction,
                    child: isUpdating
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            nextActionLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1A2D24).withOpacity(0.78),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        children: const [
          Icon(
            Icons.receipt_long_outlined,
            size: 58,
            color: Color(0xFF34F087),
          ),
          SizedBox(height: 16),
          Text(
            'No orders here',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create orders and move them through your productive pipeline.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFE8FFF2),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class CreateOrderSheet extends StatefulWidget {
  const CreateOrderSheet({
    super.key,
    required this.customers,
    required this.products,
  });

  final List<dynamic> customers;
  final List<dynamic> products;

  @override
  State<CreateOrderSheet> createState() => _CreateOrderSheetState();
}

class _CreateOrderSheetState extends State<CreateOrderSheet> {
  bool isSubmitting = false;

  String? selectedCustomerId;
  String? selectedProductId;

  final quantityController = TextEditingController(text: '1');
  final notesController = TextEditingController();
  final variantController = TextEditingController();

  String source = 'manual';

  List<Map<String, dynamic>> get customerMaps {
    return widget.customers
        .map((customer) => Map<String, dynamic>.from(customer as Map))
        .toList();
  }

  List<Map<String, dynamic>> get productMaps {
    return widget.products
        .map((product) => Map<String, dynamic>.from(product as Map))
        .toList();
  }

  Map<String, dynamic>? get selectedCustomer {
    for (final customer in customerMaps) {
      if (customer['id']?.toString() == selectedCustomerId) {
        return customer;
      }
    }
    return null;
  }

  Map<String, dynamic>? get selectedProduct {
    for (final product in productMaps) {
      if (product['id']?.toString() == selectedProductId) {
        return product;
      }
    }
    return null;
  }

  Future<void> createOrder() async {
    final customer = selectedCustomer;
    final product = selectedProduct;

    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a customer')),
      );
      return;
    }

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a product')),
      );
      return;
    }

    final quantity = int.tryParse(quantityController.text.trim()) ?? 1;
    final price = double.tryParse('${product['price']}') ?? 0;

    setState(() => isSubmitting = true);

    try {
      await apiClient.post(
        '/orders',
        data: {
          'customer_id': customer['id'],
          'source': source,
          'notes': notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
          'custom_variant': variantController.text.trim().isEmpty
              ? null
              : variantController.text.trim(),
          'items': [
            {
              'product_id': product['id'],
              'quantity': quantity,
              'unit_price': price,
              'variant_notes': variantController.text.trim().isEmpty
                  ? null
                  : variantController.text.trim(),
            }
          ],
        },
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = customerMaps;
    final products = productMaps;

    return Padding(
      padding: EdgeInsets.only(
        left: 18,
        right: 18,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.28),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Create Order',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Color(0xFFFFC8C8),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: selectedCustomerId,
              dropdownColor: const Color(0xFF0B1510),
              decoration: const InputDecoration(
                labelText: 'Customer',
                border: OutlineInputBorder(),
              ),
              items: customers.map((customer) {
                final id = customer['id']?.toString();
                final name = customer['display_name']?.toString() ??
                    customer['instagram_username']?.toString() ??
                    customer['email']?.toString() ??
                    'Customer';

                return DropdownMenuItem<String>(
                  value: id,
                  child: Text(name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCustomerId = value;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedProductId,
              dropdownColor: const Color(0xFF0B1510),
              decoration: const InputDecoration(
                labelText: 'Product',
                border: OutlineInputBorder(),
              ),
              items: products.map((product) {
                final id = product['id']?.toString();
                final name = product['name']?.toString() ?? 'Product';
                final price = product['price']?.toString() ?? '0';
                final stock = product['stock_count']?.toString() ?? '0';

                return DropdownMenuItem<String>(
                  value: id,
                  child: Text('$name • ₹$price • Stock $stock'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedProductId = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: source,
              dropdownColor: const Color(0xFF0B1510),
              decoration: const InputDecoration(
                labelText: 'Order Source',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'manual', child: Text('Manual')),
                DropdownMenuItem(value: 'dm', child: Text('Instagram DM')),
                DropdownMenuItem(
                  value: 'comment',
                  child: Text('Instagram Comment'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  source = value ?? 'manual';
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: variantController,
              decoration: const InputDecoration(
                labelText: 'Variant / Size / Color',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF34F087),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: isSubmitting ? null : createOrder,
                child: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Create Order',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}