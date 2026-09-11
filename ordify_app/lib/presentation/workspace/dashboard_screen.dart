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
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
                          color: const Color(0xFFDCE7E2),
                          height: 1.4,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OrdifyMetricCard(
                              title: 'Products',
                              value: '$_productCount',
                              icon: Icons.inventory_2_rounded,
                              color: const Color(0xFFEFF7F5),
                              iconColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OrdifyMetricCard(
                              title: 'Low Stock',
                              value: '$_lowStockCount',
                              icon: Icons.warning_amber_rounded,
                              color: const Color(0xFFF4F0E7),
                              iconColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OrdifyMetricCard(
                              title: 'Health',
                              value: '$storeHealth%',
                              icon: Icons.favorite_rounded,
                              color: const Color(0xFFEFF4FB),
                              iconColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _InstagramCard(
                  connected: _instagramConnected,
                  username: _instagramUsername,
                  onConnect: _connectInstagram,
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 760;

                    final buttons = <Widget>[
                      _ShortcutTile(
                        icon: Icons.analytics_rounded,
                        title: 'Analytics',
                        color: const Color(0xFFE7F3FF),
                        onTap: () => context.push('/analytics'),
                      ),
                      _ShortcutTile(
                        icon: Icons.receipt_long_rounded,
                        title: 'Orders',
                        color: const Color(0xFFE9F9EE),
                        onTap: () => context.go('/orders'),
                      ),
                      _ShortcutTile(
                        icon: Icons.inventory_2_rounded,
                        title: 'Stock',
                        color: const Color(0xFFF5F3EA),
                        onTap: () => context.go('/inventory'),
                      ),
                      _ShortcutTile(
                        icon: Icons.people_alt_rounded,
                        title: 'CRM',
                        color: const Color(0xFFF2EBFF),
                        onTap: () => context.go('/customers'),
                      ),
                      _ShortcutTile(
                        icon: Icons.auto_awesome_rounded,
                        title: 'AI',
                        color: const Color(0xFFE8F5F0),
                        onTap: () => context.go('/ai-tools'),
                      ),
                    ];

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: buttons,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 192,
                            child: _SidebarNav(
                              items: const [
                                _SidebarItemData(
                                  title: 'Quick Flow',
                                  icon: Icons.flash_on_rounded,
                                  selected: true,
                                ),
                                _SidebarItemData(
                                  title: 'Settings',
                                  icon: Icons.settings_rounded,
                                  selected: false,
                                ),
                              ],
                              onTap: (title) {
                                if (title == 'Settings') {
                                  context.push('/settings');
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: buttons,
                        ),
                        const SizedBox(height: 12),
                        _SidebarNav(
                          items: const [
                            _SidebarItemData(
                              title: 'Quick Flow',
                              icon: Icons.flash_on_rounded,
                              selected: true,
                            ),
                            _SidebarItemData(
                              title: 'Settings',
                              icon: Icons.settings_rounded,
                              selected: false,
                            ),
                          ],
                          onTap: (title) {
                            if (title == 'Settings') {
                              context.push('/settings');
                            }
                          },
                        ),
                      ],
                    );
                  },
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
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          child: const Icon(
            Icons.dashboard_rounded,
            color: Colors.white,
            size: 24,
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
                  fontSize: 12,
                ),
              ),
              _GlowText(
                'OrdiFy Hub',
                fontSize: 27,
              ),
            ],
          ),
        ),
        if (!isLoading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withOpacity(0.07),
              ),
            ),
            child: Text(
              'LIVE',
              style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          )
        else
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
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
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            child: Icon(
              connected ? Icons.verified_rounded : Icons.link_rounded,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GlowText(
                  connected ? 'Instagram Connected' : 'Instagram Not Connected',
                  fontSize: 15,
                  soft: true,
                ),
                const SizedBox(height: 4),
                Text(
                  username,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE8FFF2),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItemData {
  const _SidebarItemData({
    required this.title,
    required this.icon,
    required this.selected,
  });

  final String title;
  final IconData icon;
  final bool selected;
}

class _SidebarNav extends StatelessWidget {
  const _SidebarNav({
    required this.items,
    required this.onTap,
  });

  final List<_SidebarItemData> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      padding: const EdgeInsets.all(14),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Menu',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onTap(item.title),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: item.selected
                        ? Colors.white.withOpacity(0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: item.selected
                          ? Colors.white.withOpacity(0.08)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 18,
                        color: item.selected ? Colors.white : Colors.white60,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.inter(
                            color: item.selected ? Colors.white : Colors.white60,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 72) / 2,
      child: OrdifyGlassCard(
        padding: const EdgeInsets.all(16),
        radius: 22,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Icon(
                  icon,
                  color: color.withOpacity(0.9),
                  size: 20,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
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
        color: const Color(0xFFF1F6F4),
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}