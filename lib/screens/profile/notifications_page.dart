import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/database_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared_widgets.dart';

/// The signed-in user's notification inbox, fetched live from the API.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  String? _error;
  List<AppNotification> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      items = await DatabaseService.fetchMyNotifications();
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load notifications.';
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await DatabaseService.markAllNotificationsRead();
    await _load();
  }

  IconData _iconFor(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.order:
        return Icons.local_shipping_rounded;
      case NotificationKind.offer:
        return Icons.local_offer_rounded;
      case NotificationKind.support:
        return Icons.support_agent_rounded;
      case NotificationKind.general:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(NotificationKind kind) {
    switch (kind) {
      case NotificationKind.order:
        return AppColors.blueDark;
      case NotificationKind.offer:
        return AppColors.pink;
      case NotificationKind.support:
        return AppColors.warning;
      case NotificationKind.general:
        return AppColors.textMuted;
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final unread = items.where((n) => n.unread).length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (!_loading && unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load notifications',
                        message: _error!,
                      ),
                      const SizedBox(height: 6),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 60),
                            EmptyState(
                              icon: Icons.notifications_none_rounded,
                              title: 'No notifications',
                              message:
                                  "You're all caught up! We'll let you know when\nsomething needs your attention.",
                            ),
                          ],
                        )
                      : _buildList(),
                ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 30),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final n = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SoftCard(
            color: n.unread ? const Color(0xFFF1F8FF) : Colors.white,
            onTap: n.unread
                ? () async {
                    await DatabaseService.markNotificationRead(n.id);
                    await _load();
                  }
                : null,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: _colorFor(n.kind).withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(_iconFor(n.kind), color: _colorFor(n.kind), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          if (n.unread)
                            Container(
                              height: 8,
                              width: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.pink,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        n.subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _timeAgo(n.time),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
