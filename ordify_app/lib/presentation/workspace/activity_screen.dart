import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ordify_app/core/network/api_client.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    super.key,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<dynamic> logs = [];

  @override
  void initState() {
    super.initState();
    fetchActivity();
  }

  Future<void> fetchActivity() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await apiClient.get('/activity');

      setState(() {
        logs = response.data['logs'] ?? [];
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  int countByKeyword(String keyword) {
    return logs.where((log) {
      if (log is! Map) return false;

      final action = log['action']?.toString().toLowerCase() ?? '';
      final entityType = log['entity_type']?.toString().toLowerCase() ?? '';

      return action.contains(keyword) || entityType.contains(keyword);
    }).length;
  }

  IconData iconForAction(String action, String entityType) {
    final text = '$action $entityType'.toLowerCase();

    if (text.contains('payment')) return Icons.payments_rounded;
    if (text.contains('invoice')) return Icons.picture_as_pdf_rounded;
    if (text.contains('stock') || text.contains('product')) {
      return Icons.inventory_2_rounded;
    }
    if (text.contains('order')) return Icons.receipt_long_rounded;
    if (text.contains('email')) return Icons.email_rounded;
    if (text.contains('whatsapp')) return Icons.chat_rounded;

    return Icons.history_rounded;
  }

  Color colorForAction(String action, String entityType) {
    final text = '$action $entityType'.toLowerCase();

    if (text.contains('payment')) return const Color(0xFF34F087);
    if (text.contains('invoice')) return const Color(0xFF9DF6FF);
    if (text.contains('stock') || text.contains('product')) {
      return const Color(0xFFFFC857);
    }
    if (text.contains('order')) return const Color(0xFFB788FF);
    if (text.contains('email') || text.contains('whatsapp')) {
      return const Color(0xFF50E3C2);
    }

    return const Color(0xFFE8FFF2);
  }

  String formatAction(String action) {
    if (action.trim().isEmpty) return 'Activity';

    return action
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1);
        })
        .join(' ');
  }

  String formatDate(dynamic value) {
    if (value == null) return '';

    final raw = value.toString();

    try {
      final date = DateTime.parse(raw).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');

      return '$day/$month • $hour:$minute';
    } catch (_) {
      return raw;
    }
  }

  void backOrOrders() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/orders');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      onRefresh: fetchActivity,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                        children: [
                          _Header(
                            onBack: backOrOrders,
                            onRefresh: fetchActivity,
                          ),
                          const SizedBox(height: 18),

                          _GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Activity Command Center',
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
                                  'A clear business timeline of payments, invoices, stock changes and order actions.',
                                  style: TextStyle(
                                    color: Color(0xFFE8FFF2),
                                    fontWeight: FontWeight.w700,
                                    height: 1.35,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricTile(
                                        icon: Icons.history_rounded,
                                        value: logs.length.toString(),
                                        label: 'Total',
                                        color: const Color(0xFF34F087),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _MetricTile(
                                        icon: Icons.payments_rounded,
                                        value:
                                            countByKeyword('payment').toString(),
                                        label: 'Payments',
                                        color: const Color(0xFF9DF6FF),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _MetricTile(
                                        icon: Icons.inventory_2_rounded,
                                        value: countByKeyword('stock').toString(),
                                        label: 'Stock',
                                        color: const Color(0xFFFFC857),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          const Text(
                            'Timeline',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: Color(0xFFFFD6D6),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          if (logs.isEmpty)
                            const _EmptyActivity()
                          else
                            ...logs.map((log) {
                              final logMap =
                                  Map<String, dynamic>.from(log as Map);

                              final action =
                                  logMap['action']?.toString() ?? 'activity';

                              final description =
                                  logMap['description']?.toString() ?? '';

                              final entityType =
                                  logMap['entity_type']?.toString() ?? '';

                              final createdAt = formatDate(
                                logMap['created_at'],
                              );

                              final icon = iconForAction(action, entityType);
                              final color = colorForAction(action, entityType);

                              return _ActivityCard(
                                icon: icon,
                                color: color,
                                action: formatAction(action),
                                description: description,
                                entityType: entityType,
                                createdAt: createdAt,
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
                'Business timeline',
                style: TextStyle(
                  color: Color(0xFFE8FFF2),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Activity Hub',
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.color,
    required this.action,
    required this.description,
    required this.entityType,
    required this.createdAt,
  });

  final IconData icon;
  final Color color;
  final String action;
  final String description;
  final String entityType;
  final String createdAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: _GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
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
                const SizedBox(height: 8),
                Container(
                  width: 2,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          action,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            shadows: [
                              Shadow(
                                color: Color(0xFFFFC8C8),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (entityType.isNotEmpty)
                        _StatusPill(
                          text: entityType.toUpperCase(),
                          color: color,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description.isEmpty ? 'No description available' : description,
                    style: const TextStyle(
                      color: Color(0xFFE8FFF2),
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if (createdAt.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: Color(0xFFE8FFF2),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          createdAt,
                          style: const TextStyle(
                            color: Color(0xFFE8FFF2),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.42)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
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
        border: Border.all(
          color: Colors.white.withOpacity(0.22),
        ),
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

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return const _GlassCard(
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            size: 58,
            color: Color(0xFF34F087),
          ),
          SizedBox(height: 16),
          Text(
            'No activity yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Payments, invoices, stock updates and order changes will appear here.',
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