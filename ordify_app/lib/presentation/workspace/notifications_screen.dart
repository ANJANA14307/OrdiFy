import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ordify_app/core/network/api_client.dart';

import 'ordify_workspace_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool isLoading = true;
  String? errorMessage;

  List<dynamic> notifications = [];

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await apiClient.get('/notifications');

      setState(() {
        notifications = response.data['notifications'] ?? [];
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  int get unreadCount {
    return notifications.where((notification) {
      if (notification is! Map) return false;
      return notification['is_read'] != true;
    }).length;
  }

  int get successCount {
    return notifications.where((notification) {
      if (notification is! Map) return false;
      return notification['type'] == 'success';
    }).length;
  }

  int get warningCount {
    return notifications.where((notification) {
      if (notification is! Map) return false;
      return notification['type'] == 'warning';
    }).length;
  }

  Future<void> markAllRead() async {
    try {
      await apiClient.patch('/notifications/mark-all-read');
      await fetchNotifications();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All notifications marked as read')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> markRead(String notificationId) async {
    try {
      await apiClient.patch('/notifications/$notificationId/read');
      await fetchNotifications();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  IconData iconForType(String type) {
    if (type == 'success') return Icons.check_circle_rounded;
    if (type == 'warning') return Icons.warning_rounded;
    if (type == 'error') return Icons.error_rounded;
    return Icons.info_rounded;
  }

  Color colorForType(String type) {
    if (type == 'success') return const Color(0xFF34F087);
    if (type == 'warning') return const Color(0xFFFFC857);
    if (type == 'error') return const Color(0xFFFF5E73);
    return const Color(0xFF9DF6FF);
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
                      onRefresh: fetchNotifications,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                        children: [
                          _Header(
                            onBack: () => context.pop(),
                            onRefresh: fetchNotifications,
                          ),
                          const SizedBox(height: 18),
                          OrdifyGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Notification Command Center',
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
                                  'Track payments, invoices, stock alerts and important business updates.',
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
                                      child: OrdifyMetricCard(
                                        icon: Icons.notifications_active_rounded,
                                        value: unreadCount.toString(),
                                        label: 'Unread',
                                        color: const Color(0xFF34F087),
                                        minHeight: 112,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OrdifyMetricCard(
                                        icon: Icons.check_circle_rounded,
                                        value: successCount.toString(),
                                        label: 'Success',
                                        color: const Color(0xFF9DF6FF),
                                        minHeight: 112,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OrdifyMetricCard(
                                        icon: Icons.warning_rounded,
                                        value: warningCount.toString(),
                                        label: 'Alerts',
                                        color: const Color(0xFFFFC857),
                                        minHeight: 112,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (notifications.isNotEmpty)
                            OrdifyGlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF34F087),
                                        side: BorderSide(
                                          color: Colors.white.withOpacity(0.22),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                        ),
                                      ),
                                      onPressed: markAllRead,
                                      icon: const Icon(Icons.done_all_rounded),
                                      label: const Text(
                                        'Mark All Read',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (notifications.isNotEmpty)
                            const SizedBox(height: 16),
                          if (notifications.isEmpty)
                            const _EmptyNotifications()
                          else
                            ...notifications.map((notification) {
                              final notificationMap =
                                  Map<String, dynamic>.from(
                                notification as Map,
                              );

                              final type =
                                  notificationMap['type']?.toString() ??
                                      'info';

                              final isRead =
                                  notificationMap['is_read'] == true;

                              return _NotificationCard(
                                title: notificationMap['title']?.toString() ??
                                    'Notification',
                                message:
                                    notificationMap['message']?.toString() ??
                                        '',
                                type: type,
                                isRead: isRead,
                                icon: iconForType(type),
                                color: colorForType(type),
                                onMarkRead: isRead
                                    ? null
                                    : () => markRead(
                                          notificationMap['id'].toString(),
                                        ),
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
                'Business alerts',
                style: TextStyle(
                  color: Color(0xFFE8FFF2),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Notifications Hub',
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.icon,
    required this.color,
    required this.onMarkRead,
  });

  final String title;
  final String message;
  final String type;
  final bool isRead;
  final IconData icon;
  final Color color;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: OrdifyGlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight:
                                isRead ? FontWeight.w800 : FontWeight.w900,
                            shadows: const [
                              Shadow(
                                color: Color(0xFFFFC8C8),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                      _StatusPill(
                        text: type.toUpperCase(),
                        color: color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFFE8FFF2),
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                  if (!isRead) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF34F087),
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.22),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: onMarkRead,
                        icon: const Icon(Icons.done_rounded, size: 18),
                        label: const Text(
                          'Read',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
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

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return OrdifyGlassCard(
      child: const Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 58,
            color: Color(0xFF34F087),
          ),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Payment, invoice and stock alerts will appear here.',
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