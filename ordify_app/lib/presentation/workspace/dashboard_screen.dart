import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import 'ordify_workspace_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      final productResponse =
          await apiClient.get('/products?page=1&limit=50');

      final products = productResponse.data['products'] ?? [];

      int lowStock = 0;
      for (final product in products) {
        final stock = _toInt(product['stock_count']);
        final threshold =
            _toInt(product['low_stock_threshold'], fallback: 5);

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
      backgroundColor: ordifyBg,
      body: OrdifyBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: ordifyGreen,
            onRefresh: _loadDashboard,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 145),
              children: [
                OrdifyTopHeader(
                  eyebrow: 'Welcome back',
                  title: 'OrdiFy Hub',
                  icon: Icons.dashboard_rounded,
                  badgeText: _isLoading ? 'Syncing' : 'Live',
                ),
                const SizedBox(height: 18),
                OrdifyGlassCard(
                  radius: 30,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Business Command Center',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Track your catalog, Instagram connection, and daily operations from one place.',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          height: 1.4,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OrdifyMetricCard(
                              title: 'Products',
                              value: '$_productCount',
                              icon: Icons.inventory_2_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OrdifyMetricCard(
                              title: 'Low Stock',
                              value: '$_lowStockCount',
                              icon: Icons.warning_amber_rounded,
                              color: ordifyYellow,
                            ),
                          ),
                          const SizedBox(width: 10),
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
                OrdifyGlassCard(
                  radius: 28,
                  child: Row(
                    children: [
                      Container(
                        height: 54,
                        width: 54,
                        decoration: BoxDecoration(
                          color: (_instagramConnected
                                  ? ordifyGreen
                                  : ordifyYellow)
                              .withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(
                          _instagramConnected
                              ? Icons.verified_rounded
                              : Icons.link_rounded,
                          color: _instagramConnected
                              ? ordifyGreen
                              : ordifyYellow,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _instagramConnected
                                  ? 'Instagram Connected'
                                  : 'Instagram Not Connected',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _instagramUsername,
                              style: GoogleFonts.inter(
                                color: Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: _connectInstagram,
                        child: Text(
                          _instagramConnected ? 'Refresh' : 'Connect',
                          style: GoogleFonts.inter(
                            color: ordifyGreen,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const OrdifySectionTitle(title: 'Quick Flow'),
                const SizedBox(height: 12),
                const OrdifyActionTile(
                  icon: Icons.receipt_long_rounded,
                  title: 'Orders Pipeline',
                  subtitle: 'Create and track customer orders',
                ),
                const SizedBox(height: 12),
                const OrdifyActionTile(
                  icon: Icons.people_alt_rounded,
                  title: 'Customer CRM',
                  subtitle: 'Manage buyers and repeat customers',
                  color: ordifyBlue,
                ),
                const SizedBox(height: 12),
                const OrdifyActionTile(
                  icon: Icons.auto_awesome_rounded,
                  title: 'OrdiFy AI',
                  subtitle: 'Get smart stock and sales suggestions',
                  color: ordifyYellow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}