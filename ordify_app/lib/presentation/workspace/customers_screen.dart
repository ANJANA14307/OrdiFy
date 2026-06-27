import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';

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

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers({bool clearMessage = true}) async {
    setState(() {
      _isLoading = true;
      if (clearMessage) {
        _message = null;
      }
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

  int get _vipCount {
    return _customers.where((customer) {
      return customer['is_vip'] == true;
    }).length;
  }

  int get _customerCount => _customers.length;

  double get _totalSpent {
    double total = 0;

    for (final customer in _customers) {
      total += _toDouble(customer['total_spent']);
    }

    return total;
  }

  int get _totalOrders {
    int total = 0;

    for (final customer in _customers) {
      total += _toInt(customer['total_orders']);
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
    final isEditing = customer != null;

    final instagramController = TextEditingController(
      text: isEditing ? customer['instagram_username']?.toString() ?? '' : '',
    );
    final nameController = TextEditingController(
      text: isEditing ? customer['display_name']?.toString() ?? '' : '',
    );
    final emailController = TextEditingController(
      text: isEditing ? customer['email']?.toString() ?? '' : '',
    );
    final phoneController = TextEditingController(
      text: isEditing ? customer['phone']?.toString() ?? '' : '',
    );

    bool isVip = isEditing ? customer['is_vip'] == true : false;

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
                decoration: const BoxDecoration(
                  color: Color(0xFF080808),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      Text(
                        isEditing ? 'Edit Customer' : 'Add Customer',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isEditing
                            ? 'Update customer details.'
                            : 'Save a customer for faster order creation.',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 22),

                      _sheetLabel('Instagram Username'),
                      _darkTextField(
                        controller: instagramController,
                        hintText: 'Example: anjana_store',
                      ),

                      const SizedBox(height: 16),

                      _sheetLabel('Display Name'),
                      _darkTextField(
                        controller: nameController,
                        hintText: 'Example: Anjana Customer',
                      ),

                      const SizedBox(height: 16),

                      _sheetLabel('Email'),
                      _darkTextField(
                        controller: emailController,
                        hintText: 'example@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 16),

                      _sheetLabel('Phone'),
                      _darkTextField(
                        controller: phoneController,
                        hintText: '9876543210',
                        keyboardType: TextInputType.phone,
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
                            color: const Color(0xFF101010),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isVip
                                  ? Colors.amberAccent.withOpacity(0.35)
                                  : Colors.white.withOpacity(0.10),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isVip
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: isVip
                                    ? Colors.amberAccent
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
                                activeColor: const Color(0xFF00FFCC),
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
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.18),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                              ),
                              child: Text(
                                'Close',
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
                              onPressed: () =>
                                  Navigator.pop(sheetContext, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00FFCC),
                                foregroundColor: Colors.black,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                              ),
                              child: Text(
                                isEditing ? 'Save Changes' : 'Create Customer',
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
        customerId: customer['id'].toString(),
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
    final customerId = customer['id']?.toString();

    if (customerId == null || customerId.isEmpty) {
      setState(() {
        _message = 'Customer id missing';
      });
      return;
    }

    final customerName = customer['display_name']?.toString() ??
        customer['instagram_username']?.toString() ??
        'this customer';

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF101010),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'Delete Customer?',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Delete $customerName? Customers with existing orders cannot be deleted.',
            style: GoogleFonts.inter(
              color: Colors.white60,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                'Keep',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'Delete',
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
    await _updateCustomer(
      customerId: customer['id'].toString(),
      instagramUsername: customer['instagram_username']?.toString() ?? '',
      displayName: customer['display_name']?.toString() ?? '',
      email: customer['email']?.toString() ?? '',
      phone: customer['phone']?.toString() ?? '',
      isVip: customer['is_vip'] != true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : () => _openCustomerSheet(),
        backgroundColor: const Color(0xFF00FFCC),
        foregroundColor: Colors.black,
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
          _isSaving ? 'Working...' : 'Add Customer',
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
            Expanded(
              child: _isLoading && _customers.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00FFCC),
                      ),
                    )
                  : _customers.isEmpty
                      ? _emptyState()
                      : RefreshIndicator(
                          color: const Color(0xFF00FFCC),
                          backgroundColor: const Color(0xFF101010),
                          onRefresh: () => _loadCustomers(),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 90),
                            itemCount: _customers.length,
                            itemBuilder: (context, index) {
                              return _customerCard(_customers[index]);
                            },
                          ),
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
                'Customers',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Save customer details and create orders faster.',
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
          onPressed: _isLoading ? null : () => _loadCustomers(),
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
            title: 'Customers',
            value: _customerCount.toString(),
            icon: Icons.people_alt_rounded,
          ),
          _statCard(
            title: 'VIP',
            value: _vipCount.toString(),
            icon: Icons.star_rounded,
          ),
          _statCard(
            title: 'Orders',
            value: _totalOrders.toString(),
            icon: Icons.receipt_long_rounded,
          ),
          _statCard(
            title: 'Spent',
            value: _money(_totalSpent),
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
        _message!.contains('successfully') || _message!.contains('updated');

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

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 76,
              width: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF00FFCC).withOpacity(0.10),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                color: Color(0xFF00FFCC),
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No customers yet',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add customers here. Then you can create orders faster from the Orders screen.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customerCard(dynamic customer) {
    final name = customer['display_name']?.toString();
    final username = customer['instagram_username']?.toString() ?? 'customer';
    final email = customer['email']?.toString() ?? '';
    final phone = customer['phone']?.toString() ?? '';
    final isVip = customer['is_vip'] == true;
    final totalOrders = _toInt(customer['total_orders']);
    final totalSpent = _money(customer['total_spent']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isVip
              ? Colors.amberAccent.withOpacity(0.25)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: isVip
                      ? Colors.amberAccent.withOpacity(0.12)
                      : const Color(0xFF00FFCC).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  isVip ? Icons.star_rounded : Icons.person_rounded,
                  color: isVip ? Colors.amberAccent : const Color(0xFF00FFCC),
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name == null || name.isEmpty ? username : name,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@$username',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _vipChip(isVip),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniInfo(
                  title: 'Orders',
                  value: totalOrders.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniInfo(
                  title: 'Spent',
                  value: totalSpent,
                ),
              ),
            ],
          ),
          if (email.isNotEmpty || phone.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (email.isNotEmpty)
              _contactRow(
                icon: Icons.email_rounded,
                text: email,
              ),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 8),
              _contactRow(
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
                  onPressed: _isSaving
                      ? null
                      : () => _openCustomerSheet(customer: customer),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text(
                    'Edit',
                    style: GoogleFonts.inter(
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
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _toggleVip(customer),
                  icon: Icon(
                    isVip ? Icons.star_border_rounded : Icons.star_rounded,
                    size: 18,
                  ),
                  label: Text(
                    isVip ? 'Remove VIP' : 'Make VIP',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isVip ? Colors.white70 : Colors.amberAccent,
                    side: BorderSide(
                      color: isVip
                          ? Colors.white.withOpacity(0.16)
                          : Colors.amberAccent.withOpacity(0.35),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: _isSaving ? null : () => _deleteCustomer(customer),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vipChip(bool isVip) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: isVip
            ? Colors.amberAccent.withOpacity(0.12)
            : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        isVip ? 'VIP' : 'Regular',
        style: GoogleFonts.inter(
          color: isVip ? Colors.amberAccent : Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w900,
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

  Widget _contactRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white38,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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

  Widget _darkTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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
}

class CrmScreen extends CustomersScreen {
  const CrmScreen({super.key});
}