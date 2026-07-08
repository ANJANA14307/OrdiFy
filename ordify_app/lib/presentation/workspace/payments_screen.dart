import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:ordify_app/core/network/api_client.dart';

import 'ordify_workspace_widgets.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  bool isLoading = true;
  bool isSubmitting = false;
  String? errorMessage;

  List<dynamic> payments = [];

  @override
  void initState() {
    super.initState();
    fetchPayments();
  }

  Future<void> fetchPayments() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await apiClient.get('/payments/order/${widget.orderId}');

      setState(() {
        payments = response.data['payments'] ?? [];
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get paymentMaps {
    return payments
        .whereType<Map>()
        .map((payment) => Map<String, dynamic>.from(payment))
        .toList();
  }

  Map<String, dynamic>? get latestPayment {
    final list = paymentMaps;
    if (list.isEmpty) return null;
    return list.first;
  }

  bool get hasCodPayment {
    return paymentMaps.any((payment) => payment['gateway'] == 'cod');
  }

  int get paidCount {
    return paymentMaps.where((payment) => payment['status'] == 'paid').length;
  }

  Future<void> createCodPayment() async {
    if (hasCodPayment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('COD payment already exists for this order'),
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await apiClient.post(
        '/payments/cod/create',
        data: {'order_id': widget.orderId},
      );

      await fetchPayments();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('COD payment created')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> createRazorpayLink() async {
    setState(() => isSubmitting = true);

    try {
      final response = await apiClient.post(
        '/payments/razorpay/create-link',
        data: {'order_id': widget.orderId},
      );

      final paymentUrl = response.data['payment_url'];

      if (paymentUrl != null) {
        await Clipboard.setData(
          ClipboardData(text: paymentUrl.toString()),
        );
      }

      await fetchPayments();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paymentUrl == null
                ? 'Razorpay payment link created'
                : 'Payment link copied',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> markPaymentPaid(String paymentId) async {
    setState(() => isSubmitting = true);

    try {
      await apiClient.patch('/payments/$paymentId/mark-paid');

      await fetchPayments();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment marked as paid')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Color statusColor(String status) {
    if (status == 'paid') return const Color(0xFF34F087);
    if (status == 'pending') return const Color(0xFFFFC857);
    if (status == 'failed') return const Color(0xFFFF5E73);
    return const Color(0xFF9CA3AF);
  }

  @override
  Widget build(BuildContext context) {
    final latest = latestPayment;
    final latestStatus = latest?['status']?.toString() ?? 'unpaid';

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
                  : RefreshIndicator(
                      onRefresh: fetchPayments,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                        children: [
                          _Header(
                            onBack: () => context.pop(),
                            onRefresh: fetchPayments,
                          ),
                          const SizedBox(height: 18),
                          OrdifyGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payment Command Center',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    shadows: [
                                      Shadow(
                                        color: Color(0xFFFFC8C8),
                                        blurRadius: 9,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Create payment records, mark payments as paid and trigger invoices.',
                                  style: TextStyle(
                                    color: Color(0xFFE8FFF2),
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricTile(
                                        icon: Icons.payments_rounded,
                                        value: paymentMaps.length.toString(),
                                        label: 'Records',
                                        color: const Color(0xFF34F087),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _MetricTile(
                                        icon: Icons.check_circle_rounded,
                                        value: paidCount.toString(),
                                        label: 'Paid',
                                        color: const Color(0xFF9DF6FF),
                                      ),
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
                                  'Create Payment',
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
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: hasCodPayment
                                              ? Colors.white.withOpacity(0.16)
                                              : const Color(0xFF34F087),
                                          foregroundColor: hasCodPayment
                                              ? Colors.white54
                                              : Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                        onPressed: isSubmitting || hasCodPayment
                                            ? null
                                            : createCodPayment,
                                        icon: const Icon(Icons.money_rounded),
                                        label: const Text(
                                          'COD',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
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
                                        onPressed: isSubmitting
                                            ? null
                                            : createRazorpayLink,
                                        icon: const Icon(Icons.link_rounded),
                                        label: const Text(
                                          'Razorpay',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (hasCodPayment) ...[
                                  const SizedBox(height: 10),
                                  const Text(
                                    'COD already created. Duplicate COD is disabled to keep this order clean.',
                                    style: TextStyle(
                                      color: Color(0xFFE8FFF2),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (latest == null)
                            const _EmptyPayments()
                          else ...[
                            _LatestPaymentCard(
                              payment: latest,
                              color: statusColor(latestStatus),
                              isSubmitting: isSubmitting,
                              onMarkPaid: latestStatus == 'paid'
                                  ? null
                                  : () => markPaymentPaid(
                                        latest['id'].toString(),
                                      ),
                            ),
                            const SizedBox(height: 16),
                            _PaymentHistory(
                              payments: paymentMaps,
                              statusColor: statusColor,
                            ),
                          ],
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
    required this.onBack,
    required this.onRefresh,
  });

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Payments Hub',
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
          onPressed: onRefresh,
          icon: const Icon(
            Icons.refresh_rounded,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Color(0xFFFFC8C8),
                    blurRadius: 7,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFE8FFF2),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LatestPaymentCard extends StatelessWidget {
  const _LatestPaymentCard({
    required this.payment,
    required this.color,
    required this.isSubmitting,
    required this.onMarkPaid,
  });

  final Map<String, dynamic> payment;
  final Color color;
  final bool isSubmitting;
  final VoidCallback? onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final gateway = payment['gateway']?.toString() ?? 'payment';
    final amount = payment['amount']?.toString() ?? '0';
    final status = payment['status']?.toString() ?? 'pending';

    return OrdifyGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest Payment',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: color,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gateway.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
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
                      '₹$amount',
                      style: const TextStyle(
                        color: Color(0xFFE8FFF2),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(text: status.toUpperCase(), color: color),
            ],
          ),
          if (onMarkPaid != null) ...[
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
                onPressed: isSubmitting ? null : onMarkPaid,
                child: const Text(
                  'Mark Paid',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentHistory extends StatelessWidget {
  const _PaymentHistory({
    required this.payments,
    required this.statusColor,
  });

  final List<Map<String, dynamic>> payments;
  final Color Function(String status) statusColor;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      padding: const EdgeInsets.all(12),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          collapsedIconColor: const Color(0xFF34F087),
          iconColor: const Color(0xFF34F087),
          title: Text(
            'Payment History (${payments.length})',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: const Text(
            'Tap to view all records',
            style: TextStyle(
              color: Color(0xFFE8FFF2),
              fontWeight: FontWeight.w700,
            ),
          ),
          children: payments.map((payment) {
            final gateway = payment['gateway']?.toString() ?? 'payment';
            final amount = payment['amount']?.toString() ?? '0';
            final status = payment['status']?.toString() ?? 'pending';
            final color = statusColor(status);

            return ListTile(
              tileColor: Colors.transparent,
              splashColor: Colors.white10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: Icon(
                Icons.payments_rounded,
                color: color,
              ),
              title: Text(
                '${gateway.toUpperCase()} • ₹$amount',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              trailing: _StatusPill(
                text: status.toUpperCase(),
                color: color,
              ),
            );
          }).toList(),
        ),
      ),
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

class _EmptyPayments extends StatelessWidget {
  const _EmptyPayments();

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      child: const Column(
        children: [
          Icon(
            Icons.payments_outlined,
            size: 58,
            color: Color(0xFF34F087),
          ),
          SizedBox(height: 16),
          Text(
            'No payments yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create COD or Razorpay payment for this order.',
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