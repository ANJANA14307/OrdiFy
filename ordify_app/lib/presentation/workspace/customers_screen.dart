import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import 'ordify_workspace_widgets.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  bool _isLoading = false;
  bool _isSaving = false;
  String? _message;

  List<dynamic> _customers = [];
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers({bool clearMessage = true}) async {
    setState(() {
      _isLoading = true;
      if (clearMessage) _message = null;
    });

    try {
      final response = await apiClient.get('/customers');

      if (!mounted) return;

      setState(() {
        _customers = List<dynamic>.from(response.data['customers'] ?? []);
      });
    } catch (e) {
      debugPrint('CUSTOMERS LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _message = 'Could not load customers';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredCustomers {
    if (_searchText.trim().isEmpty) return _customers;

    final query = _searchText.toLowerCase().trim();

    return _customers.where((customer) {
      if (customer is! Map) return false;

      final name = customer['display_name']?.toString().toLowerCase() ?? '';
      final instagram =
          customer['instagram_username']?.toString().toLowerCase() ?? '';
      final email = customer['email']?.toString().toLowerCase() ?? '';
      final phone = customer['phone']?.toString().toLowerCase() ?? '';

      return name.contains(query) ||
          instagram.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();
  }

  int get _vipCount {
    return _customers.where((customer) {
      if (customer is! Map) return false;
      return customer['is_vip'] == true;
    }).length;
  }

  int get _customerCount => _customers.length;

  double get _totalSpent {
    double total = 0;

    for (final customer in _customers) {
      if (customer is Map) {
        total += _toDouble(customer['total_spent']);
      }
    }

    return total;
  }

  int get _totalOrders {
    int total = 0;

    for (final customer in _customers) {
      if (customer is Map) {
        total += _toInt(customer['total_orders']);
      }
    }

    return total;
  }

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

  Future<void> _openCustomerSheet({dynamic customer}) async {
    final customerMap =
        customer is Map ? Map<String, dynamic>.from(customer) : null;

    final isEditing = customerMap != null;

    final instagramController = TextEditingController(
      text: isEditing
          ? customerMap['instagram_username']?.toString() ?? ''
          : '',
    );
    final nameController = TextEditingController(
      text: isEditing ? customerMap['display_name']?.toString() ?? '' : '',
    );
    final emailController = TextEditingController(
      text: isEditing ? customerMap['email']?.toString() ?? '' : '',
    );
    final phoneController = TextEditingController(
      text: isEditing ? customerMap['phone']?.toString() ?? '' : '',
    );

    bool isVip = isEditing ? customerMap['is_vip'] == true : false;

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B1510),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(32),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Theme(
              data: Theme.of(context).copyWith(
                inputDecorationTheme: InputDecorationTheme(
                  labelStyle: GoogleFonts.inter(
                    color: const Color(0xFFE8FFF2),
                    fontWeight: FontWeight.w700,
                  ),
                  hintStyle: GoogleFonts.inter(
                    color: Colors.white30,
                  ),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.16),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: Color(0xFF34F087),
                      width: 2,
                    ),
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 18,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          height: 4,
                          width: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        isEditing ? 'Edit Customer' : 'Add Customer',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(
                              color: Color(0xFFFFC8C8),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isEditing
                            ? 'Update saved buyer details.'
                            : 'Save a buyer profile for faster order creation.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE8FFF2),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: instagramController,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Instagram Username',
                          hintText: 'example: anjana_store',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameController,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Display Name',
                          hintText: 'example: Anjana Customer',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'example@gmail.com',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Phone',
                          hintText: '9876543210',
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            isVip = !isVip;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isVip
                                  ? const Color(0xFFFFC857).withOpacity(0.45)
                                  : Colors.white.withOpacity(0.16),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isVip
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: isVip
                                    ? const Color(0xFFFFC857)
                                    : Colors.white38,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Mark as VIP Customer',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Switch(
                                value: isVip,
                                activeColor: const Color(0xFF34F087),
                                onChanged: (value) {
                                  setSheetState(() {
                                    isVip = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.pop(sheetContext, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF34F087),
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.22),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Text(
                                'Close',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.pop(sheetContext, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF34F087),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Text(
                                isEditing ? 'Save' : 'Create',
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
              ),
            );
          },
        );
      },
    );

    if (shouldSave != true) {
      instagramController.dispose();
      nameController.dispose();
      emailController.dispose();
      phoneController.dispose();
      return;
    }

    final instagramUsername = instagramController.text.trim();
    final displayName = nameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();

    instagramController.dispose();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();

    if (instagramUsername.isEmpty) {
      setState(() {
        _message = 'Instagram username is required';
      });
      return;
    }

    if (isEditing) {
      await _updateCustomer(
        customerId: customerMap['id'].toString(),
        instagramUsername: instagramUsername,
        displayName: displayName,
        email: email,
        phone: phone,
        isVip: isVip,
      );
    } else {
      await _createCustomer(
        instagramUsername: instagramUsername,
        displayName: displayName,
        email: email,
        phone: phone,
      );
    }
  }

  Future<void> _createCustomer({
    required String instagramUsername,
    required String displayName,
    required String email,
    required String phone,
  }) async {
    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      await apiClient.post(
        '/customers',
        data: {
          'instagram_username': instagramUsername,
          'display_name': displayName.isEmpty ? null : displayName,
          'email': email.isEmpty ? null : email,
          'phone': phone.isEmpty ? null : phone,
        },
      );

      if (!mounted) return;

      setState(() {
        _message = 'Customer created successfully';
      });

      await _loadCustomers(clearMessage: false);
    } catch (e) {
      debugPrint('CREATE CUSTOMER ERROR: $e');

      if (!mounted) return;

      setState(() {
        _message = 'Could not create customer';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _updateCustomer({
    required String customerId,
    required String instagramUsername,
    required String displayName,
    required String email,
    required String phone,
    required bool isVip,
  }) async {
    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      await apiClient.patch(
        '/customers/$customerId',
        data: {
          'instagram_username': instagramUsername,
          'display_name': displayName.isEmpty ? null : displayName,
          'email': email.isEmpty ? null : email,
          'phone': phone.isEmpty ? null : phone,
          'is_vip': isVip,
        },
      );

      if (!mounted) return;

      setState(() {
        _message = 'Customer updated successfully';
      });

      await _loadCustomers(clearMessage: false);
    } catch (e) {
      debugPrint('UPDATE CUSTOMER ERROR: $e');

      if (!mounted) return;

      setState(() {
        _message = 'Could not update customer';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _deleteCustomer(dynamic customer) async {
    if (customer is! Map) return;

    final customerMap = Map<String, dynamic>.from(customer);
    final customerId = customerMap['id']?.toString();

    if (customerId == null || customerId.isEmpty) {
      setState(() {
        _message = 'Customer id missing';
      });
      return;
    }

    final customerName = customerMap['display_name']?.toString() ??
        customerMap['instagram_username']?.toString() ??
        'this customer';

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B1510),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Delete Customer?',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'Delete $customerName? Customers with existing orders cannot be deleted.',
            style: GoogleFonts.inter(
              color: const Color(0xFFE8FFF2),
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Keep',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      await apiClient.delete('/customers/$customerId');

      if (!mounted) return;

      setState(() {
        _message = 'Customer deleted successfully';
      });

      await _loadCustomers(clearMessage: false);
    } catch (e) {
      debugPrint('DELETE CUSTOMER ERROR: $e');

      if (!mounted) return;

      setState(() {
        _message = 'Could not delete customer';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _toggleVip(dynamic customer) async {
    if (customer is! Map) return;

    final customerMap = Map<String, dynamic>.from(customer);

    await _updateCustomer(
      customerId: customerMap['id'].toString(),
      instagramUsername: customerMap['instagram_username']?.toString() ?? '',
      displayName: customerMap['display_name']?.toString() ?? '',
      email: customerMap['email']?.toString() ?? '',
      phone: customerMap['phone']?.toString() ?? '',
      isVip: customerMap['is_vip'] != true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleCustomers = _filteredCustomers;

    return Scaffold(
      backgroundColor: const Color(0xFF050807),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customers_add_customer_fab',
        onPressed: _isSaving ? null : () => _openCustomerSheet(),
        backgroundColor: const Color(0xFF34F087),
        foregroundColor: Colors.black,
        elevation: 12,
        icon: _isSaving
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : const Icon(Icons.person_add_alt_1_rounded),
        label: Text(
          _isSaving ? 'Working...' : 'Customer',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
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
          child: _isLoading && _customers.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF34F087),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFF34F087),
                  backgroundColor: const Color(0xFF0B1510),
                  onRefresh: () => _loadCustomers(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                    children: [
                      _TopHeader(
                        isLoading: _isLoading,
                        onRefresh: () => _loadCustomers(),
                      ),
                      const SizedBox(height: 22),
                      _CommandCard(
                        customerCount: _customerCount,
                        vipCount: _vipCount,
                        totalOrders: _totalOrders,
                        totalSpent: _money(_totalSpent),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        _MessageBox(message: _message!),
                      ],
                      const SizedBox(height: 18),
                      _SearchBox(
                        onChanged: (value) {
                          setState(() {
                            _searchText = value;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Customer Directory',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
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
                      if (visibleCustomers.isEmpty)
                        _EmptyState(
                          hasSearch: _searchText.trim().isNotEmpty,
                        )
                      else
                        ...visibleCustomers.map((customer) {
                          final customerMap = Map<String, dynamic>.from(
                            customer as Map,
                          );

                          return _CustomerCard(
                            customer: customerMap,
                            money: _money,
                            toInt: _toInt,
                            isSaving: _isSaving,
                            onEdit: () =>
                                _openCustomerSheet(customer: customerMap),
                            onVip: () => _toggleVip(customerMap),
                            onDelete: () => _deleteCustomer(customerMap),
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

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.isLoading,
    required this.onRefresh,
  });

  final bool isLoading;
  final VoidCallback onRefresh;

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
                color: const Color(0xFF34F087).withOpacity(0.42),
                blurRadius: 24,
              ),
            ],
          ),
          child: const Icon(
            Icons.people_alt_rounded,
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
                'Buyer relationships',
                style: TextStyle(
                  color: Color(0xFFE8FFF2),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Customers Hub',
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
          onPressed: isLoading ? null : onRefresh,
          icon: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF34F087),
                  ),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                ),
        ),
      ],
    );
  }
}

class _CommandCard extends StatelessWidget {
  const _CommandCard({
    required this.customerCount,
    required this.vipCount,
    required this.totalOrders,
    required this.totalSpent,
  });

  final int customerCount;
  final int vipCount;
  final int totalOrders;
  final String totalSpent;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Command Center',
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
            'Manage buyers, VIP customers, contact details and repeat orders.',
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
                child: OrdifyMetricCard(
                  icon: Icons.people_alt_rounded,
                  value: customerCount.toString(),
                  label: 'Customers',
                  color: const Color(0xFF34F087),
                  minHeight: 112,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OrdifyMetricCard(
                  icon: Icons.star_rounded,
                  value: vipCount.toString(),
                  label: 'VIP',
                  color: const Color(0xFFFFC857),
                  minHeight: 112,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OrdifyMetricCard(
                  icon: Icons.receipt_long_rounded,
                  value: totalOrders.toString(),
                  label: 'Orders',
                  color: const Color(0xFF9DF6FF),
                  minHeight: 112,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OrdifyMetricCard(
                  icon: Icons.currency_rupee_rounded,
                  value: totalSpent,
                  label: 'Spent',
                  color: const Color(0xFFB788FF),
                  minHeight: 112,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.onChanged,
  });

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: onChanged,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          icon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF34F087),
          ),
          hintText: 'Search customer, Instagram, email or phone',
          hintStyle: GoogleFonts.inter(
            color: const Color(0xFFE8FFF2).withOpacity(0.70),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final isSuccess =
        message.contains('successfully') || message.contains('updated');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSuccess
            ? const Color(0xFF34F087).withOpacity(0.10)
            : Colors.redAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSuccess
              ? const Color(0xFF34F087).withOpacity(0.25)
              : Colors.redAccent.withOpacity(0.30),
        ),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          color: isSuccess ? const Color(0xFF34F087) : Colors.redAccent,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.money,
    required this.toInt,
    required this.isSaving,
    required this.onEdit,
    required this.onVip,
    required this.onDelete,
  });

  final Map<String, dynamic> customer;
  final String Function(dynamic value) money;
  final int Function(dynamic value) toInt;
  final bool isSaving;
  final VoidCallback onEdit;
  final VoidCallback onVip;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = customer['display_name']?.toString();
    final username = customer['instagram_username']?.toString() ?? 'customer';
    final email = customer['email']?.toString() ?? '';
    final phone = customer['phone']?.toString() ?? '';
    final isVip = customer['is_vip'] == true;
    final totalOrders = toInt(customer['total_orders']);
    final totalSpent = money(customer['total_spent']);

    final displayName = name == null || name.isEmpty ? username : name;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: OrdifyGlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: 54,
                  width: 54,
                  decoration: BoxDecoration(
                    color: isVip
                        ? const Color(0xFFFFC857).withOpacity(0.18)
                        : const Color(0xFF34F087).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    isVip ? Icons.star_rounded : Icons.person_rounded,
                    color: isVip
                        ? const Color(0xFFFFC857)
                        : const Color(0xFF34F087),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(
                              color: Color(0xFFFFC8C8),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@$username',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFE8FFF2),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(
                  text: isVip ? 'VIP' : 'REGULAR',
                  color: isVip
                      ? const Color(0xFFFFC857)
                      : const Color(0xFF34F087),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniInfo(
                    title: 'Orders',
                    value: totalOrders.toString(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniInfo(
                    title: 'Spent',
                    value: totalSpent,
                  ),
                ),
              ],
            ),
            if (email.isNotEmpty || phone.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (email.isNotEmpty)
                _ContactRow(
                  icon: Icons.email_rounded,
                  text: email,
                ),
              if (phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ContactRow(
                  icon: Icons.phone_rounded,
                  text: phone,
                ),
              ],
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSaving ? null : onEdit,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: Text(
                      'Edit',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF34F087),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.22),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSaving ? null : onVip,
                    icon: Icon(
                      isVip ? Icons.star_border_rounded : Icons.star_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isVip ? 'Regular' : 'VIP',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isVip
                          ? const Color(0xFFE8FFF2)
                          : const Color(0xFFFFC857),
                      side: BorderSide(
                        color: isVip
                            ? Colors.white.withOpacity(0.22)
                            : const Color(0xFFFFC857).withOpacity(0.38),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: isSaving ? null : onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFFE8FFF2),
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
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFFE8FFF2),
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFFE8FFF2),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.42)),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasSearch,
  });

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      child: Column(
        children: [
          const Icon(
            Icons.people_alt_rounded,
            size: 58,
            color: Color(0xFF34F087),
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No matching customers' : 'No customers yet',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasSearch
                ? 'Try another name, Instagram username, email or phone.'
                : 'Add customers here. Then create orders faster from the Orders screen.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFE8FFF2),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class CrmScreen extends CustomersScreen {
  const CrmScreen({super.key});
}