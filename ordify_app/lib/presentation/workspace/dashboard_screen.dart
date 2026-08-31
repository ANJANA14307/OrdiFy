import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/api_client.dart';
import 'ordify_workspace_widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = false;
  bool _instagramConnected = false;

  String _instagramUsername = 'Not connected';

  int _productCount = 0;
  int _lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);

    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    debugPrint('SUPABASE TOKEN: $token');

    try {
      final productResponse = await apiClient.get('/products?page=1&limit=50');

      final products = productResponse.data['products'] ?? [];

      int lowStock = 0;

      for (final product in products) {
        final stock = _toInt(product['stock_count']);
        final threshold = _toInt(
          product['low_stock_threshold'],
          fallback: 5,
        );

        if (stock <= threshold) {
          lowStock++;
        }
      }

      bool connected = false;
      String username = 'Not connected';

      try {
        final instaResponse = await apiClient.get('/instagram/status');
        final data = instaResponse.data;

        connected = data['connected'] == true ||
            data['is_connected'] == true ||
            data['instagram_connected'] == true ||
            data['instagram_username'] != null;

        username = data['instagram_username']?.toString() ??
            data['username']?.toString() ??
            'Connected';
      } catch (_) {
        connected = false;
      }

      if (!mounted) return;

      setState(() {
        _productCount = products.length;
        _lowStockCount = lowStock;
        _instagramConnected = connected;
        _instagramUsername = connected ? '@$username' : 'Not connected';
      });
    } catch (e) {
      debugPrint('DASHBOARD LOAD ERROR: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _connectInstagram() async {
    try {
      await apiClient.post('/instagram/connect');
      await _loadDashboard();
    } catch (e) {
      debugPrint('INSTAGRAM CONNECT ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeHealth = _productCount == 0
        ? 0
        : (((_productCount - _lowStockCount) / _productCount) * 100).round();

    return Scaffold(
      backgroundColor: const Color(0xFF090E0C),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.25,
            colors: [
              Color(0xFF173125),
              Color(0xFF0B1714),
              Color(0xFF090E0C),
            ],
            stops: [0.0, 0.35, 1.0],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: ordifyGreen,
            backgroundColor: const Color(0xFF0B1510),
            onRefresh: _loadDashboard,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 130),
              children: [
                _GlitterHeader(
                  isLoading: _isLoading,
                  onRefresh: _loadDashboard,
                ),
                const SizedBox(height: 22),
                OrdifyGlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _GlowText(
                        'Business Command Center',
                        fontSize: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Track your catalog, Instagram connection, and daily operations from one place.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFDDEAE4),
                          height: 1.4,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OrdifyMetricCard(
                              title: 'Products',
                              value: '$_productCount',
                              icon: Icons.inventory_2_rounded,
                              color: ordifyGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OrdifyMetricCard(
                              title: 'Low Stock',
                              value: '$_lowStockCount',
                              icon: Icons.warning_amber_rounded,
                              color: ordifyYellow,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OrdifyMetricCard(
                              title: 'Health',
                              value: '$storeHealth%',
                              icon: Icons.favorite_rounded,
                              color: ordifyBlue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _InstagramCard(
                  connected: _instagramConnected,
                  username: _instagramUsername,
                  onConnect: _connectInstagram,
                ),
                const SizedBox(height: 24),
                const _GlowText(
                  'Quick Flow',
                  fontSize: 22,
                ),
                const SizedBox(height: 14),
                _ActionTile(
                  icon: Icons.analytics_rounded,
                  title: 'Analytics Hub',
                  subtitle:
                      'View revenue, orders, stock health and business insights',
                  color: const Color(0xFF9DF6FF),
                  onTap: () => context.push('/analytics'),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  subtitle:
                      'Manage business profile, Instagram handle and account info',
                  color: const Color(0xFFB788FF),
                  onTap: () => context.push('/settings'),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.receipt_long_rounded,
                  title: 'Orders Pipeline',
                  subtitle: 'Create and track customer orders',
                  color: ordifyGreen,
                  onTap: () => context.go('/orders'),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.people_alt_rounded,
                  title: 'Customer CRM',
                  subtitle: 'Manage buyers and repeat customers',
                  color: ordifyBlue,
                  onTap: () => context.go('/customers'),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.inventory_2_rounded,
                  title: 'Stock Control',
                  subtitle: 'Manage products and low stock alerts',
                  color: ordifyYellow,
                  onTap: () => context.go('/inventory'),
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  icon: Icons.auto_awesome_rounded,
                  title: 'OrdiFy AI',
                  subtitle: 'Get smart stock and sales suggestions',
                  color: const Color(0xFFB788FF),
                  onTap: () => context.go('/ai-tools'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlitterHeader extends StatelessWidget {
  const _GlitterHeader({
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
            color: ordifyGreen,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: ordifyGreen.withOpacity(0.42),
                blurRadius: 24,
              ),
            ],
          ),
          child: const Icon(
            Icons.dashboard_rounded,
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
                'Welcome back',
                style: TextStyle(
                  color: Color(0xFFE8FFF2),
                  fontWeight: FontWeight.w700,
                ),
              ),
              _GlowText(
                'OrdiFy Hub',
                fontSize: 27,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ordifyGreen.withOpacity(0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: ordifyGreen.withOpacity(0.35),
            ),
          ),
          child: Text(
            isLoading ? 'SYNCING' : 'LIVE',
            style: GoogleFonts.inter(
              color: ordifyGreen,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: isLoading ? null : onRefresh,
          icon: isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ordifyGreen,
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

class _InstagramCard extends StatelessWidget {
  const _InstagramCard({
    required this.connected,
    required this.username,
    required this.onConnect,
  });

  final bool connected;
  final String username;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final color = connected ? ordifyGreen : ordifyYellow;

    return OrdifyGlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              connected ? Icons.verified_rounded : Icons.link_rounded,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GlowText(
                  connected ? 'Instagram Connected' : 'Instagram Not Connected',
                  fontSize: 16,
                  soft: true,
                ),
                const SizedBox(height: 5),
                Text(
                  username,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE8FFF2),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onConnect,
            child: Text(
              connected ? 'Refresh' : 'Connect',
              style: GoogleFonts.inter(
                color: ordifyGreen,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Row(
          children: [
            Container(
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
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GlowText(
                    title,
                    fontSize: 17,
                    soft: true,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFE8FFF2),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFFE8FFF2),
              size: 16,
            ),
          ],
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
        color: const Color(0xFFF1F6F4),
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        shadows: [
          Shadow(
            color: ordifyGreen.withOpacity(0.12),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}