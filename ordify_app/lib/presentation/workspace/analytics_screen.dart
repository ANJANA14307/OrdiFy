import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import 'ordify_workspace_widgets.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic> summary = {};
  List<dynamic> insights = [];
  List<dynamic> bestCustomers = [];
  List<dynamic> topProducts = [];
  List<dynamic> slowMovingProducts = [];

  @override
  void initState() {
    super.initState();
    fetchAnalytics();
  }

  Future<void> fetchAnalytics() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await apiClient.get('/analytics/dashboard');
      final data = Map<String, dynamic>.from(response.data as Map);

      setState(() {
        summary = Map<String, dynamic>.from(data['summary'] ?? {});
        insights = data['insights'] ?? [];
        bestCustomers = data['best_customers'] ?? [];
        topProducts = data['top_products'] ?? [];
        slowMovingProducts = data['slow_moving_products'] ?? [];
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  String money(dynamic value) {
    final amount = double.tryParse(value?.toString() ?? '0') ?? 0;

    if (amount == amount.roundToDouble()) {
      return '₹${amount.toStringAsFixed(0)}';
    }

    return '₹${amount.toStringAsFixed(2)}';
  }

  String textValue(dynamic value) {
    return value?.toString() ?? '0';
  }

  void backOrDashboard() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalRevenue = money(summary['total_revenue']);
    final weekRevenue = money(summary['revenue_this_week']);
    final monthRevenue = money(summary['revenue_this_month']);
    final averageOrderValue = money(summary['average_order_value']);
    final orderSuccessRate = textValue(summary['order_success_rate']);
    final healthScore = textValue(summary['business_health_score']);

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
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF34F087),
                  ),
                )
              : errorMessage != null
                  ? _ErrorView(
                      message: errorMessage!,
                      onRetry: fetchAnalytics,
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF34F087),
                      backgroundColor: const Color(0xFF0B1510),
                      onRefresh: fetchAnalytics,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
                        children: [
                          _Header(
                            onBack: backOrDashboard,
                            onRefresh: fetchAnalytics,
                          ),
                          const SizedBox(height: 18),
                          _HeroReportCard(
                            totalRevenue: totalRevenue,
                            healthScore: healthScore,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricTile(
                                  icon: Icons.calendar_view_week_rounded,
                                  value: weekRevenue,
                                  label: 'This Week',
                                  color: const Color(0xFF34F087),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricTile(
                                  icon: Icons.calendar_month_rounded,
                                  value: monthRevenue,
                                  label: 'This Month',
                                  color: const Color(0xFF9DF6FF),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricTile(
                                  icon: Icons.shopping_bag_rounded,
                                  value: averageOrderValue,
                                  label: 'Avg Order Value',
                                  color: const Color(0xFFFFC857),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _MetricTile(
                                  icon: Icons.speed_rounded,
                                  value: '$orderSuccessRate%',
                                  label: 'Success Rate',
                                  color: const Color(0xFFB788FF),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 26),
                          const _GlowText(
                            'Smart Insights',
                            fontSize: 23,
                          ),
                          const SizedBox(height: 14),
                          if (insights.isEmpty)
                            const _EmptyCard(
                              icon: Icons.auto_awesome_rounded,
                              title: 'No insights yet',
                              subtitle:
                                  'Create paid orders to unlock business insights.',
                            )
                          else
                            ...insights.map((item) {
                              return _InsightCard(text: item.toString());
                            }),
                          const SizedBox(height: 26),
                          const _GlowText(
                            'Best Customers',
                            fontSize: 23,
                          ),
                          const SizedBox(height: 14),
                          if (bestCustomers.isEmpty)
                            const _EmptyCard(
                              icon: Icons.people_alt_outlined,
                              title: 'No customer ranking yet',
                              subtitle:
                                  'Best customers will appear after paid orders.',
                            )
                          else
                            ...bestCustomers.map((customer) {
                              final customerMap =
                                  Map<String, dynamic>.from(customer as Map);

                              return _CustomerCard(
                                customer: customerMap,
                                money: money,
                              );
                            }),
                          const SizedBox(height: 26),
                          const _GlowText(
                            'Top Products',
                            fontSize: 23,
                          ),
                          const SizedBox(height: 14),
                          if (topProducts.isEmpty)
                            const _EmptyCard(
                              icon: Icons.inventory_2_outlined,
                              title: 'No product ranking yet',
                              subtitle:
                                  'Top products will appear after paid product orders.',
                            )
                          else
                            ...topProducts.map((product) {
                              final productMap =
                                  Map<String, dynamic>.from(product as Map);

                              return _ProductCard(
                                product: productMap,
                                money: money,
                              );
                            }),
                          const SizedBox(height: 26),
                          const _GlowText(
                            'Slow Moving Products',
                            fontSize: 23,
                          ),
                          const SizedBox(height: 14),
                          if (slowMovingProducts.isEmpty)
                            const _EmptyCard(
                              icon: Icons.trending_up_rounded,
                              title: 'No slow products found',
                              subtitle:
                                  'Products with no sales will appear here.',
                            )
                          else
                            ...slowMovingProducts.map((product) {
                              final productMap =
                                  Map<String, dynamic>.from(product as Map);

                              return _SlowProductCard(product: productMap);
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Growth report',
                style: TextStyle(
                  color: Color(0xFFE8FFF2),
                  fontWeight: FontWeight.w700,
                ),
              ),
              _GlowText(
                'Analytics Hub',
                fontSize: 26,
              ),
            ],
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

class _HeroReportCard extends StatelessWidget {
  const _HeroReportCard({
    required this.totalRevenue,
    required this.healthScore,
  });

  final String totalRevenue;
  final String healthScore;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _GlowText(
            'Revenue Performance',
            fontSize: 24,
          ),
          const SizedBox(height: 8),
          Text(
            'Focused report for sales growth, customer value and product movement.',
            style: GoogleFonts.inter(
              color: const Color(0xFFE8FFF2),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _BigNumberBox(
                  title: 'Total Revenue',
                  value: totalRevenue,
                  icon: Icons.currency_rupee_rounded,
                  color: const Color(0xFF34F087),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigNumberBox(
                  title: 'Health Score',
                  value: '$healthScore%',
                  icon: Icons.favorite_rounded,
                  color: const Color(0xFF9DF6FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigNumberBox extends StatelessWidget {
  const _BigNumberBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(
                    color: Color(0xFFFFC8C8),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFFE8FFF2),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
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
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(
                        color: Color(0xFFFFC8C8),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE8FFF2),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: OrdifyGlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _IconBubble(
              icon: Icons.auto_awesome_rounded,
              color: const Color(0xFF34F087),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  height: 1.4,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({
    required this.customer,
    required this.money,
  });

  final Map<String, dynamic> customer;
  final String Function(dynamic value) money;

  @override
  Widget build(BuildContext context) {
    final name = customer['name']?.toString() ?? 'Customer';
    final spent = money(customer['total_spent']);
    final orders = customer['paid_orders']?.toString() ?? '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: OrdifyGlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _IconBubble(
              icon: Icons.people_alt_rounded,
              color: const Color(0xFFB788FF),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GlowText(
                    name,
                    fontSize: 17,
                    soft: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$spent spent • $orders purchase(s)',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE8FFF2),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.money,
  });

  final Map<String, dynamic> product;
  final String Function(dynamic value) money;

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? 'Product';
    final quantity = product['quantity_sold']?.toString() ?? '0';
    final revenue = money(product['revenue']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: OrdifyGlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _IconBubble(
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF34F087),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GlowText(
                    name,
                    fontSize: 17,
                    soft: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$quantity sold • $revenue',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE8FFF2),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlowProductCard extends StatelessWidget {
  const _SlowProductCard({
    required this.product,
  });

  final Map<String, dynamic> product;

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? 'Product';
    final stock = product['stock_count']?.toString() ?? '0';
    final reason = product['reason']?.toString() ?? 'No sales recorded yet';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: OrdifyGlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _IconBubble(
              icon: Icons.trending_down_rounded,
              color: const Color(0xFFFFC857),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GlowText(
                    name,
                    fontSize: 17,
                    soft: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock $stock • $reason',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE8FFF2),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        icon,
        color: color,
        size: 28,
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      child: Column(
        children: [
          Icon(
            icon,
            color: const Color(0xFF34F087),
            size: 56,
          ),
          const SizedBox(height: 16),
          _GlowText(
            title,
            fontSize: 20,
            soft: true,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFFE8FFF2),
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: OrdifyGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFFF5E73),
                size: 56,
              ),
              const SizedBox(height: 14),
              const _GlowText(
                'Analytics failed',
                fontSize: 20,
                soft: true,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34F087),
                  foregroundColor: const Color(0xFF052113),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  'Retry',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowText extends StatelessWidget {
  const _GlowText(
    this.text, {
    required this.fontSize,
    this.soft = false,
  });

  final String text;
  final double fontSize;
  final bool soft;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.inter(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        shadows: [
          Shadow(
            color: soft ? const Color(0xFFFFC8C8) : const Color(0xFFFFD6D6),
            blurRadius: soft ? 8 : 12,
          ),
          Shadow(
            color: const Color(0xFF34F087).withOpacity(0.25),
            blurRadius: soft ? 8 : 14,
          ),
        ],
      ),
    );
  }
}