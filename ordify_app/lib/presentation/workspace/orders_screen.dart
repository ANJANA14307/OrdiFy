import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _message;

  List<dynamic> _orders = [];

  static const List<_OrderColumnMeta> _columns = [
    _OrderColumnMeta(
      key: 'new',
      label: 'Order Came',
      helper: 'New customer orders waiting for you.',
      icon: Icons.notifications_active_rounded,
    ),
    _OrderColumnMeta(
      key: 'confirmed',
      label: 'Accepted',
      helper: 'You accepted the order. Start packing.',
      icon: Icons.thumb_up_alt_rounded,
    ),
    _OrderColumnMeta(
      key: 'packed',
      label: 'Packed',
      helper: 'Parcel is ready. Send it to customer.',
      icon: Icons.inventory_2_rounded,
    ),
    _OrderColumnMeta(
      key: 'shipped',
      label: 'On the Way',
      helper: 'Order is travelling to the customer.',
      icon: Icons.local_shipping_rounded,
    ),
    _OrderColumnMeta(
      key: 'delivered',
      label: 'Delivered',
      helper: 'Customer received the order.',
      icon: Icons.check_circle_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders({bool clearMessage = true}) async {
    setState(() {
      _isLoading = true;
      if (clearMessage) _message = null;
    });

    try {
      final response = await apiClient.get('/orders?page=1&limit=50');

      if (!mounted) return;

      setState(() {
        _orders = List<dynamic>.from(response.data['orders'] ?? []);
      });
    } catch (e) {
      debugPrint('ORDERS LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _message = 'Could not load orders';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openNewOrderSheet() async {
    setState(() {
      _isUpdating = true;
      _message = null;
    });

    List<dynamic> customers = [];
    List<dynamic> customerResults = [];
    List<dynamic> products = [];

    try {
      final customersResponse = await apiClient.get('/customers');
      final productsResponse = await apiClient.get('/products?page=1&limit=50');

      customers = List<dynamic>.from(customersResponse.data['customers'] ?? []);
      customerResults = customers;
      products = List<dynamic>.from(productsResponse.data['products'] ?? []);
    } catch (e) {
      debugPrint('LOAD NEW ORDER DATA ERROR: $e');

      if (!mounted) return;

      setState(() {
        _message = 'Could not load customers or products';
        _isUpdating = false;
      });

      return;
    }

    if (!mounted) return;

    setState(() {
      _isUpdating = false;
    });

    if (customers.isEmpty) {
      setState(() {
        _message = 'Add one customer first';
      });
      return;
    }

    final inStockProducts = products.where((product) {
      return _toInt(product['stock_count']) > 0;
    }).toList();

    if (inStockProducts.isEmpty) {
      setState(() {
        _message = 'Add stock to at least one product first';
      });
      return;
    }

    int currentStep = 0;
    bool isSearchingCustomers = false;
    String? sheetError;

    dynamic selectedCustomer = customerResults.first;
    String selectedSource = 'manual';

    final customerSearchController = TextEditingController();
    final notesController = TextEditingController();
    final variantController = TextEditingController();

    final orderItems = <_OrderFormItem>[
      _OrderFormItem(
        product: inStockProducts.first,
        quantityController: TextEditingController(text: '1'),
      ),
    ];

    void disposeFormControllers() {
      customerSearchController.dispose();
      notesController.dispose();
      variantController.dispose();

      for (final item in orderItems) {
        item.quantityController.dispose();
      }
    }

    Future<void> searchCustomers(
      String value,
      StateSetter setSheetState,
    ) async {
      setSheetState(() {
        isSearchingCustomers = true;
        sheetError = null;
      });

      try {
        final query = Uri.encodeQueryComponent(value.trim());
        final response = await apiClient.get('/customers?search=$query');

        customerResults =
            List<dynamic>.from(response.data['customers'] ?? []);

        if (customerResults.isNotEmpty) {
          final selectedId = selectedCustomer?['id']?.toString();

          final stillExists = customerResults.any((customer) {
            return customer['id']?.toString() == selectedId;
          });

          if (!stillExists) {
            selectedCustomer = customerResults.first;
          }
        } else {
          selectedCustomer = null;
        }
      } catch (e) {
        debugPrint('CUSTOMER SEARCH ERROR: $e');
        sheetError = 'Could not search customers';
      } finally {
        setSheetState(() {
          isSearchingCustomers = false;
        });
      }
    }

    bool canGoNext() {
      if (currentStep == 0) {
        if (selectedCustomer == null) {
          sheetError = 'Select one customer';
          return false;
        }
      }

      if (currentStep == 1) {
        final validationError = _validateOrderItems(orderItems);

        if (validationError != null) {
          sheetError = validationError;
          return false;
        }
      }

      sheetError = null;
      return true;
    }

    final shouldCreate = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget stepBody;

            if (currentStep == 0) {
              stepBody = _customerStep(
                customerSearchController: customerSearchController,
                customerResults: customerResults,
                selectedCustomer: selectedCustomer,
                isSearchingCustomers: isSearchingCustomers,
                onSearchChanged: (value) {
                  searchCustomers(value, setSheetState);
                },
                onSelectCustomer: (customer) {
                  setSheetState(() {
                    selectedCustomer = customer;
                    sheetError = null;
                  });
                },
              );
            } else if (currentStep == 1) {
              stepBody = _productsStep(
                orderItems: orderItems,
                products: products,
                inStockProducts: inStockProducts,
                setSheetState: setSheetState,
              );
            } else if (currentStep == 2) {
              stepBody = _notesStep(
                selectedSource: selectedSource,
                notesController: notesController,
                variantController: variantController,
                onSourceChanged: (value) {
                  setSheetState(() {
                    selectedSource = value;
                  });
                },
              );
            } else {
              stepBody = _confirmStep(
                customer: selectedCustomer,
                source: selectedSource,
                notes: notesController.text.trim(),
                customVariant: variantController.text.trim(),
                items: orderItems,
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.92,
                ),
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                decoration: const BoxDecoration(
                  color: Color(0xFF080808),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        height: 4,
                        width: 46,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Create New Order',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _stepIndicator(currentStep),
                    const SizedBox(height: 18),
                    if (sheetError != null) ...[
                      _sheetErrorBox(sheetError!),
                      const SizedBox(height: 14),
                    ],
                    Expanded(
                      child: SingleChildScrollView(
                        child: stepBody,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _multiOrderTotalPreview(items: orderItems),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              if (currentStep == 0) {
                                Navigator.pop(sheetContext, false);
                              } else {
                                setSheetState(() {
                                  currentStep -= 1;
                                  sheetError = null;
                                });
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.18),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: Text(
                              currentStep == 0 ? 'Close' : 'Back',
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (currentStep < 3) {
                                setSheetState(() {
                                  if (canGoNext()) {
                                    currentStep += 1;
                                  }
                                });
                                return;
                              }

                              setSheetState(() {
                                final validationError =
                                    _validateOrderItems(orderItems);

                                if (selectedCustomer == null) {
                                  sheetError = 'Select one customer';
                                  return;
                                }

                                if (validationError != null) {
                                  sheetError = validationError;
                                  return;
                                }

                                sheetError = null;
                              });

                              if (sheetError == null) {
                                Navigator.pop(sheetContext, true);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FFCC),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: Text(
                              currentStep == 3 ? 'Create Order' : 'Next',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (shouldCreate != true) {
      disposeFormControllers();
      return;
    }

    final validationError = _validateOrderItems(orderItems);

    if (selectedCustomer == null || validationError != null) {
      disposeFormControllers();

      setState(() {
        _message = validationError ?? 'Select one customer';
      });

      return;
    }

    final itemsPayload = _buildItemsPayload(orderItems);

    await _createOrderFromForm(
      customerId: selectedCustomer['id'].toString(),
      source: selectedSource,
      customVariant: variantController.text.trim(),
      notes: notesController.text.trim(),
      items: itemsPayload,
    );

    disposeFormControllers();
  }

  Future<void> _createOrderFromForm({
    required String customerId,
    required String source,
    required String customVariant,
    required String notes,
    required List<Map<String, dynamic>> items,
  }) async {
    setState(() {
      _isUpdating = true;
      _message = null;
    });

    try {
      await apiClient.post(
        '/orders',
        data: {
          'customer_id': customerId,
          'source': source,
          'notes': notes.isEmpty ? 'Order created from OrdiFy app' : notes,
          'custom_variant': customVariant.isEmpty ? null : customVariant,
          'items': items,
        },
      );

      if (!mounted) return;

      setState(() {
        _message = 'New order created successfully';
      });

      await _loadOrders(clearMessage: false);
    } catch (e) {
      debugPrint('CREATE ORDER ERROR: $e');

      if (!mounted) return;

      setState(() {
        _message = 'Could not create order';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isUpdating = false;
      });
    }
  }

  List<Map<String, dynamic>> _buildItemsPayload(List<_OrderFormItem> items) {
    return items.map((item) {
      return {
        'product_id': item.product['id']?.toString(),
        'quantity': item.quantity,
        'unit_price': null,
        'variant_notes': null,
      };
    }).toList();
  }

  String? _validateOrderItems(List<_OrderFormItem> items) {
    if (items.isEmpty) {
      return 'Add at least one product';
    }

    final quantityByProduct = <String, int>{};
    final stockByProduct = <String, int>{};
    final nameByProduct = <String, String>{};

    for (final item in items) {
      final productId = item.product['id']?.toString() ?? '';
      final productName = item.product['name']?.toString() ?? 'Product';
      final quantity = item.quantity;
      final stock = _toInt(item.product['stock_count']);

      if (productId.isEmpty) {
        return 'Product id missing';
      }

      if (stock <= 0) {
        return '$productName is out of stock';
      }

      if (quantity <= 0) {
        return 'Every product needs quantity at least 1';
      }

      quantityByProduct[productId] =
          (quantityByProduct[productId] ?? 0) + quantity;

      stockByProduct[productId] = stock;
      nameByProduct[productId] = productName;
    }

    for (final entry in quantityByProduct.entries) {
      final productId = entry.key;
      final wantedQuantity = entry.value;
      final availableStock = stockByProduct[productId] ?? 0;
      final productName = nameByProduct[productId] ?? 'Product';

      if (wantedQuantity > availableStock) {
        return 'Only $availableStock available for $productName';
      }
    }

    return null;
  }

  List<dynamic> _ordersForStatus(String status) {
    return _orders.where((order) {
      return order['status']?.toString() == status;
    }).toList();
  }

  int _countForStatus(String status) {
    return _ordersForStatus(status).length;
  }

  int get _activeOrderCount {
    return _orders.where((order) {
      final status = order['status']?.toString();
      return status != 'cancelled' && status != 'delivered';
    }).length;
  }

  int get _deliveredCount {
    return _orders.where((order) {
      return order['status']?.toString() == 'delivered';
    }).length;
  }

  double get _pipelineValue {
    double total = 0;

    for (final order in _orders) {
      final status = order['status']?.toString();

      if (status == 'cancelled') continue;

      total += _toDouble(order['total_amount']);
    }

    return total;
  }

  String _money(dynamic value) {
    final amount = _toDouble(value);

    if (amount == amount.roundToDouble()) {
      return '₹${amount.toStringAsFixed(0)}';
    }

    return '₹${amount.toStringAsFixed(2)}';
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'dm':
        return 'DM';
      case 'comment':
        return 'Comment';
      case 'manual':
        return 'Manual';
      default:
        return source;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'new':
        return 'Order Came';
      case 'confirmed':
        return 'Accepted';
      case 'packed':
        return 'Packed';
      case 'shipped':
        return 'On the Way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String? _nextStatus(String status) {
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

  String _actionLabel(String status) {
    switch (status) {
      case 'new':
        return 'Accept Order';
      case 'confirmed':
        return 'Packing Done';
      case 'packed':
        return 'Send Out';
      case 'shipped':
        return 'Mark Delivered';
      default:
        return 'Update Order';
    }
  }

  String _elapsedTime(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty) {
      return 'Just now';
    }

    final createdAt = DateTime.tryParse(raw);

    if (createdAt == null) {
      return 'Just now';
    }

    final diff = DateTime.now().difference(createdAt.toLocal());

    if (diff.inMinutes < 1) {
      return 'Just now';
    }

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }

    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }

    return '${diff.inDays}d ago';
  }

  Future<void> _updateStatus(dynamic order, String newStatus) async {
    final orderId = order['id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      setState(() {
        _message = 'Order id missing';
      });
      return;
    }

    setState(() {
      _isUpdating = true;
      _message = null;
    });

    try {
      await apiClient.patch(
        '/orders/$orderId/status',
        data: {
          'status': newStatus,
        },
      );

      if (!mounted) return;

      setState(() {
        _message = 'Order moved to ${_statusLabel(newStatus)}';
      });

      await _loadOrders(clearMessage: false);
    } catch (e) {
      debugPrint('ORDER STATUS UPDATE ERROR: $e');

      if (!mounted) return;

      setState(() {
        _message = 'Could not update order status';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _cancelOrder(dynamic order) async {
    final orderId = order['id']?.toString();

    if (orderId == null || orderId.isEmpty) {
      setState(() {
        _message = 'Order id missing';
      });
      return;
    }

    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101010),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Cancel Order?',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'This will cancel the order and restore stock if it was already accepted.',
            style: GoogleFonts.inter(
              color: Colors.white60,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Keep Order',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Cancel Order',
                style: GoogleFonts.inter(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldCancel != true) return;

    setState(() {
      _isUpdating = true;
      _message = null;
    });

    try {
      await apiClient.delete('/orders/$orderId');

      if (!mounted) return;

      setState(() {
        _message = 'Order cancelled successfully';
      });

      await _loadOrders(clearMessage: false);
    } catch (e) {
      debugPrint('ORDER CANCEL ERROR: $e');

      if (!mounted) return;

      setState(() {
        _message = 'Could not cancel order';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isUpdating = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'new':
        return const Color(0xFF00FFCC);
      case 'confirmed':
        return Colors.lightGreenAccent;
      case 'packed':
        return Colors.amberAccent;
      case 'shipped':
        return Colors.lightBlueAccent;
      case 'delivered':
        return Colors.greenAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }

  void _openOrderDetail(dynamic order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(order: order),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUpdating ? null : () => _openNewOrderSheet(),
        backgroundColor: const Color(0xFF00FFCC),
        foregroundColor: Colors.black,
        icon: _isUpdating
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : const Icon(Icons.add_rounded),
        label: Text(
          _isUpdating ? 'Working...' : 'New Order',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _topHeader(),
                  const SizedBox(height: 18),
                  _statsRow(),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    _messageBox(),
                  ],
                ],
              ),
            ),
            if (_isLoading && _orders.isEmpty)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF00FFCC),
                  ),
                ),
              )
            else
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 90),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _columns.map((column) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: SizedBox(
                              width: 310,
                              height: constraints.maxHeight,
                              child: _statusColumn(column),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Orders',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Create orders manually and track each order from received to delivered.',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _isLoading ? null : () => _loadOrders(),
          icon: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF00FFCC),
                  ),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFF00FFCC),
                ),
        ),
      ],
    );
  }

  Widget _statsRow() {
    return SizedBox(
      height: 86,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _statCard(
            title: 'Total Orders',
            value: _orders.length.toString(),
            icon: Icons.receipt_long_rounded,
          ),
          _statCard(
            title: 'Need Action',
            value: _activeOrderCount.toString(),
            icon: Icons.timelapse_rounded,
          ),
          _statCard(
            title: 'Delivered',
            value: _deliveredCount.toString(),
            icon: Icons.verified_rounded,
          ),
          _statCard(
            title: 'Order Money',
            value: _money(_pipelineValue),
            icon: Icons.currency_rupee_rounded,
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.09),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF00FFCC).withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF00FFCC),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBox() {
    final isSuccess =
        _message!.contains('successfully') || _message!.contains('moved');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSuccess
            ? const Color(0xFF00FFCC).withOpacity(0.08)
            : Colors.redAccent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuccess
              ? const Color(0xFF00FFCC).withOpacity(0.20)
              : Colors.redAccent.withOpacity(0.25),
        ),
      ),
      child: Text(
        _message!,
        style: GoogleFonts.inter(
          color: isSuccess ? const Color(0xFF00FFCC) : Colors.redAccent,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statusColumn(_OrderColumnMeta column) {
    final orders = _ordersForStatus(column.key);
    final color = _statusColor(column.key);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _columnHeader(column, color),
          const SizedBox(height: 14),
          Expanded(
            child: orders.isEmpty
                ? _emptyColumn(column.label)
                : ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      return _orderCard(orders[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _columnHeader(_OrderColumnMeta column, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              column.icon,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                column.label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _countForStatus(column.key).toString(),
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          column.helper,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _emptyColumn(String label) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_rounded,
              color: Colors.white.withOpacity(0.22),
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              'Nothing here now',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$label orders will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white30,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderCard(dynamic order) {
    final id = order['id']?.toString() ?? '';
    final shortId = id.length >= 8 ? id.substring(0, 8) : id;

    final status = order['status']?.toString() ?? 'new';
    final nextStatus = _nextStatus(status);
    final statusColor = _statusColor(status);

    final orderNumber = order['order_number']?.toString() ?? 'ORD-$shortId';

    final customer = order['customer'];
    final customerName = customer is Map
        ? customer['display_name']?.toString() ??
            customer['instagram_username']?.toString() ??
            'Customer'
        : 'Customer';

    final customerHandle =
        customer is Map ? customer['instagram_username']?.toString() ?? '' : '';

    final itemCount = (order['item_count'] as num?)?.toInt() ??
        ((order['items'] is List) ? (order['items'] as List).length : 0);

    final totalQuantity = (order['total_quantity'] as num?)?.toInt() ?? 0;

    final paymentStatus = order['payment_status']?.toString() ?? 'pending';

    final source = order['source']?.toString() ?? 'manual';

    final canCancel = status != 'delivered' && status != 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: statusColor.withOpacity(0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _openOrderDetail(order),
            borderRadius: BorderRadius.circular(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        orderNumber,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _chip(
                      text: _statusLabel(status),
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00FFCC).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF00FFCC),
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (customerHandle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              '@$customerHandle',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _orderedItemsSection(order),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniInfo(
                  title: 'Items',
                  value: '$itemCount item • $totalQuantity qty',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniInfo(
                  title: 'Total',
                  value: _money(order['total_amount']),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniInfo(
                  title: 'Payment',
                  value: paymentStatus,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniInfo(
                  title: 'Source',
                  value: _sourceLabel(source),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _miniInfo(
            title: 'Created',
            value: _elapsedTime(order['created_at']),
          ),
          const SizedBox(height: 14),
          if (nextStatus != null)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed:
                    _isUpdating ? null : () => _updateStatus(order, nextStatus),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFCC),
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  _actionLabel(status),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                'Order completed',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.greenAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton.icon(
              onPressed: () => _openOrderDetail(order),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                'View Details',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(
                  color: Colors.white.withOpacity(0.16),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
          if (canCancel) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: _isUpdating ? null : () => _cancelOrder(order),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: Colors.redAccent.withOpacity(0.45),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  'Cancel Order',
                  style: GoogleFonts.inter(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _customerStep({
    required TextEditingController customerSearchController,
    required List<dynamic> customerResults,
    required dynamic selectedCustomer,
    required bool isSearchingCustomers,
    required ValueChanged<String> onSearchChanged,
    required ValueChanged<dynamic> onSelectCustomer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetTitle(
          title: 'Step 1 — Select Customer',
          subtitle: 'Search by Instagram username, name, email, or phone.',
        ),
        const SizedBox(height: 16),
        _darkTextField(
          controller: customerSearchController,
          hintText: 'Search customer...',
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: 14),
        if (isSearchingCustomers)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                color: Color(0xFF00FFCC),
              ),
            ),
          )
        else if (customerResults.isEmpty)
          _sheetEmptyBox('No customers found')
        else
          ...customerResults.map((customer) {
            final isSelected =
                selectedCustomer?['id']?.toString() == customer['id']?.toString();

            final name = customer['display_name']?.toString() ??
                customer['instagram_username']?.toString() ??
                'Customer';

            final handle = customer['instagram_username']?.toString() ?? '';

            return GestureDetector(
              onTap: () => onSelectCustomer(customer),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF101010),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF00FFCC).withOpacity(0.55)
                        : Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.person_rounded,
                      color: isSelected
                          ? const Color(0xFF00FFCC)
                          : Colors.white38,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (handle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              '@$handle',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _productsStep({
    required List<_OrderFormItem> orderItems,
    required List<dynamic> products,
    required List<dynamic> inStockProducts,
    required StateSetter setSheetState,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetTitle(
          title: 'Step 2 — Add Products',
          subtitle: 'Choose products and quantity. Out-of-stock products are disabled.',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Ordered Products',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setSheetState(() {
                  orderItems.add(
                    _OrderFormItem(
                      product: inStockProducts.first,
                      quantityController: TextEditingController(text: '1'),
                    ),
                  );
                });
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Add',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w900,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF00FFCC),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(orderItems.length, (index) {
          final item = orderItems[index];

          return _orderItemInput(
            index: index,
            item: item,
            products: products,
            canRemove: orderItems.length > 1,
            setSheetState: setSheetState,
            onRemove: () {
              setSheetState(() {
                item.quantityController.dispose();
                orderItems.removeAt(index);
              });
            },
          );
        }),
      ],
    );
  }

  Widget _notesStep({
    required String selectedSource,
    required TextEditingController notesController,
    required TextEditingController variantController,
    required ValueChanged<String> onSourceChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetTitle(
          title: 'Step 3 — Extra Details',
          subtitle: 'Add source, note, and custom variant if needed.',
        ),
        const SizedBox(height: 16),
        _sheetLabel('Order Source'),
        Row(
          children: [
            Expanded(
              child: _sourceOption(
                value: 'manual',
                label: 'Manual',
                selectedSource: selectedSource,
                onTap: onSourceChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _sourceOption(
                value: 'dm',
                label: 'DM',
                selectedSource: selectedSource,
                onTap: onSourceChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _sourceOption(
                value: 'comment',
                label: 'Comment',
                selectedSource: selectedSource,
                onTap: onSourceChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sheetLabel('Custom Variant'),
        _darkTextField(
          controller: variantController,
          hintText: 'Example: black color, size M, gift pack',
        ),
        const SizedBox(height: 16),
        _sheetLabel('Notes'),
        _darkTextField(
          controller: notesController,
          hintText: 'Example: Customer wants fast delivery',
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _confirmStep({
    required dynamic customer,
    required String source,
    required String notes,
    required String customVariant,
    required List<_OrderFormItem> items,
  }) {
    final customerName = customer?['display_name']?.toString() ??
        customer?['instagram_username']?.toString() ??
        'Customer';

    final handle = customer?['instagram_username']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sheetTitle(
          title: 'Step 4 — Confirm Order',
          subtitle: 'Check everything before creating the order.',
        ),
        const SizedBox(height: 16),
        _confirmBox(
          title: 'Customer',
          value: handle.isEmpty ? customerName : '$customerName (@$handle)',
        ),
        const SizedBox(height: 10),
        _confirmBox(
          title: 'Source',
          value: _sourceLabel(source),
        ),
        const SizedBox(height: 10),
        _confirmBox(
          title: 'Custom Variant',
          value: customVariant.isEmpty ? 'Not added' : customVariant,
        ),
        const SizedBox(height: 10),
        _confirmBox(
          title: 'Notes',
          value: notes.isEmpty ? 'No notes added' : notes,
        ),
        const SizedBox(height: 16),
        Text(
          'Products',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map((item) {
          final productName = item.product['name']?.toString() ?? 'Product';
          final price = _toDouble(item.product['price']);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF101010),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_bag_rounded,
                  color: Color(0xFF00FFCC),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    productName,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${item.quantity} × ${_money(price)}',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _orderedItemsSection(dynamic order) {
    final rawItems = order['items'];

    if (rawItems is! List || rawItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF050505),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        child: Text(
          'Ordered items not available',
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF00FFCC).withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ordered Items',
            style: GoogleFonts.inter(
              color: const Color(0xFF00FFCC),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          ...rawItems.map((item) {
            return _orderedItemRow(item);
          }).toList(),
        ],
      ),
    );
  }

  Widget _orderedItemRow(dynamic item) {
    final quantity = _toInt(item['quantity']);

    final product = item['product'];
    final productName = product is Map
        ? product['name']?.toString() ?? 'Product'
        : 'Product';

    final unitPrice = item['unit_price'] != null
        ? _toDouble(item['unit_price'])
        : product is Map
            ? _toDouble(product['price'])
            : 0;

    final variantNotes = item['variant_notes']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF00FFCC).withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              color: Color(0xFF00FFCC),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$quantity qty • ${_money(unitPrice)} each',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (variantNotes.isNotEmpty &&
                    variantNotes.toLowerCase() != 'created from app') ...[
                  const SizedBox(height: 3),
                  Text(
                    variantNotes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderItemInput({
    required int index,
    required _OrderFormItem item,
    required List<dynamic> products,
    required bool canRemove,
    required StateSetter setSheetState,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Product ${index + 1}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (canRemove)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _darkDropdown(
            value: item.product['id']?.toString(),
            items: products.map((product) {
              final id = product['id']?.toString() ?? '';
              final name = product['name']?.toString() ?? 'Product';
              final stock = _toInt(product['stock_count']);
              final price = _money(product['price']);
              final isOutOfStock = stock <= 0;

              return DropdownMenuItem<String>(
                value: id,
                enabled: !isOutOfStock,
                child: Text(
                  isOutOfStock
                      ? '$name • Out of stock'
                      : '$name • $price • Stock: $stock',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isOutOfStock ? Colors.white30 : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value == null) return;

              final selected = products.firstWhere(
                (product) => product['id']?.toString() == value,
              );

              if (_toInt(selected['stock_count']) <= 0) return;

              setSheetState(() {
                item.product = selected;
              });
            },
          ),
          const SizedBox(height: 12),
          _darkTextField(
            controller: item.quantityController,
            hintText: 'Quantity',
            keyboardType: TextInputType.number,
            onChanged: (_) {
              setSheetState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _multiOrderTotalPreview({
    required List<_OrderFormItem> items,
  }) {
    int totalQuantity = 0;
    double orderTotal = 0;
    String? warning;

    final quantityByProduct = <String, int>{};
    final stockByProduct = <String, int>{};
    final nameByProduct = <String, String>{};

    for (final item in items) {
      final productId = item.product['id']?.toString() ?? '';
      final productName = item.product['name']?.toString() ?? 'Product';
      final quantity = item.quantity;
      final stock = _toInt(item.product['stock_count']);
      final price = _toDouble(item.product['price']);

      if (stock <= 0) {
        warning = '$productName is out of stock.';
      }

      if (quantity <= 0) {
        warning = 'Every product needs quantity at least 1.';
      }

      final safeQuantity = quantity < 0 ? 0 : quantity;

      totalQuantity += safeQuantity;
      orderTotal += price * safeQuantity;

      if (productId.isNotEmpty) {
        quantityByProduct[productId] =
            (quantityByProduct[productId] ?? 0) + safeQuantity;
        stockByProduct[productId] = stock;
        nameByProduct[productId] = productName;
      }
    }

    for (final entry in quantityByProduct.entries) {
      final productId = entry.key;
      final wantedQuantity = entry.value;
      final availableStock = stockByProduct[productId] ?? 0;
      final productName = nameByProduct[productId] ?? 'Product';

      if (wantedQuantity > availableStock) {
        warning = 'Quantity is more than stock for $productName.';
        break;
      }
    }

    final hasWarning = warning != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasWarning
              ? Colors.redAccent.withOpacity(0.40)
              : const Color(0xFF00FFCC).withOpacity(0.18),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Products added',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                items.length.toString(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total quantity',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                totalQuantity.toString(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Order total',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _money(orderTotal),
                style: GoogleFonts.inter(
                  color: const Color(0xFF00FFCC),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (hasWarning) ...[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                warning!,
                style: GoogleFonts.inter(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepIndicator(int currentStep) {
    final labels = ['Customer', 'Products', 'Details', 'Confirm'];

    return Row(
      children: List.generate(labels.length, (index) {
        final isActive = index == currentStep;
        final isDone = index < currentStep;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: isActive || isDone
                  ? const Color(0xFF00FFCC).withOpacity(0.12)
                  : const Color(0xFF101010),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isActive || isDone
                    ? const Color(0xFF00FFCC).withOpacity(0.32)
                    : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Text(
              labels[index],
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color:
                    isActive || isDone ? const Color(0xFF00FFCC) : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _sheetTitle({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 13,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _sheetErrorBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.redAccent.withOpacity(0.28),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.redAccent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _sheetEmptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: Colors.white38,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _confirmBox({
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceOption({
    required String value,
    required String label,
    required String selectedSource,
    required ValueChanged<String> onTap,
  }) {
    final isSelected = value == selectedSource;

    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00FFCC).withOpacity(0.12)
              : const Color(0xFF101010),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00FFCC).withOpacity(0.40)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: isSelected ? const Color(0xFF00FFCC) : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _miniInfo({
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _darkDropdown({
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          dropdownColor: const Color(0xFF101010),
          iconEnabledColor: const Color(0xFF00FFCC),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _darkTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          color: Colors.white30,
          fontSize: 13,
        ),
        filled: true,
        fillColor: const Color(0xFF101010),
        contentPadding: const EdgeInsets.all(14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.10),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF00FFCC),
          ),
        ),
      ),
    );
  }

  Widget _chip({
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class OrderDetailScreen extends StatelessWidget {
  final dynamic order;

  const OrderDetailScreen({
    super.key,
    required this.order,
  });

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _money(dynamic value) {
    final amount = _toDouble(value);

    if (amount == amount.roundToDouble()) {
      return '₹${amount.toStringAsFixed(0)}';
    }

    return '₹${amount.toStringAsFixed(2)}';
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'dm':
        return 'DM';
      case 'comment':
        return 'Comment';
      case 'manual':
        return 'Manual';
      default:
        return source;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'new':
        return 'Order Came';
      case 'confirmed':
        return 'Accepted';
      case 'packed':
        return 'Packed';
      case 'shipped':
        return 'On the Way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  String _formatDate(dynamic value) {
    final raw = value?.toString();

    if (raw == null || raw.isEmpty) {
      return 'Not yet';
    }

    final parsed = DateTime.tryParse(raw);

    if (parsed == null) {
      return 'Not yet';
    }

    final local = parsed.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final id = order['id']?.toString() ?? '';
    final shortId = id.length >= 8 ? id.substring(0, 8) : id;

    final orderNumber = order['order_number']?.toString() ?? 'ORD-$shortId';
    final status = order['status']?.toString() ?? 'new';
    final source = order['source']?.toString() ?? 'manual';
    final paymentStatus = order['payment_status']?.toString() ?? 'pending';
    final notes = order['notes']?.toString() ?? '';
    final customVariant = order['custom_variant']?.toString() ?? '';

    final customer = order['customer'];
    final customerName = customer is Map
        ? customer['display_name']?.toString() ??
            customer['instagram_username']?.toString() ??
            'Customer'
        : 'Customer';

    final customerHandle =
        customer is Map ? customer['instagram_username']?.toString() ?? '' : '';

    final customerEmail =
        customer is Map ? customer['email']?.toString() ?? '' : '';

    final customerPhone =
        customer is Map ? customer['phone']?.toString() ?? '' : '';

    final rawItems = order['items'];

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          'Order Details',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          _detailHeader(
            orderNumber: orderNumber,
            status: _statusLabel(status),
            total: _money(order['total_amount']),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Customer'),
          _infoCard(
            icon: Icons.person_rounded,
            title: customerName,
            subtitle: customerHandle.isEmpty ? 'No Instagram handle' : '@$customerHandle',
          ),
          if (customerEmail.isNotEmpty || customerPhone.isNotEmpty) ...[
            const SizedBox(height: 10),
            _smallInfoRow(
              leftTitle: 'Email',
              leftValue: customerEmail.isEmpty ? 'Not added' : customerEmail,
              rightTitle: 'Phone',
              rightValue: customerPhone.isEmpty ? 'Not added' : customerPhone,
            ),
          ],
          const SizedBox(height: 18),
          _sectionTitle('Items Ordered'),
          if (rawItems is List && rawItems.isNotEmpty)
            ...rawItems.map((item) => _detailItemCard(item)).toList()
          else
            _emptyBox('No ordered items found'),
          const SizedBox(height: 18),
          _sectionTitle('Order Info'),
          _smallInfoRow(
            leftTitle: 'Payment',
            leftValue: paymentStatus,
            rightTitle: 'Source',
            rightValue: _sourceLabel(source),
          ),
          const SizedBox(height: 10),
          _smallInfoRow(
            leftTitle: 'Created',
            leftValue: _formatDate(order['created_at']),
            rightTitle: 'Current Status',
            rightValue: _statusLabel(status),
          ),
          const SizedBox(height: 18),
          _sectionTitle('Notes'),
          _textCard(notes.isEmpty ? 'No notes added' : notes),
          const SizedBox(height: 10),
          _sectionTitle('Custom Variant'),
          _textCard(customVariant.isEmpty ? 'No custom variant added' : customVariant),
          const SizedBox(height: 18),
          _sectionTitle('Status Timeline'),
          _timeline(order),
        ],
      ),
    );
  }

  Widget _detailHeader({
    required String orderNumber,
    required String status,
    required String total,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF00FFCC).withOpacity(0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF00FFCC).withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF00FFCC),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  orderNumber,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  status,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF00FFCC),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            total,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00FFCC)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailItemCard(dynamic item) {
    final product = item['product'];
    final productName = product is Map
        ? product['name']?.toString() ?? 'Product'
        : 'Product';

    final quantity = _toInt(item['quantity']);

    final unitPrice = item['unit_price'] != null
        ? _toDouble(item['unit_price'])
        : product is Map
            ? _toDouble(product['price'])
            : 0;

    final total = unitPrice * quantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shopping_bag_rounded,
            color: Color(0xFF00FFCC),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              productName,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '$quantity × ${_money(unitPrice)}\n${_money(total)}',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallInfoRow({
    required String leftTitle,
    required String leftValue,
    required String rightTitle,
    required String rightValue,
  }) {
    return Row(
      children: [
        Expanded(
          child: _smallInfoCard(
            title: leftTitle,
            value: leftValue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _smallInfoCard(
            title: rightTitle,
            value: rightValue,
          ),
        ),
      ],
    );
  }

  Widget _smallInfoCard({
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _textCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.white70,
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: Colors.white38,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _timeline(dynamic order) {
    final rows = [
      _TimelineRow('Order Came', order['created_at']),
      _TimelineRow('Accepted', order['confirmed_at']),
      _TimelineRow('Packed', order['packed_at']),
      _TimelineRow('On the Way', order['shipped_at']),
      _TimelineRow('Delivered', order['delivered_at']),
      _TimelineRow('Cancelled', order['cancelled_at']),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: rows.map((row) {
          final isDone = row.value != null && row.value.toString().isNotEmpty;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isDone ? const Color(0xFF00FFCC) : Colors.white24,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.label,
                    style: GoogleFonts.inter(
                      color: isDone ? Colors.white : Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _formatDate(row.value),
                  style: GoogleFonts.inter(
                    color: isDone ? Colors.white54 : Colors.white24,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OrderColumnMeta {
  final String key;
  final String label;
  final String helper;
  final IconData icon;

  const _OrderColumnMeta({
    required this.key,
    required this.label,
    required this.helper,
    required this.icon,
  });
}

class _OrderFormItem {
  dynamic product;
  final TextEditingController quantityController;

  _OrderFormItem({
    required this.product,
    required this.quantityController,
  });

  int get quantity {
    return int.tryParse(quantityController.text.trim()) ?? 0;
  }
}

class _TimelineRow {
  final String label;
  final dynamic value;

  const _TimelineRow(this.label, this.value);
}