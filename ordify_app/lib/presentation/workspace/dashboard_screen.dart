import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/api_client.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  bool _instagramConnected = false;
  String? _loadError;
  String? _instagramError;
  String _instagramUsername = '';
  int _productCount = 0;
  int _lowStockCount = 0;

  String get _businessName {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata;
    final businessName = metadata?['business_name']?.toString().trim();
    if (businessName != null && businessName.isNotEmpty) return businessName;

    final displayName = metadata?['full_name']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.split(' ').first;
    }

    final emailName = user?.email?.split('@').first.trim();
    if (emailName != null && emailName.isNotEmpty) return emailName;
    return 'there';
  }

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
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
        _instagramError = null;
      });
    }

    try {
      final productResponse = await apiClient.get(
        '/products',
        queryParameters: {'page': 1, 'limit': 50},
      );
      final data = productResponse.data;
      final rawProducts = data is Map ? data['products'] : null;
      if (rawProducts is! List) {
        throw const FormatException('The products response is invalid.');
      }

      var lowStockCount = 0;
      for (final product in rawProducts.whereType<Map>()) {
        final stock = _toInt(product['stock_count']);
        final threshold = _toInt(product['low_stock_threshold'], fallback: 5);
        if (stock <= threshold) lowStockCount++;
      }

      var instagramConnected = false;
      var instagramUsername = '';
      String? instagramError;
      try {
        final response = await apiClient.get('/instagram/status');
        final status = response.data;
        if (status is! Map) {
          throw const FormatException(
            'The Instagram status response is invalid.',
          );
        }
        instagramConnected =
            status['connected'] == true ||
            status['is_connected'] == true ||
            status['instagram_connected'] == true ||
            status['instagram_username'] != null;
        instagramUsername =
            status['instagram_username']?.toString() ??
            status['username']?.toString() ??
            '';
      } catch (error) {
        instagramError = error.toString();
      }

      if (!mounted) return;
      setState(() {
        _productCount = rawProducts.length;
        _lowStockCount = lowStockCount;
        _instagramConnected = instagramConnected;
        _instagramUsername = instagramUsername;
        _instagramError = instagramError;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B100E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B100E),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 22,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ORDIFY',
              style: GoogleFonts.inter(
                color: const Color(0xFF8EE2B6),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.7,
              ),
            ),
            Text(
              'Welcome, $_businessName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFFF0F4F1),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _isLoading ? null : _loadDashboard,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              switch (value) {
                case 'notifications':
                  context.push('/notifications');
                case 'activity':
                  context.push('/activity');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'notifications',
                child: ListTile(
                  leading: Icon(Icons.notifications_outlined),
                  title: Text('Notifications'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'activity',
                child: ListTile(
                  leading: Icon(Icons.history_rounded),
                  title: Text('Activity'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: const Color(0xFF8EE2B6),
          backgroundColor: const Color(0xFF171E1A),
          onRefresh: _loadDashboard,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 132),
                    children: [
                      _WelcomeCard(
                        name: _businessName,
                        onAddProduct: () => context.go('/inventory'),
                        onShareCatalog: () => context.push('/catalog-share'),
                      ),
                      const SizedBox(height: 28),
                      const _SectionHeading(
                        title: 'Your store',
                        subtitle: 'A quick look at your inventory',
                      ),
                      const SizedBox(height: 14),
                      if (_loadError != null)
                        _LoadErrorCard(
                          message: _loadError!,
                          onRetry: _loadDashboard,
                        )
                      else
                        LayoutBuilder(
                          builder: (context, metricConstraints) {
                            final columns = metricConstraints.maxWidth < 480
                                ? 1
                                : 2;
                            return GridView.count(
                              crossAxisCount: columns,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: columns == 1 ? 3.3 : 4.2,
                              children: [
                                _MetricCard(
                                  title: 'Active products',
                                  value: _isLoading ? '—' : '$_productCount',
                                  subtitle: 'In your inventory',
                                  icon: Icons.inventory_2_outlined,
                                  accent: const Color(0xFF8EE2B6),
                                ),
                                _MetricCard(
                                  title: 'Needs attention',
                                  value: _isLoading ? '—' : '$_lowStockCount',
                                  subtitle: 'Low or out of stock',
                                  icon: Icons.priority_high_rounded,
                                  accent: const Color(0xFFF0C878),
                                ),
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 28),
                      const _SectionHeading(
                        title: 'Quick actions',
                        subtitle: 'Get to the tools you use most',
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (context, actionConstraints) {
                          final columns = actionConstraints.maxWidth >= 900
                              ? 4
                              : actionConstraints.maxWidth >= 600
                              ? 3
                              : 2;
                          return GridView.count(
                            crossAxisCount: columns,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: columns == 2 ? 1.65 : 1.35,
                            children: [
                              _ActionCard(
                                title: 'Orders',
                                subtitle: 'View and manage',
                                icon: Icons.receipt_long_outlined,
                                onTap: () => context.go('/orders'),
                              ),
                              _ActionCard(
                                title: 'Inventory',
                                subtitle: 'Products and stock',
                                icon: Icons.inventory_2_outlined,
                                onTap: () => context.go('/inventory'),
                              ),
                              _ActionCard(
                                title: 'Customers',
                                subtitle: 'Your customer list',
                                icon: Icons.people_outline_rounded,
                                onTap: () => context.go('/customers'),
                              ),
                              _ActionCard(
                                title: 'Analytics',
                                subtitle: 'Business performance',
                                icon: Icons.query_stats_rounded,
                                onTap: () => context.push('/analytics'),
                              ),
                              _ActionCard(
                                title: 'WhatsApp orders',
                                subtitle: 'Social order inbox',
                                icon: Icons.chat_bubble_outline_rounded,
                                onTap: () => context.push('/whatsapp-orders'),
                              ),
                              _ActionCard(
                                title: 'Instagram tools',
                                subtitle: 'Links and replies',
                                icon: Icons.camera_alt_outlined,
                                onTap: () => context.push('/instagram-tools'),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      const _SectionHeading(
                        title: 'Channels',
                        subtitle: 'Keep your storefront connected',
                      ),
                      const SizedBox(height: 14),
                      _InstagramStatusCard(
                        connected: _instagramConnected,
                        username: _instagramUsername,
                        error: _instagramError,
                        onTap: () => context.push('/instagram-tools'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.name,
    required this.onAddProduct,
    required this.onShareCatalog,
  });

  final String name;
  final VoidCallback onAddProduct;
  final VoidCallback onShareCatalog;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF17231C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2A3B30)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onAddProduct,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8EE2B6),
                  foregroundColor: const Color(0xFF0D1811),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Add product'),
              ),
              OutlinedButton.icon(
                onPressed: onShareCatalog,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE7EEE9),
                  side: const BorderSide(color: Color(0xFF43564A)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.ios_share_rounded, size: 17),
                label: const Text('Share catalog'),
              ),
            ],
          );
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR BUSINESS, AT A GLANCE',
                style: GoogleFonts.inter(
                  color: const Color(0xFF8EE2B6),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Good to see you, $name.',
                style: GoogleFonts.inter(
                  color: const Color(0xFFF1F5F2),
                  fontSize: constraints.maxWidth < 480 ? 23 : 29,
                  height: 1.15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage products, orders, and customer conversations from one place.',
                style: GoogleFonts.inter(
                  color: const Color(0xFFAEBBB2),
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
            ],
          );

          if (constraints.maxWidth >= 720) {
            return Row(
              children: [
                Expanded(child: intro),
                const SizedBox(width: 20),
                actions,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [intro, const SizedBox(height: 20), actions],
          );
        },
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: const Color(0xFFEAF0EC),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: const Color(0xFF89968D),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF151C18),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF26312A)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFBEC9C1),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF0F4F1),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF849087),
                    fontSize: 10,
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF151C18),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFF26312A)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: const Color(0xFF8EE2B6), size: 22),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAF0EC),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF89968D),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstagramStatusCard extends StatelessWidget {
  const _InstagramStatusCard({
    required this.connected,
    required this.username,
    required this.error,
    required this.onTap,
  });

  final bool connected;
  final String username;
  final String? error;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = error != null
        ? const Color(0xFFF0C878)
        : connected
        ? const Color(0xFF8EE2B6)
        : const Color(0xFFBBC5BE);
    final title = error != null
        ? 'Instagram status unavailable'
        : connected
        ? 'Instagram connected'
        : 'Connect Instagram tools';
    final detail = error != null
        ? 'Open Instagram tools to check the connection.'
        : connected
        ? (username.isEmpty ? 'Your account is ready' : '@$username')
        : 'Set up catalog links and customer replies.';

    return Material(
      color: const Color(0xFF151C18),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFF26312A)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.camera_alt_outlined, color: accent),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFEAF0EC),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF89968D),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF89968D),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadErrorCard extends StatelessWidget {
  const _LoadErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF251B16),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF493528)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: Color(0xFFF0C878)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not load store data: $message',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: const Color(0xFFE7D8C6),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
